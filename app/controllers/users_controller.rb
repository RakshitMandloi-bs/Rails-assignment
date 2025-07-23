class UsersController < ApplicationController
  before_action :redirect_if_logged_in, only: [:new, :create]
  skip_before_action :require_login, only: [:new, :create]

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    
    if @user.save
      session[:user_id] = @user.id
      redirect_to dashboard_path, notice: "Account created successfully! Welcome, #{@user.name}!"
    else
      render :new
    end
  end

  def edit
    @user = current_user
  end

  def update
    @user = current_user
    
    # Remove password from params if it's blank
    if params[:user][:password].blank?
      params[:user].delete(:password)
    end
    
    if @user.update(user_update_params)
      redirect_to profile_path, notice: "Profile updated successfully!"
    else
      render :edit
    end
  end

  private

  def user_params
    params.require(:user).permit(:username, :email, :name, :password)
  end

  def user_update_params
    params.require(:user).permit(:email, :name, :password)
  end
end
