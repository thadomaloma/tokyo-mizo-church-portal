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

    # minitest 6 dropped minitest/mock, so this replaces Webpush.payload_send
    # for the duration of the block and always restores the original method,
    # keeping tests independent of any real external push provider.
    def stub_webpush_payload_send(implementation)
      original = Webpush.method(:payload_send)
      Webpush.define_singleton_method(:payload_send) { |**kwargs| implementation.call(**kwargs) }
      yield
    ensure
      Webpush.define_singleton_method(:payload_send, original)
    end
  end
end
