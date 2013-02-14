FactoryGirl.define do

  factory :comp do
    sequence :id1
    sequence :id2
    sequence :idx
  end

  factory :indexed_comp, :parent => :comp  do
    after(:create) { |foo| foo.create_search_index }
  end

end