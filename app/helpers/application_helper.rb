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
end
