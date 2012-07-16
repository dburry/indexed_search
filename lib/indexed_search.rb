require 'rails/engine'

module IndexedSearch
  class Engine < Rails::Engine
    require 'activerecord-import'
    require 'each_batched'
    require 'text'
    require 'unicode_utils'
    require 'valium'

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

  end
end
