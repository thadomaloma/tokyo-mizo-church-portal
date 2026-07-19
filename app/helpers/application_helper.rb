module ApplicationHelper
  RICH_TEXT_TAGS = %w[
    p br div strong b em i u ul ol li
  ].freeze

  RICH_TEXT_ATTRIBUTES = [].freeze

  def rich_minute_content(value)
    content = value.to_s

    if content.match?(/<\/?[a-z][\s\S]*>/i)
      sanitize(
        content,
        tags: RICH_TEXT_TAGS,
        attributes: RICH_TEXT_ATTRIBUTES
      )
    else
      simple_format(content)
    end
  end

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
