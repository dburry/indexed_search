
module IndexedSearch

  # This implements a kind of optimistic duplication-prevention behavior without using any
  # slow locking or anything like that.
  #
  # The way it works is: certain column(s) get a unique index on them at the database level,
  # so that you cannot create duplicate entries for them.  If you were to try, you'd cause an
  # ActiveRecord::RecordNotUnique error.
  #
  # The expected scenario is like such: you look up and find the records you need, and if
  # any aren't found, you do a (relatively expensive) generation process for the new ones and
  # insert them.  You wrap this entire process in a special function that catches any insertion
  # errors, and retries (including the looking-up of what is in there again).
  #
  # This may sound similar to find_or_create_by_ already built into ActiveRecord, but it has
  # one key difference: if your generation process is quite expensive, you only have to do it
  # for missing records.  If most of the time records should be found and not need to be
  # generated, then this can give you significant time savings.

  module Collision

    class TooManyCollisionsException < Exception
    end

    # maximum number of retries when optimistic creates fail from collisions
    # after it retries this many times, it will just raise the exception
    # optimistic non-locking-just-catching-exceptions can't really deadlock
    # when done properly but can might overwhelmed from too much concurrency
    # so if you get exceptions, that's probably your problem is too much concurrency
    # in testing it seems pretty unlikely to happen (more likely to crash the machine first)
    mattr_accessor :max_collision_retries
    self.max_collision_retries = 3

    # usage like this:
    #
    # extend IndexedSearch::Collision
    # def find_or_create_foos_ids(foos)
    #   retrying_on_collision do
    #     ids_hash = quick_find_current_foos_ids(foos)
    #     foos.collect { |foo| ids_hash[foo] || expensive_create_foo_and_return_id(foo) }
    #   end
    # end
    #
    # or something else similar... :)
    def retrying_on_collision(retry_count=0)
      yield
    rescue ActiveRecord::RecordNotUnique
      raise TooManyCollisionsException.new('Too many db uniqueness collisions') if retry_count >= max_collision_retries
      # random sleep from 0-100 ms makes collisions MUCH more likely to resolve themselves on their own
      sleep(rand(100) / 1000.0)
      retrying_on_collision(retry_count + 1) { yield }
    end

  end

end