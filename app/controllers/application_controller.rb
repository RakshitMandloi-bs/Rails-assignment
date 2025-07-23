class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
  
  before_action :require_login, except: [:new, :create]

  private

  def current_user
    @current_user ||= User.find(session[:user_id]) if session[:user_id]
  end

  def logged_in?
    !!current_user
  end

  def require_login
    unless logged_in?
      flash[:alert] = "Please log in to access this page"
      redirect_to login_path
    end
  end

  def redirect_if_logged_in
    redirect_to dashboard_path if logged_in?
  end

  helper_method :current_user, :logged_in?
end
