require File.expand_path(File.dirname(__FILE__) + '/../../../spec_helper')

describe IndexedSearch::Match::Metaphone do
  before(:each) do
    @e = IndexedSearch::Entry
    @q = IndexedSearch::Query
    @f1 = create(:foo, :name => 'thing')
    Foo.create_search_index
    @def = IndexedSearch::Match.perform_match_types
    IndexedSearch::Match.perform_match_types = [:metaphone]
  end
  after(:each) do
    IndexedSearch::Match.perform_match_types = @def
  end

  it('find1')   { @e.find_results(@q.new('thin'), 25).should be_empty }
  it('find2')   { @e.find_results(@q.new('thing'), 25).models.should == [@f1] }
  it('find3')   { @e.find_results(@q.new('things'), 25).should be_empty }
  it('find4')   { @e.find_results(@q.new('th1ng'), 25).models.should == [@f1] }
  it('find5')   { @e.find_results(@q.new('theng'), 25).models.should == [@f1] }
  it('find6')   { @e.find_results(@q.new('think'), 25).models.should == [@f1] }

end
