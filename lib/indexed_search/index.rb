
require 'each_batched'
require 'activerecord-import'
require 'indexed_search/core_ext/hash'

# 
# Utility module containing what is needed to index a given model for searching
# 
# create an index, for example, in a rake task:
#   Foo.extend IndexedSearch::Index
#   Foo.create_search_index # (or update_ or delete_)
# 
# setup an ActiveRecord model that stays up to date all the time on the fly:
#   class Foo < ActiveRecord::Base
#     include IndexedSearch::Index
#   end
#   class FooIndexer < ActiveModel::Observer
#     def after_create(foo)
#       foo.create_search_index
#     end
#     def after_update(foo)
#       # rule of thumb is check everything in search_index_info:
#       # note: foo.<attribute>_changed? doesn't seem to work right with null values...
#       if foo.name_was != foo.name || foo.description_was != foo.description || foo.alliance_id_was != foo.alliance_id
#         foo.update_search_index
#       end
#       # if changes to foo here causes reindexing to occur in any related models, then do those too:
#       if foo.alliance_id_was != foo.alliance_id && ! foo.alliance_id.nil?
#         foo.alliance.update_search_index
#       end
#       if foo.alliance_id_was != foo.alliance_id && ! foo.alliance_id_was.nil? &&
#           ! (old_ally = Eve::Alliance.find(foo.alliance_id_was)).nil?
#         old_ally.update_search_index
#       end
#       if foo.alliance_id_was != foo.alliance_id
#         foo.characters.each { |char| char.update_search_index }
#       end
#       # also call update_search_priority for any changes that only affect the priority but not the word index
#       # rule of thumb there is check everything in search_priority and subtract anything in search_index_info
#     end
#     def after_destroy(foo)
#       foo.delete_search_index
#     end
#   end
#   ActiveRecord::Base.observers << :foo_indexer
# 
# in both cases, the model should also have this in it:
#   class Foo < ActiveRecord::Base
#     scope :search_index_scope, where(:public => 1) # define scope as {} if every row should be indexed
#     def search_result_title
#       name
#     end
#     def search_result_summary
#       squish_space(strip_html(description))
#     end
#     def search_index_info
#       [
#         # string/array of words to index, integer of rank to assign for each word
#         # times as many different rows as you need to describe all searchable text of the model
#         # string may be nil or empty, if this one doesn't apply this time
#         [name,                             30],
#         [race.nil? ? nil : race.name,      20],
#         [categories.collect {|c| c.name},  10],
#         [strip_html(description),           1]
#       ]
#     end
#     # the following could also be a row on the model, if you want to precalculate it
#     # for example, for static data that could make indexing go a bit faster
#     def search_priority
#       0.4 + (ceo? ? 0.1 : 0) + (player_corporation? ? 0.02 : -0.02) + (alliance? ? 0.01 : 0)
#     end
#   end
# 

module IndexedSearch
  module Index

    class BadModelException < Exception
    end

    # storage for model to id mappings
    mattr_accessor :models_by_id
    self.models_by_id = {}
    
    module ClassMethods

      # main entry points for indexing a whole model in one go
      # uses some alternate more complicated/fragile queries to avoid loading entire table into memory!
      # beware that you shouldn't add/remove rows concurrently while updating...
      def create_search_index
        word_count_incrs = Hash.new(0)
        search_index_scope.order(id_for_index_attr).batches_by_ids(1_000, id_for_index_attr) do |group_scope|
          IndexedSearch::Entry.transaction do
            rank_data = group_scope.collect_search_ranks
            search_insertion_data = []
            group_scope.each do |row|
              search_insertion_data += row.make_search_insertion_data(rank_data[row.id_for_index])
              rank_data[row.id_for_index].keys.each { |word_id| word_count_incrs[word_id] += 1 }
            end
            #Rails.logger.info(search_insertion_data)
            IndexedSearch::Entry.import(search_insertion_headings, search_insertion_data, :validate => false)
          end
        end
        #Rails.logger.info(word_count_incrs)
        word_count_incrs.invert_multi.each { |amount, ids| IndexedSearch::Word.incr_counts_by_ids(ids, amount) }
        IndexedSearch::Word.update_ranks_by_ids(word_count_incrs.keys)
        #Rails.logger.info(IndexedSearch::Word.all.collect(&:inspect).join("\n"))
        #Rails.logger.info(IndexedSearch::Entry.all.collect(&:inspect).join("\n"))
      end
      def update_search_index
        word_count_incrs = Hash.new(0)
        word_count_decrs = Hash.new(0)
        word_rank_changes = Set.new
        # reindex existing rows
        search_index_scope.order(id_for_index_attr).batches_by_ids(1_000, id_for_index_attr) do |group_scope, group_ids|
          IndexedSearch::Entry.transaction do
            # pre-cache entire group of existing index entries by model id
            entry_cache = Hash.of { [] }
            IndexedSearch::Entry.where(:modelid => model_id, :modelrowid => group_ids).each do |entry|
              entry_cache[entry.modelrowid] << entry
            end
            rank_data = group_scope.collect_search_ranks
            # figure out what to add, update, and delete from each
            search_insertion_data = []
            inverted_update_data = Hash.of { [] }
            search_deletion_data = []
            group_scope.each do |row|
              (inserts, updates, deletions, count_decrs, rank_changes) = row.make_search_update_data(rank_data[row.id_for_index], entry_cache[row.id_for_index])
              search_insertion_data += row.make_search_insertion_data(inserts)
              updates.each { |id, vals| inverted_update_data[vals] << id }
              search_deletion_data += deletions
              inserts.keys.each { |word_id| word_count_incrs[word_id] += 1 }
              count_decrs.each { |word_id| word_count_decrs[word_id] += 1 }
              word_rank_changes += rank_changes
            end
            # add, update, and delete index entries for this group of models
            IndexedSearch::Entry.import(search_insertion_headings, search_insertion_data, :validate => false) unless search_insertion_data.blank?
            inverted_update_data.each { |vals, ids| IndexedSearch::Entry.where(:id => ids).update_all(vals) }
            IndexedSearch::Entry.where(:id => search_deletion_data).delete_all unless search_deletion_data.blank?
          end
        end
        # delete indexes for model rows that no longer exist
        entry_table = IndexedSearch::Entry.arel_table
        subrelation = unscoped.select(arel_table[id_for_index_attr]).
          where(entry_table[:modelid].eq(model_id).and(entry_table[:modelrowid].eq(arel_table[id_for_index_attr])))
        search_deletion_data = []
        search_entries.where("(#{subrelation.to_sql}) IS NULL").values_of(:id, :word_id).each do |id, word_id|
          search_deletion_data << id
          word_count_decrs[word_id] += 1
          word_rank_changes << word_id
        end
        IndexedSearch::Entry.where(:id => search_deletion_data).delete_all unless search_deletion_data.blank?
        # increment/decrement counts for added/removed words
        word_count_incrs.invert_multi.each { |amount, ids| IndexedSearch::Word.incr_counts_by_ids(ids, amount) }
        word_count_decrs.invert_multi.each { |amount, ids| IndexedSearch::Word.decr_counts_by_ids(ids, amount) }
        # delete orphaned words no longer used anywhere
        IndexedSearch::Word.delete_empty unless word_count_decrs.blank?
        # update word ranks
        IndexedSearch::Word.update_ranks_by_ids(word_rank_changes.to_a) unless word_rank_changes.blank?
        #Rails.logger.info(IndexedSearch::Word.all.collect(&:inspect).join("\n"))
        #Rails.logger.info(IndexedSearch::Entry.all.collect(&:inspect).join("\n"))
      end
      def delete_search_index
        search_entries.delete_all
        IndexedSearch::Entry.reset_auto_increment
        IndexedSearch::Word.fix_counts_orphans_and_ranks
      end
      
      def search_entries
        IndexedSearch::Entry.where(:modelid => model_id)
      end
      def model_id
        # kind_of? allows both STI and regular Ruby subclasses to work
        # name.constantize allows rails class reloading to work in development
        # todo: this is not very efficient and needs rethinking
        IndexedSearch::Index.models_by_id.detect {|k,v| self.new.kind_of?(v.name.constantize) }.first
      rescue
        raise BadModelException.new("#{self.name} does not appear to be an indexed model, see IndexedSearch::Index.models_by_id in config/initializers/indexed_search.rb")
      end
      def collect_search_ranks
        word_list = Set.new
        wrd_rnk_map = Hash.of { Hash.new(0) }
        (self.respond_to?(:each) ? self : self.scoped).each do |row|
          row.search_index_info.each do |txt, amnt|
            words = IndexedSearch::Query.split_into_words(txt)
            word_list += words
            words.each { |word| wrd_rnk_map[row.id_for_index][word] += amnt }
          end
        end
        #pp word_list.to_a
        wrd_id_map = IndexedSearch::Word.word_id_map(word_list.to_a)
        srch_rnks = Hash.of { {} }
        wrd_rnk_map.each { |id, data| data.each { |wrd, rnk| srch_rnks[id][wrd_id_map[wrd]] = rnk } }
        srch_rnks
      end
      #def collect_search_ranks
      #  wrd_rnk_map = Hash.new(0)
      #  search_index_info.each { |txt, amnt| IndexedSearch::Query.split_into_words(txt).each { |w| wrd_rnk_map[w] += amnt } }
      #  wrd_id_map = IndexedSearch::Word.word_id_map(wrd_rnk_map.keys)
      #  srch_rnks = {}
      #  wrd_rnk_map.each { |wrd, rnk| srch_rnks[wrd_id_map[wrd]] = rnk }
      #  srch_rnks
      #end

      # The column from your indexed model that will be stored in the Entry model's modelrowid attribute.
      #
      # Override this in your model if you're using a different column than what is returned by
      # model.primary_key (usually 'id' unless you've set self.primary_key = 'something_else' in
      # your model).
      #
      # This column *must* be a unique integer key in your table.
      #
      # If your table's primary key is a composite primary key, then you must have another unique
      # key (not composite) defined in your table and override this method to tell indexed_search
      # which column to use.
      #
      # Hint: To define an auto-increment column that is not your primary key in MySQL, use:
      #   alter table #{@table_name} add column #{column} int(11) NOT NULL AUTO_INCREMENT UNIQUE KEY
      #
      # (id would return an array in that case (if using composite_primary_keys gem, anyway), which
      # is hard to store in a single column in the Entry model.)
      def id_for_index_attr
        :id
      end
      def search_insertion_headings
        [:word_id, :rowidx, :modelid, :modelrowid, :rank, :row_priority]
      end

    end # ClassMethods
    
    module InstanceMethods
      
      def create_search_index(do_quickly=false)
        IndexedSearch::Entry.transaction do
          srch_rnks = collect_search_ranks
          IndexedSearch::Entry.import(self.class.search_insertion_headings, make_search_insertion_data(srch_rnks), :validate => false)
          unless do_quickly
            IndexedSearch::Word.incr_counts_by_ids(srch_rnks.keys)
            IndexedSearch::Word.update_ranks_by_ids(srch_rnks.keys)
          end
        end
      end
      # updates and deletes are often called in a loop to manipulate multiple rows at once
      def update_search_index(do_quickly=false)
        (inserts, updates, deletions, count_decrs, rank_changes) = make_search_update_data(collect_search_ranks)
        unless inserts.blank? && updates.blank? && deletions.blank?
          IndexedSearch::Entry.transaction do
            IndexedSearch::Entry.import(self.class.search_insertion_headings, make_search_insertion_data(inserts), :validate => false) unless inserts.blank?
            updates.invert_multi.each { |vals, ids| IndexedSearch::Entry.where(:id => ids).update_all(vals) }
            IndexedSearch::Entry.where(:id => deletions).delete_all unless deletions.blank?
            unless do_quickly
              IndexedSearch::Word.incr_counts_by_ids(inserts.keys)  unless inserts.blank?
              IndexedSearch::Word.decr_counts_by_ids(count_decrs)   unless count_decrs.blank?
              IndexedSearch::Word.delete_empty                      unless count_decrs.blank?
              IndexedSearch::Word.update_ranks_by_ids(rank_changes) unless rank_changes.blank?
            end
          end
        end
      end
      def update_search_priority
        IndexedSearch::Entry.transaction do
          search_entries.update_all(:row_priority => search_priority.round(15))
        end
      end
      def delete_search_index
        IndexedSearch::Entry.transaction do
          search_entries.delete_all
          #IndexedSearch::Word.fix_counts_orphans_and_ranks
        end
      end
      
      def search_entries
        self.class.search_entries.where(:modelrowid => id_for_index)
      end
      def model_id
        self.class.model_id
      end
      def collect_search_ranks
        wrd_rnk_map = Hash.new(0)
        search_index_info.each { |txt, amnt| IndexedSearch::Query.split_into_words(txt).each { |w| wrd_rnk_map[w] += amnt } }
        wrd_id_map = IndexedSearch::Word.word_id_map(wrd_rnk_map.keys)
        srch_rnks = {}
        wrd_rnk_map.each { |wrd, rnk| srch_rnks[wrd_id_map[wrd]] = rnk }
        srch_rnks
      end

      def id_for_index
        send self.class.id_for_index_attr
      end
      def make_search_insertion_data(ranks)
        id = id_for_index
        idx = ((id << 8) | model_id)
        mid = model_id
        pri = search_priority.round(15)
        ranks.collect { |wid, rnk| [wid, idx, mid, id, rnk, pri] }
      end
      def make_search_update_data(ranks, search_entries=nil)
        updates = {}
        deletions = []
        count_decrs = []
        rank_changes = []
        sp = search_priority.round(15)
        (search_entries || self.search_entries).each do |hit|
          if ranks.has_key?(hit.word_id)
            upd = {}
            if hit.rank != ranks[hit.word_id]
              upd[:rank]        = ranks[hit.word_id]
              rank_changes      << hit.word_id
            end
            upd[:row_priority]  = sp     if hit.row_priority  != sp
            updates[hit.id]     = upd    unless upd.empty?
            ranks.delete(hit.word_id)
          else
            deletions << hit.id
            count_decrs << hit.word_id
            rank_changes << hit.word_id
          end
        end
        # at this point, whatever is left in the ranks variable should be inserted as new entries
        rank_changes += ranks.keys
        [ranks, updates, deletions, count_decrs, rank_changes]
      end

    end # InstanceMethods
    
    # make the whole thing work when included and extended:
    def self.included(base)
      initialize_methods(base)
    end
    def self.extended(base)
      initialize_methods(base)
    end
    def self.initialize_methods(base)
      base.instance_eval { include IndexedSearch::Index::InstanceMethods }
      base.extend IndexedSearch::Index::ClassMethods
      raise BadModelException.new("#{base.name} does not appear to be an ActiveRecord model.") unless base.respond_to?(:has_many)
    end
    
  end
end
