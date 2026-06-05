module ChurchEventsHelper
  def google_maps_search_url(location)
    "https://www.google.com/maps/search/?api=1&query=#{CGI.escape(location.to_s)}"
  end

  def google_maps_embed_url(location)
    "https://www.google.com/maps?q=#{CGI.escape(location.to_s)}&output=embed"
  end
end
