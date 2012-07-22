
# DRY out some common code used in matcher testing

# set IndexedSearch::Match.perform_match_types so that only certain match types are run
# then restore it back to default after test
def set_perform_match_types(types)
  before(:each) do
    @default_perform_match_types = IndexedSearch::Match.perform_match_types
    IndexedSearch::Match.perform_match_types = types
  end
  after(:each) do
    IndexedSearch::Match.perform_match_types = @default_perform_match_types
  end
end

# set IndexedSearch::Match.perform_match_types so that only a certain match type is run
# then restore it back to default after test
def set_perform_match_type(type)
  set_perform_match_types([type])
end
