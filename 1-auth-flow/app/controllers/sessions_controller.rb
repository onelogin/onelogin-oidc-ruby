class SessionsController < ApplicationController
  def new
    redirect_to authorization_uri, allow_other_host: true
  end

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

  def destroy
    log_out
    redirect_to root_url
  end
end
