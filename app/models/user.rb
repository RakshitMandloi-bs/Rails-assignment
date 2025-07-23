require 'openssl'
require 'securerandom'

class User < ApplicationRecord
  has_many :uploaded_files, dependent: :destroy

  validates :username, presence: true, uniqueness: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true
  validate :password_complexity, if: :password_present?

  attr_accessor :password

  def password=(password)
    return if password.blank?
    @password = password
    self.password_salt = SecureRandom.hex(16)
    self.password_hash = OpenSSL::Digest::SHA256.hexdigest(self.password_salt + password)
  end

  def authenticate(password)
    return false if password_hash.blank? || password_salt.blank?
    self.password_hash == OpenSSL::Digest::SHA256.hexdigest(self.password_salt + password)
  end

  private

  def password_present?
    @password.present?
  end

  def password_complexity
    return unless @password.present?

    errors.add(:password, "must be at least 9 characters long") if @password.length < 9
    errors.add(:password, "must contain at least one uppercase letter") unless @password.match(/[A-Z]/)
    errors.add(:password, "must contain at least one lowercase letter") unless @password.match(/[a-z]/)
    errors.add(:password, "must contain at least one digit") unless @password.match(/\d/)
  end
end
