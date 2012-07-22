require File.expand_path(File.dirname(__FILE__) + '/../../../spec_helper')

describe IndexedSearch::Match::Metaphone do
  set_perform_match_type :metaphone

  context 'standard' do
    before(:each) { @f1 = create(:indexed_foo, :name => 'thing') }
    it('find1') { find_results_for('thin').should be_empty }
    it('find2') { find_results_for('thing').models.should == [@f1] }
    it('find3') { find_results_for('things').should be_empty }
    it('find4') { find_results_for('th1ng').models.should == [@f1] }
    it('find5') { find_results_for('theng').models.should == [@f1] }
    it('find6') { find_results_for('think').models.should == [@f1] }
  end

end
