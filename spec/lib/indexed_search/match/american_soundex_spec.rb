# coding: utf-8

require File.expand_path(File.dirname(__FILE__) + '/../../../spec_helper')

describe IndexedSearch::Match::AmericanSoundex do

  context 'make_index_value' do
    before(:each) { @m = IndexedSearch::Match::AmericanSoundex }

    # every different soundex liibrary/algorithm/implementation does different things
    # especially when it comes to non-originally-defined edge cases...
    # we need to know exactly how this one works to use it optimally
    #
    # here's what this teaches:
    #
    # this algorithm is the "american" variation not the "original" ruleset
    # it is *not* limited to 4 characters (though arbitrary limiting to such is possible)
    # it skips to the first unicode "letter" character before starting
    # it then incorporates that letter as it's first character, even if that isn't ascii
    # then it's very tolerant of non-ascii characters and just ignores them entirely
    #
    # note: this algorithm  is fairly similar to MySQL's internal SOUNDEX() function
    # although not perfectly bug-for-bug the same

    it('norm')                        { @m.make_index_value('norm').should     == 'N650' }
    it('short word 1')                { @m.make_index_value('s').should        == 'S000' }
    it('short word 2')                { @m.make_index_value('sh').should       == 'S000' }
    it('long word')                   { @m.make_index_value('reallylongword').should == 'R45263' }
    it('empty')                       { @m.make_index_value('').should         be_nil }

    it('standard 1')                  { @m.make_index_value('robert').should   == 'R163' }
    it('standard 2')                  { @m.make_index_value('rupert').should   == 'R163' }
    it('standard 3')                  { @m.make_index_value('rubin').should    == 'R150' }
    it('h between same letters 1')    { @m.make_index_value('ashcraft').should == 'A2613' }
    it('h between same letters 2')    { @m.make_index_value('ashcroft').should == 'A2613' }
    it('vowel between same letters')  { @m.make_index_value('tymczak').should  == 'T522' } # mysql: T520 here!
    it('first 2 letters same')        { @m.make_index_value('pfister').should  == 'P236' }

    it('uni vowel between same ltrs') { @m.make_index_value('tymczäk').should  == 'T520' }

    it('hyphen')                      { @m.make_index_value('too-much').should == 'T520' }
    it('apostrophe')                  { @m.make_index_value('can\'t').should   == 'C530' }
    it('smart apostrophe')            { @m.make_index_value('can’t').should    == 'C530' }
    it('initial hyphen')              { @m.make_index_value('-toomuch').should == 'T520' }
    it('initial apostrophe')          { @m.make_index_value('\'cant').should   == 'C530' }
    it('initial smart apostrophe')    { @m.make_index_value('’cant').should    == 'C530' } # mysql: ’253 here!

    it('starts with number')          { @m.make_index_value('1norm').should    == 'N650' }
    it('contains numbers')            { @m.make_index_value('no2r45m').should  == 'N650' }
    it('starts/contains numbers')     { @m.make_index_value('1no2r45m').should == 'N650' }
    it('all numbers')                 { @m.make_index_value('1234').should     be_nil }

    it('starts with unicode')         { @m.make_index_value('ﾃnorm').should    == 'ﾃ565' }
    it('starts with more unicode')    { @m.make_index_value('ﾃｰﾚnorm').should  == 'ﾃ565' }
    it('contains unicode')            { @m.make_index_value('noﾃrm').should    == 'N650' }
    it('all unicode')                 { @m.make_index_value('ﾃｰﾚｯﾃ').should    == 'ﾃ000' }

    # for comparison's sake, here's a mysql query to test:
    # SELECT SOUNDEX('norm'), SOUNDEX('s'), SOUNDEX('sh'), SOUNDEX('reallylongword'), SOUNDEX(''),
    # SOUNDEX('robert'), SOUNDEX('rupert'), SOUNDEX('rubin'), SOUNDEX('ashcraft'), SOUNDEX('ashcroft'),
    # SOUNDEX('tymczak'), SOUNDEX('pfister'), SOUNDEX('tymczäk'),
    # SOUNDEX('too-much'), SOUNDEX('can\'t'), SOUNDEX('can’t'), SOUNDEX('-toomuch'), SOUNDEX('\'cant'),
    # SOUNDEX('’cant'),
    # SOUNDEX('1norm'), SOUNDEX('no2r45m'), SOUNDEX('1no2r45m'), SOUNDEX('1234'),
    # SOUNDEX('ﾃnorm'), SOUNDEX('ﾃｰﾚnorm'), SOUNDEX('noﾃrm'), SOUNDEX('ﾃｰﾚｯﾃ')

    context 'with length of 5' do
      set_matcher_max_length :american_soundex, 5
      it('long word') { @m.make_index_value('reallylongword').should == 'R4526' }
    end
    context 'with length of 4' do
      set_matcher_max_length :american_soundex, 4
      it('long word') { @m.make_index_value('reallylongword').should == 'R452' }
    end
    context 'with length of 1' do
      set_matcher_max_length :american_soundex, 1
      it('long word') { @m.make_index_value('reallylongword').should == 'R' }
    end
  end

  context 'with an index' do
    set_perform_match_type :american_soundex
    set_index_match_type :american_soundex

    context 'standard' do
      before(:each) { @f1 = create(:indexed_foo, :name => 'thing') }
      it('find1') { find_results_for('thin').should be_empty }
      it('find2') { find_results_for('thing').models.should == [@f1] }
      it('find3') { find_results_for('things').models.should == [@f1] }
      it('find4') { find_results_for('th1ng').models.should == [@f1] }
      it('find5') { find_results_for('theng').models.should == [@f1] }
      it('find6') { find_results_for('think').models.should == [@f1] }
    end

    context 'single letter' do
      before(:each) { @f1 = create(:indexed_foo, :name => 't') }
      it('should be found') { find_results_for('t').models.should == [@f1] }
    end
    context 'two letters' do
      before(:each) { @f1 = create(:indexed_foo, :name => 'th') }
      it('should not be found') { find_results_for('th').models.should == [@f1] }
    end
    context 'a letter and a number' do
      before(:each) { @f1 = create(:indexed_foo, :name => 't1') }
      it('should be found') { find_results_for('t1').models.should == [@f1] }
    end
    context 'single number' do
      before(:each) { @f1 = create(:indexed_foo, :name => '1') }
      it('should not be found') { find_results_for('t1').should be_empty }
    end
    context 'multiple numbers' do
      before(:each) { @f1 = create(:indexed_foo, :name => '1234') }
      it('should not be found') { find_results_for('thi1').should be_empty }
    end

  end

end
