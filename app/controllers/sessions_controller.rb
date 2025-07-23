class SessionsController < ApplicationController
  before_action :redirect_if_logged_in, only: [:new, :create]
  skip_before_action :require_login, only: [:new, :create]

  def new
    # Login form
  end

  def create
    user = User.find_by(username: params[:username])
    
    if user && user.authenticate(params[:password])
      session[:user_id] = user.id
      redirect_to dashboard_path, notice: "Welcome back, #{user.name}!"
    else
      flash.now[:alert] = "Couldn't find that user! Please try again"
      render :new
    end
  end

  def destroy
    session[:user_id] = nil
    redirect_to login_path, notice: "You have been logged out"
  end
end
