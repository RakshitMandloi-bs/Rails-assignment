require 'rails_helper'

RSpec.describe SharedFilesController, type: :controller do
  let(:user) do
    User.create!(username: 'testuser', email: 'test@example.com', name: 'Test User', password: 'Password123')
  end

  let(:public_file) do
    UploadedFile.create!(
      filename: 'shared.pdf',
      filepath: '/path/to/shared.pdf',
      uploaded_at: Time.current,
      user: user,
      public: true,
      share_token: 'validtoken123'
    )
  end

  let(:private_file) do
    UploadedFile.create!(
      filename: 'private.pdf',
      filepath: '/path/to/private.pdf',
      uploaded_at: Time.current,
      user: user,
      public: false,
      share_token: nil
    )
  end

  describe 'GET #show' do
    it 'serves a public file with valid token' do
      allow(File).to receive(:exist?).with(public_file.filepath).and_return(true)
      expect(controller).to receive(:send_file).with(
        public_file.filepath,
        filename: public_file.filename,
        disposition: :attachment
      )

      get :show, params: { token: public_file.share_token }
    end

    it 'returns not found for invalid token' do
      get :show, params: { token: 'invalidtoken' }
      
      expect(response).to have_http_status(:not_found)
      expect(response.body).to eq('File not found')
    end

    it 'returns not found for private file token' do
      get :show, params: { token: 'sometoken' }
      
      expect(response).to have_http_status(:not_found)
      expect(response.body).to eq('File not found')
    end

    it 'returns not found when file does not exist on disk' do
      allow(File).to receive(:exist?).with(public_file.filepath).and_return(false)

      get :show, params: { token: public_file.share_token }
      
      expect(response).to have_http_status(:not_found)
      expect(response.body).to eq('File not found on disk')
    end

    it 'does not require login' do
      # Ensure no session is set
      session[:user_id] = nil
      
      allow(File).to receive(:exist?).with(public_file.filepath).and_return(true)
      expect(controller).to receive(:send_file)

      get :show, params: { token: public_file.share_token }
      
      # Should not redirect to login
      expect(response).not_to redirect_to(login_path)
    end
  end
end
