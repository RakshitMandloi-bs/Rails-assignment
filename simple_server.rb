#!/usr/bin/env ruby

# Simple Ruby web server for FileManager
require 'webrick'
require 'sqlite3'
require 'json'
require 'openssl'
require 'securerandom'
require 'fileutils'
require 'cgi'

puts "Starting FileManager Server..."

# Database setup
script_dir = File.dirname(File.expand_path(__FILE__))
db_path = File.join(script_dir, 'db', 'development.sqlite3')
DB = SQLite3::Database.new(db_path)
DB.results_as_hash = true

# Simple User model
class User
  attr_accessor :id, :username, :email, :name, :password_hash, :password_salt
  
  def initialize(attributes = {})
    # Initialize with empty values, set manually to avoid @0, @1 issues from DB
  end
  
  def self.find_by_username(username)
    result = DB.execute("SELECT * FROM users WHERE username = ?", [username]).first
    return nil unless result
    
    user = User.new
    user.id = result['id']
    user.username = result['username']
    user.email = result['email']
    user.name = result['name']
    user.password_hash = result['password_hash']
    user.password_salt = result['password_salt']
    user
  end
  
  def self.create(attributes)
    user = User.new
    user.username = attributes[:username]
    user.email = attributes[:email]
    user.name = attributes[:name]
    user.password = attributes[:password] if attributes[:password]
    
    DB.execute(
      "INSERT INTO users (username, email, name, password_hash, password_salt, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
      [user.username, user.email, user.name, user.password_hash, user.password_salt, Time.now.to_s, Time.now.to_s]
    )
    
    user.id = DB.last_insert_row_id
    user
  end
  
  def password=(password)
    @password_salt = SecureRandom.hex(16)
    @password_hash = OpenSSL::Digest::SHA256.hexdigest(@password_salt + password)
  end
  
  def authenticate(password)
    @password_hash == OpenSSL::Digest::SHA256.hexdigest(@password_salt + password)
  end
end

# Simple file storage
def create_user_storage_dir(user_id)
  dir = "storage/#{user_id}"
  FileUtils.mkdir_p(dir)
  dir
end

# Session management
SESSIONS = {}

class FileServer < WEBrick::HTTPServlet::AbstractServlet
  def do_GET(request, response)
    path = request.path
    query = request.query
    
    if path == '/' || path == '/login'
      error_message = nil
      if query && query['error']
        error_message = CGI.unescape(query['error'])
      end
      serve_login_page(response, error_message)
    elsif path == '/signup'
      error_message = nil
      if query && query['error']
        error_message = CGI.unescape(query['error'])
      end
      serve_signup_page(response, error_message)
    elsif path == '/dashboard'
      success_message = nil
      error_message = nil
      if query && query['message']
        success_message = CGI.unescape(query['message'])
      end
      if query && query['error']
        error_message = CGI.unescape(query['error'])
      end
      serve_dashboard(request, response, success_message, error_message)
    elsif path.start_with?('/shared/') && path.include?('/download')
      handle_shared_file_download(request, response)
    elsif path.start_with?('/shared/')
      serve_shared_file(request, response)
    elsif path.start_with?('/files/') && path.include?('/download')
      handle_file_download(request, response)
    elsif path.start_with?('/files/') && path.include?('/share')
      handle_file_share(request, response)
    elsif path.start_with?('/files/') && path.include?('/unshare')
      handle_file_unshare(request, response)
    elsif path.start_with?('/files/') && path.include?('/delete')
      handle_file_delete(request, response)
    elsif path == '/logout'
      handle_logout(request, response)
    else
      response.status = 404
      response.body = 'Not Found'
    end
  end
  
  def do_POST(request, response)
    path = request.path
    
    if path == '/login'
      handle_login(request, response)
    elsif path == '/signup'
      handle_signup(request, response)
    elsif path == '/upload'
      handle_upload(request, response)
    else
      response.status = 404
      response.body = 'Not Found'
    end
  end
  
  private
  
  def get_current_user(request)
    session_id = request.cookies.find { |c| c.name == 'session_id' }&.value
    puts "DEBUG GET_USER: Session ID from cookie: #{session_id}"
    puts "DEBUG GET_USER: Available sessions: #{SESSIONS.inspect}"
    
    return nil unless session_id && SESSIONS[session_id]
    
    user_id = SESSIONS[session_id]
    puts "DEBUG GET_USER: User ID from session: #{user_id}"
    
    result = DB.execute("SELECT * FROM users WHERE id = ?", [user_id]).first
    puts "DEBUG GET_USER: User query result: #{result.inspect}"
    return nil unless result
    
    user = User.new
    user.id = result['id']
    user.username = result['username']
    user.email = result['email']
    user.name = result['name']
    user.password_hash = result['password_hash']
    user.password_salt = result['password_salt']
    puts "DEBUG GET_USER: Created user object: #{user.id}, #{user.username}"
    user
  end
  
  def serve_login_page(response, error_message = nil)
    response.status = 200
    response['Content-Type'] = 'text/html'
    
    error_html = error_message ? "<div class='error'>#{error_message}</div>" : ""
    
    response.body = <<-HTML
<!DOCTYPE html>
<html>
<head>
  <title>FileManager - Login</title>
  <style>
    body { font-family: Arial, sans-serif; max-width: 500px; margin: 50px auto; padding: 20px; }
    .form-group { margin-bottom: 15px; }
    label { display: block; margin-bottom: 5px; font-weight: bold; }
    input { width: 100%; padding: 10px; box-sizing: border-box; border: 1px solid #ddd; border-radius: 4px; }
    button { background: #007bff; color: white; padding: 12px 20px; border: none; cursor: pointer; border-radius: 4px; width: 100%; }
    button:hover { background: #0056b3; }
    .error { color: #721c24; background: #f8d7da; border: 1px solid #f5c6cb; padding: 10px; border-radius: 4px; margin: 15px 0; }
    .success { color: #155724; background: #d4edda; border: 1px solid #c3e6cb; padding: 10px; border-radius: 4px; margin: 15px 0; }
    .card { background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
    h1 { text-align: center; color: #333; margin-bottom: 30px; }
    h2 { text-align: center; color: #666; margin-bottom: 20px; }
    .link { text-align: center; margin-top: 20px; }
    .link a { color: #007bff; text-decoration: none; }
    .link a:hover { text-decoration: underline; }
  </style>
</head>
<body>
  <div class="card">
    <h1>FileManager</h1>
    <h2>Login</h2>
    
    #{error_html}
    
    <form method="POST" action="/login">
      <div class="form-group">
        <label>Username:</label>
        <input type="text" name="username" required placeholder="Enter your username">
      </div>
      <div class="form-group">
        <label>Password:</label>
        <input type="password" name="password" required placeholder="Enter your password">
      </div>
      <button type="submit">Login</button>
    </form>
    
    <div class="link">
      <p><a href="/signup">Don't have an account? Sign up here</a></p>
    </div>
    
    <div style="margin-top: 30px; padding: 15px; background: #f8f9fa; border-radius: 4px; font-size: 14px;">
      <strong>Test Account:</strong><br>
      Username: <code>rakshitm</code><br>
      <em>Use the password you set during signup</em>
    </div>
  </div>
</body>
</html>
    HTML
  end
  
  def serve_signup_page(response, error_message = nil)
    response.status = 200
    response['Content-Type'] = 'text/html'
    
    error_html = error_message ? "<div class='error'>#{error_message}</div>" : ""
    
    response.body = <<-HTML
<!DOCTYPE html>
<html>
<head>
  <title>FileManager - Sign Up</title>
  <style>
    body { font-family: Arial, sans-serif; max-width: 500px; margin: 50px auto; padding: 20px; }
    .form-group { margin-bottom: 15px; }
    label { display: block; margin-bottom: 5px; font-weight: bold; }
    input { width: 100%; padding: 10px; box-sizing: border-box; border: 1px solid #ddd; border-radius: 4px; }
    button { background: #28a745; color: white; padding: 12px 20px; border: none; cursor: pointer; border-radius: 4px; width: 100%; }
    button:hover { background: #1e7e34; }
    .error { color: #721c24; background: #f8d7da; border: 1px solid #f5c6cb; padding: 10px; border-radius: 4px; margin: 15px 0; }
    .card { background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
    h1 { text-align: center; color: #333; margin-bottom: 30px; }
    h2 { text-align: center; color: #666; margin-bottom: 20px; }
    .link { text-align: center; margin-top: 20px; }
    .link a { color: #007bff; text-decoration: none; }
    .link a:hover { text-decoration: underline; }
    .password-help { font-size: 12px; color: #666; margin-top: 5px; }
  </style>
</head>
<body>
  <div class="card">
    <h1>FileManager</h1>
    <h2>Create Account</h2>
    
    #{error_html}
    
    <form method="POST" action="/signup">
      <div class="form-group">
        <label>Full Name:</label>
        <input type="text" name="name" required placeholder="Enter your full name">
      </div>
      <div class="form-group">
        <label>Username:</label>
        <input type="text" name="username" required placeholder="Choose a username">
      </div>
      <div class="form-group">
        <label>Email:</label>
        <input type="email" name="email" required placeholder="Enter your email address">
      </div>
      <div class="form-group">
        <label>Password:</label>
        <input type="password" name="password" required placeholder="Create a secure password">
        <div class="password-help">Must be at least 9 characters with 1 uppercase, 1 lowercase, and 1 digit</div>
      </div>
      <button type="submit">Create Account</button>
    </form>
    
    <div class="link">
      <p><a href="/login">Already have an account? Login here</a></p>
    </div>
  </div>
</body>
</html>
    HTML
  end
  
  def serve_dashboard(request, response, success_message = nil, error_message = nil)
    user = get_current_user(request)
    unless user
      response.status = 302
      response['Location'] = '/login?error=' + CGI.escape('Please log in to access the dashboard')
      return
    end
    
    files = DB.execute("SELECT * FROM uploaded_files WHERE user_id = ? ORDER BY uploaded_at DESC", [user.id])
    
    success_html = success_message ? "<div class='success'>#{success_message}</div>" : ""
    error_html = error_message ? "<div class='error'>#{error_message}</div>" : ""
    
    response.status = 200
    response['Content-Type'] = 'text/html'
    response.body = <<-HTML
<!DOCTYPE html>
<html>
<head>
  <title>Dashboard - FileManager</title>
  <script>
    function copyToClipboard(text) {
      navigator.clipboard.writeText(text).then(function() {
        // Show success feedback
        event.target.innerHTML = 'Copied!';
        event.target.style.background = '#28a745';
        setTimeout(function() {
          event.target.innerHTML = 'Copy';
          event.target.style.background = '#007bff';
        }, 2000);
      }).catch(function(err) {
        // Fallback for older browsers
        var textArea = document.createElement("textarea");
        textArea.value = text;
        document.body.appendChild(textArea);
        textArea.focus();
        textArea.select();
        try {
          document.execCommand('copy');
          event.target.innerHTML = 'Copied!';
          event.target.style.background = '#28a745';
          setTimeout(function() {
            event.target.innerHTML = 'Copy';
            event.target.style.background = '#007bff';
          }, 2000);
        } catch (err) {
          alert('Copy failed. Please manually copy the URL.');
        }
        document.body.removeChild(textArea);
      });
    }
  </script>
  <style>
    body { font-family: Arial, sans-serif; margin: 0; padding: 20px; background: #f8f9fa; }
    .header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 30px; padding: 20px; background: white; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
    .upload-area { border: 2px dashed #007bff; padding: 30px; text-align: center; margin-bottom: 30px; background: white; border-radius: 8px; }
    .upload-area:hover { border-color: #0056b3; background: #f8f9ff; }
    .files-grid { display: block; }
    .file-card { border: 1px solid #ddd; padding: 20px; margin-bottom: 15px; border-radius: 8px; background: white; box-shadow: 0 2px 4px rgba(0,0,0,0.1); display: flex; align-items: center; justify-content: space-between; }
    .file-card:hover { box-shadow: 0 4px 8px rgba(0,0,0,0.15); }
    .file-info { flex: 1; }
    .file-name { font-weight: bold; margin-bottom: 5px; font-size: 16px; }
    .file-date { color: #666; font-size: 14px; margin-bottom: 0; }
    .file-actions { margin-left: 20px; text-align: right; min-width: 300px; }
    .btn { padding: 8px 12px; margin-right: 8px; margin-bottom: 5px; text-decoration: none; border: none; cursor: pointer; border-radius: 4px; font-size: 14px; display: inline-block; }
    .btn-primary { background: #007bff; color: white; }
    .btn-primary:hover { background: #0056b3; }
    .btn-success { background: #28a745; color: white; }
    .btn-success:hover { background: #1e7e34; }
    .btn-danger { background: #dc3545; color: white; }
    .btn-danger:hover { background: #c82333; }
    .btn-secondary { background: #6c757d; color: white; }
    .btn-secondary:hover { background: #545b62; }
    .shared-badge { background: #28a745; color: white; padding: 3px 8px; border-radius: 12px; font-size: 12px; margin-left: 10px; }
    .success { color: #155724; background: #d4edda; border: 1px solid #c3e6cb; padding: 12px; border-radius: 4px; margin: 15px 0; }
    .error { color: #721c24; background: #f8d7da; border: 1px solid #f5c6cb; padding: 12px; border-radius: 4px; margin: 15px 0; }
    .empty-state { text-align: center; padding: 40px; background: white; border-radius: 8px; color: #666; }
    .user-info { color: #666; }
    .logo { font-size: 20px; font-weight: bold; color: #007bff; }
  </style>
</head>
<body>
  <div class="header">
    <div class="logo">FileManager</div>
    <div>
      <span class="user-info">Hello, #{user.name}! (@#{user.username})</span>
      <a href="/logout" class="btn btn-secondary">Logout</a>
    </div>
  </div>
  
  #{success_html}
  #{error_html}
  
  <div class="upload-area">
    <h3>Upload a New File</h3>
    <p>Drag and drop a file here or click to browse</p>
    <form method="POST" action="/upload" enctype="multipart/form-data">
      <input type="file" name="file" required style="margin: 10px;">
      <br>
      <button type="submit" class="btn btn-success">Upload File</button>
    </form>
  </div>
  
  #{files.empty? ? 
    '<div class="empty-state"><h3>No files uploaded yet</h3><p>Upload your first file using the form above!</p></div>' :
    '<div class="files-grid">' + files.map { |file|
      shared_indicator = (file['public'] == 1) ? '<span class="shared-badge">SHARED</span>' : ''
      share_url = (file['public'] == 1) ? '<br><small style="color: #666; font-size: 12px; margin-top: 5px; display: block;">Share URL: <a href="http://' + request.host + ':' + request.port.to_s + '/shared/' + file['share_token'].to_s + '" target="_blank" style="color: #007bff; text-decoration: none;">http://' + request.host + ':' + request.port.to_s + '/shared/' + file['share_token'].to_s + '</a> <button onclick="copyToClipboard(\'http://' + request.host + ':' + request.port.to_s + '/shared/' + file['share_token'].to_s + '\')" style="background: #007bff; color: white; border: none; padding: 2px 6px; border-radius: 3px; cursor: pointer; font-size: 10px; margin-left: 5px;">Copy</button></small>' : ''
      <<-FILE_CARD
      <div class="file-card">
        <div class="file-info">
          <div class="file-name">#{file['filename']} #{shared_indicator}</div>
          <div class="file-date">Uploaded: #{file['uploaded_at']}</div>
          #{share_url}
        </div>
        <div class="file-actions">
          <a href="/files/#{file['id']}/download" class="btn btn-primary">Download</a>
          #{(file['public'] == 1) ? '<a href="/files/' + file['id'].to_s + '/unshare" class="btn btn-secondary">Unshare</a>' : '<a href="/files/' + file['id'].to_s + '/share" class="btn btn-success">Share</a>'}
          #{(file['public'] == 1) ? '' : '<a href="/files/' + file['id'].to_s + '/delete" class="btn btn-danger" onclick="return confirm(\'Are you sure you want to delete this file?\')">Delete</a>'}
        </div>
      </div>
      FILE_CARD
    }.join('') + '</div>'
  }
</body>
</html>
    HTML
  end
  
  def handle_logout(request, response)
    session_id = request.cookies.find { |c| c.name == 'session_id' }&.value
    SESSIONS.delete(session_id) if session_id
    
    response.status = 302
    response['Location'] = '/login?message=' + CGI.escape('You have been logged out successfully')
    response['Set-Cookie'] = "session_id=; Path=/; Expires=Thu, 01 Jan 1970 00:00:00 GMT"
  end
  
  def handle_login(request, response)
    params = CGI.parse(request.body)
    username = params['username']&.first&.strip
    password = params['password']&.first
    
    # Validate input
    if username.nil? || username.empty?
      response.status = 302
      response['Location'] = '/login?error=' + CGI.escape('Username is required')
      return
    end
    
    if password.nil? || password.empty?
      response.status = 302
      response['Location'] = '/login?error=' + CGI.escape('Password is required')
      return
    end
    
    # Find user
    user = User.find_by_username(username)
    
    if user.nil?
      response.status = 302
      response['Location'] = '/login?error=' + CGI.escape("User '#{username}' not found. Please check your username or sign up.")
      return
    end
    
    # Check password
    if user.authenticate(password)
      session_id = SecureRandom.hex(16)
      SESSIONS[session_id] = user.id
      
      response.status = 302
      response['Location'] = '/dashboard?message=' + CGI.escape("Welcome back, #{user.name}!")
      response['Set-Cookie'] = "session_id=#{session_id}; Path=/"
    else
      response.status = 302
      response['Location'] = '/login?error=' + CGI.escape("Incorrect password for user '#{username}'. Please try again.")
    end
  end
  
  def validate_password(password)
    errors = []
    
    if password.nil? || password.length < 9
      errors << "Password must be at least 9 characters long"
    end
    
    unless password.match(/[A-Z]/)
      errors << "Password must contain at least one uppercase letter"
    end
    
    unless password.match(/[a-z]/)
      errors << "Password must contain at least one lowercase letter"
    end
    
    unless password.match(/\d/)
      errors << "Password must contain at least one digit"
    end
    
    errors
  end
  
  def handle_signup(request, response)
    params = CGI.parse(request.body)
    
    name = params['name']&.first&.strip
    username = params['username']&.first&.strip
    email = params['email']&.first&.strip
    password = params['password']&.first
    
    # Validate input
    errors = []
    
    errors << "Name is required" if name.nil? || name.empty?
    errors << "Username is required" if username.nil? || username.empty?
    errors << "Email is required" if email.nil? || email.empty?
    errors << "Password is required" if password.nil? || password.empty?
    
    # Validate email format
    if email && !email.match(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
      errors << "Please enter a valid email address"
    end
    
    # Validate password complexity
    if password
      errors.concat(validate_password(password))
    end
    
    # Check for existing users
    if username && User.find_by_username(username)
      errors << "Username '#{username}' is already taken"
    end
    
    if email
      existing_email = DB.execute("SELECT id FROM users WHERE email = ?", [email]).first
      if existing_email
        errors << "Email '#{email}' is already registered"
      end
    end
    
    if errors.any?
      error_message = errors.join(', ')
      response.status = 302
      response['Location'] = '/signup?error=' + CGI.escape(error_message)
      return
    end
    
    begin
      user = User.create(
        name: name,
        username: username,
        email: email,
        password: password
      )
      
      session_id = SecureRandom.hex(16)
      SESSIONS[session_id] = user.id
      
      response.status = 302
      response['Location'] = '/dashboard?message=' + CGI.escape("Account created successfully! Welcome, #{user.name}!")
      response['Set-Cookie'] = "session_id=#{session_id}; Path=/"
    rescue => e
      response.status = 302
      response['Location'] = '/signup?error=' + CGI.escape("Failed to create account: #{e.message}")
    end
  end
  
  def handle_upload(request, response)
    user = get_current_user(request)
    unless user
      response.status = 302
      response['Location'] = '/login'
      return
    end
    
    begin
      # Parse multipart form data
      content_type = request['Content-Type']
      unless content_type && content_type.include?('multipart/form-data')
        response.status = 302
        response['Location'] = '/dashboard?error=' + CGI.escape('Invalid upload format')
        return
      end
      
      # Extract boundary from content type
      boundary = content_type.split('boundary=').last
      body = request.body
      
      # Parse the multipart data
      file_data = parse_multipart_data(body, boundary)
      
      if file_data.nil? || file_data[:filename].nil? || file_data[:content].nil?
        response.status = 302
        response['Location'] = '/dashboard?error=' + CGI.escape('No file selected or invalid file data')
        return
      end
      
      # Validate file
      if file_data[:filename].empty?
        response.status = 302
        response['Location'] = '/dashboard?error=' + CGI.escape('Please select a file to upload')
        return
      end
      
      if file_data[:content].empty?
        response.status = 302
        response['Location'] = '/dashboard?error=' + CGI.escape('Selected file is empty')
        return
      end
      
      # Create user storage directory
      storage_dir = create_user_storage_dir(user.id)
      
      # Generate unique filename to avoid conflicts
      timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
      safe_filename = file_data[:filename].gsub(/[^a-zA-Z0-9\-_\.]/, '_')
      unique_filename = "#{timestamp}_#{safe_filename}"
      file_path = File.join(storage_dir, unique_filename)
      
      # Save file to disk
      File.open(file_path, 'wb') do |f|
        f.write(file_data[:content])
      end
      
      # Generate share token
      share_token = SecureRandom.hex(16)
      
      # Save file record to database
      DB.execute(
        "INSERT INTO uploaded_files (filename, filepath, uploaded_at, public, share_token, user_id, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        [file_data[:filename], file_path, Time.now.to_s, 0, share_token, user.id, Time.now.to_s, Time.now.to_s]
      )
      
      response.status = 302
      response['Location'] = '/dashboard?message=' + CGI.escape("File '#{file_data[:filename]}' uploaded successfully!")
      
    rescue => e
      puts "Upload error: #{e.message}"
      puts e.backtrace
      response.status = 302
      response['Location'] = '/dashboard?error=' + CGI.escape("Upload failed: #{e.message}")
    end
  end
  
  # Parse multipart form data manually
  def parse_multipart_data(body, boundary)
    return nil unless boundary
    
    # Split by boundary
    parts = body.split("--#{boundary}")
    
    parts.each do |part|
      next if part.strip.empty? || part.strip == '--'
      
      # Split headers and content
      header_end = part.index("\r\n\r\n")
      next unless header_end
      
      headers = part[0...header_end]
      content = part[header_end + 4..-1]
      
      # Remove trailing \r\n
      content = content.chomp("\r\n") if content.end_with?("\r\n")
      
      # Check if this part contains a file
      if headers.include?('Content-Disposition: form-data') && headers.include?('filename=')
        # Extract filename
        filename_match = headers.match(/filename="([^"]*)"/)
        filename = filename_match ? filename_match[1] : nil
        
        next if filename.nil? || filename.empty?
        
        return {
          filename: filename,
          content: content
        }
      end
    end
    
    nil
  end
  
  def handle_file_download(request, response)
    user = get_current_user(request)
    unless user
      puts "DEBUG: No user found in session"
      response.status = 302
      response['Location'] = '/login'
      return
    end
    
    # Extract file ID from path like /files/123/download
    file_id_match = request.path.match(/\/files\/(\d+)\/download/)
    unless file_id_match
      puts "DEBUG: Could not extract file ID from path: #{request.path}"
      response.status = 302
      response['Location'] = '/dashboard?error=' + CGI.escape('Invalid file URL')
      return
    end
    
    file_id = file_id_match[1].to_i  # Convert to integer!
    puts "DEBUG: Looking for file ID #{file_id} (#{file_id.class}) for user ID #{user.id}"
    
    # Get file record
    puts "DEBUG: Running query: SELECT * FROM uploaded_files WHERE id = #{file_id} AND user_id = #{user.id}"
    file_record = DB.execute("SELECT * FROM uploaded_files WHERE id = ? AND user_id = ?", [file_id, user.id]).first
    puts "DEBUG: Query result: #{file_record.inspect}"
    
    unless file_record
      puts "DEBUG: No file record found for file ID #{file_id} and user ID #{user.id}"
      # Check if file exists but belongs to different user
      any_file = DB.execute("SELECT * FROM uploaded_files WHERE id = ?", [file_id]).first
      if any_file
        puts "DEBUG: File exists but belongs to user ID #{any_file['user_id']}, not #{user.id}"
      else
        puts "DEBUG: File with ID #{file_id} does not exist at all"
      end
      response.status = 302
      response['Location'] = '/dashboard?error=' + CGI.escape('File not found')
      return
    end
    
    file_path = file_record['filepath']
    puts "DEBUG: File path: #{file_path}"
    
    unless File.exist?(file_path)
      puts "DEBUG: File not found on disk: #{file_path}"
      response.status = 302
      response['Location'] = '/dashboard?error=' + CGI.escape('File not found on disk')
      return
    end
    
    puts "DEBUG: Successfully serving file: #{file_record['filename']}"
    # Serve the file
    response.status = 200
    response['Content-Type'] = 'application/octet-stream'
    response['Content-Disposition'] = "attachment; filename=\"#{file_record['filename']}\""
    response.body = File.read(file_path)
  end
  
  def handle_shared_file_download(request, response)
    # Extract share token from path like /shared/abc123/download
    share_token = request.path.match(/\/shared\/([^\/]+)\/download/)[1]
    
    file_record = DB.execute("SELECT * FROM uploaded_files WHERE share_token = '#{share_token}' AND public = 1").first
    
    unless file_record
      response.status = 404
      response.body = 'Shared file not found'
      return
    end
    
    # Get the full file path
    script_dir = File.dirname(File.expand_path(__FILE__))
    file_path = File.join(script_dir, file_record['filepath'])
    
    unless File.exist?(file_path)
      response.status = 404
      response.body = 'File not available on disk'
      return
    end
    
    # Serve the file
    response.status = 200
    response['Content-Type'] = 'application/octet-stream'
    response['Content-Disposition'] = "attachment; filename=\"#{file_record['filename']}\""
    response.body = File.read(file_path)
  end

  def handle_file_share(request, response)
    user = get_current_user(request)
    unless user
      response.status = 302
      response['Location'] = '/login'
      return
    end
    
    file_id = request.path.match(/\/files\/(\d+)\/share/)[1].to_i
    
    file_record = DB.execute("SELECT * FROM uploaded_files WHERE id = ? AND user_id = ?", [file_id, user.id]).first
    
    unless file_record
      response.status = 302
      response['Location'] = '/dashboard?error=' + CGI.escape('File not found')
      return
    end
    
    # Update file to be public
    DB.execute("UPDATE uploaded_files SET public = 1, updated_at = ? WHERE id = ?", [Time.now.to_s, file_id])
    
    response.status = 302
    response['Location'] = '/dashboard?message=' + CGI.escape("File '#{file_record['filename']}' is now publicly shared!")
  end
  
  def handle_file_unshare(request, response)
    user = get_current_user(request)
    unless user
      puts "DEBUG UNSHARE: No user found in session"
      response.status = 302
      response['Location'] = '/login'
      return
    end
    
    file_id_match = request.path.match(/\/files\/(\d+)\/unshare/)
    unless file_id_match
      puts "DEBUG UNSHARE: Could not extract file ID from path: #{request.path}"
      response.status = 302
      response['Location'] = '/dashboard?error=' + CGI.escape('Invalid file URL')
      return
    end
    
    file_id = file_id_match[1].to_i
    puts "DEBUG UNSHARE: Looking for file ID #{file_id} for user ID #{user.id}"
    
    file_record = DB.execute("SELECT * FROM uploaded_files WHERE id = ? AND user_id = ?", [file_id, user.id]).first
    
    unless file_record
      puts "DEBUG UNSHARE: No file record found for file ID #{file_id} and user ID #{user.id}"
      response.status = 302
      response['Location'] = '/dashboard?error=' + CGI.escape('File not found')
      return
    end
    
    puts "DEBUG UNSHARE: Found file record, updating to private"
    # Update file to be private
    DB.execute("UPDATE uploaded_files SET public = 0, updated_at = ? WHERE id = ?", [Time.now.to_s, file_id])
    
    response.status = 302
    response['Location'] = '/dashboard?message=' + CGI.escape("File '#{file_record['filename']}' is no longer shared")
  end
  
  def handle_file_delete(request, response)
    user = get_current_user(request)
    unless user
      response.status = 302
      response['Location'] = '/login'
      return
    end
    
    file_id = request.path.match(/\/files\/(\d+)\/delete/)[1].to_i
    
    file_record = DB.execute("SELECT * FROM uploaded_files WHERE id = ? AND user_id = ?", [file_id, user.id]).first
    
    unless file_record
      response.status = 302
      response['Location'] = '/dashboard?error=' + CGI.escape('File not found')
      return
    end
    
    # Don't allow deletion of shared files
    if file_record['public'] == 1
      response.status = 302
      response['Location'] = '/dashboard?error=' + CGI.escape('Cannot delete a shared file. Unshare it first.')
      return
    end
    
    # Delete file from disk
    file_path = file_record['filepath']
    if File.exist?(file_path)
      File.delete(file_path)
    end
    
    # Delete from database
    DB.execute("DELETE FROM uploaded_files WHERE id = ?", [file_id])
    
    response.status = 302
    response['Location'] = '/dashboard?message=' + CGI.escape("File '#{file_record['filename']}' deleted successfully")
  end
  
  def serve_shared_file(request, response)
    # Extract share token from path like /shared/abc123
    share_token = request.path.split('/shared/').last
    
    # Find the file using direct query to avoid parameterized query issues
    file_record = DB.execute("SELECT * FROM uploaded_files WHERE share_token = '#{share_token}' AND public = 1").first
    
    unless file_record
      response.status = 404
      response['Content-Type'] = 'text/html'
      response.body = <<-HTML
<!DOCTYPE html>
<html>
<head>
  <title>File Not Found</title>
  <style>
    body { font-family: Arial, sans-serif; text-align: center; margin: 50px; }
    .error { color: #721c24; background: #f8d7da; border: 1px solid #f5c6cb; padding: 20px; border-radius: 4px; display: inline-block; }
  </style>
</head>
<body>
  <div class="error">
    <h2>File Not Found</h2>
    <p>The shared file you're looking for doesn't exist or is no longer available.</p>
  </div>
</body>
</html>
      HTML
      return
    end
    
    # Get the full file path
    script_dir = File.dirname(File.expand_path(__FILE__))
    file_path = File.join(script_dir, file_record['filepath'])
    
    unless File.exist?(file_path)
      response.status = 404
      response['Content-Type'] = 'text/html'
      response.body = <<-HTML
<!DOCTYPE html>
<html>
<head>
  <title>File Not Found</title>
  <style>
    body { font-family: Arial, sans-serif; text-align: center; margin: 50px; }
    .error { color: #721c24; background: #f8d7da; border: 1px solid #f5c6cb; padding: 20px; border-radius: 4px; display: inline-block; }
  </style>
</head>
<body>
  <div class="error">
    <h2>File Not Available</h2>
    <p>The file exists in our records but is not available on disk.</p>
  </div>
</body>
</html>
      HTML
      return
    end
    
    # Get user info
    user_record = DB.execute("SELECT name, username FROM users WHERE id = ?", [file_record['user_id']]).first
    
    # Serve shared file page
    response.status = 200
    response['Content-Type'] = 'text/html'
    response.body = <<-HTML
<!DOCTYPE html>
<html>
<head>
  <title>Shared File - #{file_record['filename']}</title>
  <style>
    body { font-family: Arial, sans-serif; max-width: 600px; margin: 50px auto; padding: 20px; }
    .card { background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
    .file-icon { font-size: 48px; text-align: center; margin-bottom: 20px; }
    .file-name { font-size: 24px; font-weight: bold; text-align: center; margin-bottom: 10px; }
    .file-info { color: #666; text-align: center; margin-bottom: 30px; }
    .download-btn { background: #007bff; color: white; padding: 15px 30px; border: none; cursor: pointer; border-radius: 4px; font-size: 16px; text-decoration: none; display: inline-block; }
    .download-btn:hover { background: #0056b3; }
    .shared-by { text-align: center; margin-top: 20px; padding: 15px; background: #f8f9fa; border-radius: 4px; color: #666; }
  </style>
</head>
<body>
  <div class="card">
    <div class="file-icon">File</div>
    <div class="file-name">#{file_record['filename']}</div>
    <div class="file-info">
      Uploaded: #{file_record['uploaded_at']}<br>
      Size: #{File.size(file_path)} bytes
    </div>
    
    <div style="text-align: center;">
      <a href="/shared/#{share_token}/download" class="download-btn">Download File</a>
    </div>
    
    <div class="shared-by">
      Shared by #{user_record ? user_record['name'] : 'Unknown User'}
      #{user_record ? "(@#{user_record['username']})" : ''}
    </div>
  </div>
</body>
</html>
    HTML
  end
end

# Start the server
server = WEBrick::HTTPServer.new(Port: 3000)
server.mount '/', FileServer

trap('INT') { server.shutdown }

puts "Server running at http://localhost:3000"
puts "Features available:"
puts "   - User registration and login"
puts "   - Manual password hashing (OpenSSL)"
puts "   - SQLite database"
puts "   - File storage structure"
puts ""
puts "Press Ctrl+C to stop the server"

server.start
