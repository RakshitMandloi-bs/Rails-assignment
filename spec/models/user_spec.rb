require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    let(:valid_user) do
      User.new(
        username: 'testuser',
        email: 'test@example.com',
        name: 'Test User',
        password: 'Password123'
      )
    end

    it 'is valid with valid attributes' do
      expect(valid_user).to be_valid
    end

    it 'is invalid without username' do
      valid_user.username = nil
      expect(valid_user).not_to be_valid
      expect(valid_user.errors[:username]).to include("can't be blank")
    end

    it 'is invalid without email' do
      valid_user.email = nil
      expect(valid_user).not_to be_valid
      expect(valid_user.errors[:email]).to include("can't be blank")
    end

    it 'is invalid without name' do
      valid_user.name = nil
      expect(valid_user).not_to be_valid
      expect(valid_user.errors[:name]).to include("can't be blank")
    end

    it 'is invalid with duplicate username' do
      User.create!(username: 'testuser', email: 'first@example.com', name: 'First User', password: 'Password123')
      expect(valid_user).not_to be_valid
      expect(valid_user.errors[:username]).to include("has already been taken")
    end

    it 'is invalid with duplicate email' do
      User.create!(username: 'firstuser', email: 'test@example.com', name: 'First User', password: 'Password123')
      expect(valid_user).not_to be_valid
      expect(valid_user.errors[:email]).to include("has already been taken")
    end

    it 'is invalid with invalid email format' do
      valid_user.email = 'invalid-email'
      expect(valid_user).not_to be_valid
      expect(valid_user.errors[:email]).to include("is invalid")
    end
  end

  describe 'password complexity' do
    let(:user) { User.new(username: 'testuser', email: 'test@example.com', name: 'Test User') }

    it 'is invalid with password less than 9 characters' do
      user.password = 'Short1'
      expect(user).not_to be_valid
      expect(user.errors[:password]).to include("must be at least 9 characters long")
    end

    it 'is invalid without uppercase letter' do
      user.password = 'lowercase123'
      expect(user).not_to be_valid
      expect(user.errors[:password]).to include("must contain at least one uppercase letter")
    end

    it 'is invalid without lowercase letter' do
      user.password = 'UPPERCASE123'
      expect(user).not_to be_valid
      expect(user.errors[:password]).to include("must contain at least one lowercase letter")
    end

    it 'is invalid without digit' do
      user.password = 'NoDigitsHere'
      expect(user).not_to be_valid
      expect(user.errors[:password]).to include("must contain at least one digit")
    end

    it 'is valid with proper password complexity' do
      user.password = 'Password123'
      expect(user).to be_valid
    end
  end

  describe 'password authentication' do
    let(:user) do
      User.create!(
        username: 'testuser',
        email: 'test@example.com',
        name: 'Test User',
        password: 'Password123'
      )
    end

    it 'authenticates with correct password' do
      expect(user.authenticate('Password123')).to be true
    end

    it 'does not authenticate with incorrect password' do
      expect(user.authenticate('WrongPassword')).to be false
    end

    it 'stores password as hash, not plaintext' do
      expect(user.password_hash).not_to eq('Password123')
      expect(user.password_hash).to be_present
      expect(user.password_salt).to be_present
    end
  end

  describe 'associations' do
    it 'has many uploaded_files' do
      association = User.reflect_on_association(:uploaded_files)
      expect(association.macro).to eq :has_many
      expect(association.options[:dependent]).to eq :destroy
    end
  end
end
