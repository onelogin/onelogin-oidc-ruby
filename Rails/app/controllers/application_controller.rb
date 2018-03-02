class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
  include SessionsHelper

  def require_current_user
    puts "CHECK ACCESS"
    if current_user
      return true
    else
      redirect_to root_url, error: "Please sign in."
      return false
    end
  end
end
