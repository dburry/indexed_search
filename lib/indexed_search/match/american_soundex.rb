# coding: utf-8

require 'unicode_utils/simple_upcase'

module IndexedSearch
  module Match

    # Does the "american soundex" variation of the soundex algorithm comparison to find words
    # that sound similar.  Only works well for English.
    #
    # Also supports keys longer than 4 characters, and is more tolerant of unicode characters
    # in a way that's somewhat similar to how MySQL's SOUNDEX() function works...
    #
    # Uses an american_soundex column to store a soundex value with each entry in the IndexedSearch::Word model.
    # TODO: ideally non-ascii letters should be normalized to similar ascii ones if they can...
    class AmericanSoundex < IndexedSearch::Match::Base

      # american_soundex matches have fairly high importance, since they are fairly specific in what they match.
      self.rank_multiplier = 10
      self.term_multiplier = 1.23

      # Only do american_soundex for words that contain at least one ascii letter.
      self.match_against_term = proc { |term| term =~ /[a-z]/ }

      # The default column name to store soundex values in is 'american_soundex'
      # You may want to change it if you're doing multiple soundex variants in the same index.
      self.matcher_attribute = :american_soundex

      # Set this to your standard max word length probably...
      # Or if you prefer the standard 4 character keys instead, set that here...
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

      MAP = {
        'a' => '0', 'e' => '0', 'i' => '0', 'o' => '0', 'u' => '0',
        'b' => '1', 'f' => '1', 'p' => '1', 'v' => '1',
        'c' => '2', 'g' => '2', 'j' => '2', 'k' => '2', 'q' => '2', 's' => '2', 'x' => '2', 'z' => '2',
        'd' => '3', 't' => '3',
        'l' => '4',
        'm' => '5', 'n' => '5',
        'r' => '6'
      }

      # see: http://en.wikipedia.org/wiki/Soundex#Rules
      # our exception is of course the length, and some limited unicode tolerance
      def self.make_index_value(term)
        idx = 0
        idx += 1 until term[idx] =~ /\A\p{Alpha}\Z/  || idx >= term.size
        return nil if idx >= term.size
        value = UnicodeUtils.simple_upcase(term[idx])
        return value if max_length == 1
        last_code = MAP[term[idx]]
        while idx < term.size do
          idx += 1
          code = MAP[term[idx]]
          if ! code.nil? && code != last_code
            value += code if code != '0'
            return value if value.size >= max_length
            last_code = code
          end
        end
        value.size < 4 ? value + "000"[0,4-value.size] : value
      end

    end
  end
end

