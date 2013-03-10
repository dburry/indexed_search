require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe IndexedSearch::Word do
  before(:each) do
    @sw = IndexedSearch::Word
    @se = IndexedSearch::Entry
  end

  context 'finding/creating' do

    context 'without pre-existing words' do

      it 'to_s should return word text' do
        build(:word, :word => 'foo').to_s.should == 'foo'
      end
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
    end # with pre-existing words

  end # finding/creating
  
  context 'deleting/cleaning up unindexed words' do
    before(:each) { @ids = @sw.find_or_create_word_ids(['thoughts', 'those', 'going', 'gone']) }
    
    context 'when all words are unindexed' do
      it 'scope should include all of them' do
        Set.new(@sw.empty_entry).should == Set.new(@sw.find_all_by_id(@ids))
      end
      it 'delete orphaned should remove all of them' do
        @sw.delete_orphaned.should == 4
        @sw.all.should be_empty
      end
      it 'delete empty should remove all of them' do
        @sw.delete_empty.should == 4
        @sw.all.should be_empty
      end
    end
    
    context 'when only some are unindexed' do
      before(:each) do
        @id = @ids.shift # @ids only has unindexed left, after create!
        create(:entry, :word_id => @id)
      end
      it 'scope should include only some of them' do
        @sw.empty_entry.count.should > 1
        @sw.empty_entry.count.should < @sw.count
        Set.new(@sw.empty_entry).should == Set.new(@sw.find_all_by_id(@ids))
      end
      it 'delete should remove only some of them' do
        @sw.delete_orphaned.should == 3
        @sw.count.should == 1
        @sw.all.should == [@sw.find_by_id(@id)]
      end
      it 'delete empty without updating counts should still remove all of them' do
        @sw.delete_empty.should == 4
        @sw.all.should be_empty
      end
      it 'delete empty with updating counts should only remove some of them' do
        @sw.update_counts.should == 1
        @sw.delete_empty.should == 3
        @sw.count.should == 1
        @sw.all.should == [@sw.find_by_id(@id)]
      end
    end
    
    context 'when they are all indexed' do
      before(:each) { @ids.each { |id| create(:entry, :word_id => id) } }

      it 'updating counts should work' do
	@sw.update_counts.should == 4
	@sw.value_of(:entries_count).should == [1, 1, 1, 1]
      end
      it 'incrementing counts should work' do
	@sw.incr_counts_by_ids(@ids).should == 4
	@sw.value_of(:entries_count).should == [1, 1, 1, 1]
      end
      it 'decrementing counts should work' do
	@sw.update_counts
	@sw.decr_counts_by_ids(@ids).should == 4
        @sw.value_of(:entries_count).should == [0, 0, 0, 0]
      end
      it 'updating ranks should not do anything with not enough entries' do
	@sw.update_counts
	@sw.update_ranks.should == 0
        @sw.value_of(:rank_limit).should == [0, 0, 0, 0]
      end
      it 'updating ranks by ids should not do anything with not enough entries' do
	@sw.update_counts
	@sw.update_ranks_by_ids(@ids).should == 0
        @sw.value_of(:rank_limit).should == [0, 0, 0, 0]
      end
      it 'updating ranks by one id should not do anything with not enough entries' do
	@sw.update_counts
	@sw.update_ranks_by_ids([@ids.first]).should == 0
        @sw.value_of(:rank_limit).should == [0, 0, 0, 0]
      end
    
      context 'and one is indexed many more times' do
        before(:each) do
          #1500.times { create(:entry, :word_id => @ids.first) } # this is way too slow... so:
          @se.import([:word_id, :rowidx, :modelid, :modelrowid, :rank], [[@ids.first, 1, 1, 1, 1]] * 1500, :validate => false) 
        end

        it 'updating counts should have worked' do
	  @sw.update_counts
	  @sw.value_of(:entries_count).sort.should == [1, 1, 1, 1501]
        end
        it 'updating ranks without counts should not work' do
	  @sw.update_ranks.should == 0
	  @sw.value_of(:rank_limit).sort.should == [0, 0, 0, 0]
        end
        it 'updating ranks with updated counts should work' do
	  @sw.update_counts
	  @sw.update_ranks.should == 1
	  @sw.value_of(:rank_limit).sort.should == [0, 0, 0, 1]
        end
        it 'updating ranks by ids should work' do
	  @sw.update_counts
	  @sw.update_ranks_by_ids(@ids).should == 1
	  @sw.value_of(:rank_limit).sort.should == [0, 0, 0, 1]
        end
        it 'updating ranks by one id should work' do
	  @sw.update_counts
	  @sw.update_ranks_by_ids([@ids.first]).should == 1
	  @sw.value_of(:rank_limit).sort.should == [0, 0, 0, 1]
        end
	it 'updating counts/orphans/ranks should work' do
          @se.where(:id => @ids.last).delete_all
	  @sw.fix_counts_orphans_and_ranks.should == 5
	  @sw.value_of(:entries_count).sort.should == [1, 1, 1501]
	  @sw.value_of(:rank_limit).sort.should == [0, 0, 1]
	end
    
        context 'and then some indexes are removed' do
          before(:each) do
	    @sw.update_counts
	    @sw.update_ranks
	    eids = @se.where(:word_id => @ids.first).limit(500).value_of(:id)
	    @se.where(:id => eids).delete_all
	    @sw.update_counts
          end
          it 'updating counts should have worked' do
	    @sw.value_of(:entries_count).sort.should == [1, 1, 1, 1001]
          end
          it 'updating ranks should work' do
	    @sw.update_ranks.should == 1
	    @sw.value_of(:rank_limit).sort.should == [0, 0, 0, 0]
          end
          it 'updating ranks by ids should work' do
	    @sw.update_ranks_by_ids(@ids).should == 1
	    @sw.value_of(:rank_limit).sort.should == [0, 0, 0, 0]
          end
          it 'updating ranks by one id should work' do
	    @sw.update_ranks_by_ids([@ids.first]).should == 1
	    @sw.value_of(:rank_limit).sort.should == [0, 0, 0, 0]
          end
        end # and then some indexes are removed

      end # and one is indexed many more times
    end # when they are all indexed
  end # deleting/cleaning up unindexed words
end
