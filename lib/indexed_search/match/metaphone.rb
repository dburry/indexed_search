
module IndexedSearch
  module Match
    
    # Does a metaphone algorithm comparison to find words that sound similar.
    # This only works well for English.
    # 
    # Uses a metaphone column to store a metaphone value with each entry in the IndexedSearch::Word model.
    class Metaphone < IndexedSearch::Match::Base
      
      # Metaphone matches have higher importance than soundex, because they're probably closer
      self.rank_multiplier = 10
      self.term_multiplier =  1.20

      # Only do metaphone for words that contain at least two ascii letters, or are one ascii letter.
      # This was found to work best through experimentation.
      self.match_against_term = proc { |term| term.length == 1 && term =~ /^[a-z]$/ || term.length > 1 && term =~ /[a-z].*?[a-z]/ }

      # The default column name to store metaphone values in is 'metaphone'
      self.matcher_attribute = :metaphone

      # This must never be longer than the database words.metaphone column.
      # You will need to reindex everything after lengthening this (though lowering it only needs shortening db column).
      cattr_accessor :max_length
      self.max_length = 64

      def scope
        @scope.where(self.class.matcher_attribute => term_map.keys)
      end

      def term_map
        @term_map ||= Hash.new { |hash,key| hash[key] = [] }.tap do |map|
          term_matches.each { |term| map[self.class.make_index_value(term)] << term }
        end
      end
      
      def self.make_index_value(term)
        Text::Metaphone.metaphone(term)[0..max_length]
      end
      
    end
  end
end

