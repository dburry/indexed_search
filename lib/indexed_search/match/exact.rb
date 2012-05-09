
module IndexedSearch
  module Match
    
    # Does a simple exact match.
    # 
    # Note this uses database string equality matching in some places, and ruby string equality in others,
    # which does not always mean exactly the same thing especially with certain unicode characters.
    # But our term normalization in IndexedSearch::Query.split_into_words should make it a non-issue.
    class Exact < IndexedSearch::Match::Base
      
      # Exact matches are extremely important, and should therefore have highest importance by far.
      self.rank_multiplier = 130
      self.term_multiplier =   1.90
      
      def scope
        @scope.where(self.class.matcher_attribute => term_matches.to_a)
      end
      
      # ideally exact matches ideally shouldn't need this complexity, just other types do...
      # since 'exact' match terms exactly equal their matches (duh),
      # but it's just too complicated to make a difference....
      def term_map
        @term_map ||= {}.tap { |map| term_matches.each { |term| map[term] = [term] } }
      end
      
    end
  end
end
