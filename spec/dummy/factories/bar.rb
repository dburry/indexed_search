FactoryGirl.define do

  factory :bar do
    foo
  end

  factory :indexed_bar, :parent => :bar  do
    after(:create) { |bar| bar.create_search_index }
  end

end