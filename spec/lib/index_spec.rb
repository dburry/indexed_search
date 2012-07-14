require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe IndexedSearch::Index do
  before(:each) do
    @e = IndexedSearch::Entry
    @q = IndexedSearch::Query
    @f1 = create(:foo, :name => 'first one',  :description => 'test first foo')
    @f2 = create(:foo, :name => 'second one', :description => 'test second two')
    @b1 = create(:bar, :name => 'first bar', :foo => @f1)
    @b2 = create(:bar, :name => 'second bar')
    Foo.create_search_index
    Bar.create_search_index
  end

  context 'values' do
    it('model')   { @e.first.model.should                      == @f1 }
    it('models')  { Bar.search_entries.models.should           == [@b1, @b1, @b1, @b2, @b2] }
    it('find1')   { @e.find_results(@q.new('one two'), 25).models.should      == [@f2, @f1, @b1] }
    it('find2')   { @e.find_results(@q.new('first test'), 25).models.should   == [@f1, @b1, @f2] }
    it('find3')   { @e.find_results(@q.new('first test'), 2).models.should    == [@f1, @b1] }
    it('find4')   { @e.find_results(@q.new('first test'), 2, 2).models.should == [@f2] }
    it('find5')   { @e.find_results(@q.new('notfound'), 25).should            == [] }
    it('find6')   { Foo.search_entries.find_results(@q.new('first test one'), 25).models.should == [@f1, @f2] }
    it('find7')   { @e.find_results(@q.new('ba'), 2).models.should            == [@b1, @b2] }
    it('find8')   { @e.find_results(@q.new('bars'), 2).models.should          == [@b1, @b2] }
    it('find9')   { @e.find_results(@q.new('bara'), 2).models.should          == [@b1, @b2] }
    it('find10')  { @e.find_results(@q.new('barred'), 2).models.should        == [@b1, @b2] }
    it('count1')  { @e.count_results(@q.new('one two')).should         == 3 }
    it('count2')  { @e.count_results(@q.new('first test')).should      == 3 }
    it('count3')  { @e.count_results(@q.new('notfound')).should        == 0 }
  end

  context 'updating' do
    before(:each) do
      @f1.name = 'yet again'
      @b1.name = 'another'
    end

    context 'saved models' do
      before(:each) do
        @f1.save!
        @b1.save!
      end
      context 'normal' do
        before(:each) do
          Foo.update_search_index
          Bar.update_search_index
        end
        it('find1')   { @e.find_results(@q.new('first test'), 25).models.should   == [@f1, @f2] }
        it('find2')   { @e.find_results(@q.new('one two'), 25).models.should      == [@f2] }
        it('find3')   { @e.find_results(@q.new('again'), 25).models.should        == [@f1, @b1] }
        it('find4')   { Foo.search_entries.find_results(@q.new('first test one'), 25).models.should == [@f2, @f1] }
      end
      context 'after a row removal' do
        before(:each) do
          @f2.destroy
          Foo.update_search_index
          Bar.update_search_index
        end
        it('find1')   { @e.find_results(@q.new('first test'), 25).models.should   == [@f1] }
        it('find2')   { @e.find_results(@q.new('one two'), 25).should             == [] }
        it('find3')   { @e.find_results(@q.new('again'), 25).models.should        == [@f1, @b1] }
        it('find4')   { Foo.search_entries.find_results(@q.new('first test one'), 25).models.should == [@f1] }
      end
      context 'via a scope' do
        before(:each) { Foo.where(:id => @f1.id).update_search_index }
        it('find1')   { @e.find_results(@q.new('first test'), 25).models.should   == [@b1, @f1, @f2] }
        it('find2')   { @e.find_results(@q.new('one two'), 25).models.should      == [@f2, @b1] }
        it('find3')   { @e.find_results(@q.new('again'), 25).models.should        == [@f1] }
        it('find4')   { Foo.search_entries.find_results(@q.new('first test one'), 25).models.should == [@f2, @f1] }
      end
    end

    context 'unsaved row' do
      before(:each) { @f1.update_search_index }
      it('find1')   { @e.find_results(@q.new('first test'), 25).models.should   == [@b1, @f1, @f2] }
      it('find2')   { @e.find_results(@q.new('one two'), 25).models.should      == [@f2, @b1] }
      it('find3')   { @e.find_results(@q.new('again'), 25).models.should        == [@f1] }
      it('find4')   { Foo.search_entries.find_results(@q.new('first test one'), 25).models.should == [@f2, @f1] }
    end

  end

end
