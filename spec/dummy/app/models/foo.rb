class Foo < ActiveRecord::Base
  has_many :bars
  attr_accessible :name, :description

  include IndexedSearch::Index
  scope :search_index_scope, {}
  def search_index_info
    [
      [name,                 51],
      [bars.collect(&:name),  5],
      [description,           1],
    ]
  end
  def search_priority
    0.6
  end
end