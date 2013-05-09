
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
  #
  # Other potential alternatives (each with other different drawbacks) include:
  # MySQL's INSERT ON DUPLICATE UPDATE and INSERT IGNORE and ANSI SQL's MERGE

  module Collision

    class TooManyCollisionsException < Exception
    end

    # maximum number of retries when optimistic creates fail from collisions
    # after it retries this many times, it will just raise the exception
    # optimistic non-locking-just-catching-exceptions can't really deadlock
    # when done properly but can might overwhelmed from too much concurrency
    # so if you get exceptions, that's probably your problem is too much concurrency
    # in testing it seems pretty unlikely to happen (you'd consume all cpu/mem/etc first)
    mattr_accessor :max_collision_retries
    self.max_collision_retries = 4

    # When it has to retry, there is often another process or thread trying to retry too.
    # In case the yielded operation takes some time to run, each retry should wait an
    # increasing amount of time, yet be random so that one of the retries actually wins.
    # This should be an array of ranges, of the same size as the number of retries.
    mattr_accessor :wait_time_seconds
    self.wait_time_seconds = [
      0.0 .. 0.1,
      0.1 .. 1.0,
      1.0 .. 3.0,
      6.0 .. 9.0 # a long time for a web app... we're desperate if it gets this far
    ]

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
      rand_range = wait_time_seconds[retry_count]
      sleep(rand(rand_range.end - rand_range.begin) + rand_range.begin) # rand(range) seems broken in 1.9.2-p320, so work around
      retrying_on_collision(retry_count + 1) { yield }
    end

  end

end
