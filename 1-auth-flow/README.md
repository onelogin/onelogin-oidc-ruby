# OpenId Connect Authentication Flow Sample

This sample is a default [Ruby on Rails 8](https://rubyonrails.org/) app that makes use of the [openid_connect](https://github.com/nov/openid_connect) gem for authenticating users via the OpenId Connect Authorization Code Flow.

The sample tries to keep everything as simple as possible so only
implements
* Login - redirecting users to OneLogin for authentication
* Logout - destroying the local session and revoking the token at OneLogin
* User Info - fetching profile information from OneLogin

The `openid_connect` gem reads OneLogin's endpoints from its discovery document and generates the auth url in the `sessions_helper`.
Every login sends a random `state`, a `nonce` and a [PKCE](https://developers.onelogin.com/openid-connect/guides/auth-flow-pkce) code challenge.

```ruby
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
```

The callback is handled in the `sessions_controller`. It checks the `state`, swaps the code for tokens, and verifies the ID token's signature, issuer, audience and `nonce` before logging the user in.

```ruby
def callback
  # Authorization Response
  if params[:error].present?
    return redirect_to root_url, alert: "Login failed: #{params[:error_description] || params[:error]}"
  end

  # Only accept a response to the login this browser started
  if params[:state].blank? || params[:state] != session.delete(:state)
    return redirect_to root_url, alert: "Login failed: state mismatch."
  end

  # Token Request
  log_in(request_access_token(params[:code])) # => OpenIDConnect::AccessToken
  redirect_to dashboard_url
rescue Rack::OAuth2::Client::Error, OpenIDConnect::ResponseObject::IdToken::InvalidToken, JSON::JWT::Exception => e
  logger.warn("Login failed: #{e.message}")
  redirect_to root_url, alert: "Login failed: #{e.message}"
end
```

The `dashboard#index` is a protected page to prove the authentication works and creates a session. You will need to be authenticated to view it.

## Setup
In order to run this sample you need to setup an OpenId Connect
app in your OneLogin Admin portal.

If you don't have a OneLogin developer account [you can sign up here](https://www.onelogin.com/developer-signup).

1. Clone this repo
2. On the app's **Configuration** tab, add `http://localhost:3000/signin-oidc` to the **Redirect URI's**.
3. On the app's **SSO** tab, note the **Client ID** and **Client Secret**, and the
**Token Endpoint Authentication Method** (Basic by default).
4. Copy `.env.sample` to `.env` and fill it in. `ONELOGIN_TOKEN_AUTH_METHOD` must match the
app's Token Endpoint Authentication Method: `basic`, `post`, or `none` for None (PKCE), which
needs no client secret.

```
ONELOGIN_ISSUER=https://YOUR_SUBDOMAIN.onelogin.com/oidc/2
ONELOGIN_CLIENT_ID=YOUR_ONELOGIN_CLIENT_ID
ONELOGIN_CLIENT_SECRET=YOUR_ONELOGIN_CLIENT_SECRET
ONELOGIN_REDIRECT_URI=http://localhost:3000/signin-oidc
ONELOGIN_TOKEN_AUTH_METHOD=basic
```

## Run
You need Ruby 3.4 (see `.ruby-version`). From the command line run
```
> bundle install
> bin/rails server
```

Then open `http://localhost:3000`.

Or run it in Docker
```
> docker build -t onelogin-oidc-auth-flow .
> docker run --rm -p 3000:3000 --env-file .env onelogin-oidc-auth-flow
```

## Test
The tests stub OneLogin, so they need no account or network access.
```
> bin/rails test
```

## Troubleshooting
* **Login failed: invalid_client** - the client secret is wrong, or `ONELOGIN_TOKEN_AUTH_METHOD`
doesn't match the app's Token Endpoint Authentication Method.
* **OneLogin shows a redirect_uri error** - `ONELOGIN_REDIRECT_URI` must exactly match one of the app's Redirect URI's.
* **TypeError: no implicit conversion of Hash into String** - you are running `openid_connect` 1.x with
`rack-oauth2` 2.2 or newer. Use the versions in this sample's `Gemfile.lock` (`openid_connect` 2.x).
