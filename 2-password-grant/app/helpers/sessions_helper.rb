module SessionsHelper
  # https://<subdomain>.onelogin.com/oidc/2
  def issuer
    ENV.fetch("ONELOGIN_ISSUER")
  end

  def log_in(username, password)
    response = HTTParty.post("#{issuer}/token",
      body: {
        grant_type: "password",
        client_id: ENV.fetch("ONELOGIN_CLIENT_ID"),
        client_secret: ENV.fetch("ONELOGIN_CLIENT_SECRET"),
        username: username,
        password: password,
        scope: "openid profile email"
      }
    )

    if response.ok?
      session[:access_token] = response["access_token"]
    else
      logger.warn("Login failed: HTTP #{response.code} #{response.body}")
      nil
    end
  end

  def log_out
    if session[:access_token].present?
      HTTParty.post("#{issuer}/token/revocation",
        body: {
          client_id: ENV.fetch("ONELOGIN_CLIENT_ID"),
          client_secret: ENV.fetch("ONELOGIN_CLIENT_SECRET"),
          token: session[:access_token],
          token_type_hint: "access_token"
        }
      )
    end

    reset_session
    @current_user = nil
  end

  def user_info
    return nil unless session[:access_token].present?

    response = HTTParty.get("#{issuer}/me",
      headers: {
        "Authorization" => "Bearer #{session[:access_token]}"
      }
    )

    response.parsed_response if response.ok?
  end

  def current_user
    @current_user ||= user_info
  end
end
