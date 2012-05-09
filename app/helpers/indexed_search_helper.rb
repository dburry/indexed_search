
module IndexedSearchHelper

  # calculations about a page
  # params: current page number, number of items on a page, total items
  # returns: first item number on current page, last on current page, total pages
  def calculate_page_details(page, size, total)
    return page_first(page, size), page_last(page, size, total), total_pages(size, total)
  end
  def page_first(page, size)
    (page - 1) * size + 1
  end
  def page_last(page, size, total)
    [page * size, total].min
  end
  def total_pages(size, total)
    (1.0 * total / size).ceil
  end

end