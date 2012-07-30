# This migration comes from indexed_search_engine (originally 1)
class AddLongSoundex < ActiveRecord::Migration
  def self.up
    add_column :words, :american_soundex, :string, :null => true, :default => nil, :limit => 64
    add_index :words, :american_soundex
  end

  def self.down
    remove_column :words, :american_soundex
  end
end
