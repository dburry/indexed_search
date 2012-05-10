
#
# ActiveRecord model class represents one single word match entry, in the search index.
#
# word_id
# rowidx --unique index number for modelid/modelrowid combinations, for optimized grouping
# modelid
# modelrowid
# rank
#

module IndexedSearch
  class Entry < ActiveRecord::Base
    belongs_to :word, :class_name => 'IndexedSearch::Word'
    
    # main entry points for searching database (either whole thing, or scope a limit first)
    # returns results, sorted in ranking order, with pagination support
    # note it actually returns a scope that can be lazily loaded! use #models to convert to actual models
    def self.find_results(query, page_size, page_number=1)
      query.nil? || query.empty? || query.results.empty? ? [] : matching_query(query.results).ranked_rows(query.results).paged(page_size, page_number)
    end
    # count the total results (with no sorting by ranking, pagination, etc)
    def self.count_results(query)
      query.nil? || query.empty? || query.results.empty? ? 0 : matching_query(query.results).count_distinct_rows
    end
    
    # find by word list: finds index entries with words that are exact, stemmed, abbreviated, or sounds like
    scope :matching_query, lambda { |query_results|
      terms = query_results.limited_word_map.collect { |id, lim| arel_table[:word_id].eq(id).and(arel_table[:rank].gt(lim)) }
      terms << arel_table[:word_id].in(query_results.unlimited_words) if query_results.unlimited_words.present?
      where(terms.inject { |a, b| a.or(b) })
    }
    # limit entries scope by model type
    scope :by_modelid, lambda { |mdlid|  where(:modelid    => mdlid) }
    # limit entries scope by model row
    scope :by_rowid,   lambda { |rowid|  where(:modelrowid => rowid) }
    # limit entries scope by entry id list
    scope :by_ids,     lambda { |ids|    where(:id         => ids) }
    # scope for removing indicated entry ids
    scope :not_rowids, lambda { |rowids| where(arel_table[:modelrowid].not_in(rowids)) }
    # group found results by distinct rows, sorted by sum of all matching word ranks
    # times a multiplier that makes more-multiple-word matches bubble up toward the top
    scope :ranked_rows, lambda { |query_results|
      select('entries.*, ' +
      # matching word rank multipliers, this is the main base ranking mechanism
      # multiplies higher for better matches (defaults: times 130 for exact, 12 stem, 8 startswith, 1 soundex)
      'SUM(' +
        query_results.reverse.collect { |result|
          "IF(word_id IN(#{result.list_map_words.join(',')}), #{result.rank_multiplier} * rank, "
        }.inject('1') { |inner, outer| outer + inner + ')' } +
      ') * ' +
      # term multipliers, to make things that match more search terms rank a lot higher
      # multiplies higher for better matches (number of matching terms times power of 1.90 for exact, 1.30 stem,
      # 1.15 startswith, or just straight multiply by 1 for soundex (by default those are the numbers anyway))
      '(' +
        query_results.collect { |result|
          "POWER(#{result.list_map.collect { |w,ids|
            "IF(SUM(IF(word_id IN(#{ids.join(',')}), 1, 0)) > 0, 1, 0)"
          }.join(' + ')}, #{result.term_multiplier})"
        }.join(' + ') +
      ') * ' +
      # result row priority multiplier, to weight more important data to sort slightly higher
      # (regardless of how well it matches), don't go quite to zero so multipliers aren't all zeroed out
      'IF(row_priority > 0, row_priority, 0.001) ' +
      'AS queryrank').
      group(:rowidx).
      order("queryrank DESC, rowidx")
    }
    # count distinct rows found (it's a function because count ignores any select/group from scope, but not conditions)
    def self.count_distinct_rows
      count(:select => 'DISTINCT rowidx')
    end
    # easy paging of results
    scope(:paged, lambda { |size, num| limit(size).offset(size * ([num - 1, 0].max)) })

    # get the instantiated results model class from the hit(s) we represent
    def self.models
      all.collect { |hit| hit.model }
    end
    def model
      @model ||= model_type.where(model_type.id_for_index_attr => modelrowid).first
    end
    def model_type
      @@model_type ||= IndexedSearch::Index.models_by_id[modelid]
    end
    
    # TODO: move this into a supporting library that adds it to activerecord somewhere?
    def self.reset_auto_increment
      connection.execute("ALTER TABLE entries AUTO_INCREMENT = 1") if count == 0
    end
    
    def to_s
      model.to_s
    end
  end
end
