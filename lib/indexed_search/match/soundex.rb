
module IndexedSearch
  module Match
    
    # Does a soundex algorithm comparison to find words that sound similar.  Only works well for English.
    # 
    # Uses a soundex column to store a soundex value with each entry in the IndexedSearch::Word model.
    class Soundex < IndexedSearch::Match::Base
      
      # Soundex matches have the lowest importance (it matches a lot of unrelated stuff, but might catch a misspelling)
      self.rank_multiplier = 1
      self.term_multiplier = 1.0

      # Only do soundex for words that contain more than two ascii letters.
      self.match_against_term = proc { |term| term.length > 2 && term =~ /[a-z].*?[a-z].*?[a-z]/ }

      # The default column name to store soundex values in is 'soundex'
      # You may want to change it if you're doing multiple soundex variants in the same index.
      self.matcher_attribute = :soundex
      
      # The implementation in the text gem cannot ever go bigger than 4 characters.
      cattr_accessor :max_length
      self.max_length = 4

      def scope
        @scope.where(self.class.matcher_attribute => term_map.keys)
      end
      
      def term_map
        @term_map ||= Hash.new { |hash,key| hash[key] = [] }.tap do |map|
          term_matches.each { |term| map[self.class.make_index_value(term)] << term }
        end
      end
      
      def self.make_index_value(term)
        Text::Soundex.soundex(term)
      end
      
    end
  end
end

