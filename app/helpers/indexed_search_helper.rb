
module IndexedSearchHelper

  # Calculate the index number of the first item on the page,
  # from current page number and number of items on a page.
  # Suitable for a <tt>"<em>first</em>-<em>last</em> of <em>total</em>"</tt> display.
  def page_first(current_page, page_size)
    (current_page - 1) * page_size + 1
  end

  # Calculate the index number of the last item on the page,
  # from current page number, number of items on a page, and total number of items.
  # Suitable for a <tt>"<em>first</em>-<em>last</em> of <em>total</em>"</tt> display
  def page_last(current_page, page_size, total_number)
    [current_page * page_size, total_number].min
  end

  # Calculate the number of pages the total results occupy,
  # from the number of items on a page, and the total number of items.
  # Useful for pagination navigation.
  def total_pages(page_size, total_number)
    (1.0 * total_number / page_size).ceil
  end

  # Shortcut to grab all page related calculations in one go.
  # Returns an array of the index number of the first item on the page, the last item on the page,
  # and the number of pages the total results occupy.
  def calculate_page_details(current_page, page_size, total_number)
    return page_first(current_page, page_size), page_last(current_page, page_size, total_number),
        total_pages(page_size, total_number)
  end

end