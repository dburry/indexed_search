FactoryGirl.define do
  factory 'indexed_search/entry', :aliases => [:entry] do
    word
    rowidx 1
    modelid 1
    modelrowid 1
    rank 1
  end
end