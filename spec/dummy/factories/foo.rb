FactoryGirl.define do

  factory :foo

  factory :indexed_foo, :parent => :foo  do
    after(:create) { |foo| foo.create_search_index }
  end

end