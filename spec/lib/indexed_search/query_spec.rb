require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe IndexedSearch::Query do
  context 'when splitting into words' do
    it 'quoting/apostrophe should work correctly' do
      IndexedSearch::Query.split_into_words("'a b 'c' 'd e'f' g'").should == ['a', 'b', 'c', 'd', "e'f", 'g']
    end
    it 'array parameter should work' do
      IndexedSearch::Query.split_into_words(['some more', '', nil, 'text']).should == ['some', 'more', 'text']
    end
    it 'should preserve duplicates' do
      IndexedSearch::Query.split_into_words('text text text').should == ['text', 'text', 'text']
    end
    it 'nil should be empty' do
      IndexedSearch::Query.split_into_words(nil).should == []
    end
    it 'empty should be empty' do
      IndexedSearch::Query.split_into_words('').should == []
    end
  end
  context 'when initializing' do
    it 'should not preserve duplicates' do
      IndexedSearch::Query.new('text text text').should == ['text']
    end
  end
end
