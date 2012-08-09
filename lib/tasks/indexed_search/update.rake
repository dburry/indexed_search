
# rake tasks for creating/deleting/updating the index

namespace :indexed_search do

  namespace :internal do

    # get models from environment variable MODELS, or full list if there is no env
    def indexed_search_get_models
      return IndexedSearch::Index.models_by_id.values if ENV['MODELS'].blank? || ENV['MODELS'].strip == 'all'
      my_mdls = Set.new(ENV['MODELS'].split(',').collect { |m| m.strip })
      mdl_index = Set.new(IndexedSearch::Index.models_by_id.values.collect { |mdl| mdl.table_name.singularize })
      raise 'Unknown model' if my_mdls.reject { |m| mdl_index.include?(m) }.length > 0
      return IndexedSearch::Index.models_by_id.values.select { |mdl| my_mdls.include?(mdl.table_name.singularize) }
    end

    # initialize models
    # anything that doesn't auto-update itself needs to be extended with IndexedSearch::Index first, before we can index it
    task :init do
      indexed_search_get_models.reject { |mdl| mdl.respond_to?(:create_search_index) }.each { |mdl| mdl.extend IndexedSearch::Index }
    end

    # index models, assuming no existing ones
    # will create double-indexing if there are existing ones, so make sure there aren't any first!
    task :create do
      indexed_search_get_models.each do |mdl|
        puts "Indexing #{mdl.table_name}..."
        mdl.create_search_index
      end
    end

    # reindex existing model indexes in-place
    task :update do
      indexed_search_get_models.each do |mdl|
        puts "Reindexing #{mdl.table_name}..."
        mdl.update_search_index
      end
    end

    # erase indexes for models
    task :delete do
      if ENV.has_key?('MODELS')
        indexed_search_get_models.each do |mdl|
          puts "Erasing index for #{mdl.table_name}..."
          mdl.delete_search_index
        end
      else
        # more efficient to truncate, if we don't need to do a partial delete...
        puts "Truncating all index tables..."
        IndexedSearch::Entry.truncate_table
        IndexedSearch::Word.truncate_table
      end
    end

  end

  # our public tasks stitch internal above ones together in different useful ways

  desc "Make new indexes (NOTE: should not exist prior)"
  task :create => [:environment, 'indexed_search:internal:init', 'indexed_search:internal:create']

  desc "Redo indexes by deleting and creating, indexes aren't available inbetween"
  task :recreate => [:environment, 'indexed_search:internal:init', 'indexed_search:internal:delete', 'indexed_search:internal:create']

  desc "Redo existing live indexes in-place, with no down time"
  task :update => [:environment, 'indexed_search:internal:init', 'indexed_search:internal:update']

  desc "Delete existing indexes (can be scoped to just certain models)"
  task :delete => [:environment, 'indexed_search:internal:init', 'indexed_search:internal:delete']

  # TODO: remove this...
  task :clear do
    puts "This rake task has been removed.  Use indexed_search:delete (or indexed_search:recreate) instead."
  end

end
