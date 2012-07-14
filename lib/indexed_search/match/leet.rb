# coding: utf-8
# ^ oh goody! a comment so our unicode literals work!

module IndexedSearch
  module Match
    
    # Performs a speedy but minimalistic rudimentary 1337 (Leet) match, see: http://en.wikipedia.org/wiki/Leet
    # Note that non-alpha-numerics are never included in the index, so we're limited to letters and numbers.
    # The default mappings only has some basic ascii, but could be extended to include many unicode characters.
    # It's kept so short by default so that speed impact doesn't get out of hand.  Using regular expressions
    # could yield higher quantity and quality matches, and be a more succinct of a description of them too,
    # but they are very slow with really large word lists so they're kind of impractical to use here.
    class Leet < IndexedSearch::Match::Base
      
      # The word index is normalized to lowercase and various other international foldings.
      # So given character x, if UnicodeUtils.casefold('x').match(/^[\p{Lower}\p{Number}]+$/) is true,
      # then that character can be indexed, and these strings should always contain the casefold value.
      # Keys must be single characters (multi-byte ok), and values can be any number of characters per value.
      # The default list is small for speed, since resource usage grows exponentially with this algorithm.
      # TODO: support multi-character keys someday maybe?
      cattr_accessor :replacements
      self.replacements = {
        '1' => ['i','l','t'],
        '2' => ['z'],
        '3' => ['e'],
        '4' => ['a','h'],
        '5' => ['s'],
        '6' => ['b','g'],
        '7' => ['l','t','z'],
        '8' => ['b'],
        '9' => ['g','q'],
        '0' => ['d','o','q'],
        'a' => ['4'],
        'b' => ['8','6','13','l3'],
        'd' => ['0','c1','cl'],
        'e' => ['3'],
        'g' => ['6','9'],
        'h' => ['4'],
        'i' => ['1'],
        'l' => ['1','7'],
        'm' => ['nn'],
        'o' => ['0'],
        'q' => ['0','9'],
        'r' => ['12','l2'],
        's' => ['5','z'],
        't' => ['7','1'],
        'w' => ['uu','vv'],
        'z' => ['2','7']
      }
      
      # Leet matches are of higher importance than many things, but not highest.
      self.rank_multiplier = 13
      self.term_multiplier =  1.40
      
      # Only do leet for shorter words, the list of potential matches gets exponentially too large otherwise,
      # and then it takes too long to run on large indexes (seconds instead of milliseconds).
      self.max_term_length = 9

      def scope
        @scope.where(self.class.matcher_attribute => term_map.keys)
      end
      
      # map potential matches back to which search query term(s) have them
      def term_map
        @term_map ||= Hash.new { |hash,key| hash[key] = [] }.tap do |map|
          term_matches.each { |term| self.class.matches_for(term).each { |match| map[match] << term } }
        end
      end
      
      # given a string of characters, look each one up in the leet replacement table, and return a giant batch
      # of possibilities with every character replaced with every possible combination of leet from the table
      # this loop tries to be efficient due to the potential for a lot of possible matches
      def self.matches_for(term)
        matches = []
        counts = [0] * term.length
        # cached in local var for speed increase, compared to method call in loops
        replacements = (0..term.length-1).collect { |pos| replacements_for(term[pos]) || [term[pos]] }
        # treating original string like a bunch of digits, this loop is the digit incrementer
        loop do
          # concatenate a match together (better speed by not using temporary arrays with a chained one-liner)
          match = ''
          (0..term.length-1).each { |pos| match << replacements[pos][counts[pos]] }
          matches << match
          # increment digit
          counts[0] += 1
          # loop for carrying over to next digit(s), when a digit reaches its maximum
          pos = 0
          while counts[pos] >= replacements[pos].length
            counts[pos] = 0
            pos += 1
            # return results when all digits reached max, we're done
            return matches if pos >= term.length
            counts[pos] += 1
          end
        end
      end
      
      def self.replacements_for(char)
        # cached version with original first, like a zero is used in math when you count
        (@@replacements_for ||= Hash[replacements.collect { |orig,repls| [orig, [orig] + repls] }])[char]
      end
      
    end
    
  end
end
