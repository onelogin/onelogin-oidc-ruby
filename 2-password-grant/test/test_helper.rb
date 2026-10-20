ENV["RAILS_ENV"] ||= "test"
ENV["ONELOGIN_ISSUER"] = "https://example.onelogin.com/oidc/2"
ENV["ONELOGIN_CLIENT_ID"] = "test-client-id"
ENV["ONELOGIN_CLIENT_SECRET"] = "test-client-secret"

require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)
  end
end
