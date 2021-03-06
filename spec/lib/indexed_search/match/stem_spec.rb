require File.expand_path(File.dirname(__FILE__) + '/../../../spec_helper')

describe IndexedSearch::Match::Stem do
  set_perform_match_type :stem

  context 'standard' do
    before(:each) { @f1 = create(:indexed_foo, :name => 'thing') }
    it('find1') { find_results_for('thin').should be_empty }
    it('find2') { find_results_for('thing').models.should == [@f1] }
    it('find3') { find_results_for('things').models.should == [@f1] }
    it('find4') { find_results_for('th1ng').should be_empty }
    it('find5') { find_results_for('theng').should be_empty }
    it('find6') { find_results_for('think').should be_empty }
  end

  context 'reverse' do
    before(:each) { @f1 = create(:indexed_foo, :name => 'things') }
    it('find1') { find_results_for('thin').should be_empty }
    it('find2') { find_results_for('thing').models.should == [@f1] }
    it('find3') { find_results_for('things').models.should == [@f1] }
  end

end
