class InitialAppSetup < ActiveRecord::Migration

  def self.up
    create_table(:foos, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
      t.string 'name',        :null => false, :default => '', :limit => 10
      t.string 'description', :null => false, :default => '', :limit => 20
    end
    create_table(:bars, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
      t.integer 'foo_id',     :null => false
      t.string 'name',        :null => false, :default => '', :limit => 10
    end
    add_index :bars, :foo_id
  end

  def self.down
    drop_table :bars
    drop_table :foos
  end
end
