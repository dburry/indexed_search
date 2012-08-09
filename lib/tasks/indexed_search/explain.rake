
require 'valium'

# rake task for explaining the innards of how a query is working with your settings and index
# very useful for debugging problems and optimizing your settings
# TODO: need to make it time how long the queries take...

namespace :indexed_search do

  desc "Explain a query for optimizing/debugging, uses QUERY, LIMIT, VERBOSE"
  task :explain => :environment do
    querystr = ENV['QUERY']
    limit = ENV['LIMIT'].to_i
    querystr.blank? and raise "must specify a QUERY variable"
    limit = 10 if limit <= 0
    ENV['VERBOSE'].blank? || ENV['VERBOSE'] =~ /^(?:1|0|yes|no|true|false|on|off)$/ or raise "bad value for VERBOSE"
    verbose = ENV['VERBOSE'].present? && ENV['VERBOSE'] =~ /^(?:1|yes|true|on)$/

    query = IndexedSearch::Query.new(querystr)
    if query.empty?
      puts "Query contained no terms!"
      next
    end
    puts "Parsed into terms: " + query.join(', ')

    if query.results.empty?
      puts "Query matched no words in the index!"
      next
    end
    puts "Word matches:"
    (verbose ? IndexedSearch::Match::ResultList.new(query, true) : query.results).each do |matchresult|
      matchname = matchresult.matcher.class.name.demodulize.underscore
      puts "  #{matchname}:"
      if verbose
        non_matches = matchresult.matcher.term_non_matches
        unless non_matches.empty?
          puts "    skipped terms (too short or wrong format): " + non_matches.join(', ')
        end
        ignored_matches = matchresult.ignored_because_already_used
        unless ignored_matches.empty?
          puts "    skipped matches (previously used): " +
                 IndexedSearch::Word.where(id: ignored_matches).value_of(:word).join(', ')
        end
      end
      matchresult.list_map.each do |term, ids|
        values = IndexedSearch::Word.order(:entries_count).where(id: ids).values_of(:word, :entries_count)
        puts "    #{term}: " + values.collect {|w,c| "#{w} (#{c})"}.join(', ')
      end
      if matchresult.matcher.scope.length >= matchresult.matcher.matches_reduction_factor
        puts "    NOTE: Matching words may be truncated due to #{matchresult.matcher.matches_reduction_factor} matches!" +
               "  If this is a problem, see matches_reduction_factor in your settings."
      end
      if matchresult.reduced_by_limit_reduction_factor
        puts "    NOTE: Matching words truncated due to over #{matchresult.limit_reduction_factor} results!" +
               "  If this is a problem, see limit_recution_factor in your settings."
      end
    end
    limited = query.results.counts_by_term.select {|t,c| c >= IndexedSearch::Match::Base.type_reduction_factor }.keys
    unless limited.empty?
      puts "  NOTE: Match types may be truncated (for terms #{limited.join(', ')}) due to too many results!" +
             "  If this is a problem, see type_reduction_factor in your settings."
    end

    count = IndexedSearch::Entry.count_results(query)
    if count == 0
      puts "No results were found!\nNOTE: Your index needs to be compacted, since word matches were found but no results."
      next
    end
    puts "Results (" + (count <= limit ? count.to_s : "#{limit} of #{count}") + '):'
    IndexedSearch::Entry.find_results(query, limit, 1).each do |result|
      name = result.model.respond_to?(:name) ? result.model.name : result.model.to_s
      puts "  #{result.model.class.name.underscore} [#{result.queryrank.to_i}]: #{name}"
    end

  end

end
