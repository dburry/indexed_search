
require 'valium'
require 'activerecord-import'

#
# all the unique words that are indexed
#
# id
# word
# stem
# soundex
#

module IndexedSearch
  class Word < ActiveRecord::Base
    has_many :entries, :class_name => 'IndexedSearch::Entry'

    extend IndexedSearch::Collision
    extend IndexedSearch::ResetTable

    # limit to only considering this many top ranked matches per each word match
    # this is to limit adverse speed impact of very common words
    # for best speed tune this via experimentation to be as low as you can, and still give you good results
    # note: words.rank_limit column needs to be rebuilt (with #update_ranks) to take advantage of any changes to this
    cattr_accessor :rank_reduction_factor
    self.rank_reduction_factor = 1200
    
    # don't drop entries due to rank_reduction_factor, if their rank is at or above this rank
    # set this lower to limit the carnage rank_reduction_factor can cause to some really-common-but-important words
    # of course at the expense to some increased time for those words...
    # in practice this is pretty ineffectual to use, because even unimportant words are used in important
    # contexts, making them slow your search to a crawl if you reduce it by much
    cattr_accessor :min_rank_reduction
    self.min_rank_reduction = 120
    
    # What types of matching algorithms to consider when building an index.  Some algorithms need an extra column in
    # the word list table of the index (:stem, :soundex, :metaphone, :double_metaphone currently).  Note adding to
    # this will require rebuilding the whole index.
    mattr_accessor :index_match_types
    self.index_match_types = [:stem, :soundex, :metaphone, :double_metaphone]
    
    # Set maximum word length
    cattr_accessor :max_length
    self.max_length = 64

    GROUP_BY_AMOUNT = 1_000

    # when indexing, the words may or may not exist in the model yet...
    # param: array of word strings
    # returns: array of word model ids (some may be previously existing, some may be brand new)
    def self.find_or_create_word_ids(words, retry_count=0)
      retrying_on_collision do
        id_map = existing_word_id_map(words)
        words.collect { |w| id_map.has_key?(w) ? id_map[w] : create_word(w) }
      end
    end
    # another version that returns a word->id map hash, instead of just an ids array
    def self.word_id_map(words, retry_count=0)
      retrying_on_collision do
        id_map = existing_word_id_map(words)
        words.reject { |w| id_map.has_key?(w) }.each { |w| id_map[w] = create_word(w) }
        id_map
      end
    end
    def self.existing_word_id_map(words)
      id_map = {}
      where(:word => words).values_of(:id, :word).each { |id, w| id_map[w] = id }
      id_map
    end
    def self.create_word(word)
      attrs = {:word => word}
      index_match_types.each do |type|
        klass = IndexedSearch::Match.match_class(type)
        if klass.match_against_term?(word)
          vals = klass.make_index_value(word)
          atrs = klass.matcher_attribute
          if atrs.kind_of?(Array)
            # TODO: isn't this logic duplicated somewhere else?
            (0...atrs.length).to_a.each { |idx| attrs.merge!({atrs[idx] => vals[idx]}) }
          else
            attrs.merge!({atrs => vals})
          end
        end
      end
      # import would be faster but it doesn't return the id
      #import(attrs.keys, [attrs.values], :validate => false)
      create!(attrs, :without_protection => true).id
    end

    # quickly increment entries_count column for certain word ids (can be used when adding entries)
    def self.incr_counts_by_ids(ids, offset=1)
      where(:id => ids).order('id').update_all("entries_count = entries_count + #{offset}")
    end
    
    # quickly decrement entries_count column for certain word ids (can be used when removing entries)
    def self.decr_counts_by_ids(ids, offset=1)
      where(:id => ids).order('id').update_all("entries_count = entries_count - #{offset}")
    end

    # update entries_count column for words
    def self.update_counts
      cnt = 0
      old_counts = Hash[scoped.values_of(:id, :entries_count)]
      old_counts.keys.in_groups_of(GROUP_BY_AMOUNT, false) do |old_id_group|
        updates = {}
        IndexedSearch::Entry.where(:word_id => old_id_group).group(:word_id).count.each do |id, new_count|
	  updates[id] = new_count if old_counts[id] != new_count
	end
        updates.invert_multi.each { |new_count, up_ids| cnt += scoped.where(:id => up_ids).order('id').update_all(:entries_count => new_count) }
      end
      cnt
    end

    # optimized update of rank_limit column for certain word ids
    def self.update_ranks_by_ids(ids)
      cnt = 0
      if ids.length == 1
        (c, old_lim) = where(:id => ids.first).values_of(:entries_count, :rank_limit).first
        if c  > rank_reduction_factor
          new_lim = calculate_rank_limit_for_id(ids.first)
          cnt += where(:id => ids.first).update_all(:rank_limit => new_lim) if new_lim != old_lim
        elsif old_lim > 0
          cnt += zero_out_ranks_by_id(ids.first)
        end
      else
        cnt = update_zeroed_ranks
	updates = {}
        ids.in_groups_of(GROUP_BY_AMOUNT, false).each { |id_group| updates.merge!(where(:id => id_group).rank_limit_updates) }
        cnt += update_rank_limits(updates)
      end
      cnt
    end

    # update rank_limit column for words
    def self.update_ranks
      update_zeroed_ranks + update_rank_limits(rank_limit_updates)
    end

    private
    def self.update_zeroed_ranks
      ids = rank_limit_needs_zeroing.value_of(:id)
      return 0 if ids.blank?
      cnt = 0
      ids.in_groups_of(1000, false).each { |id_group| cnt += zero_out_ranks_by_id(id_group) }
      cnt
    end
    def self.zero_out_ranks_by_id(ids)
      scoped.where(:id => ids).order('id').update_all(:rank_limit => 0)
    end
    def self.calculate_rank_limit_for_id(id)
      [IndexedSearch::Entry.where(:word_id => id).order('rank DESC').limit(1).offset(rank_reduction_factor).value_of(:rank).first || 0, min_rank_reduction].min
    end
    def self.rank_limit_updates
      updates = {}
      rank_limit_needs_checking.values_of(:id, :rank_limit).each do |id, old_lim|
        new_lim = calculate_rank_limit_for_id(id)
        updates[id] = new_lim if new_lim != old_lim
      end
      updates
    end
    def self.update_rank_limits(updates)
      cnt = 0
      updates.invert_multi.each do |lim, up_ids|
        up_ids.in_groups_of(GROUP_BY_AMOUNT, false).each { |id_group| cnt += scoped.where(:id => id_group).update_all(:rank_limit => lim) }
      end
      cnt
    end
    scope :rank_limit_needs_zeroing, where(arel_table[:entries_count].lteq(rank_reduction_factor).and(arel_table[:rank_limit].gt(0)))
    scope :rank_limit_needs_checking, where(arel_table[:entries_count].gt(rank_reduction_factor))
    public
    
    # cleanup after reindexing/deleting from main index
    # doesn't hurt index for extra words to hang around, just wastes space
    # also resets auto increment if the entire database is purged
    def self.delete_orphaned
      cnt = empty_entry.delete_all
      reset_auto_increment
      cnt
    end

    # scope used by delete_orphaned
    scope :empty_entry, {:conditions => 'NOT EXISTS (SELECT * FROM entries WHERE entries.word_id=words.id)'}

    # faster version of delete_orphaned that depends on the entries_count column being up to date
    def self.delete_empty
      cnt = where(:entries_count => 0).delete_all
      reset_auto_increment
      cnt
    end

    # update entries_count, remove orphan words no longer used, and rank_limit all at once
    def self.fix_counts_orphans_and_ranks
      update_counts + delete_empty + update_ranks
    end

    def to_s
      word
    end
  end
end
