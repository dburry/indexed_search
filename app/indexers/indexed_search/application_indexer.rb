
#
# base class for model search re-indexers, using observers similarly to how cache sweepers work
#
# rule of thumb used here is: when a piece of data changes, go through all the places that reference it when indexing
# and re-index all the related model instances that reference it
#
# note: static data that does not dynamically reindex don't need these, of course
# because they are handled another way (via rake tasks only) that's run only when that static data changes...
# these indexers are only for data that somehow references dynamic live data
#

require 'indexed_search/disabler.rb'

module IndexedSearch
  class ApplicationIndexer < ActiveRecord::Observer

    # override these in subclasses to alter or fine tune functionality
    # or alter them here to change functionality overall...
    def after_create(mdl)
      mdl.create_search_index unless mdl.no_indexing?
    end
    def after_update(mdl)
      mdl.update_search_index unless mdl.no_indexing?
    end
    def after_destroy(mdl)
      mdl.delete_search_index unless mdl.no_indexing?
    end

  end
end
