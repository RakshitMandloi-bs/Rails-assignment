require 'rails_helper'

RSpec.describe UsersController, type: :controller do
  describe 'GET #new' do
    it 'renders the signup form' do
      get :new
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:new)
      expect(assigns(:user)).to be_a_new(User)
    end

    it 'redirects to dashboard if already logged in' do
      user = User.create!(username: 'testuser', email: 'test@example.com', name: 'Test User', password: 'Password123')
      session[:user_id] = user.id
      
      get :new
      expect(response).to redirect_to(dashboard_path)
    end
  end

  describe 'POST #create' do
    let(:valid_params) do
      {
        user: {
          username: 'newuser',
          email: 'new@example.com',
          name: 'New User',
          password: 'Password123'
        }
      }
    end

    context 'with valid parameters' do
      it 'creates a new user and logs them in' do
        expect {
          post :create, params: valid_params
        }.to change(User, :count).by(1)
        
        user = User.last
        expect(session[:user_id]).to eq(user.id)
        expect(response).to redirect_to(dashboard_path)
        expect(flash[:notice]).to include('Account created successfully')
      end
    end

    context 'with invalid parameters' do
      it 'does not create a user and renders new template' do
        invalid_params = valid_params.deep_dup
        invalid_params[:user][:email] = 'invalid-email'
        
        expect {
          post :create, params: invalid_params
        }.not_to change(User, :count)
        
        expect(session[:user_id]).to be_nil
        expect(response).to render_template(:new)
        expect(assigns(:user).errors).to be_present
      end
    end
  end

  describe 'GET #edit' do
    it 'renders the profile edit form for logged in user' do
      user = User.create!(username: 'testuser', email: 'test@example.com', name: 'Test User', password: 'Password123')
      session[:user_id] = user.id
      
      get :edit
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:edit)
      expect(assigns(:user)).to eq(user)
    end

    it 'redirects to login if not logged in' do
      get :edit
      expect(response).to redirect_to(login_path)
    end
  end

  describe 'PATCH #update' do
    let(:user) do
      User.create!(username: 'testuser', email: 'test@example.com', name: 'Test User', password: 'Password123')
    end

    before do
      session[:user_id] = user.id
    end

    context 'with valid parameters' do
      it 'updates the user profile' do
        patch :update, params: {
          user: {
            name: 'Updated Name',
            email: 'updated@example.com'
          }
        }
        
        user.reload
        expect(user.name).to eq('Updated Name')
        expect(user.email).to eq('updated@example.com')
        expect(response).to redirect_to(profile_path)
        expect(flash[:notice]).to eq('Profile updated successfully!')
      end

      it 'updates password when provided' do
        old_password_hash = user.password_hash
        
        patch :update, params: {
          user: {
            name: 'Updated Name',
            email: 'updated@example.com',
            password: 'NewPassword123'
          }
        }
        
        user.reload
        expect(user.password_hash).not_to eq(old_password_hash)
        expect(user.authenticate('NewPassword123')).to be true
      end

      it 'does not update password when blank' do
        old_password_hash = user.password_hash
        
        patch :update, params: {
          user: {
            name: 'Updated Name',
            email: 'updated@example.com',
            password: ''
          }
        }
        
        user.reload
        expect(user.password_hash).to eq(old_password_hash)
        expect(user.authenticate('Password123')).to be true
      end
    end

    context 'with invalid parameters' do
      it 'does not update user and renders edit template' do
        patch :update, params: {
          user: {
            email: 'invalid-email'
          }
        }
        
        expect(response).to render_template(:edit)
        expect(assigns(:user).errors).to be_present
      end
    end
  end
end
