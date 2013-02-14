FactoryGirl.define do

  factory :key do
    sequence :idx
  end

  factory :indexed_key, :parent => :key  do
    after(:create) { |foo| foo.create_search_index }
  end

end