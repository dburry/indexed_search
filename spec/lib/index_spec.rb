require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe Search::Index do 
  before(:each) do
    @sg = Eve::Subgroup.create!(:group => Eve::Group.create)
    @i1 = Eve::Item.create!(:subgroup => @sg, :name => 'first one',  :description => 'test first item') { |i| i.id = 1 }
    @i2 = Eve::Item.create!(:subgroup => @sg, :name => 'second one', :description => 'test second two') { |i| i.id = 2 }
    @r1 = Eve::Race.create!(:name => 'first race', :description => 'test race description') { |r| r.id = 1 }
    Eve::Item.extend Search::Index
    Eve::Race.extend Search::Index
    Eve::Item.create_search_index
    Eve::Race.create_search_index
  end
  
  describe 'values' do
    it('model')   { Search::Entry.first.model.should                      == @i1 }
    it('models')  { Eve::Race.search_entries.models.should                == [@r1, @r1, @r1, @r1, @r1] }
    it('find1')   { Search::Entry.find_results(Search::Query.new('one two'), 25).models.should      == [@i2, @i1] }
    it('find2')   { Search::Entry.find_results(Search::Query.new('first test'), 25).models.should   == [@r1, @i1, @i2] }
    it('find3')   { Search::Entry.find_results(Search::Query.new('first test'), 2).models.should    == [@r1, @i1] }
    it('find4')   { Search::Entry.find_results(Search::Query.new('first test'), 2, 2).models.should == [@i2] }
    it('find5')   { Search::Entry.find_results(Search::Query.new('notfound'), 25).should            == [] }
    it('find6')   { Eve::Item.search_entries.find_results(Search::Query.new('first test one'), 25).models.should == [@i1, @i2] }
    it('find7')   { Search::Entry.find_results(Search::Query.new('descr'), 2).models.should         == [@r1] }
    it('find8')   { Search::Entry.find_results(Search::Query.new('descriptions'), 2).models.should  == [@r1] }
    it('find9')   { Search::Entry.find_results(Search::Query.new('racu'), 2).models.should          == [@r1] }
    it('find10')  { Search::Entry.find_results(Search::Query.new('raced'), 2).models.should         == [@r1] }
    it('count1')  { Search::Entry.count_results(Search::Query.new('one two')).should         == 2 }
    it('count2')  { Search::Entry.count_results(Search::Query.new('first test')).should      == 3 }
    it('count3')  { Search::Entry.count_results(Search::Query.new('notfound')).should        == 0 }
  end
  
  describe '' do
    before(:each) { @i1.name = 'yet again' }

    describe 'model update' do
      before(:each) { @i1.save! }
      describe 'simple' do
        before(:each) { Eve::Item.update_search_index }
        it('find1')   { Search::Entry.find_results(Search::Query.new('first test'), 25).models.should   == [@r1, @i1, @i2] }
        it('find2')   { Search::Entry.find_results(Search::Query.new('one two'), 25).models.should      == [@i2] }
        it('find3')   { Search::Entry.find_results(Search::Query.new('again'), 25).models.should        == [@i1] }
        it('find4')   { Eve::Item.search_entries.find_results(Search::Query.new('first test one'), 25).models.should == [@i2, @i1] }
      end
      #describe 'with row removal' do
      #  before(:each) { @i2.destroy; Eve::Item.update_search_index }
      #  it('find1')   { Search::Entry.find_results(Search::Query.new('first test'), 25).models.should   == [@r1, @i1] }
      #  it('find2')   { Search::Entry.find_results(Search::Query.new('one two'), 25).should             == [] }
      #  it('find3')   { Search::Entry.find_results(Search::Query.new('again'), 25).models.should        == [@i1] }
      #  it('find4')   { Eve::Item.search_entries.find_results(Search::Query.new('first test one'), 25).models.should == [@i1] }
      #end
    end

    describe 'row update' do
      before(:each) { @i1.update_search_index }
      it('find1')   { Search::Entry.find_results(Search::Query.new('first test'), 25).models.should   == [@r1, @i1, @i2] }
      it('find2')   { Search::Entry.find_results(Search::Query.new('one two'), 25).models.should      == [@i2] }
      it('find3')   { Search::Entry.find_results(Search::Query.new('again'), 25).models.should        == [@i1] }
      it('find4')   { Eve::Item.search_entries.find_results(Search::Query.new('first test one'), 25).models.should == [@i2, @i1] }
    end

  end

end
