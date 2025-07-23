class UploadedFile < ApplicationRecord
  belongs_to :user

  validates :filename, presence: true
  validates :filepath, presence: true
  validates :uploaded_at, presence: true
  validates :share_token, uniqueness: true, allow_nil: true

  scope :public_files, -> { where(public: true) }
  scope :private_files, -> { where(public: false) }
  scope :by_upload_date_desc, -> { order(uploaded_at: :desc) }

  def can_be_deleted?
    !public?
  end

  def generate_share_token
    loop do
      token = SecureRandom.hex(10)
      break token unless UploadedFile.exists?(share_token: token)
    end
  end

  def make_public
    update!(public: true, share_token: generate_share_token)
  end

  def make_private
    update!(public: false, share_token: nil)
  end

  def toggle_public
    if public?
      make_private
    else
      make_public
    end
  end
end
