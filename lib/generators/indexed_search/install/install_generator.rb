
module IndexedSearch
  class InstallGenerator < Rails::Generators::Base

    # Install the initial config files
    def install_initial_files
      generate("indexed_search:initializer")
      generate("indexed_search:application_indexer")
    end

  end
end
