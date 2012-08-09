
module IndexedSearch
  module Match

    # Does an "initials" match for names.  Basically, it matches a full name against its initial,
    # and an initial against all full names.  This is kind of a variation of a start-with match,
    # but more efficient for this one purpose, and it works properly in both directions.
    class Initials < IndexedSearch::Match::Base

      # Initials matches are around where starts_with matches are.
      self.rank_multiplier = 7
      self.term_multiplier = 1.15

      # set some different defaults for this matcher
      self.matches_reduction_factor = 250

      def scope
        arel_atr = @scope.arel_table[self.class.matcher_attribute]
        @scope.where(
          arel_atr.matches_any(term_matches.select { |t| t.length == 1 }.uniq.collect { |t| "#{t}%" }).
          or(
            arel_atr.in(term_matches.select { |t| t.length > 1 }.collect(&:first).uniq)
          )
        )
      end

      def term_map
        @term_map ||= Hash.new { |hash,key| hash[key] = [] }.tap do |map|
          find.each do |id,count,rank,match|
            term_matches.each { |term| map[match] << term if term.length == 1 ? match.start_with?(term) : match == term.first }
          end
        end
      end

    end

  end
end
