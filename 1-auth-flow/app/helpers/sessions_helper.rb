module SessionsHelper
  # OneLogin publishes its endpoints and signing keys at
  # <issuer>/.well-known/openid-configuration, so the issuer is the only URL to configure
  def self.discovery
    @discovery ||= OpenIDConnect::Discovery::Provider::Config.discover!(ENV.fetch("ONELOGIN_ISSUER"))
  end

  def client
    @client ||= OpenIDConnect::Client.new(
      identifier: ENV.fetch("ONELOGIN_CLIENT_ID"),
      # A None (PKCE) app is a public client, so it never sends a secret
      secret: (ENV["ONELOGIN_CLIENT_SECRET"] unless token_auth_method == "none"),
      redirect_uri: ENV.fetch("ONELOGIN_REDIRECT_URI"),
      authorization_endpoint: SessionsHelper.discovery.authorization_endpoint,
      token_endpoint: SessionsHelper.discovery.token_endpoint,
      userinfo_endpoint: SessionsHelper.discovery.userinfo_endpoint,
      # Not part of OpenID Connect Discovery, so openid_connect has no reader for it
      revocation_endpoint: SessionsHelper.discovery.raw[:revocation_endpoint]
    )
  end

  def authorization_uri
    session[:state] = SecureRandom.hex(16)
    session[:nonce] = SecureRandom.hex(16)
    session[:code_verifier] = SecureRandom.urlsafe_base64(32)

    client.authorization_uri(
      scope: %w[openid profile email],
      state: session[:state],
      nonce: session[:nonce],
      code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(session[:code_verifier]), padding: false),
      code_challenge_method: "S256"
    )
  end

  # Swaps the authorization code for tokens, then checks that the ID token was
  # signed by OneLogin, issued to this app, and belongs to this login attempt
  def request_tokens(code)
    client.authorization_code = code
    access_token = client.access_token!(
      client_auth_method: client_auth_method,
      code_verifier: session.delete(:code_verifier)
    )

    id_token = OpenIDConnect::ResponseObject::IdToken.decode(access_token.id_token, SessionsHelper.discovery)
    id_token.verify!(
      issuer: SessionsHelper.discovery.issuer,
      client_id: client.identifier,
      nonce: session.delete(:nonce)
    )

    [ access_token, id_token ]
  end

  # Must match the app's "Token Endpoint Authentication Method" in OneLogin: basic, post or none
  def token_auth_method
    ENV.fetch("ONELOGIN_TOKEN_AUTH_METHOD", "basic")
  end

  # rack-oauth2 puts the client credentials in an Authorization header for :basic,
  # and in the request body otherwise
  def client_auth_method
    token_auth_method == "basic" ? :basic : :post
  end

  def log_in(access_token, id_token)
    session[:access_token] = access_token.access_token
    session[:user_id] = id_token.sub
  end

  def log_out
    if session[:access_token].present?
      client.revoke!(access_token: session[:access_token], client_auth_method: client_auth_method)
    end
  rescue Rack::OAuth2::Client::Error, Faraday::Error => e
    # Still end the local session when OneLogin refuses or can't be reached
    logger.warn("Token revocation failed: #{e.message}")
  ensure
    reset_session
    @current_user = nil
  end

  def user_info
    return nil unless session[:access_token].present?

    access_token = OpenIDConnect::AccessToken.new(
      access_token: session[:access_token],
      client: client
    )

    user_info = access_token.userinfo!
    # Only trust UserInfo about the user the ID token was issued for (OpenID Connect Core 5.3.2)
    user_info if user_info.sub == session[:user_id]
  rescue OpenIDConnect::Unauthorized
    # The access token expired or was revoked at OneLogin
    session.delete(:access_token)
    nil
  end

  def current_user
    @current_user ||= user_info
  end
end
