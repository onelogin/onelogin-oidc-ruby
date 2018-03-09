require 'httparty'

module SessionsHelper

  ONELOGIN_CLIENT_ID = 'YOUR OIDC CLIENT ID'
  ONELOGIN_CLIENT_SECRET = 'YOUR OIDC CLIENT SECRET'
  ONELOGIN_SUBDOMAIN = 'SUBDOMAIN'

  def log_in(username, password)
    response = HTTParty.post("https://#{ONELOGIN_SUBDOMAIN}.onelogin.com/oidc/token",
      body: {
        grant_type: 'password',
        client_id: ONELOGIN_CLIENT_ID,
        client_secret: ONELOGIN_CLIENT_SECRET,
        username: username,
        password: password,
        scope: 'openid profile email'
      }
    )

    json = JSON.parse(response.body)

    return nil unless json['access_token']

    session[:access_token] = json['access_token']
  end

  def log_out
    HTTParty.post("https://#{ONELOGIN_SUBDOMAIN}.onelogin.com/oidc/token/revocation",
      body: {
        client_id: ONELOGIN_CLIENT_ID,
        client_secret: ONELOGIN_CLIENT_SECRET,
        token: session[:access_token],
        token_type_hint: 'access_token'
      }
    )

    session.delete(:access_token)
    @current_user = nil
  end

  def user_info
    return nil unless session[:access_token].present?

    response = HTTParty.get("https://#{ONELOGIN_SUBDOMAIN}.onelogin.com/oidc/me",
      headers: {
        'Authorization' => "Bearer #{session[:access_token]}"
      }
    )

    JSON.parse(response.body)
  end

  def current_user
    @current_user ||= user_info
  end
end
