require "test_helper"

# Drives the Resource Owner Password Grant against a stubbed OneLogin
class LoginFlowTest < ActionDispatch::IntegrationTest
  ISSUER = ENV["ONELOGIN_ISSUER"]

  setup do
    stub_request(:get, "#{ISSUER}/me")
      .with(headers: { "Authorization" => "Bearer test-access-token" })
      .to_return(json_response(sub: "12345", name: "Ada Lovelace", email: "ada@example.com"))
  end

  test "login exchanges the username and password for an access token and shows the user" do
    token_request = stub_request(:post, "#{ISSUER}/token")
      .with(body: {
        grant_type: "password",
        client_id: "test-client-id",
        client_secret: "test-client-secret",
        username: "ada",
        password: "correct horse",
        scope: "openid profile email"
      })
      .to_return(json_response(access_token: "test-access-token", token_type: "Bearer", expires_in: 3600))

    post "/login", params: { username: "ada", password: "correct horse" }
    assert_redirected_to "/dashboard"

    follow_redirect!
    assert_response :success
    assert_select ".profile", "name: Ada Lovelace"
    assert_select ".profile", "email: ada@example.com"
    assert_requested token_request
  end

  test "login fails when OneLogin rejects the credentials" do
    stub_request(:post, "#{ISSUER}/token").to_return(
      json_response(status: 400, error: "invalid_grant", error_description: "invalid user credentials")
    )

    post "/login", params: { username: "ada", password: "wrong" }

    assert_redirected_to root_url
    assert_equal "Login failed.", flash[:alert]
    get "/dashboard"
    assert_redirected_to root_url
  end

  test "dashboard requires an access token OneLogin still accepts" do
    stub_request(:post, "#{ISSUER}/token").to_return(json_response(access_token: "expired-token", token_type: "Bearer"))
    stub_request(:get, "#{ISSUER}/me").with(headers: { "Authorization" => "Bearer expired-token" })
      .to_return(json_response(status: 401, error: "invalid_token", error_description: "access token expired"))

    post "/login", params: { username: "ada", password: "correct horse" }
    get "/dashboard"

    assert_redirected_to root_url
  end

  test "logout revokes the access token and ends the session" do
    stub_request(:post, "#{ISSUER}/token").to_return(json_response(access_token: "test-access-token", token_type: "Bearer"))
    revocation = stub_request(:post, "#{ISSUER}/token/revocation")
      .with(body: hash_including(token: "test-access-token", token_type_hint: "access_token"))
      .to_return(status: 200)
    post "/login", params: { username: "ada", password: "correct horse" }

    delete "/logout"

    assert_redirected_to root_url
    assert_requested revocation
    get "/dashboard"
    assert_redirected_to root_url
  end

  private

  def json_response(status: 200, **body)
    { status: status, body: body.to_json, headers: { "Content-Type" => "application/json" } }
  end
end
