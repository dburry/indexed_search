
require 'valium'

# uses a MODELS environment variable listing specific
# model names to process, otherwise it does all by default

namespace :indexed_search do

  namespace :internal do

    # get models from environment variable MODELS, or full list if there is no env
    def indexed_search_get_models
      return IndexedSearch::Index.models_by_id.values if ENV['MODELS'].blank? || ENV['MODELS'].strip == 'all'
      my_mdls = Set.new(ENV['MODELS'].split(',').collect { |m| m.strip })
      mdl_index = Set.new(IndexedSearch::Index.models_by_id.values.collect { |mdl| mdl.table_name.singularize })
      raise 'Unknown model' if my_mdls.reject { |m| mdl_index.include?(m) }.length > 0
      return IndexedSearch::Index.models_by_id.values.select { |mdl| my_mdls.include?(mdl.table_name.singularize) }
    end

    # initialize models
    # anything that doesn't auto-update itself needs to be extended with IndexedSearch::Index first, before we can index it
    task :init do
      indexed_search_get_models.reject { |mdl| mdl.respond_to?(:create_search_index) }.each { |mdl| mdl.extend IndexedSearch::Index }
    end

    # index models, assuming no existing ones
    # will create double-indexing if there are existing ones, so make sure there aren't any first!
    task :create do
      indexed_search_get_models.each do |mdl|
        puts "Indexing #{mdl.table_name}..."
        mdl.create_search_index
      end
    end

    # reindex existing model indexes in-place
    task :update do
      indexed_search_get_models.each do |mdl|
        puts "Reindexing #{mdl.table_name}..."
        mdl.update_search_index
      end
    end

    # erase indexes for models
    task :delete do
      indexed_search_get_models.each do |mdl|
        puts "Erasing index for #{mdl.table_name}..."
        mdl.delete_search_index
      end
    end

  end

  # our public tasks stitch internal above ones together in different useful ways

  desc "Make new indexes (NOTE: should not exist prior)"
  task :create => [:environment, 'indexed_search:internal:init', 'indexed_search:internal:create']

  desc "Redo indexes by deleting and creating, indexes aren't available inbetween"
  task :recreate => [:environment, 'indexed_search:internal:init', 'indexed_search:internal:delete', 'indexed_search:internal:create']

  desc "Redo existing live indexes in-place, with no down time"
  task :update => [:environment, 'indexed_search:internal:init', 'indexed_search:internal:update']

  desc "Delete existing indexes (can be scoped to just certain models)"
  task :delete => [:environment, 'indexed_search:internal:init', 'indexed_search:internal:delete']

  desc "Delete all indexes entirely (quickly, without caring what's in them')"
  task :clear => :environment do
    puts "Deleting all indexes..."
    IndexedSearch::Entry.delete_all
    IndexedSearch::Entry.reset_auto_increment
    IndexedSearch::Word.delete_all
    IndexedSearch::Word.reset_auto_increment
  end

  desc "When shortening indexed word lengths, de-duplicate and merge any indexes (site must be down for maintenance, and must migrate to shorter after)"
  task :merge_shortened_duplicates => :environment do
    len = ENV['LENGTH'].to_i
    len > 0 or raise "must specify a LENGTH variable"
    puts "Shortening internal word list data to #{len} characters"

    list = Hash.new { |hash,key| hash[key] = [] }
    IndexedSearch::Word.where(['CHAR_LENGTH(word) > ?', len]).each { |word| list[word.word[0..len]] << word }
    list = list.select { |key, val| val.length > 1 }
    puts "Detected #{list.length} words that would cause duplicates, when made shorter"

    list.each do |short, dups|
      newone = dups.first
      dups.delete(newone)
      dups.each do |dup|
        IndexedSearch::Entry.where(:word_id => dup.id).update_all(:word_id => newone.id)
        IndexedSearch::Word.delete(dup.id)
      end
    end
    puts "Merged duplicates"
  end

  desc "Explain a query, for optimization debugging purposes"
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
