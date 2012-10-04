
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

    def self.update_ranks_by_ids(ids)
      if ids.length == 1
        (cnt, lim) = where(:id => ids).values_of(:entries_count, :rank_limit).first
        if cnt  > rank_reduction_factor
          where(:id => ids).update_all(update_rank_sql(ids[0]))
        elsif lim != 0
          where(:id => ids).update_all(:rank_limit => 0)
        end
      else
        where(:id => ids).update_ranks
      end
    end
    def self.update_counts_by_ids(ids)
      ids.each { |id| where(:id => id).update_all(update_count_sql(id)) }
    end
    def self.incr_counts_by_ids(ids)
      where(:id => ids).order('id').update_all("entries_count = entries_count + 1")
    end
    def self.decr_counts_by_ids(ids)
      where(:id => ids).order('id').update_all("entries_count = entries_count - 1")
    end
    def self.update_ranks
      scoped.where(arel_table[:entries_count].lteq(rank_reduction_factor)).order('id').update_all(:rank_limit => 0)
      scoped.where(arel_table[:entries_count].gt(rank_reduction_factor)).value_of(:id).each do |id|
        IndexedSearch::Word.where(:id => id).update_all(update_rank_sql(id))
      end
      # maybe technically faster in some cases? but internally locks table for a while:
      #scoped.where(arel_table[:entries_count].gt(rank_reduction_factor)).order('id').update_all(update_rank_sql('words.id'))
    end
    def self.update_counts
      update_counts_by_ids(scoped.value_of(:id))
      # maybe faster? but can internally lock table for a long time:
      # scoped.order('id').update_all(update_count_sql('words.id'))
    end
    # a sql string suitable for passing to #update_all
    # pass an id to do one word row, or the string 'words.id' to do a mass update (might lock table for a long time tho)
    # note parameter is assumed to be safe
    def self.update_rank_sql(id_text)
      "rank_limit=LEAST((SELECT rank FROM entries WHERE word_id=#{id_text} ORDER BY rank DESC LIMIT 1 OFFSET #{rank_reduction_factor}), #{min_rank_reduction})"
    end
    # a sql string suitable for passing to #update_all
    # pass an id to do one word row, or the string 'words.id' to do a mass update (might lock table for a long time tho)
    # note parameter is assumed to be safe
    def self.update_count_sql(id_text)
      "entries_count=(SELECT COUNT(*) FROM entries WHERE word_id=#{id_text})"
    end
    
    # cleanup after reindexing/deleting from main index
    # doesn't hurt index for extra words to hang around, just wastes space
    # also resets auto increment if the entire database is purged
    def self.delete_orphaned
      empty_entry.delete_all
      reset_auto_increment
    end
    # scope used by delete_orphaned
    scope :empty_entry, {:conditions => 'NOT EXISTS (SELECT * FROM entries WHERE entries.word_id=words.id)'}

    def to_s
      word
    end
  end
end
