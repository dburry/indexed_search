require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Search::Query do
  context 'when splitting into words' do
    it 'quoting/apostrophe should work correctly' do
      Search::Query.split_into_words("'a b 'c' 'd e'f' g'").should == ['a', 'b', 'c', 'd', "e'f", 'g']
    end
    it 'array parameter should work' do
      Search::Query.split_into_words(['some more', '', nil, 'text']).should == ['some', 'more', 'text']
    end
    it 'should preserve duplicates' do
      Search::Query.split_into_words('text text text').should == ['text', 'text', 'text']
    end
    it 'nil should be empty' do
      Search::Query.split_into_words(nil).should == []
    end
    it 'empty should be empty' do
      Search::Query.split_into_words('').should == []
    end
  end
  context 'when initializing' do
    it 'should not preserve duplicates' do
      Search::Query.new('text text text').should == ['text']
    end
  end
end
