require File.expand_path(File.dirname(__FILE__) + '/../../../spec_helper')

describe IndexedSearch::Match::Initials do
  set_perform_match_type :initials

  context 'standard' do
    before(:each) { @f1 = create(:indexed_foo, :name => 'thing') }
    it('find1') { find_results_for('thin').should be_empty }
    it('find2') { find_results_for('thing').should be_empty }
    it('find3') { find_results_for('things').should be_empty }
    it('find4') { find_results_for('th1ng').should be_empty }
    it('find5') { find_results_for('theng').should be_empty }
    it('find6') { find_results_for('think').should be_empty }
    it('find7') { find_results_for('t').models.should == [@f1] }
  end

  context 'single letter' do
    before(:each) { @f1 = create(:indexed_foo, :name => 't') }
    it('find 1') { find_results_for('t').models.should == [@f1] }
    it('find 2') { find_results_for('th').models.should == [@f1] }
    it('find 2') { find_results_for('this').models.should == [@f1] }
  end
  context 'two letters' do
    before(:each) { @f1 = create(:indexed_foo, :name => 'th') }
    it('should not be found') { find_results_for('th').should be_empty }
  end

end
