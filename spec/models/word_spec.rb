require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Search::Word do
  before(:each) { @sw = Search::Word }
  describe 'finding/creating' do
    describe 'without pre-existing words' do
      it 'creating with normal word should use soundex' do
        id = @sw.find_or_create_word_ids(['norm'])
        @sw.find(id)[0].soundex.should == 'N650'
      end
      it 'creating with long word should use long soundex' do
        id = @sw.find_or_create_word_ids(['reallylongword'])
        @sw.find(id)[0].soundex.should == 'R445' # some algorithms might return R452 or R45263
      end
      it 'creating with mixed numerical and alphabetical word should use soundex' do
        id = @sw.find_or_create_word_ids(['123no1r45m'])
        @sw.find(id)[0].soundex.should be_nil # some algorithms might return R650
      end
     it 'creating with too short of a word shouldn\'t use soundex' do
        id = @sw.find_or_create_word_ids(['sh'])
        @sw.find(id)[0].soundex.should be_nil
      end
      it 'creating with numerical word shouldn\'t use soundex' do
        id = @sw.find_or_create_word_ids(['1234'])
        @sw.find(id)[0].soundex.should be_nil
      end
    end

    describe 'with pre-existing words' do
      before(:each) do
        @sw.create!(:word => 'thoughts', :stem => 'thought', :soundex => 'f1') { |sw| sw.id = 1 }
        @sw.create!(:word => 'those',    :stem => 'those',   :soundex => 'f2') { |sw| sw.id = 2 }
      end
      it 'single find' do
        Set.new(@sw.find_or_create_word_ids(['thoughts'])).should == Set.new([1])
      end
      it 'multiple find' do
        Set.new(@sw.find_or_create_word_ids(['thoughts', 'those'])).should == Set.new([1, 2])
      end
      it 'finding with some creating' do
        fc = @sw.find_or_create_word_ids(['thoughts', 'those', 'going', 'gone'])
        extra_ids = @sw.find_all_by_word(['going', 'gone']).collect { |w| w.id }
        Set.new(fc).should == Set.new([1, 2] + extra_ids)
      end
    end
  end
  
  describe 'deleting/cleaning up unindexed words' do
    before(:each) { @ids = @sw.find_or_create_word_ids(['thoughts', 'those', 'going', 'gone']) }
    describe 'when all words are unindexed' do
      it 'scope should include all of them' do
        Set.new(@sw.empty_entry).should == Set.new(@sw.find_all_by_id(@ids))
      end
      it 'delete should remove all of them' do
        @sw.delete_extra_words
        Set.new(@sw.all).should == Set.new
      end
    end
    describe 'when only some are unindexed' do
      before(:each) do
        @id = @ids.shift # @ids only has unindexed left, after create!
        Search::Entry.create!(:word_id => @id, :rowidx => 1, :modelid => 1, :modelrowid => 1, :rank => 1) { |sh| sh.id = 1 }
      end
      it 'scope should include only some of them' do
        Set.new(@sw.empty_entry).should == Set.new(@sw.find_all_by_id(@ids))
      end
      it 'delete should remove only some of them' do
        @sw.delete_extra_words
        Set.new(@sw.all).should == Set.new([@sw.find_by_id(@id)])
      end
    end
  end

end
