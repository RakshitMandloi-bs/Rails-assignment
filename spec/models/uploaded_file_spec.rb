require 'rails_helper'

RSpec.describe UploadedFile, type: :model do
  let(:user) do
    User.create!(
      username: 'testuser',
      email: 'test@example.com',
      name: 'Test User',
      password: 'Password123'
    )
  end

  let(:uploaded_file) do
    UploadedFile.new(
      filename: 'test.pdf',
      filepath: '/path/to/test.pdf',
      uploaded_at: Time.current,
      user: user
    )
  end

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(uploaded_file).to be_valid
    end

    it 'is invalid without filename' do
      uploaded_file.filename = nil
      expect(uploaded_file).not_to be_valid
      expect(uploaded_file.errors[:filename]).to include("can't be blank")
    end

    it 'is invalid without filepath' do
      uploaded_file.filepath = nil
      expect(uploaded_file).not_to be_valid
      expect(uploaded_file.errors[:filepath]).to include("can't be blank")
    end

    it 'is invalid without uploaded_at' do
      uploaded_file.uploaded_at = nil
      expect(uploaded_file).not_to be_valid
      expect(uploaded_file.errors[:uploaded_at]).to include("can't be blank")
    end

    it 'is invalid without user' do
      uploaded_file.user = nil
      expect(uploaded_file).not_to be_valid
    end

    it 'validates uniqueness of share_token when present' do
      uploaded_file.save!
      uploaded_file.update!(share_token: 'unique_token')
      
      another_file = UploadedFile.new(
        filename: 'another.pdf',
        filepath: '/path/to/another.pdf',
        uploaded_at: Time.current,
        user: user,
        share_token: 'unique_token'
      )
      
      expect(another_file).not_to be_valid
      expect(another_file.errors[:share_token]).to include("has already been taken")
    end
  end

  describe 'associations' do
    it 'belongs to user' do
      association = UploadedFile.reflect_on_association(:user)
      expect(association.macro).to eq :belongs_to
    end
  end

  describe 'scopes' do
    before do
      uploaded_file.save!
      @public_file = UploadedFile.create!(
        filename: 'public.pdf',
        filepath: '/path/to/public.pdf',
        uploaded_at: Time.current,
        user: user,
        public: true
      )
    end

    it 'has public_files scope' do
      expect(UploadedFile.public_files).to include(@public_file)
      expect(UploadedFile.public_files).not_to include(uploaded_file)
    end

    it 'has private_files scope' do
      expect(UploadedFile.private_files).to include(uploaded_file)
      expect(UploadedFile.private_files).not_to include(@public_file)
    end

    it 'has by_upload_date_desc scope' do
      later_file = UploadedFile.create!(
        filename: 'later.pdf',
        filepath: '/path/to/later.pdf',
        uploaded_at: 1.hour.from_now,
        user: user
      )
      
      ordered_files = UploadedFile.by_upload_date_desc
      expect(ordered_files.first).to eq(later_file)
    end
  end

  describe '#can_be_deleted?' do
    it 'returns true for private files' do
      uploaded_file.public = false
      expect(uploaded_file.can_be_deleted?).to be true
    end

    it 'returns false for public files' do
      uploaded_file.public = true
      expect(uploaded_file.can_be_deleted?).to be false
    end
  end

  describe '#generate_share_token' do
    it 'generates a unique token' do
      uploaded_file.save!
      token = uploaded_file.generate_share_token
      expect(token).to be_present
      expect(token.length).to eq(20) # SecureRandom.hex(10) produces 20 characters
    end

    it 'generates unique tokens for different calls' do
      uploaded_file.save!
      token1 = uploaded_file.generate_share_token
      token2 = uploaded_file.generate_share_token
      expect(token1).not_to eq(token2)
    end
  end

  describe '#make_public' do
    it 'makes file public and generates share token' do
      uploaded_file.save!
      uploaded_file.make_public
      uploaded_file.reload
      
      expect(uploaded_file.public?).to be true
      expect(uploaded_file.share_token).to be_present
    end
  end

  describe '#make_private' do
    it 'makes file private and removes share token' do
      uploaded_file.save!
      uploaded_file.update!(public: true, share_token: 'some_token')
      
      uploaded_file.make_private
      uploaded_file.reload
      
      expect(uploaded_file.public?).to be false
      expect(uploaded_file.share_token).to be_nil
    end
  end

  describe '#toggle_public' do
    it 'toggles from private to public' do
      uploaded_file.save!
      expect(uploaded_file.public?).to be false
      
      uploaded_file.toggle_public
      uploaded_file.reload
      
      expect(uploaded_file.public?).to be true
      expect(uploaded_file.share_token).to be_present
    end

    it 'toggles from public to private' do
      uploaded_file.save!
      uploaded_file.update!(public: true, share_token: 'some_token')
      
      uploaded_file.toggle_public
      uploaded_file.reload
      
      expect(uploaded_file.public?).to be false
      expect(uploaded_file.share_token).to be_nil
    end
  end
end
