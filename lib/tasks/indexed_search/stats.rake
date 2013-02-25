
namespace :indexed_search do

  desc "Display some stats about the search database"
  task :stats => ['stats:basic', 'stats:matchers', 'stats:words', 'stats:models']

  namespace :stats do

    task :basic => :environment do
      puts "\n"
      puts "#{IndexedSearch::Word.count} words (unique case-folded words)"
      puts "#{IndexedSearch::Entry.count} entries (many-to-many mappings between words and model records)"
    end

    task :matchers => :environment do
      puts "\n"
      puts "#{IndexedSearch::Match.perform_match_types.length} matchers enabled:"
      IndexedSearch::Match.perform_match_types.each do |match_type|
        match_klass = IndexedSearch::Match.match_class(match_type)
        match_attr = match_klass.matcher_attribute
        if match_attr == IndexedSearch::Match::Base.matcher_attribute
          puts "  #{match_type}"
        else
          puts "  #{match_type}:"
          match_attr = Array.wrap(match_attr)
          match_attr.each do |attr|
            count = IndexedSearch::Word.where(IndexedSearch::Word.arel_table[attr].not_eq(nil)).count
            puts "    #{count} words indexed as #{attr}"
          end
        end
      end
    end

    task :words => :environment do
      topwords = ENV['TOPWORDS'].to_i
      topwords = 20 if topwords <= 0
      puts "\n"
      factor = IndexedSearch::Word.rank_reduction_factor
      high = IndexedSearch::Word.where(IndexedSearch::Word.arel_table[:entries_count].gt(factor)).count
      puts "#{high} words are being limited in search results because they are found in more than #{factor} records"
      puts "#{topwords} most common words:"
      IndexedSearch::Word.order('entries_count DESC').limit(topwords).each do |word|
        #usage = IndexedSearch::Entry.where(:word_id => word.id).group('modelid').count.collect do |id, cnt|
        #  "#{IndexedSearch::Index.models_by_id[id].name.underscore}: #{cnt}"
        #end
        usage = IndexedSearch::Index.models_by_id.collect do |id, mdl|
          cnt = IndexedSearch::Entry.where(:modelid => id, :word_id => word.id).count
          cnt == 0 ? nil : "#{mdl.name.underscore}: #{cnt}"
        end.compact
        puts "  #{word.word}: #{word.entries_count} records (used in: #{usage.join(', ')})"
      end
    end

    task :models => :environment do
      puts "\n"
      puts "#{IndexedSearch::Index.models_by_id.length} different models indexed:"
      IndexedSearch::Index.models_by_id.each do |id, mdl|
        puts "  #{mdl.name.underscore}:"
        mdl_count = mdl.search_index_scope.count
        puts "    #{mdl_count} records"
        entry_mdl_count = IndexedSearch::Entry.by_modelid(id).count
        puts "    #{entry_mdl_count} entries (avg #{(1.0 * entry_mdl_count / mdl_count).round} unique words per record)"
        entry_word_mdl_count = IndexedSearch::Entry.by_modelid(id).count('DISTINCT word_id')
        puts "    #{entry_word_mdl_count} unique words (avg #{(1.0 * entry_word_mdl_count / mdl_count).round} overall unique in each record)"
      end
    end

  end

end
