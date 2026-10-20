require "test_helper"

# Drives the whole Authorization Code flow against a stubbed OneLogin
class LoginFlowTest < ActionDispatch::IntegrationTest
  ISSUER = ENV["ONELOGIN_ISSUER"]
  SIGNING_KEY = OpenSSL::PKey::RSA.generate(2048)

  setup do
    stub_request(:get, "#{ISSUER}/.well-known/openid-configuration").to_return(json_response(
      issuer: ISSUER,
      authorization_endpoint: "#{ISSUER}/auth",
      token_endpoint: "#{ISSUER}/token",
      userinfo_endpoint: "#{ISSUER}/me",
      revocation_endpoint: "#{ISSUER}/token/revocation",
      jwks_uri: "#{ISSUER}/certs",
      response_types_supported: [ "code" ],
      subject_types_supported: [ "public" ],
      id_token_signing_alg_values_supported: [ "RS256" ]
    ))
    stub_request(:get, "#{ISSUER}/certs").to_return(json_response(
      keys: [ JSON::JWK.new(SIGNING_KEY.public_key, kid: "test-key") ]
    ))
    stub_request(:get, "#{ISSUER}/me")
      .with(headers: { "Authorization" => "Bearer test-access-token" })
      .to_return(json_response(sub: "12345", given_name: "Ada", family_name: "Lovelace", email: "ada@example.com"))
  end

  test "login redirects to OneLogin with state, nonce and a PKCE challenge" do
    query = start_login

    assert_equal "#{ISSUER}/auth", response.location.split("?").first
    assert_equal "test-client-id", query["client_id"]
    assert_equal "code", query["response_type"]
    assert_equal "http://www.example.com/signin-oidc", query["redirect_uri"]
    assert_equal "openid profile email", query["scope"]
    assert_equal "S256", query["code_challenge_method"]
    assert query["state"].present?
    assert query["nonce"].present?
    assert query["code_challenge"].present?
  end

  test "callback exchanges the code, verifies the ID token and shows the user" do
    query = start_login
    stub_token_response(id_token: id_token(nonce: query["nonce"]))

    get "/signin-oidc", params: { code: "test-code", state: query["state"] }
    assert_redirected_to "/dashboard"

    follow_redirect!
    assert_response :success
    assert_select "p", "Id: 12345"
    assert_select "p", "Name: Ada Lovelace"
    assert_select "p", "Email: ada@example.com"

    assert_requested(:post, "#{ISSUER}/token") do |request|
      form = Rack::Utils.parse_query(request.body)
      challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(form["code_verifier"].to_s), padding: false)

      request.headers["Authorization"] == "Basic #{Base64.strict_encode64("test-client-id:test-client-secret")}" &&
        form["grant_type"] == "authorization_code" &&
        form["code"] == "test-code" &&
        form["redirect_uri"] == "http://www.example.com/signin-oidc" &&
        challenge == query["code_challenge"]
    end
  end

  test "callback rejects a state it did not issue" do
    start_login

    get "/signin-oidc", params: { code: "test-code", state: "forged" }

    assert_redirected_to root_url
    assert_equal "Login failed: state mismatch.", flash[:alert]
    assert_not_requested :post, "#{ISSUER}/token"
  end

  test "callback rejects an ID token issued for a different login" do
    query = start_login
    stub_token_response(id_token: id_token(nonce: "someone-elses-nonce"))

    get "/signin-oidc", params: { code: "test-code", state: query["state"] }

    assert_redirected_to root_url
    assert_match "Nonce does not match", flash[:alert]
    get "/dashboard"
    assert_redirected_to root_url
  end

  test "callback reports a token endpoint error" do
    query = start_login
    stub_request(:post, "#{ISSUER}/token").to_return(
      json_response(status: 401, error: "invalid_client", error_description: "client authentication failed")
    )

    get "/signin-oidc", params: { code: "test-code", state: query["state"] }

    assert_redirected_to root_url
    assert_match "invalid_client", flash[:alert]
  end

  test "callback reports an error returned by OneLogin" do
    get "/signin-oidc", params: { error: "access_denied", error_description: "User is not assigned to this app" }

    assert_redirected_to root_url
    assert_equal "Login failed: User is not assigned to this app", flash[:alert]
  end

  test "logout revokes the access token and ends the session" do
    query = start_login
    stub_token_response(id_token: id_token(nonce: query["nonce"]))
    get "/signin-oidc", params: { code: "test-code", state: query["state"] }
    revocation = stub_request(:post, "#{ISSUER}/token/revocation")
      .with(body: { token: "test-access-token", token_type_hint: "access_token" })
      .to_return(status: 200)

    delete "/logout"

    assert_redirected_to root_url
    assert_requested revocation
    get "/dashboard"
    assert_redirected_to root_url
  end

  test "dashboard requires login" do
    get "/dashboard"

    assert_redirected_to root_url
    assert_equal "Please sign in.", flash[:alert]
  end

  private

  def start_login
    get "/login"
    assert_response :redirect
    Rack::Utils.parse_query(URI(response.location).query)
  end

  def stub_token_response(id_token:)
    stub_request(:post, "#{ISSUER}/token").to_return(json_response(
      access_token: "test-access-token", token_type: "Bearer", expires_in: 3600, id_token: id_token
    ))
  end

  def id_token(nonce:)
    jwt = JSON::JWT.new(
      iss: ISSUER, sub: "12345", aud: "test-client-id", nonce: nonce,
      iat: Time.now.to_i, exp: 5.minutes.from_now.to_i
    )
    jwt.kid = "test-key"
    jwt.sign(SIGNING_KEY, :RS256).to_s
  end

  def json_response(status: 200, **body)
    { status: status, body: body.to_json, headers: { "Content-Type" => "application/json" } }
  end
end
