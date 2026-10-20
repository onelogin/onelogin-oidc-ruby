# Resource Owner Password Grant Sample

This sample is a default [Ruby on Rails 8](https://rubyonrails.org/) app that uses [HTTParty](https://github.com/jnunemaker/httparty) to authenticate users with the OpenId Connect [Resource Owner Password Grant](https://developers.onelogin.com/openid-connect/api/password-grant).

The password grant hands the user's password to your app, so only use it for apps you fully
trust. Prefer the [Authentication Flow sample](../1-auth-flow) for new apps.

The sample tries to keep everything as simple as possible so only
implements
* Login - Authenticate users in a single request to OneLogin with out any redirects
* User Info - fetching profile information from OneLogin
* Logout - destroying the local session and revoking the token at OneLogin

### Authenticate the user

```ruby
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
```

### Fetch user info

```ruby
def user_info
  return nil unless session[:access_token].present?

  response = HTTParty.get("#{issuer}/me",
    headers: {
      "Authorization" => "Bearer #{session[:access_token]}"
    }
  )

  response.parsed_response if response.ok?
end
```

### Destroy the session

```ruby
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
```

The `dashboard#index` is a protected page to prove the authentication works and creates a session. You will need to be authenticated to view it.

## Setup
In order to run this sample you need to setup an OpenId Connect
app in your OneLogin Admin portal.

If you don't have a OneLogin developer account [you can sign up here](https://www.onelogin.com/developer-signup).

1. Clone this repo
2. On the app's **SSO** tab, set **Token Endpoint Authentication Method** to **POST**. This sample
sends the client credentials in the request body.
3. Copy `.env.sample` to `.env` and set the **Client ID** and **Client Secret** from the SSO tab,
and your OneLogin subdomain.

```
ONELOGIN_ISSUER=https://YOUR_SUBDOMAIN.onelogin.com/oidc/2
ONELOGIN_CLIENT_ID=YOUR_ONELOGIN_CLIENT_ID
ONELOGIN_CLIENT_SECRET=YOUR_ONELOGIN_CLIENT_SECRET
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
> docker build -t onelogin-oidc-password-grant .
> docker run --rm -p 3000:3000 --env-file .env onelogin-oidc-password-grant
```

## Test
The tests stub OneLogin, so they need no account or network access.
```
> bin/rails test
```
