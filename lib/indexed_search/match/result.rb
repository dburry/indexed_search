
module IndexedSearch
  module Match
    
    # each matcher class generates one (or more) of these to describe its results.
    class Result
      attr_accessor :matcher, :term_map, :rank_multiplier, :term_multiplier, :limit_reduction_factor, :type_reduction_factor, :matchidx
      def initialize(matcher, term_map, rank_multiplier, term_multiplier, limit_reduction_factor, type_reduction_factor, matchidx=0)
        self.matcher = matcher
        self.term_map = term_map
        self.rank_multiplier = rank_multiplier
        self.term_multiplier = term_multiplier
        self.limit_reduction_factor = limit_reduction_factor
        self.type_reduction_factor = type_reduction_factor
        self.matchidx = matchidx
        self.list_map = Hash.new { |hash,key| hash[key] = [] }
      end
      def find
        # TODO: I don't think this select should be necessary for everything, right?
        @find ||= matcher.find.select { |id, count, rank, *matches| term_map.has_key?(matches[matchidx]) }
      end
      def empty?
        find.empty?
      end
      
      # populated by result list class
      attr_accessor :list_map
      
      def list_map_words
        list_map.values.flatten.uniq
      end
      
    end # result class
    
  end # match module
end # search module
