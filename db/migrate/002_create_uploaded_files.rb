class CreateUploadedFiles < ActiveRecord::Migration[6.0]
  def change
    create_table :uploaded_files do |t|
      t.string :filename, null: false
      t.string :filepath, null: false
      t.datetime :uploaded_at, null: false
      t.boolean :public, default: false
      t.string :share_token
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :uploaded_files, :share_token, unique: true
    add_index :uploaded_files, [:user_id, :uploaded_at]
  end
end
