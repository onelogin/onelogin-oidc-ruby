class SessionsController < ApplicationController
  def new
    if log_in(params['username'], params['password'])
      redirect_to dashboard_url
    else
      redirect_to root_url, error: 'Login failed.'
    end
  end

  def destroy
    log_out
    redirect_to root_url
  end
end
