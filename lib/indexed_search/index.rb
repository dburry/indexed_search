
require 'each_batched'
require 'activerecord-import'

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
        search_index_scope.includes(:search_entries).each_by_ids(700) { |row| row.create_search_index }
      end
      def update_search_index
        # reindex existing rows
        search_index_scope.includes(:search_entries).each_by_ids(700) { |row| row.update_search_index }
        # remove index for model rows that no longer exist
        search_entries.
          where(
            "(" +
              "SELECT #{table_name}.#{id_for_index_attr} " +
              "FROM #{table_name} " +
              "WHERE entries.modelid=#{model_id} AND " +
                "entries.modelrowid=#{table_name}.#{id_for_index_attr}" +
            ") IS NULL"
          ).
          delete_all
        # cleanup any extra words that are no longer used, when done
        IndexedSearch::Word.delete_orphaned
      end
      def delete_search_index
        search_entries.delete_all
        IndexedSearch::Entry.reset_auto_increment
        IndexedSearch::Word.delete_orphaned
        IndexedSearch::Word.update_counts
        IndexedSearch::Word.update_ranks
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
    end # ClassMethods
    
    module InstanceMethods
      
      def create_search_index
        IndexedSearch::Entry.transaction do
          srch_rnks = collect_search_ranks
          IndexedSearch::Entry.import(*make_search_insertions(srch_rnks), :validate => false)
          IndexedSearch::Word.incr_counts_by_ids(srch_rnks.keys)
        end
      end
      # updates and deletes are often called in a loop to manipulate multiple rows at once
      # it's recommended at the end of the whole loop, call this to keep index clean:
      # IndexedSearch::Word.delete_orphaned, just as the class-level versions above do
      # it's not included here for speed when looping
      def update_search_index
        ranks = collect_search_ranks
        updates = {}
        deletions = []
        rank_changes = []
        count_decrs = []
        sp = search_priority.round(15)
        search_entries.each do |hit|
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
            rank_changes << hit.word_id
            count_decrs << hit.word_id
          end
        end
        # at this point, whatever's left in the ranks variable should be inserted into new entries
        # ideally we should do rank_changes for those inserts too, but it's commented out because it's slow
        # failing to update this will merely cause searches to get slower over time with a lot of additions
        # a manually-triggered update via rake task periodically will fix it, especially after major model changes
        # rank_changes += ranks.keys
        unless ranks.blank? && updates.blank? && deletions.blank?
          IndexedSearch::Entry.transaction do
            IndexedSearch::Entry.import(*make_search_insertions(ranks), :validate => false) unless ranks.blank?
            unless updates.blank?
              inverted_updates = Hash.new { |h, k| h[k] = [] }
              updates.each { |id, vals| inverted_updates[vals] << id }
              inverted_updates.each { |vals, ids| IndexedSearch::Entry.where(:id => ids).update_all(vals) }
            end
            IndexedSearch::Entry.where(:id => deletions).delete_all unless deletions.blank?
            IndexedSearch::Word.update_ranks_by_ids(rank_changes)   unless rank_changes.blank?
            IndexedSearch::Word.incr_counts_by_ids(ranks.keys)      unless ranks.blank?
            IndexedSearch::Word.decr_counts_by_ids(count_decrs)     unless count_decrs.blank?
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
          # note: delete_all is an alias for clear, and uses dependent setting on association
          search_entries.clear
        end
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
      def make_search_insertions(ranks)
        id = id_for_index
        idx = ((id << 8) | model_id)
        mid = model_id
        pri = search_priority.round(15)
        [
          [:word_id, :rowidx, :modelid, :modelrowid, :rank, :row_priority],
          ranks.collect { |wid, rnk| [wid, idx, mid, id, rnk, pri] }
        ]
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
      base.has_many :search_entries, :class_name => 'IndexedSearch::Entry', :foreign_key => :modelrowid, :conditions => proc { {:modelid => base.model_id} }, :dependent => :delete_all
    end
    
  end
end
