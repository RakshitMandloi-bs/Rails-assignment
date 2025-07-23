require 'fileutils'

class UploadedFilesController < ApplicationController
  before_action :set_uploaded_file, only: [:download, :destroy, :toggle_share]

  def index
    @uploaded_files = current_user.uploaded_files.by_upload_date_desc
  end

  def create
    uploaded_file = params[:file]
    
    if uploaded_file.blank?
      redirect_to dashboard_path, alert: "Please select a file to upload"
      return
    end

    # Create user storage directory
    user_storage_dir = Rails.root.join("storage", current_user.id.to_s)
    FileUtils.mkdir_p(user_storage_dir)

    # Save file to disk
    file_path = user_storage_dir.join(uploaded_file.original_filename)
    
    begin
      File.open(file_path, 'wb') do |file|
        file.write(uploaded_file.read)
      end

      # Create database record
      @uploaded_file = current_user.uploaded_files.create!(
        filename: uploaded_file.original_filename,
        filepath: file_path.to_s,
        uploaded_at: Time.current
      )

      redirect_to dashboard_path, notice: "File '#{uploaded_file.original_filename}' uploaded successfully!"
    rescue => e
      redirect_to dashboard_path, alert: "Failed to upload file: #{e.message}"
    end
  end

  def download
    if File.exist?(@uploaded_file.filepath)
      send_file @uploaded_file.filepath, 
                filename: @uploaded_file.filename, 
                disposition: :attachment
    else
      redirect_to dashboard_path, alert: "File not found"
    end
  end

  def destroy
    unless @uploaded_file.can_be_deleted?
      redirect_to dashboard_path, alert: "Can't delete a shared file"
      return
    end

    begin
      # Delete file from disk
      File.delete(@uploaded_file.filepath) if File.exist?(@uploaded_file.filepath)
      
      # Delete database record
      @uploaded_file.destroy
      
      redirect_to dashboard_path, notice: "File deleted successfully"
    rescue => e
      redirect_to dashboard_path, alert: "Failed to delete file: #{e.message}"
    end
  end

  def toggle_share
    begin
      @uploaded_file.toggle_public
      
      if @uploaded_file.public?
        redirect_to dashboard_path, notice: "File is now shared publicly"
      else
        redirect_to dashboard_path, notice: "File is now private"
      end
    rescue => e
      redirect_to dashboard_path, alert: "Failed to update sharing status: #{e.message}"
    end
  end

  private

  def set_uploaded_file
    @uploaded_file = current_user.uploaded_files.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to dashboard_path, alert: "File not found"
  end
end
