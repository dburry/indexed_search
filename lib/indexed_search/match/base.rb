require 'valium'

module IndexedSearch
  module Match
    
    # base class for common functionality in match definition classes
    class Base
      
      # Limit the number of matched words considered within each match type (exact, stem, start_with, soundex)
      # to the top this many most common matches.  Default is 50, and can be overridden by each match type in their
      # own subclass.
      # 
      # In theory this could toss out important results, but in practice if you have so many words matching a single term,
      # then it's likely that your search is simply too broad anyway, so this just limits the adverse speed impact of
      # matching against so many words up front.  Remember that real people generally only look at the first
      # page or two of results anyway, thank Google for teaching people that.
      # 
      # For example:
      # You have a search term of "ab" and there are no "exact" matches in your word index.  So, more broadly, you're
      # afterward performing a "start_with" type of match against it, and you have 400 words in your word index that
      # start with "ab".  In this case, the end user is not likely to find so many results useful.  It's more likely
      # the end user will be overwhelmed with too many bogus results, and have to refine their search.  So you'd just
      # waste time looking up that many results anyway.  Rather than doing that, we'll limit it to the top 50
      # most-common words that start with "ab".  Already we've reduced our search time by 75%
      # 
      # It does the most common ones first here, to attempt to soak up as many results with as few matching words as it
      # can so that other reduction factors can take over and limit results and improve speed even further sooner in the
      # process. For example, limit_reduction_factor, type_reduction_factor, and rank_reduction_factor all happen
      # after matches_reduction_factor, and can speed up results further this way.  Note that this most-common-first
      # rule has no influence at all on ranking of results, as that's applied much much later in the whole process.
      class_attribute :matches_reduction_factor
      self.matches_reduction_factor = 50
      
      # Stop any further gathering of more matches for a given term within the same match type, if all current
      # matches for that term would resolve to more than this many reults.  Default is 200, and can be overridden
      # by each match type in their own subclass.
      # 
      # In theory this could toss out important results, but in practice if you have so many results, then it's 
      # likely that your search is simply too broad anyway, so this just limits the adverse speed impact of
      # trying to look up so many results afterwards.  Remember that real people generally only look at the first
      # page or two of results anyway, thank Google for teaching people that.
      # 
      # This runs after matches_reduction_factor has already had its cut at reducing stuff, but before
      # type_reduction_factor and rank_reduction_factor has had a chance.  Note that this reduction has no influence
      # at all on ranking of results, as that's applied much much later in the whole process.
      # 
      # This depends on the "entries_count" column in the "words" model to function properly.
      class_attribute :limit_reduction_factor
      self.limit_reduction_factor = 200
      
      # Stop progressing to any further match types in the chain for an input term (default is: exact > stem >
      # start_with > soundex) if all current matches for that term would resolve to more than this many reults.
      # Default is 100, and can be overridden by each match type in their own subclass.
      # 
      # In theory this could toss out important results, but in practice if you have so many results, then it's 
      # likely that your search is simply too broad anyway, so this just limits the adverse speed impact of
      # trying to look up so many results afterwards.  Remember that real people generally only look at the first
      # page or two of results anyway, thank Google for teaching people that.
      # 
      # This essentially short-circuits the matching process, to save time by not even running further match
      # algorithms at all, if you have too many results.  This runs after matches_reduction_factor and
      # limit_reduction_factor, but before rank_reduction_factor.  Note that this reduction has no influence
      # at all on ranking of results, as that's applied much much later in the whole process.
      # 
      # This depends on the "entries_count" column in the "words" model to function properly.
      class_attribute :type_reduction_factor
      self.type_reduction_factor = 100

      # Overridden by most subclasses to indicate a multiplier used by the ranking system
      # to indicate the relative value of each match type, compared to matches of other types.
      # This is used as a base multiplier against every match.
      # Defaults to 1, which is a very low value, and should be an integer in the range of about 1 to 200 or so.
      # (as a multiplier there isn't technically a limit, that's just a suggestion)
      class_attribute :rank_multiplier
      self.rank_multiplier = 1

      # Overridden by most subclasses to indicate a multiplier used by the ranking system
      # to indicate the relative value of each match type, compared to matches of other types.
      # This is used as an exponential multiplier to make results that match multiple terms score much higher.
      # Defaults to 1.0, which is a very low value, and should be a float in the range of about 1.0 or 2.0 or so.
      # (as a multiplier there isn't technically a limit, that's just a suggestion)
      class_attribute :term_multiplier
      self.term_multiplier = 1.0

      # If you want a given match type to only accept words with at least so many characters, override this.
      # Defaults to nil, which means there is no minimum, some matchers do override by default.
      class_attribute :min_term_length
      self.min_term_length = nil

      # If you want a given match type to only accept words with at most so many characters, override this.
      # Defaults to nil, which means there is no maximum, some matchers do override by default.
      class_attribute :max_term_length
      self.max_term_length = nil

      # If you have custom code you want to run to check the format of each term to determine if it can be used
      # by a given matcher or not, set a proc here.  Note that setting this overrides any min_term_length and
      # max_term_length settings, unless your code actually makes use of them...
      # Defaults to nil, which means there is no such code, all word formats are allowed to be indexed,
      # and some matchers do override this default.
      class_attribute :match_against_term
      self.match_against_term = nil

      # Override in subclass to pick the IndexedSearch::Word model attribute that the given match type needs
      # Defaults to "word" since that's what most of them need.
      # Can also be changed in config file in cases where there is an unusual non-default database column name.
      class_attribute :matcher_attribute
      self.matcher_attribute = :word

      def initialize(scope, terms)
        @scope = scope
        @terms = terms
      end
      
      # the terms we should actually match against for a given match algorithm type
      # for some algorithms this will be shorter than the terms we were initialized with,
      # because some terms are unsuitable for some algorithms (too short, bad characters, etc)
      def term_matches
        @term_matches ||= @terms.select { |t| self.class.match_against_term?(t) }
      end

      # the inverse of term_matches, a list of the terms that were rejected
      # only used by explain rake task, not the usual searching algorithm
      def term_non_matches
        @terms.reject { |t| self.class.match_against_term?(t) }
      end
      
      # Whether or not we should do a given algorithm match on indicated input term word text.
      # Rather than overriding, see class attributes: min_term_length, max_term_length, match_against_term
      def self.match_against_term?(term)
        if ! match_against_term.nil?
          match_against_term.call(term)
        else
          return false if ! min_term_length.nil? && term.length < min_term_length
          return false if ! max_term_length.nil? && term.length > max_term_length
          true
        end
      end
      
      # override in subclass to add a match-type-specific where clause to scope
      def scope
        @scope
      end

      def self.find_attributes
        if matcher_attribute.kind_of?(Array)
          [:id, :entries_count, :rank_limit] + matcher_attribute
        else
          [:id, :entries_count, :rank_limit] << matcher_attribute
        end
      end
      def find
        @find ||= scope.values_of(*self.class.find_attributes)
      end
      
      # override this if a matcher returns multiple kinds of results...
      def results(do_all=false)
        [].tap do |res|
          if do_all || term_matches.present?
            res << IndexedSearch::Match::Result.new(self, term_map, rank_multiplier, term_multiplier, limit_reduction_factor, type_reduction_factor)
          end
        end
      end
      
    end # base class
    
  end # match module
end # search module
