
# DRY out common code used in indexing and searching in many places
# see also the indexed model factories in the dummy rails app

def find_results_for(string)
  IndexedSearch::Entry.find_results(IndexedSearch::Query.new(string), 25)
end
