require 'rails_helper'

RSpec.describe SessionsController, type: :controller do
  describe 'GET #new' do
    it 'renders the login form' do
      get :new
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:new)
    end

    it 'redirects to dashboard if already logged in' do
      user = User.create!(username: 'testuser', email: 'test@example.com', name: 'Test User', password: 'Password123')
      session[:user_id] = user.id
      
      get :new
      expect(response).to redirect_to(dashboard_path)
    end
  end

  describe 'POST #create' do
    let(:user) do
      User.create!(username: 'testuser', email: 'test@example.com', name: 'Test User', password: 'Password123')
    end

    context 'with valid credentials' do
      it 'logs in the user and redirects to dashboard' do
        post :create, params: { username: 'testuser', password: 'Password123' }
        
        expect(session[:user_id]).to eq(user.id)
        expect(response).to redirect_to(dashboard_path)
        expect(flash[:notice]).to include('Welcome back')
      end
    end

    context 'with invalid credentials' do
      it 'does not log in and shows error message' do
        post :create, params: { username: 'testuser', password: 'wrongpassword' }
        
        expect(session[:user_id]).to be_nil
        expect(response).to render_template(:new)
        expect(flash[:alert]).to eq("Couldn't find that user! Please try again")
      end

      it 'handles non-existent user' do
        post :create, params: { username: 'nonexistent', password: 'Password123' }
        
        expect(session[:user_id]).to be_nil
        expect(response).to render_template(:new)
        expect(flash[:alert]).to eq("Couldn't find that user! Please try again")
      end
    end
  end

  describe 'DELETE #destroy' do
    it 'logs out the user and redirects to login' do
      user = User.create!(username: 'testuser', email: 'test@example.com', name: 'Test User', password: 'Password123')
      session[:user_id] = user.id
      
      delete :destroy
      
      expect(session[:user_id]).to be_nil
      expect(response).to redirect_to(login_path)
      expect(flash[:notice]).to eq('You have been logged out')
    end
  end
end
