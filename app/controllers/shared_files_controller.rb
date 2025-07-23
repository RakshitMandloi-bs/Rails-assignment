class SharedFilesController < ApplicationController
  skip_before_action :require_login

  def show
    @uploaded_file = UploadedFile.find_by(share_token: params[:token])
    
    unless @uploaded_file&.public?
      render plain: "File not found", status: :not_found
      return
    end

    if File.exist?(@uploaded_file.filepath)
      send_file @uploaded_file.filepath, 
                filename: @uploaded_file.filename,
                disposition: :attachment
    else
      render plain: "File not found on disk", status: :not_found
    end
  end
end
