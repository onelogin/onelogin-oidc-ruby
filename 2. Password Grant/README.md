# OneLogin OpenId Connect Resource Owner Password Grant Sample

This sample is a default [Ruby on Rails 5](http://rubyonrails.org/) app that makes use of the [openid-connect](https://github.com/nov/openid_connect) gem for authenticating users via the OpenId Connect Resource Owner Password Grant Flow.

The sample tries to keep everything as simple as possible so only
implements
* Login - Authenticate users in a single request to OneLogin with out any redirects
* User Info - fetching profile information from OneLogin
* Logout - destroying the local session and revoking the token at OneLogin

### Authenticate the user

```ruby
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
```

### Fetch user info

```ruby
  def user_info
    return nil unless session[:access_token].present?

    response = HTTParty.get("https://#{ONELOGIN_SUBDOMAIN}.onelogin.com/oidc/me",
      headers: {
        'Authorization' => "Bearer #{session[:access_token]}"
      }
    )

    JSON.parse(response.body)
  end
```

### Destroy the session

```ruby
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
```

The `dashboard#index` is a protected page to prove the authentication works and creates a session. You will need to be authenticated to view it.

## Setup
In order to run this sample you need to setup an OpenId Connect
app in your OneLogin Admin portal.

If you don't have a OneLogin developer account [you can sign up here](https://www.onelogin.com/developer-signup).

1. Clone this repo
2. Update `app/helpers/sessions_helper.rb` with the **client_id** and
**client_secret** you obtained from OneLogin as well as the **subdomain**
of your OneLogin account.


```ruby
ONELOGIN_CLIENT_ID = 'ONELOGIN CLIENT ID'
ONELOGIN_CLIENT_SECRET = 'ONELOGIN CLIENT SECRET'
ONELOGIN_SUBDOMAIN = 'SUBDOMAIN'
```

**Note** to keep the example simple we have included the configuration in the `sessions_helper` but you should store these values in environment variables or a secrets file.

## Run
From the command line run
```
> bundle install
> rails s
```