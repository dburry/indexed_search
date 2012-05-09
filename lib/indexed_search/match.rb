
module IndexedSearch
  module Match
    
    # What types of matching algorithms to perform, and in what order.  It is recommended you go from more specific
    # to more general.  Default is [:exact, :stem, :metaphone, :start_with, :double_metaphone, :soundex]
    mattr_accessor :perform_match_types
    self.perform_match_types = [:exact, :stem, :metaphone, :start_with, :double_metaphone, :soundex]
    
    def self.match_class(type)
      @@match_class ||= {}
      @@match_class[type] ||= IndexedSearch::Match.const_get(type.to_s.camelize)
    end
    
    # Update just the match column for a specific match type
    # Warning: long running with a large index and many updates... but well suited for a maintenance rake task.
    # Won't run at a snail's pace by instantiating millions of activerecord objects in memory, and won't run out
    # of memory by loading all the data into memory at once either!
    def self.update_index(type)
      klass = match_class(type)
      count = 0
      IndexedSearch::Word.order('word').batches_by_ids do |scope|
        updates = Hash.new { |hash,key| hash[key] = [] }
        scope.order_values = []
        matcher_attrs = klass.matcher_attribute
        matcher_attrs = [matcher_attrs] unless matcher_attrs.kind_of?(Array)
        scope.values_of(*([:id, :word] + matcher_attrs)).each do |id, word, *matches|
          vals = klass.match_against_term?(word) ? klass.make_index_value(word) : [nil] * matcher_attrs.length
          vals = [vals] * matcher_attrs.lenth unless vals.kind_of?(Array)
          atrs = {}
          (0...matcher_attrs.length).to_a.each do |idx|
            atrs[matcher_attrs[idx]] = vals[idx] if matches[idx] != vals[idx]
          end
          if atrs.present?
            updates[atrs] << id
            count += 1
          end
        end
        updates.each { |atrs,ids| IndexedSearch::Word.where(:id => ids).update_all(atrs) }
      end
      count
    end
    
  end
end
