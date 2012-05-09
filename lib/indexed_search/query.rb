# coding: utf-8
# ^ oh goody! a comment so our literal regexp is in correct encoding!

require 'unicode_utils/casefold'

# Search internals encompasses 4 steps:
# 1. parsing the literal query string into words or search terms (IndexedSearch::Query)
# 2. look in the words table to see how well they match up and get some optimizing data about them (IndexedSearch::Word, IndexedSearch::Match*)
# 3. using the data from step 2, query the big table to find the actual model matches (IndexedSearch::Entry)
# 4. using the data from step 3, convert matches to actual models and display them (do this in your controllers/views)
# 
# This class performs step 1 when you instantiate it, and has a helper for looking up and associating step 2 data with it.
# 
# note: for now parsing is just a simple array of unique words...
# whereas someday it may become a boolean AND/OR parser or something else more complicated...
module IndexedSearch
  class Query < Array
    
    # regexp defining how to split words
    # 
    # suitable for any language with:
    #  1) any unicode alpha-numeric character class is considered a word character (requires a recent ruby!)
    #  2) space or any other non-word character between every separate word
    #  3) one single embedded apostrophe (') allowed inside any word, but not around it
    #     (I know, all the apostrophe-at-word-ends will be munged, but they cannot be distinguished from quotes! so...)
    #  4) but no dash or anything else allowed inside a word, that will all indicate separate words
    # this doen't conform to any technical language word definition, just makes it practical for search term parsing
    # this works quite well not only with english, but also with a lot of non-english languages
    # 
    # TODO: some languages will need something different, we'll deal with those as we come to them, for example:
    # japanese, chinese, and thai do not put anything between their words
    # and some languages may need the whole apostrophe thing altered (removed, or something else substituted)...
    cattr_accessor :word_match_regex
    self.word_match_regex = /\p{Alnum}+(?:'\p{Alnum}+)*/
    
    # for now the query parsing is just split_into_words, and making it unique
    def initialize(str)
      super(self.class.split_into_words(str).uniq)
    end
    
    # split a string or array of strings into an array of individual word strings, ignoring any blank data
    # used equally well by parsing a simple search query, and by parsing data for indexing
    def self.split_into_words(txt)
      if txt.blank?
        []
      elsif txt.class == Array
        txt.collect { |a| a.blank? ? [] : UnicodeUtils.casefold(a).scan(word_match_regex) }.collect { |w| w[0...IndexedSearch::Word.max_length] }.flatten
      else
        UnicodeUtils.casefold(txt).scan(word_match_regex).collect { |w| w[0...IndexedSearch::Word.max_length] }
      end
    end
    
    # lookup (and cache) word id data on this word query
    def results
      @results ||= IndexedSearch::Match::ResultList.new(self)
    end
    
    # code depends on #empty? being here.. which it is, since we are a subclass of Array
    
  end
end
