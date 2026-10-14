module ApplicationHelper
  def pagination_series(pagy)
    pages = ([ 1, pagy.pages ] + ((pagy.page - 2)..(pagy.page + 2)).to_a)
      .select { |page| page.between?(1, pagy.pages) }
      .uniq
      .sort

    pages.each_with_object([]) do |page, series|
      series << :gap if series.any? && page > series.last.to_i + 1
      series << page
    end
  end
end
