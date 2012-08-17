
module IndexedSearch

  # Just a couple ways of clearing and resetting a table.

  module ResetTable

    # if a table has no rows, reset its auto increment
    def reset_auto_increment
      connection.execute("ALTER TABLE #{table_name} AUTO_INCREMENT = 1") if count == 0
    end

    # do a quick truncate on the table (removes all rows and resets auto increment both)
    def truncate_table
      connection.execute("TRUNCATE TABLE #{table_name}")
    end

  end
end