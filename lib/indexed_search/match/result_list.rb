
module IndexedSearch
  module Match
    
    # Group of result instances per match types, plus gather data for dealing with them as a group.
    class ResultList < Array
      
      attr_accessor :counts_by_word, :counts_by_term, :word_ids, :limited_word_map, :unlimited_words
      def initialize(terms)
        # terms left to process (all of them to start with, obviously)
        terms = Set.new(terms.dup)
        # result match counts so far per term (none of them to start with, obviously)
        self.counts_by_term = Hash.new { |hash,key| hash[key] = 0 }
        # ids that match so far, so we know which ones to skip later when we see them again
        self.word_ids = Set.new
        self.counts_by_word = {}
        self.limited_word_map = {}
        self.unlimited_words = []
        word_scope = IndexedSearch::Word.order('entries_count')

        IndexedSearch::Match.perform_match_types.each do |match_type|
          match_klass = IndexedSearch::Match.match_class(match_type)
          match_klass.new(word_scope.limit(match_klass.matches_reduction_factor), terms).results.each do |result|
            unless result.empty?
              result.find.each do |id, count, rank, *matches|
                unless self.word_ids.include?(id) || result.term_map[matches[result.matchidx]].any? { |term| self.counts_by_term[term] >= result.limit_reduction_factor }
                  self.word_ids << id
                  self.counts_by_word[id] = count
                  self.limited_word_map[id] = rank if rank > 0
                  self.unlimited_words << id if rank == 0
                  result.term_map[matches[result.matchidx]].each do |term|
                    result.list_map[term] << id
                    self.counts_by_term[term] += count
                    terms.delete(term) if counts_by_term[term] >= result.type_reduction_factor
                  end
                end
              end
              self << result if result.list_map.present?
              return if terms.empty?
            end
          end
        end
        
      end
      
    end # result list class
    
  end # match module
end # search module
