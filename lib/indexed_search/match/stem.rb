
module IndexedSearch
  module Match
    
    # Performs a word stemming match, using the Porter word stemming algorithm,
    # see: http://tartarus.org/martin/PorterStemmer/  Note the Porter algorithm is designed for English.
    # Requires the text gem
    # 
    # Uses a stem column to store a stem with each entry in the IndexedSearch::Word model.
    class Stem < IndexedSearch::Match::Base
      
      # Stem matches are of higher importance than most things except exact, they match relatively few words.
      # But there are better stemmer algorithms out there, so not too high of a multiplier :)
      self.rank_multiplier = [12,    11]
      self.term_multiplier = [ 1.30,  1.25]
      
      # Set maximum stem length
      cattr_accessor :max_length
      self.max_length = 64

      # TODO: remove this!
      def self.implementation=(what)
        ActiveSupport::Deprecation.warn "IndexedSearch::Match::Stem.implementation no longer does anything and will be removed from future releases.", caller
      end

      def scope
        @scope.where(self.class.matcher_attribute => term_map.keys)
      end
      self.matcher_attribute = :stem
      
      def term_map
        term_maps[0]
      end
      def term_maps
        @term_maps ||= [].tap do |maps|
          # 3 maps: both, words with stem equal to this term's stem, words with stem equal to this term
          # TODO: these still don't actually work right.. grr.. (the select in result.find weeds some unicode matches out
          # (which should be fixed by better normalization) and also weeds out the 3rd map term matches oops!)
          3.times { maps << Hash.new { |hash,key| hash[key] = [] } }
          term_matches.each do |term|
            stem = self.class.make_index_value(term)
            maps[0][stem] << term
            maps[0][term] << term if term != stem
            maps[1][stem] << term
            maps[2][term] << term
          end
        end
      end
      
      # stem routine, enforces set length too
      def self.make_index_value(term)
        # TODO figure out how to normalize these to ascii... (they've only been normalized by case)
        Text::PorterStemming.stem(term)[0..max_length]
      end
      
      def results(do_all=false)
        [].tap do |res|
          if do_all || term_maps[1].present?
            res << IndexedSearch::Match::Result.new(self, term_maps[1], rank_multiplier[0], term_multiplier[0], limit_reduction_factor, type_reduction_factor)
          end
          if do_all || term_maps[2].present?
            res << IndexedSearch::Match::Result.new(self, term_maps[2], rank_multiplier[1], term_multiplier[1], limit_reduction_factor, type_reduction_factor)
          end
        end
      end
      
    end
    
  end
end
