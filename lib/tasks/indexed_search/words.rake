
# more advanced stuff for maintaining your index, as you change certain configurations
# this is stuff that mainly affects the words table in the index

namespace :indexed_search do
  namespace :words do

    desc "When shortening indexed word lengths, de-duplicate and merge any indexes (site must be down for maintenance, and must migrate to shorter after). A LENGTH parameter is required to specify the new length."
    task :merge_shortened_dups => :environment do
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

    desc "Runs update_counts, delete_orphaned, and update_ranks.  When doing individual model record index updates/deletes, to save time these internal caches are not updated like they are for model-wide index deletes.  Running this rake task periodically can improve ranking and speed and conserve some space when that is done a lot."
    task :cleanup => :environment do
      puts "Updating words.entries_count column..."
      IndexedSearch::Word.update_counts
      puts "Deleting orphaned words that are no longer in use..."
      IndexedSearch::Word.delete_empty
      puts "Updating words.rank_limit column..."
      IndexedSearch::Word.update_ranks
      puts "Done."
    end

    desc "Updates the internal words.rank_limit column for all words.  When changing IndexedSearch::Word.rank_reduction_factor run this!"
    task :update_ranks => :environment do
      puts "Updating words.entries_count column..."
      IndexedSearch::Word.update_counts
      puts "Updating words.rank_limit column..."
      IndexedSearch::Word.update_ranks
      puts "Done."
    end

    desc "Updates the internal words.entries_count column for all words."
    task :update_counts => :environment do
      puts "Updating words.entries_count column..."
      IndexedSearch::Word.update_counts
      puts "Done."
    end

    desc "Deletes orphaned words that are no longer in use."
    task :delete_orphaned => :environment do
      puts "Deleting orphaned words that are no longer in use..."
      IndexedSearch::Word.delete_orphaned
      puts "Done."
    end

  end
end
