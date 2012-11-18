# coding: utf-8

require File.expand_path(File.dirname(__FILE__) + '/../../../spec_helper')

describe IndexedSearch::Match::Soundex do

  context 'make_index_value' do
    before(:each) { @m = IndexedSearch::Match::Soundex }

    # every different soundex liibrary/algorithm/implementation does different things
    # especially when it comes to non-originally-defined edge cases...
    # we need to know exactly how the Text gem works to use it optimally
    #
    # here's what this teaches:
    #
    # the algorithm is the "original" ruleset, not the common "american" variation
    # it is strictly limited to 4 characters and cannot be lengthened
    # it generally hates ANY non-ascii-letter chars in the string and returns nil
    # except when *only* the first character is something else, then it uses it anyway

    it('norm')                        { @m.make_index_value('norm').should     == 'N650' }
    it('short word 1')                { @m.make_index_value('s').should        == 'S000' }
    it('short word 2')                { @m.make_index_value('sh').should       == 'S000' }
    it('long word')                   { @m.make_index_value('reallylongword').should == 'R445' }
    it('empty')                       { @m.make_index_value('').should         be_nil }

    it('standard 1')                  { @m.make_index_value('robert').should   == 'R163' }
    it('standard 2')                  { @m.make_index_value('rupert').should   == 'R163' }
    it('standard 3')                  { @m.make_index_value('rubin').should    == 'R150' }
    it('h between same letters 1')    { @m.make_index_value('ashcraft').should == 'A226' }
    it('h between same letters 2')    { @m.make_index_value('ashcroft').should == 'A226' }
    it('vowel between same letters')  { @m.make_index_value('tymczak').should  == 'T522' }
    it('first 2 letters same')        { @m.make_index_value('pfister').should  == 'P236' }

    it('uni vowel between same ltrs') { @m.make_index_value('tymczäk').should  be_nil }

    it('hyphen')                      { @m.make_index_value('too-much').should be_nil }
    it('apostrophe')                  { @m.make_index_value('can\'t').should   be_nil }
    it('smart apostrophe')            { @m.make_index_value('can’t').should    be_nil }
    it('initial hyphen')              { @m.make_index_value('-toomuch').should == '-352' }
    it('initial apostrophe')          { @m.make_index_value('\'cant').should   == '\'253' }
    it('initial smart apostrophe')    { @m.make_index_value('’cant').should    == '’253' }

    it('starts with number')          { @m.make_index_value('1norm').should    == '1565' }
    it('contains numbers')            { @m.make_index_value('no2r45m').should  be_nil }
    it('starts/contains numbers')     { @m.make_index_value('1no2r45m').should be_nil }
    it('all numbers')                 { @m.make_index_value('1234').should     be_nil }

    it('starts with unicode')         { @m.make_index_value('ﾃnorm').should    == 'ﾃ565' }
    it('starts with more unicode')    { @m.make_index_value('ﾃｰﾚnorm').should  be_nil }
    it('contains unicode')            { @m.make_index_value('noﾃrm').should    be_nil }
    it('all unicode')                 { @m.make_index_value('ﾃｰﾚｯﾃ').should    be_nil }
  end

  context 'with an index' do
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
      it('should be found') { find_results_for('thi1').should be_empty }
    end
  end

end
