
module IndexedSearch

  # Generate an indexer
  class IndexerGenerator < Rails::Generators::NamedBase

    source_root File.expand_path('../templates', __FILE__)

    # Copy the template file into place, interpolating it with ERB
    def copy_indexer_file
      template 'indexer.rb.erb', "app/indexers/#{file_name}_indexer.rb"
    end

  end
end
