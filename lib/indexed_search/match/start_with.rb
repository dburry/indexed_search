
module IndexedSearch
  module Match
    
    # Does a start-with comparison to find words whose beginning part is equal to the given terms.
    # In concept it's kind of like a nice lowest-common-denominator stemmer for all languages.
    # Though it's obviously not as good as most real language-specific stemmer algorithms of course.
    # 
    # Note this uses database LIKE matching in some places, and ruby String#start_with? in others,
    # which does not always mean exactly the same thing.
    # But our term normalization in IndexedSearch::Query.split_into_words should make it a non-issue.
    class StartWith < IndexedSearch::Match::Base
      
      # Start-with matches are of somewhat low importance.
      self.rank_multiplier = 7
      self.term_multiplier = 1.15
      
      # Only do start-with for longer-than-one-letter words, otherwise they match too broadly.
      # This was found to work best through experimentation.
      self.min_term_length = 2

      def scope
        @scope.where(@scope.arel_table[self.class.matcher_attribute].matches_any(term_matches.collect { |t| "#{t}%" }))
      end
      
      def term_map
        @term_map ||= Hash.new { |hash,key| hash[key] = [] }.tap do |map|
          find.each { |id,count,rank,match| term_matches.each { |term| map[match] << term if match.start_with?(term) } }
        end
      end
      
    end
    
  end
end
