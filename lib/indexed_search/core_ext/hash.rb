class Hash

  # Returns a new hash whose values default and spring into a new yielded object when accessed.
  # Handy when assigning data into multi-dimensional structures inside loops and things,
  # especially when you cannot easily tell if all the dimensions have been initialized yet.
  # The normal way of doing this is so obtusely verbose I decided to make a shortcut!
  #
  # So, for example, instead of trying this (does NOT work):
  #
  #   x = {}
  #   x[:foo][:bar] = 'baz' # => NoMethodError: undefined method '[]=' for nil:NilClass
  #
  # or doing this (works, but terrible):
  #
  #   x = {}
  #   x[:foo] ||= {}
  #   x[:foo][:bar] = 'baz'
  #   x # => {:foo => {:bar => 'baz'}}
  #
  # or trying to do this (does NOT work as intended):
  #
  #   x = Hash.new({})
  #   x[:foo][:bar] = 'baz'
  #   x # => {}
  #   x[:foo] # => {:bar => 'baz'}
  #   x[:a][:b] = 'c'
  #   x # => {}
  #   x[:a] # => {:bar => 'baz', :b => 'c'}
  #   x[:foo] # => {:bar => 'baz', :b => 'c'}
  #
  # or this (works well, but is long and confusing looking):
  #
  #   x = Hash.new { |hash, key| hash[key] = {} }
  #   x[:foo][:bar] = 'baz'
  #   x # => {:foo => {:bar => 'baz'}}
  #
  # you can now do this instead (much cleaner looking and obvious what it does):
  #
  #   x = Hash.of { {} } # x is a hash of hashes
  #   x[:foo][:bar] = 'baz'
  #   x # => {:foo => {:bar => 'baz'}}
  #
  # It works with other things too, for example:
  #
  #   x = Hash.of { [] } # hash of arrays
  #   x[:foo] << 1
  #   x[:bar] += [1, 2, 3]
  #   x # => {:foo => [1], :bar => [1, 2, 3]}
  #
  #   x = Hash.of { Set.new } # hash of sets
  #   x[:foo] += [1, 2, 3]
  #   x[:foo] += [2, 3, 4]
  #   x # => {:foo => Set.new([1, 2, 3, 4])}
  #
  #   x = Hash.of { '' } # hash of strings
  #   x[:foo] << 'asdf'
  #   x[:foo] << ';lkj'
  #   x # => {:foo => 'asdf;lkj'}
  #
  #   x = Hash.of { Hash.of { Hash.new(0) } } # hash of hashes of hashes of integers
  #   x[:a][:b][:c] += 1
  #   x # => {:a => {:b => {:c => 1}}}
  #
  # Note: simple constants like 0 can be passed to Hash#new for the same effect,
  # so it's not necessary to use Hash#of on them (you could, but it's slower),
  # but more complex objects are actually passed in by reference so they don't work that way
  #
  def self.of
    new { |hash, key| hash[key] = yield }
  end

  # Returns a new hash created by using the values as keys, and the keys as arrays of values.
  # Instead of clobbering multiple keys with the same value like the standard Hash#invert does,
  # this one preserves that kind of data in arrays.
  #
  # For example:
  #
  #   {1 => 2, 3 => 4, 5 => 2}.invert       # => {2 => 5, 4 => 3}
  #   {1 => 2, 3 => 4, 5 => 2}.invert_multi # => {2 => [1, 5], 4 => [3]}
  #
  def invert_multi
    self.class.of { [] }.tap { |hash| each { |key, value| hash[value] << key } }
  end

end
