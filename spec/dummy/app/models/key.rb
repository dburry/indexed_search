class Key < ActiveRecord::Base
  attr_accessible :name, :description

  include IndexedSearch::Index
  scope :search_index_scope, {}
  def self.id_for_index_attr
    :idx
  end
  def search_index_info
    [
      [name,                 51],
      [description,           1],
    ]
  end
  def search_priority
    0.6
  end
end