require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

class NonARModel
end
class UnindexedModel < ActiveRecord::Base
end
class FooSubclass < Foo
end

describe IndexedSearch::Index do

  context 'with some data' do
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

    end # updating

    context 'and new data' do
      before(:each) { @f3 = create(:foo, :name => 'first first', :description => 'test first foo') }
      context 'creating row index' do
        before(:each) { @f3.create_search_index }
        it('find1') { @e.find_results(@q.new('first test'), 25).models.should == [@f3, @f1, @b1, @f2] }
        it('find2') { @e.find_results(@q.new('one two'), 25).models.should    == [@f2, @f1, @b1] }
      end
    end

    context 'and row destroyed' do
      before(:each) do
        @f2.delete_search_index
        @f2.destroy
      end
      it('find1')   { @e.find_results(@q.new('one two'), 25).models.should      == [@f1, @b1] }
      it('find2')   { @e.find_results(@q.new('first test'), 25).models.should   == [@f1, @b1] }
      it('find3')   { @e.find_results(@q.new('test second'), 25).models.should  == [@b2, @b2.foo, @f1] }
    end

    context 'and deleted index' do
      before(:each) { @f1.delete_search_index }
      it('find1') { @e.find_results(@q.new('first test'), 25).models.should == [@b1, @f2] }
      it('find2') { @e.find_results(@q.new('one two'), 25).models.should    == [@f2, @b1] }

      context 'and recreated row' do
        before(:each) { @f1.create_search_index }
        it('find1') { @e.find_results(@q.new('first test'), 25).models.should == [@f1, @b1, @f2] }
        it('find2') { @e.find_results(@q.new('one two'), 25).models.should    == [@f2, @f1, @b1] }
      end
      context 'and reloaded and recreated row' do
        before(:each) { @f1.reload }
        before(:each) { @f1.create_search_index }
        it('find1') { @e.find_results(@q.new('first test'), 25).models.should == [@f1, @b1, @f2] }
        it('find2') { @e.find_results(@q.new('one two'), 25).models.should    == [@f2, @f1, @b1] }
      end
      context 'and refound and recreated row' do
        before(:each) { @f1 = Foo.where(:name => 'first one').first }
        before(:each) { @f1.create_search_index }
        it('find1') { @e.find_results(@q.new('first test'), 25).models.should == [@f1, @b1, @f2] }
        it('find2') { @e.find_results(@q.new('one two'), 25).models.should    == [@f2, @f1, @b1] }
      end

      context 'and reupdated row' do
        before(:each) { @f1.update_search_index }
        it('find1') { @e.find_results(@q.new('first test'), 25).models.should == [@f1, @b1, @f2] }
        it('find2') { @e.find_results(@q.new('one two'), 25).models.should    == [@f2, @f1, @b1] }
      end
      context 'and reloaded and reupdated row' do
        before(:each) { @f1.reload }
        before(:each) { @f1.update_search_index }
        it('find1') { @e.find_results(@q.new('first test'), 25).models.should == [@f1, @b1, @f2] }
        it('find2') { @e.find_results(@q.new('one two'), 25).models.should    == [@f2, @f1, @b1] }
      end
      context 'and refound and reupdated row' do
        before(:each) { @f1 = Foo.where(:name => 'first one').first }
        before(:each) { @f1.update_search_index }
        it('find1') { @e.find_results(@q.new('first test'), 25).models.should == [@f1, @b1, @f2] }
        it('find2') { @e.find_results(@q.new('one two'), 25).models.should    == [@f2, @f1, @b1] }
      end

    end # and deleted row

  end

  context 'defining' do
    it 'non-AR model should raise error when trying to make indexable' do
      expect { NonARModel.extend IndexedSearch::Index }.to raise_error(IndexedSearch::Index::BadModelException, /not.*ActiveRecord model/)
    end
    it 'unindexed model should raise error when trying to make indexable' do
      # I tried to get this to raise when extending, but it gets defined too soon,
      # before the id->model index has been created
      UnindexedModel.extend IndexedSearch::Index
      expect { UnindexedModel.model_id }.to raise_error(IndexedSearch::Index::BadModelException, /not.*indexed model/)
    end
    it 'non-STI subclass should work' do
      FooSubclass.model_id.should == Foo.model_id
    end
    # TODO: do an STI test here...
  end

  context 'with no primary key' do

    before(:each) do
      @e = IndexedSearch::Entry
      @q = IndexedSearch::Query
      @k1 = create(:key, :name => 'first one',  :description => 'test first key')
      @k2 = create(:key, :name => 'second one', :description => 'test second two')
      Key.create_search_index
    end

    context 'creating' do
      it('find1')   { @e.find_results(@q.new('one two'), 25).models.collect(&:idx).should      == [@k2, @k1].collect(&:idx) }
      it('find2')   { @e.find_results(@q.new('first test'), 25).models.collect(&:idx).should   == [@k1, @k2].collect(&:idx) }
      it('find3')   { @e.find_results(@q.new('test second'), 25).models.collect(&:idx).should  == [@k2, @k1].collect(&:idx) }
      it('find4')   { @e.find_results(@q.new('again'), 25).should                              == [] }
    end

    context 'updating' do
      before(:each) do
        Key.where(:idx => @k1.idx).update_all(:name => 'yet again')
        Key.update_search_index
      end
      it('find1')   { @e.find_results(@q.new('one two'), 25).models.collect(&:idx).should      == [@k2].collect(&:idx) }
      it('find2')   { @e.find_results(@q.new('first test'), 25).models.collect(&:idx).should   == [@k1, @k2].collect(&:idx) }
      it('find3')   { @e.find_results(@q.new('test second'), 25).models.collect(&:idx).should  == [@k2, @k1].collect(&:idx) }
      it('find4')   { @e.find_results(@q.new('again'), 25).models.collect(&:idx).should        == [@k1].collect(&:idx) }
    end

    context 'deleting' do
      before(:each) do
        @k2.delete_search_index
        Key.delete_all(:idx => @k2.idx)
      end
      it('find1')   { @e.find_results(@q.new('one two'), 25).models.collect(&:idx).should      == [@k1].collect(&:idx) }
      it('find2')   { @e.find_results(@q.new('first test'), 25).models.collect(&:idx).should   == [@k1].collect(&:idx) }
      it('find3')   { @e.find_results(@q.new('test second'), 25).models.collect(&:idx).should  == [@k1].collect(&:idx) }
      it('find4')   { @e.find_results(@q.new('again'), 25).should                              == [] }
    end

  end  # with no primary key

  context 'with composite primary key' do

    before(:each) do
      @e = IndexedSearch::Entry
      @q = IndexedSearch::Query
      @c1 = create(:comp, :name => 'first one',  :description => 'test first key')
      @c2 = create(:comp, :name => 'second one', :description => 'test second two')
      Comp.create_search_index
    end

    context 'creating' do
      it('find1')   { @e.find_results(@q.new('one two'), 25).models.should      == [@c2, @c1] }
      it('find2')   { @e.find_results(@q.new('first test'), 25).models.should   == [@c1, @c2] }
      it('find3')   { @e.find_results(@q.new('test second'), 25).models.should  == [@c2, @c1] }
      it('find4')   { @e.find_results(@q.new('again'), 25).should               == [] }
    end

    context 'updating' do
      before(:each) do
        @c1.update_attributes(:name => 'yet again')
        Comp.update_search_index
      end
      it('find1')   { @e.find_results(@q.new('one two'), 25).models.should      == [@c2] }
      it('find2')   { @e.find_results(@q.new('first test'), 25).models.should   == [@c1, @c2] }
      it('find3')   { @e.find_results(@q.new('test second'), 25).models.should  == [@c2, @c1] }
      it('find4')   { @e.find_results(@q.new('again'), 25).models.should        == [@c1] }
    end

    context 'deleting' do
      before(:each) do
        @c2.delete_search_index
        @c2.destroy
      end
      it('find1')   { @e.find_results(@q.new('one two'), 25).models.should      == [@c1] }
      it('find2')   { @e.find_results(@q.new('first test'), 25).models.should   == [@c1] }
      it('find3')   { @e.find_results(@q.new('test second'), 25).models.should  == [@c1] }
      it('find4')   { @e.find_results(@q.new('again'), 25).should               == [] }
    end

  end  # with composite primary key

end
