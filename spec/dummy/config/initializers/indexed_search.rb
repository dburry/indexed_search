
IndexedSearch::Index.models_by_id = {
  1 => Foo,
  2 => Bar,
  3 => Key,
  4 => Comp
}


#new_observers = Dir[Rails.root.join('app/indexers/*_indexer.rb')].
#  collect { |f| File.basename(f, '.rb') }.
#  reject { |f| f == 'application_indexer' }
#if ! ActiveRecord::Base.observers
#  ActiveRecord::Base.observers = new_observers
#else
#  ActiveRecord::Base.observers += new_observers
#end
