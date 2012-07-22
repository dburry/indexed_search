require File.expand_path(File.dirname(__FILE__) + '/../../../spec_helper')

describe IndexedSearch::Match::Soundex do
  set_perform_match_type :soundex

  context 'standard' do
    before(:each) { @f1 = create(:indexed_foo, :name => 'thing') }
    it('find1') { find_results_for('thin').should be_empty }
    it('find2') { find_results_for('thing').models.should == [@f1] }
    it('find3') { find_results_for('things').models.should == [@f1] }
    it('find4') { find_results_for('th1ng').should be_empty }
    it('find5') { find_results_for('theng').models.should == [@f1] }
    it('find6') { find_results_for('think').models.should == [@f1] }
  end

  context 'single letter' do
    before(:each) { @f1 = create(:indexed_foo, :name => 't') }
    it('should not be found') { find_results_for('t').should be_empty }
  end
  context 'two letters' do
    before(:each) { @f1 = create(:indexed_foo, :name => 'th') }
    it('should not be found') { find_results_for('th').should be_empty }
  end
  context 'three letters' do
    before(:each) { @f1 = create(:indexed_foo, :name => 'thi') }
    it('should be found') { find_results_for('thi').models.should == [@f1] }
  end
  context 'two letters and a number' do
    before(:each) { @f1 = create(:indexed_foo, :name => 'th1') }
    it('should not be found') { find_results_for('th1').should be_empty }
  end
  context 'three letters and a number' do
    before(:each) { @f1 = create(:indexed_foo, :name => 'thi1') }
    it('should be found') { find_results_for('thi1').models.should == [@f1] }
  end

end
