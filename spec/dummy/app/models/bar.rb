class Bar < ActiveRecord::Base
  belongs_to :foo
  attr_accessible :foo_id, :name

  include IndexedSearch::Index
  scope :search_index_scope, {}
  def search_index_info
    [
      [name,                 50],
      [foo.name,              5]
    ]
  end
  def search_priority
    0.5
  end
end