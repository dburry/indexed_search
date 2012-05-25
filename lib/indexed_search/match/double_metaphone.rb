
module IndexedSearch
  module Match
    
    # Does a double metaphone algorithm comparison to find words that sound similar.
    # This only works well for English.
    # 
    # You know, they claim this is newer and "better" than the old regular Metaphone, but the keys are way shorter
    # and match tons more words (that aren't even as similar, kind of like soundex), so rank this just above soundex.
    # 
    # Uses primary_metaphone and secondary_metaphone columns to store values with each entry in the IndexedSearch::Word model.
    class DoubleMetaphone < IndexedSearch::Match::Base
      
      # Double metaphone matches have multiple values for when:
      #  * queried primary equals matched primary,
      #  * queried secondary equals matched primary,
      #  * queried primary equals matched secondary,
      #  * queried secondary equals matched secondary.
      self.rank_multiplier = [6,    5,    4,    3]
      self.term_multiplier = [1.14, 1.13, 1.12, 1.11]
      
      # This must never be longer than the database words.primary_metaphone and words.secondary_metaphone columns.
      # You will need to reindex everything after lengthening this (though lowering it only needs shortening db column).
      # The implementation in the text gem cannot ever go bigger than 4 characters!
      cattr_accessor :max_length
      self.max_length = 4
      
      
      # Only do metaphone for words that contain at least two ascii letters, or are one ascii letter.
      def self.match_against_term?(term)
        term.length == 1 && term =~ /^[a-z]$/ || term.length > 1 && term =~ /[a-z].*?[a-z]/
      end
      
      def scope
        @scope.where(@scope.arel_table[self.class.matcher_attribute.first].in(term_map.keys).or(
          @scope.arel_table[self.class.matcher_attribute.last].in(term_map.keys)))
      end
      self.matcher_attribute = [:primary_metaphone, :secondary_metaphone]
      
      def term_map
        term_maps[0]
      end
      def term_maps
        @term_maps ||= [].tap do |maps|
          # 3 maps: both, primary-only, secondary-only
          3.times { maps << Hash.new { |hash,key| hash[key] = [] } }
          term_matches.each do |term|
            vals = self.class.make_index_value(term)
            unless vals.first.nil?
              maps[0][vals.first] << term
              maps[1][vals.first] << term
            end
            unless vals.last.nil?
              maps[0][vals.last] << term
              maps[2][vals.last] << term
            end
          end
        end
      end
      
      def self.make_index_value(term)
        Text::Metaphone.double_metaphone(term).collect { |m| m.blank? ? nil : m[0..max_length] }
      end
      
      def results(do_all=false)
        [].tap do |res|
          if do_all || term_maps[1].present?
            res << IndexedSearch::Match::Result.new(self, term_maps[1], rank_multiplier[0], term_multiplier[0], limit_reduction_factor, type_reduction_factor, 0)
            res << IndexedSearch::Match::Result.new(self, term_maps[1], rank_multiplier[1], term_multiplier[1], limit_reduction_factor, type_reduction_factor, 1)
          end
          if do_all || term_maps[2].present?
            res << IndexedSearch::Match::Result.new(self, term_maps[2], rank_multiplier[2], term_multiplier[2], limit_reduction_factor, type_reduction_factor, 0)
            res << IndexedSearch::Match::Result.new(self, term_maps[2], rank_multiplier[3], term_multiplier[3], limit_reduction_factor, type_reduction_factor, 1)
          end
        end
      end
      
    end
  end
end

