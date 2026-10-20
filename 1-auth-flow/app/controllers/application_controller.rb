class ApplicationController < ActionController::Base
  include SessionsHelper

  def require_current_user
    redirect_to root_url, alert: "Please sign in." unless current_user
  end
end
