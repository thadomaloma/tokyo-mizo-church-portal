ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    include ActiveJob::TestHelper

    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

module ActionDispatch
  class IntegrationTest
    setup { ActionController::Base.cache_store.clear }

    # Visible text of the last response. Amounts render the currency symbol in
    # its own span, so "¥12,000" only appears in the text, not the raw HTML.
    def page_text
      Nokogiri::HTML(response.body).text.squish
    end
  end
end
