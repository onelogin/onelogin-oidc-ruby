# OpenId Connect Authentication Flow Sample

This sample is a default [Ruby on Rails 5](http://rubyonrails.org/) app that makes use of the [openid-connect](https://github.com/nov/openid_connect) gem for authenticating users via the OpenId Connect Authentication Flow.

The sample tries to keep everything as simple as possible so only
implements
* Login - redirecting users to OneLogin for authentication
* Logout - destroying the local session and revoking the token at OneLogin
* User Info - fetching profile information from OneLogin

The `openid-connect` gem takes care of generating the auth url in the `sessions_helper`.

```ruby
def authorization_uri
  session[:state] = SecureRandom.hex(16)
  session[:nonce] = SecureRandom.hex(16)

  client.authorization_uri(
    scope: scope,
    state: session[:state],
    nonce: session[:nonce]
  )
end
```

and the callback is handled in the `sessions_controller`.

```ruby
def callback
  # Authorization Response
  code = params[:code]

  # Token Request
  client.authorization_code = code
  access_token = client.access_token! # => OpenIDConnect::AccessToken

  if access_token
    log_in(access_token.to_s)
    redirect_to '/dashboard'
  else
    redirect_to root_url
  end
end
```


The `dashboard#index` is a protected page to prove the authentication works and creates a session. You will need to be authenticated to view it.

## Setup
In order to run this sample you need to setup an OpenId Connect
app in your OneLogin Admin portal.

If you don't have a OneLogin developer account [you can sign up here](https://www.onelogin.com/developer-signup).

1. Clone this repo
2. Rename `.env.sample` to `.env` and set the **ONELOGIN_CLIENT_ID** and
**ONELOGIN_CLIENT_SECRET** you obtained from OneLogin as well as the Redirect Uri of your local site.

You need to make sure that this matches what you specified as the
Redirect Uri when you setup your OIDC app connector in the OneLogin portal.

```ruby
ONELOGIN_CLIENT_ID= YOUR_ONELOGIN_CLIENT_ID
ONELOGIN_CLIENT_SECRET= YOUR_ONELOGIN_CLIENT_SECRET
ONELOGIN_REDIRECT_URI= YOUR_CALLBACK_URI
ONELOGIN_OIDC_HOST=openid-connect.onelogin.com
```

## Run
From the command line run
```
> bundle install
> rails s
```

### Local testing
By default these samples will run on `http://localhost:3000`.

You will need to add your callback url to the list of approved **Redirect URIs** for your OneLogin OIDC app via the Admin portal. e.g. `http://localhost:3000/oauth/callback`