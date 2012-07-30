
# DRY out some common code used in conjunction with the word model

# set IndexedSearch::Word.index_match_types so that only certain match types are indexed
# then restore it back to default after test
def set_index_match_types(types)
  set_nested_global("indexed_search/word", :index_match_types, types)
end

# set IndexedSearch::Word.index_match_types so that only a certain match type is indexed
# then restore it back to default after test
def set_index_match_type(type)
  set_nested_global("indexed_search/word", :index_match_types, [type])
end
