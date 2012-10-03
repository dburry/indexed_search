require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe IndexedSearch::Word do
  before(:each) { @sw = IndexedSearch::Word }
  context 'finding/creating' do

    context 'without pre-existing words' do

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

      context 'with concurrency' do
        before(:each) { @words = ['foo', 'bar', 'baz', 'fee', 'fi', 'fo', 'fum'] }
        it 'creating a few at once shouldn\'t cause error' do
          run_concurrency_test(15) { @sw.word_id_map(@words) }
        end
        it 'creating a few at once should cause error when done incorrectly' do
          # this kind of tests that the concurrency test implementation works on this platform too
          expect do
            run_concurrency_test(15) do
              id_map = @sw.existing_word_id_map(@words)
              @words.reject { |w| id_map.has_key?(w) }.each { |w| @sw.create_word(w) }
            end
          end.to raise_error(ActiveRecord::RecordNotUnique)
        end
      end

    end # without pre-existing words

    context 'with pre-existing words' do
      before(:each) do
        create(:word, :word => 'thoughts', :stem => 'thought', :soundex => 'f1', :id => 1)
        create(:word, :word => 'those',    :stem => 'those',   :soundex => 'f2', :id => 2)
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
  
  context 'deleting/cleaning up unindexed words' do
    before(:each) { @ids = @sw.find_or_create_word_ids(['thoughts', 'those', 'going', 'gone']) }
    context 'when all words are unindexed' do
      it 'scope should include all of them' do
        Set.new(@sw.empty_entry).should == Set.new(@sw.find_all_by_id(@ids))
      end
      it 'delete should remove all of them' do
        @sw.delete_extra_words
        Set.new(@sw.all).should == Set.new
      end
    end
    context 'when only some are unindexed' do
      before(:each) do
        @id = @ids.shift # @ids only has unindexed left, after create!
        create(:entry, :word_id => @id)
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
