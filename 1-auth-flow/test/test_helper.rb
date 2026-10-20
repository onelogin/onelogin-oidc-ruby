ENV["RAILS_ENV"] ||= "test"
ENV["ONELOGIN_ISSUER"] = "https://example.onelogin.com/oidc/2"
ENV["ONELOGIN_CLIENT_ID"] = "test-client-id"
ENV["ONELOGIN_CLIENT_SECRET"] = "test-client-secret"
ENV["ONELOGIN_REDIRECT_URI"] = "http://www.example.com/signin-oidc"
ENV["ONELOGIN_TOKEN_AUTH_METHOD"] = "basic"

require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)
  end
end
