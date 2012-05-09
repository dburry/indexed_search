# coding: utf-8
# ^ oh goody! a comment so unicode literals and regexps behave!

# This is the global configuration file for this Rails search engine.
# Unless otherwise stated, values shown commented out are the defaults

# Maps indexed models to internal integer id numbers.  Makes indexes much shorter and faster, instead of using a
# Rails-STI-style "type" string column
IndexedSearch::Index.models_by_id = {
  # YOU MUST ADD SOMETHING HERE OR NOTHING WILL BE INDEXED, for example:
  #1 => FooThing,
  #2 => BarThing
}


# Regexp defining what word characters consist of, everything else being treated as separators,
# for the purpose of indexing all the words.
#
# Suitable for any language with:
#  1) any unicode alpha-numeric character class is considered a word character (requires a recent ruby!)
#  2) space or any other non-word character between every separate word
#  3) one (at a time) embedded apostrophe (') allowed inside any word, but not around it
#     (I know, all the apostrophe-at-word-ends will be munged, but they cannot be distinguished from quotes! so...)
#  4) but no dash or anything else allowed inside a word, that will all indicate separate words
#
# This doesn't conform to any technical language word definition, just makes it practical for search term parsing.
# This default works quite well not only with English, but also with a LOT of other languages too!
#
# Some languages will need something different, however, for example:
# Japanese, Chinese, and Thai do not put anything between their words,
# and some languages may need the whole apostrophe thing altered (removed, or something else substituted)...
# Someday we may redesign it to be even more multilingual than it already is, instead of just configurable here.
#
# Note that changing this means you will need to rebuild the entire index.
# Note that you need the magic "coding: utf-8" comment at the top of *this* file for Unicode matching to work here.
#
#IndexedSearch::Query.word_match_regex = /\p{Alnum}+(?:'\p{Alnum}+)*/


# What types of matching algorithms to perform, and in what order.  It is recommended you go from more specific
# to more general.  Current possibilities are: :exact, :leet, :stem, :metaphone, :start_with, :soundex,
# and :double_metaphone
# More can be created with the API, just put them inside the IndexedSearch::Match module and on your load path.
# 
# Simple descriptions of each match type:
# 
# :exact      - Does a simple exact equality match.
# :leet       - Performs a speedy but minimalistic rudimentary 1337 (Leet) match,
#               see: http://en.wikipedia.org/wiki/Leet  The default mappings only has some basic ascii,
#               but could be extended to include many unicode characters. It's kept short by default for speed.
# :stem       - Performs a word stemming match, using the Porter word stemming algorithm,
#               see: http://tartarus.org/martin/PorterStemmer/  Note the Porter algorithm is designed for English.
#               Requires the stemmer or text gem, see: http://stemmer.rubyforge.org/wiki/wiki.pl
# :metaphone  - see: http://en.wikipedia.org/wiki/Metaphone
# :start_with - Does a start-with comparison to find words whose beginning part is equal to the given terms.
#               In concept it's kind of like a nice lowest-common-denominator stemmer for all languages.
#               Though it's obviously not as good as most real language-specific stemmer algorithms of course.
# :soundex    - Does a soundex algorithm comparison to find words that sound similar. Designed for English names.
# :double_metaphone - see: http://en.wikipedia.org/wiki/Metaphone
#
#IndexedSearch::Match.perform_match_types = [:exact, :stem, :metaphone, :start_with, :double_metaphone, :soundex]


# What types of matching algorithms to consider when building an index.  Some algorithms need an extra column in
# the word list table of the index (:stem, :metaphone, :soundex, :double_metaphone currently).  Note adding to
# this will require rebuilding the whole index.
# 
#IndexedSearch::Word.index_match_types = [:stem, :metaphone, :soundex, :double_metaphone]


# Limit so searches only consider this many top-ranked matches per each word match in the index.
# This is to limit adverse speed impact of very common words.
# For best speed tune this via experimentation to be as low as you can, and still give you good results.
# Note: words.rank_limit column needs to be rebuilt (with #update_ranks) to take advantage of any changes to this
#
#IndexedSearch::Word.rank_reduction_factor = 1200


# Don't drop entries due to rank_reduction_factor, if their rank is at or above this rank
# set this lower to limit the carnage rank_reduction_factor can cause to some really-common-but-important words
# of course at the expense to some increased time for those words...
# in practice this is pretty ineffectual to use, because even unimportant words are used in important
# contexts, making them slow your search to a crawl if you reduce it by much
#
#IndexedSearch::Word.min_rank_reduction = 120


# Set maximum length of words to be indexed.  Anything longer than this will be truncated before indexing.
# Ideally words.word table column should match this (and must not be shorter than this)
# Lengthening this requires rebuilding the whole database
# Shortening could use db to truncate, except any duplicates must be removed first!
#
#IndexedSearch::Word.max_length = 64


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
# 
#IndexedSearch::Match::Base.matches_reduction_factor = 50


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
# 
#IndexedSearch::Match::Base.limit_reduction_factor = 200


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
# 
#IndexedSearch::Match::Base.type_reduction_factor = 100


# Note:
# The IndexedSearch::Match::Base class defaults listed above are used when a specific subclassed one is not set.
# (No subclass ones are set by default.)  For example:
# 
#IndexedSearch::Match::Exact.matches_reduction_factor           =  50
#IndexedSearch::Match::Exact.limit_reduction_factor             = 200
#IndexedSearch::Match::Exact.type_reduction_factor              = 100
#IndexedSearch::Match::Leet.matches_reduction_factor            =  50
#IndexedSearch::Match::Leet.limit_reduction_factor              = 200
#IndexedSearch::Match::Leet.type_reduction_factor               = 100
#IndexedSearch::Match::Stem.matches_reduction_factor            =  50
#IndexedSearch::Match::Stem.limit_reduction_factor              = 200
#IndexedSearch::Match::Stem.type_reduction_factor               = 100
#IndexedSearch::Match::Metaphone.matches_reduction_factor       =  50
#IndexedSearch::Match::Metaphone.limit_reduction_factor         = 200
#IndexedSearch::Match::Metaphone.type_reduction_factor          = 100
#IndexedSearch::Match::StartWith.matches_reduction_factor       =  50
#IndexedSearch::Match::StartWith.limit_reduction_factor         = 200
#IndexedSearch::Match::StartWith.type_reduction_factor          = 100
#IndexedSearch::Match::Soundex.matches_reduction_factor         =  50
#IndexedSearch::Match::Soundex.limit_reduction_factor           = 200
#IndexedSearch::Match::Soundex.type_reduction_factor            = 100
#IndexedSearch::Match::DoubleMetaphone.matches_reduction_factor =  50
#IndexedSearch::Match::DoubleMetaphone.limit_reduction_factor   = 200
#IndexedSearch::Match::DoubleMetaphone.type_reduction_factor    = 100


# Every match subclass has this setting which is a multiplier used by the ranking system
# to indicate the relative value of each match type, compared to matches of other types.
# This is used as a base multiplier against every match.
# Should be an integer in the range of about 1 to 200 or so.
# (as a multiplier there isn't technically a limit, that's just a suggestion)
# 
#IndexedSearch::Match::Exact.rank_multiplier      = 130
#IndexedSearch::Match::Leet.rank_multiplier       =  13
#IndexedSearch::Match::Stem.rank_multiplier       =  12
#IndexedSearch::Match::Metaphone.rank_multiplier  =  10
#IndexedSearch::Match::StartWith.rank_multiplier  =   8
#IndexedSearch::Match::Soundex.rank_multiplier    =   1
#
# The double metaphone one is special. It has multiple values for when:
#  * queried primary equals matched primary,
#  * queried secondary equals matched primary,
#  * queried primary equals matched secondary,
#  * queried secondary equals matched secondary.
#IndexedSearch::Match::DoubleMetaphone.rank_multiplier = [6, 5, 4, 3]


# Every match subclass has this setting which is a multiplier used by the ranking system
# to indicate the relative value of each match type, compared to matches of other types.
# This is used as an exponential multiplier to make results that match multiple terms score much higher.
# Should be a float in the range of about 1.0 or 2.0 or so.
# (as a multiplier there isn't technically a limit, that's just a suggestion)
# 
#IndexedSearch::Match::Exact.term_multiplier      = 1.90
#IndexedSearch::Match::Leet.term_multiplier       = 1.40
#IndexedSearch::Match::Stem.term_multiplier       = 1.30
#IndexedSearch::Match::Metaphone.term_multiplier  = 1.20
#IndexedSearch::Match::StartWith.term_multiplier  = 1.15
#IndexedSearch::Match::Soundex.term_multiplier    = 1.00
#
# The double metaphone one is special. It has multiple values.
#IndexedSearch::Match::DoubleMetaphone.term_multiplier = [1.14, 1.13, 1.12, 1.11]


# Set max length for match subclasses that have indexed column(s) in the Word model.
# See: IndexedSearch::Word.index_match_types for more details.
# Ideally these should match the table column lengths in the migration (they must not be longer than table).
# If you lengthen these, you must reindex everything.
# If you shorten these, you must either reindex, or alter the table (which truncates them automatically).
# It is unlikely you will ever benefit from setting any of these longer than IndexedSearch::Word.max_length
# The implementation of soundex and double metaphone in the text gem cannot ever go bigger than 4 characters!
# (which is why they are set up to be lowest priority, because they match a lot of crap)
#
#IndexedSearch::Match::Stem.max_length            = 64
#IndexedSearch::Match::Metaphone.max_length       = 64
#IndexedSearch::Match::Soundex.max_length         =  4
#IndexedSearch::Match::DoubleMetaphone.max_length =  4


# If you enable the Leet matcher, you could supply your own replacement list.
# The word index is normalized to lowercase and various other international foldings.
# So given character x, if UnicodeUtils.casefold('x').match(/^#{IndexedSearch::Query.word_match_regex}$/) is true,
# then that character can be indexed, and these strings should always contain the casefold value.
# Keys must be single characters (multi-byte ok), and values can be any number of characters per value.
# The default list is small for speed, since resource usage grows exponentially with this algorithm.
# Note that you need the magic "coding: utf-8" comment at the top of *this* file if you include Unicode literals.
# 
#IndexedSearch::Match::Leet.replacements = {
#  '1' => ['i','l','t'],
#  '2' => ['z'],
#  '3' => ['e'],
#  '4' => ['a','h'],
#  '5' => ['s'],
#  '6' => ['b','g'],
#  '7' => ['l','t'],
#  '8' => ['b'],
#  '9' => ['g','q'],
#  '0' => ['d','o','q'],
#  'a' => ['4'],
#  'b' => ['8','6','13','l3'],
#  'd' => ['0','c1','cl'],
#  'e' => ['3'],
#  'g' => ['6','9'],
#  'h' => ['4'],
#  'i' => ['1'],
#  'l' => ['1','7'],
#  'm' => ['nn'],
#  'o' => ['0'],
#  'q' => ['0','9'],
#  'r' => ['12','l2'],
#  's' => ['5','z'],
#  't' => ['7','1'],
#  'w' => ['uu','vv'],
#  'z' => ['2']
#}

# Which gem's API to use for Porter Stemming: stemmer gem or text gem.
# There is no default, if you use stem matches you must choose one.
IndexedSearch::Match::Stem.implementation = :text


# Add indexers to application observers
# This could be in application.rb but why make people edit that...
new_observers = Dir[Rails.root.join('app/indexers/*_indexer.rb')].
  collect { |f| File.basename(f, '.rb') }.
  reject { |f| f == 'application_indexer' }
if ! ActiveRecord::Base.observers
  ActiveRecord::Base.observers = new_observers
else
  ActiveRecord::Base.observers += new_observers
end
