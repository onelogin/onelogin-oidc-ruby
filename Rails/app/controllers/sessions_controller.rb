class SessionsController < ApplicationController
  def new
    redirect_to authorization_uri
  end

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

  def destroy
    log_out
    redirect_to root_url
  end
end
