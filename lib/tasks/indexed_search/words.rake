
# more advanced stuff for maintaining your index, as you change certain configurations
# this is stuff that mainly affects the words table in the index

namespace :indexed_search do
  namespace :words do

    desc "When shortening indexed word lengths, de-duplicate and merge any indexes (site must be down for maintenance, and must migrate to shorter after)"
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

    desc "When changing IndexedSearch::Word.rank_reduction_factor run this!"
    task :update_ranks => :environment do
      puts "Updating words.rank_limit column..."
      IndexedSearch::Word.update_ranks
      puts "Done."
    end

    desc "When doing individual model record index deletes, internal cache of how many records have given words is not updated like it is for model-wide index deletes.  Running this rake task periodically can improve ranking and speed when that is done a lot."
    task :update_counts => :environment do
      puts "Updating words.entries_count column..."
      IndexedSearch::Word.update_counts
      puts "Done."
    end

    desc "When doing individual model record index updates/deletes, orphaned words that are no longer used are not cleaned up like they are for model-wide index updates/deletes.  Running this rake task periodically can save some space when that is done a lot."
    task :delete_orphaned => :environment do
      puts "Deleting orphaned words that are no longer in use..."
      IndexedSearch::Word.delete_orphaned
      puts "Done."
    end

  end
end
