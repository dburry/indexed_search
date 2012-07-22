require File.expand_path(File.dirname(__FILE__) + '/../../../spec_helper')

describe IndexedSearch::Match::StartWith do
  set_perform_match_type :start_with

  context 'standard' do
    before(:each) { @f1 = create(:indexed_foo, :name => 'thing') }
    it('find1') { find_results_for('thin').models.should == [@f1] }
    it('find2') { find_results_for('thing').models.should == [@f1] }
    it('find3') { find_results_for('things').should be_empty }
    it('find4') { find_results_for('th1ng').should be_empty }
    it('find5') { find_results_for('theng').should be_empty }
    it('find6') { find_results_for('think').should be_empty }
  end

  context 'single letter' do
    before(:each) { @f1 = create(:indexed_foo, :name => 't') }
    it('should not be found') { find_results_for('t').should be_empty }
  end
  context 'two letters' do
    before(:each) { @f1 = create(:indexed_foo, :name => 'th') }
    it('should be found') { find_results_for('th').models.should == [@f1] }
  end

end
