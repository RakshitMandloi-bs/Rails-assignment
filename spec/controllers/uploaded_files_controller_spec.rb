require 'rails_helper'
require 'tempfile'

RSpec.describe UploadedFilesController, type: :controller do
  let(:user) do
    User.create!(username: 'testuser', email: 'test@example.com', name: 'Test User', password: 'Password123')
  end

  before do
    session[:user_id] = user.id
  end

  describe 'GET #index' do
    it 'renders the dashboard with user files' do
      file1 = UploadedFile.create!(
        filename: 'test1.pdf',
        filepath: '/path/to/test1.pdf',
        uploaded_at: 1.hour.ago,
        user: user
      )
      file2 = UploadedFile.create!(
        filename: 'test2.pdf',
        filepath: '/path/to/test2.pdf',
        uploaded_at: 2.hours.ago,
        user: user
      )

      get :index
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:index)
      expect(assigns(:uploaded_files)).to eq([file1, file2]) # Ordered by upload date desc
    end
  end

  describe 'POST #create' do
    let(:uploaded_file) do
      ActionDispatch::Http::UploadedFile.new(
        tempfile: Tempfile.new('test'),
        filename: 'test.pdf',
        original_filename: 'test.pdf',
        type: 'application/pdf'
      )
    end

    before do
      # Mock file operations
      allow(FileUtils).to receive(:mkdir_p)
      allow(File).to receive(:open).and_yield(double(write: true))
    end

    it 'creates a new uploaded file record' do
      expect {
        post :create, params: { file: uploaded_file }
      }.to change(UploadedFile, :count).by(1)

      created_file = UploadedFile.last
      expect(created_file.filename).to eq('test.pdf')
      expect(created_file.user).to eq(user)
      expect(response).to redirect_to(dashboard_path)
      expect(flash[:notice]).to include('uploaded successfully')
    end

    it 'handles missing file parameter' do
      post :create, params: { file: nil }
      expect(response).to redirect_to(dashboard_path)
      expect(flash[:alert]).to eq('Please select a file to upload')
    end
  end

  describe 'GET #download' do
    let(:uploaded_file) do
      UploadedFile.create!(
        filename: 'test.pdf',
        filepath: '/path/to/test.pdf',
        uploaded_at: Time.current,
        user: user
      )
    end

    it 'sends the file when it exists' do
      allow(File).to receive(:exist?).with(uploaded_file.filepath).and_return(true)
      expect(controller).to receive(:send_file).with(
        uploaded_file.filepath,
        filename: uploaded_file.filename,
        disposition: :attachment
      )

      get :download, params: { id: uploaded_file.id }
    end

    it 'redirects with error when file does not exist' do
      allow(File).to receive(:exist?).with(uploaded_file.filepath).and_return(false)

      get :download, params: { id: uploaded_file.id }
      expect(response).to redirect_to(dashboard_path)
      expect(flash[:alert]).to eq('File not found')
    end

    it 'prevents access to other users files' do
      other_user = User.create!(username: 'other', email: 'other@example.com', name: 'Other', password: 'Password123')
      other_file = UploadedFile.create!(
        filename: 'other.pdf',
        filepath: '/path/to/other.pdf',
        uploaded_at: Time.current,
        user: other_user
      )

      get :download, params: { id: other_file.id }
      expect(response).to redirect_to(dashboard_path)
      expect(flash[:alert]).to eq('File not found')
    end
  end

  describe 'DELETE #destroy' do
    let(:uploaded_file) do
      UploadedFile.create!(
        filename: 'test.pdf',
        filepath: '/path/to/test.pdf',
        uploaded_at: Time.current,
        user: user,
        public: false
      )
    end

    it 'deletes a private file' do
      allow(File).to receive(:exist?).and_return(true)
      allow(File).to receive(:delete)

      expect {
        delete :destroy, params: { id: uploaded_file.id }
      }.to change(UploadedFile, :count).by(-1)

      expect(response).to redirect_to(dashboard_path)
      expect(flash[:notice]).to eq('File deleted successfully')
    end

    it 'prevents deletion of public files' do
      uploaded_file.update!(public: true, share_token: 'token123')

      expect {
        delete :destroy, params: { id: uploaded_file.id }
      }.not_to change(UploadedFile, :count)

      expect(response).to redirect_to(dashboard_path)
      expect(flash[:alert]).to eq("Can't delete a shared file")
    end
  end

  describe 'PATCH #toggle_share' do
    let(:uploaded_file) do
      UploadedFile.create!(
        filename: 'test.pdf',
        filepath: '/path/to/test.pdf',
        uploaded_at: Time.current,
        user: user,
        public: false
      )
    end

    it 'makes a private file public' do
      patch :toggle_share, params: { id: uploaded_file.id }

      uploaded_file.reload
      expect(uploaded_file.public?).to be true
      expect(uploaded_file.share_token).to be_present
      expect(response).to redirect_to(dashboard_path)
      expect(flash[:notice]).to eq('File is now shared publicly')
    end

    it 'makes a public file private' do
      uploaded_file.update!(public: true, share_token: 'token123')

      patch :toggle_share, params: { id: uploaded_file.id }

      uploaded_file.reload
      expect(uploaded_file.public?).to be false
      expect(uploaded_file.share_token).to be_nil
      expect(response).to redirect_to(dashboard_path)
      expect(flash[:notice]).to eq('File is now private')
    end
  end
end
