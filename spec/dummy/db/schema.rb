# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20120729095500) do

  create_table "bars", :force => true do |t|
    t.integer "foo_id",                               :null => false
    t.string  "name",   :limit => 10, :default => "", :null => false
  end

  add_index "bars", ["foo_id"], :name => "index_bars_on_foo_id"

  create_table "entries", :force => true do |t|
    t.integer "word_id",                                    :null => false
    t.integer "rowidx",       :limit => 8,                  :null => false
    t.integer "modelid",                                    :null => false
    t.integer "modelrowid",                                 :null => false
    t.integer "rank",                                       :null => false
    t.float   "row_priority",              :default => 0.5, :null => false
  end

  add_index "entries", ["modelid"], :name => "index_entries_on_modelid"
  add_index "entries", ["modelrowid"], :name => "index_entries_on_modelrowid"
  add_index "entries", ["rowidx"], :name => "index_entries_on_rowidx"
  add_index "entries", ["word_id", "rank"], :name => "index_entries_on_word_id_and_rank"

  create_table "foos", :force => true do |t|
    t.string "name",        :limit => 10, :default => "", :null => false
    t.string "description", :limit => 20, :default => "", :null => false
  end

  create_table "words", :force => true do |t|
    t.string  "word",                :limit => 64,                 :null => false
    t.integer "entries_count",                     :default => 0,  :null => false
    t.integer "rank_limit",                        :default => 0,  :null => false
    t.string  "stem",                :limit => 64, :default => "", :null => false
    t.string  "metaphone",           :limit => 64
    t.string  "soundex",             :limit => 4
    t.string  "primary_metaphone",   :limit => 4
    t.string  "secondary_metaphone", :limit => 4
    t.string  "american_soundex",    :limit => 64
  end

  add_index "words", ["american_soundex"], :name => "index_words_on_american_soundex"
  add_index "words", ["entries_count"], :name => "index_words_on_entries_count"
  add_index "words", ["metaphone"], :name => "index_words_on_metaphone"
  add_index "words", ["primary_metaphone"], :name => "index_words_on_primary_metaphone"
  add_index "words", ["secondary_metaphone"], :name => "index_words_on_secondary_metaphone"
  add_index "words", ["soundex"], :name => "index_words_on_soundex"
  add_index "words", ["stem"], :name => "index_words_on_stem"
  add_index "words", ["word"], :name => "index_words_on_word", :unique => true

end
