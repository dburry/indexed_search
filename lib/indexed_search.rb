module IndexedSearch
  class Engine < Rails::Engine

    # I wish you could do this here...
    #new_observers = Dir[config.root.join('app/indexers/*_indexer.rb')].
    #  collect { |f| File.basename(f, '.rb') }.
    #  reject { |f| f == 'application_indexer' }
    #if ! config.active_record.observers
    #  config.active_record.observers = new_observers
    #else
    #  config.active_record.observers += new_observers
    #end

    config.autoload_once_paths += %W(#{config.root}/lib)

    config.generators do |g|
      g.orm             :active_record
      g.test_framework  :rspec
    end

  end
end