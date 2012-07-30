
# DRY out some common code used in matcher testing

# set IndexedSearch::Match.perform_match_types so that only certain match types are run
# then restore it back to default after test
def set_perform_match_types(types)
  set_nested_global('indexed_search/match', :perform_match_types, types)
end

# set IndexedSearch::Match.perform_match_types so that only a certain match type is run
# then restore it back to default after test
def set_perform_match_type(type)
  set_nested_global('indexed_search/match', :perform_match_types, [type])
end

# set IndexedSearch::Match::<matcher>.max_length for a given section
def set_matcher_max_length(matcher, length)
  set_nested_global("indexed_search/match/#{matcher}", :max_length, length)
end
