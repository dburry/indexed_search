
# common code used in concurrency tests, using a whole bunch of threads...
# this can be used to stress test what happens when certain internal things happen many times all at once

def run_concurrency_test(how_many)
  threads = []

  # kind of experimental, turn on thread-safe rails...
  # not sure if this actually does anything that we need...
  #Rails.application.config.threadsafe!

  # start indicated number of sub-threads, run code from block in each concurrently
  # note that each thread uses its own database connection, from the connection pool
  # so MAKE SURE your connection pool is big enough to handle the number you're running plus a little!!
  how_many.times do
    threads << Thread.new do
      begin
        yield

      ensure
        # threads complain when they end, if this isn't run before ending...
        ActiveRecord::Base.connection.close
      end
    end
  end

  begin
    # wait for all sub-threads to end
    # if any thread raised an error, this will too!
    until threads.empty?
      threads.shift.join
    end

  rescue
    # if any thread raised an error, wait for the rest of them too, ignoring any further errors
    threads.each { |t| t.join rescue nil }

    # and re-raise just the first error...
    raise

  ensure
    # maybe this reloads rails back into normal non-threadsafe mode?
    #require File.expand_path("../../dummy/config/environment", __FILE__)

    # threaded database access uses separate connections so doesn't work with transaction cleaning
    DatabaseCleaner.clean_with :truncation
  end
end
