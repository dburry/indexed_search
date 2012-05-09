class InitialSetup < ActiveRecord::Migration
  def self.up

    # note this is mysql-specific:
    # needs InnoDB to support transactions, needs utf8 to better support non-english characters
    create_table(:words, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
      # needs binary collation so we can control case folding ourselves in ruby
      # instead of mysql doing something similar but slightly different mysteriously behind our backs
      t.column  'word', 'VARCHAR(64) CHARACTER SET utf8 COLLATE utf8_bin', :null => false
      t.integer 'entries_count',       :null => false, :default => 0
      t.integer 'rank_limit',          :null => false, :default => 0
      t.string  'stem',                :null => false, :default => '',  :limit =>  64
      t.string  'metaphone',           :null => true,  :default => nil, :limit =>  64
      t.string  'soundex',             :null => true,  :default => nil, :limit =>   4
      t.string  'primary_metaphone',   :null => true,  :default => nil, :limit =>   4
      t.string  'secondary_metaphone', :null => true,  :default => nil, :limit =>   4
    end
    add_index :words, :word, :unique => true
    add_index :words, :entries_count
    add_index :words, :stem
    add_index :words, :metaphone
    add_index :words, :soundex
    add_index :words, :primary_metaphone
    add_index :words, :secondary_metaphone

    create_table(:entries, :options => 'ENGINE=InnoDB') do |t|
       t.integer 'word_id', :null => false
       # this needs to be big int to hold larger indexes...
       t.column 'rowidx', 'BIGINT', :null => false
       t.integer 'modelid', 'modelrowid', 'rank', :null => false
       t.float   'row_priority', :null => false, :default => 0.5
    end
    add_index :entries, :rowidx
    add_index :entries, :modelid
    add_index :entries, :modelrowid
    add_index :entries, [:word_id, :rank]

  end

  def self.down
    drop_table :entries
    drop_table :words
  end
end
