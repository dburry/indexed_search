require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe IndexedSearch::Entry do

  context 'scopes' do
    before(:each) do
      (@wid1, @wid2, @wid3) = IndexedSearch::Word.find_or_create_word_ids(['foo', 'bar', 'baz'])
      @e  = IndexedSearch::Entry
      @h1 = create(:entry, :word_id => @wid1, :rowidx => 1, :modelid => 1, :modelrowid => 1, :rank => 1, :id => 1)
      @h2 = create(:entry, :word_id => @wid2, :rowidx => 1, :modelid => 1, :modelrowid => 1, :rank => 2, :id => 2)
      @h3 = create(:entry, :word_id => @wid3, :rowidx => 2, :modelid => 1, :modelrowid => 2, :rank => 1, :id => 3)
      @h4 = create(:entry, :word_id => @wid2, :rowidx => 2, :modelid => 1, :modelrowid => 2, :rank => 2, :id => 4)
      @h5 = create(:entry, :word_id => @wid1, :rowidx => 3, :modelid => 2, :modelrowid => 1, :rank => 3, :id => 5)
    end
    # it('words1')   { Set.new(@e.by_words(['foo'])).should                 == Set.new([@h1, @h5]) }
    # it('words2')   { Set.new(@e.by_words(['bar'])).should                 == Set.new([@h2, @h4]) }
    # it('words3')   { Set.new(@e.by_words(['baz'])).should                 == Set.new([@h3]) }
    # it('words4')   { Set.new(@e.by_words(['foo', 'bar'])).should          == Set.new([@h1, @h2, @h4, @h5]) }
    # it('words5')   { Set.new(@e.by_words(['bar', 'baz'])).should          == Set.new([@h2, @h3, @h4]) }
    # it('words6')   { Set.new(@e.by_words(['foo', 'baz'])).should          == Set.new([@h1, @h3, @h5]) }
    # it('words7')   { Set.new(@e.by_words(['foo', 'bar', 'baz'])).should   == Set.new([@h1, @h2, @h3, @h4, @h5]) }
    # it('words8')   { Set.new(@e.by_words(['fump'])).should                == Set.new([]) }
    # it('words9')   { Set.new(@e.by_words([])).should                      == Set.new([]) }
    it('modelid1') { Set.new(@e.by_modelid(1)).should                     == Set.new([@h1, @h2, @h3, @h4]) }
    it('modelid2') { Set.new(@e.by_modelid(2)).should                     == Set.new([@h5]) }
    it('modelid3') { Set.new(@e.by_modelid(3)).should                     == Set.new([]) }
    it('rowid1')   { Set.new(@e.by_modelid(1).by_rowid(1)).should         == Set.new([@h1, @h2]) }
    it('rowid2')   { Set.new(@e.by_modelid(1).by_rowid(2)).should         == Set.new([@h3, @h4]) }
    it('rowid3')   { Set.new(@e.by_modelid(1).by_rowid(3)).should         == Set.new([]) }
    it('rowid4')   { Set.new(@e.by_modelid(2).by_rowid(1)).should         == Set.new([@h5]) }
    it('rowid5')   { Set.new(@e.by_modelid(3).by_rowid(1)).should         == Set.new([]) }
    it('ids1')     { Set.new(@e.by_ids([1, 2, 3])).should                 == Set.new([@h1, @h2, @h3]) }
    it('ids2')     { Set.new(@e.by_ids([1, 2, 3, 6])).should              == Set.new([@h1, @h2, @h3]) }
    it('ids3')     { Set.new(@e.by_ids([0])).should                       == Set.new([]) }
    it('ids4')     { Set.new(@e.by_ids([])).should                        == Set.new([]) }
    it('notrow1')  { Set.new(@e.by_modelid(1).not_rowids([1])).should     == Set.new([@h3, @h4]) }
    it('notrow2')  { Set.new(@e.by_modelid(1).not_rowids([2])).should     == Set.new([@h1, @h2]) }
    it('notrow3')  { Set.new(@e.by_modelid(1).not_rowids([3])).should     == Set.new([@h1, @h2, @h3, @h4]) }
    it('notrow4')  { Set.new(@e.by_modelid(1).not_rowids([1, 2])).should  == Set.new([]) }
    it('notrow5')  { Set.new(@e.by_modelid(1).not_rowids([1, 3])).should  == Set.new([@h3, @h4]) }
    it('notrow6')  { Set.new(@e.by_modelid(2).not_rowids([1])).should     == Set.new([]) }
    it('notrow7')  { Set.new(@e.by_modelid(2).not_rowids([2])).should     == Set.new([@h5]) }
    #it('notrow8')  { Set.new(@e.by_modelid(2).not_rowids([])).should      == Set.new([@h5]) }
    # it('ranked1')  { @e.ranked_rows([]).collect { |e| e.rowidx }.should                           == [1, 2, 3] }
    # it('ranked2')  { @e.by_words(['foo']).ranked_rows(['foo']).collect { |e| e.rowidx }.should         == [3, 1] }
    # it('ranked3')  { @e.by_words(['bar', 'baz']).ranked_rows(['bar', 'baz']).collect { |e| e.rowidx }.should  == [2, 1] }
    it('distinc1') { @e.count_distinct_rows.should                           == 3 }
    # it('distinc2') { @e.by_words(['foo']).count_distinct_rows.should         == 2 }
    # it('distinc3') { @e.by_words(['bar', 'baz']).count_distinct_rows.should  == 2 }
    # it('distinc3') { @e.by_words([]).count_distinct_rows.should              == 0 }
    it('paged1')   { Set.new(@e.paged(2, 1)).should                 == Set.new([@h1, @h2]) }
    it('paged2')   { Set.new(@e.paged(2, 2)).should                 == Set.new([@h3, @h4]) }
    it('paged3')   { Set.new(@e.paged(2, 3)).should                 == Set.new([@h5]) }
    it('paged4')   { Set.new(@e.paged(2, 4)).should                 == Set.new([]) }
  end

end
