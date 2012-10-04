
# more advanced stuff for maintaining your index, as you change certain configurations
# this is stuff that mainly affects the words table in the index

namespace :indexed_search do
  namespace :entries do

    desc "Clean up when index has gotten out of sync and points to some models that no longer exist. You should not normally need to run this unless there's a bug, or you've drastically changed your index definitions in certain ways"
    task :delete_orphaned => :environment do
      puts "Deleting orphaned index entries..."
      IndexedSearch::Entry.delete_orphaned
      IndexedSearch::Word.delete_orphaned
      puts "Done."
    end

  end
end
