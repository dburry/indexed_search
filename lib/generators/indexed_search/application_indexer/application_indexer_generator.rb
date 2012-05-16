
module IndexedSearch

  # Generate an application indexer
  class ApplicationIndexerGenerator < Rails::Generators::Base

    source_root File.expand_path('../templates', __FILE__)

    # Copy the template file into place
    def copy_application_indexer_file
      copy_file "application_indexer.rb", "app/indexers/application_indexer.rb"
    end

  end
end
