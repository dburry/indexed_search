
require 'indexed_search/disabler.rb'

module IndexedSearch

  # Base class for model search re-indexers, using observers.
  # Inherit from this in your observers to get basic default functionality.
  # Override these methods to alter or fine tune that functionality.
  class ApplicationIndexer < ActiveRecord::Observer

    # When a model record is created, create an index for it too, unless indexing has been temporarily disabled.
    def after_create(mdl)
      mdl.create_search_index unless mdl.no_indexing?
    end

    # When a model record is modified, update its index too, unless indexing has been temporarily disabled.
    def after_update(mdl)
      mdl.update_search_index unless mdl.no_indexing?
    end

    # When a model record is destroyed, get rid of its index too, unless indexing has been temporarily disabled.
    def after_destroy(mdl)
      mdl.delete_search_index unless mdl.no_indexing?
    end

  end

end
