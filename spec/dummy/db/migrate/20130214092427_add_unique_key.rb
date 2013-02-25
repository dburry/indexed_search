class AddUniqueKey < ActiveRecord::Migration

  def self.up
    create_table(:keys, :id => false) do |t|
      t.integer 'idx',         :null => false
      t.string  'name',        :null => false, :default => '', :limit => 10
      t.string  'description', :null => false, :default => '', :limit => 20
    end
    add_index :keys, :idx, :unique => true

    create_table(:comps, :id => false) do |t|
      t.integer 'id1',         :null => false
      t.integer 'id2',         :null => false
      t.integer 'idx',         :null => false
      t.string  'name',        :null => false, :default => '', :limit => 10
      t.string  'description', :null => false, :default => '', :limit => 20
    end
    add_index :comps, [:id1, :id2], :unique => true
    add_index :comps, :idx, :unique => true
  end

  def self.down
    drop_table :comps
    drop_table :keys
  end
end
