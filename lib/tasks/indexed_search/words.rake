
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

  end
end
