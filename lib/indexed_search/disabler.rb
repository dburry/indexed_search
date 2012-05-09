
# add some stuff to all activerecord models to check if something should be indexed or not
class ActiveRecord::Base
  def without_indexing
    prev_indexing = @no_indexing
    @no_indexing = true
    yield.tap { @no_indexing = prev_indexing }
  end
  def self.without_indexing
    prev_indexing = (@@no_indexing ||= false)
    @@no_indexing = true
    yield.tap { @@no_indexing = prev_indexing }
  end
  def no_indexing?
    (@@no_indexing ||= false) || @no_indexing
  end
  def self.no_indexing?
    (@@no_indexing ||= false)
  end
end
