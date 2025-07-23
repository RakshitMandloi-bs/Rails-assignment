# File Sharing Application

A complete Ruby on Rails file sharing application built **without external gems** (except RSpec for testing), implementing manual user authentication, file storage, and public sharing functionality.

## 🎯 Features

### ✅ User Management
- **Sign Up**: Username, email, name, and password with complexity validation
- **Login/Logout**: Manual session management
- **Profile Editing**: Update name and email (editable only by logged-in user)
- **Password Security**: Manual hashing using OpenSSL::Digest::SHA256 with salt

### ✅ File Management
- **File Upload**: Manual file storage in `Rails.root/storage/:user_id/`
- **Dashboard**: Grid layout showing files with upload dates (descending order)
- **File Download**: Secure file serving
- **File Deletion**: Only for private files

### ✅ Public Sharing
- **Share Toggle**: Generate secure tokens for public access
- **Public URLs**: `http://localhost:3000/shared/:token`
- **Read-only Sharing**: Shared files cannot be deleted
- **Share Management**: Turn sharing on/off

### ✅ Security & Validation
- **Password Requirements**: ≥9 chars, 1 uppercase, 1 lowercase, 1 digit
- **Unique Constraints**: Username and email must be unique
- **File Access Control**: Users can only access their own files
- **Secure Tokens**: Using SecureRandom.hex(10) for share tokens
- **Password Hash & Salt**: Passwords are never stored in plain text. Each password is hashed using SHA256 with a unique random salt per user. The salt is generated with `SecureRandom.hex(16)` and stored alongside the hash. On login, the input password is hashed with the stored salt and compared to the stored hash for authentication.

## 🔧 Tech Stack

- **Ruby**: 2.6.6
- **Rails**: 6.0.x
- **Database**: SQLite3
- **Testing**: RSpec 3.10.x
- **NO EXTERNAL GEMS**: No ActiveStorage, Devise, bcrypt, CarrierWave, etc.

## 📁 Project Structure

```
file_sharing_app/
├── app/
│   ├── controllers/
│   │   ├── application_controller.rb
│   │   ├── sessions_controller.rb
│   │   ├── users_controller.rb
│   │   ├── uploaded_files_controller.rb
│   │   └── shared_files_controller.rb
│   ├── models/
│   │   ├── user.rb
│   │   └── uploaded_file.rb
│   └── views/
│       ├── layouts/application.html.erb
│       ├── sessions/new.html.erb
│       ├── users/(new|edit).html.erb
│       └── uploaded_files/index.html.erb
├── config/
│   ├── routes.rb
│   ├── database.yml
│   └── application.rb
├── db/migrate/
│   ├── 001_create_users.rb
│   └── 002_create_uploaded_files.rb
├── spec/
│   ├── models/
│   ├── controllers/
│   └── rails_helper.rb
├── storage/           # File storage directory
├── Gemfile
└── README.md
```

## 🚀 Setup Instructions

### Prerequisites
- Ruby 2.6.6
- Rails 6.0.x
- SQLite3


### Quick Start (Ruby Fallback Server)
If you have trouble with Rails or just want to run the app quickly, you can use the built-in Ruby server:

```bash
cd file_sharing_app
ruby simple_server.rb
```

You will see output like:

```
🚀 Starting FileManager Server...
🌐 Server running at http://localhost:3000
✅ Features available:
   - User registration and login
   - Manual password hashing (OpenSSL)
   - SQLite database
   - File storage structure
Press Ctrl+C to stop the server
```

Then open http://localhost:3000 in your browser.

---

### Quick Setup (Rails)
```bash
# Clone or download the project
cd /path/to/rails-assignment

# Run the setup script
./setup.sh
```

### Manual Setup
```bash
cd file_sharing_app

# Install dependencies
bundle install

# Setup database
bundle exec rake db:create
bundle exec rake db:migrate

# Create storage directory
mkdir -p storage

# Run tests
bundle exec rspec

# Start server
bundle exec rails server
```

Visit `http://localhost:3000` to access the application.

## 🧪 Testing

The application includes comprehensive RSpec tests covering:

### Model Tests
- User validations and password complexity
- Password hashing and authentication
- UploadedFile validations and associations
- File sharing behavior

### Controller Tests
- SessionsController: login/logout flow
- UsersController: signup and profile management
- UploadedFilesController: file operations
- SharedFilesController: public file access

```bash
# Run all tests
bundle exec rspec

# Run specific test files
bundle exec rspec spec/models/user_spec.rb
bundle exec rspec spec/controllers/sessions_controller_spec.rb
```

## 🛣️ Routes

```ruby
# Authentication
GET  /login          # Login form
POST /login          # Process login
GET  /signup         # Signup form
POST /signup         # Process signup
DELETE /logout       # Logout

# Profile Management
GET  /profile        # Edit profile form
PATCH /profile       # Update profile

# File Management
GET  /dashboard      # Files dashboard
POST /upload         # Upload file
GET  /files/:id/download    # Download file
DELETE /files/:id           # Delete file
PATCH /files/:id/share      # Toggle sharing

# Public Sharing
GET  /shared/:token  # Access shared file
```

## 🔐 Security Features

### Password Security
- Manual hashing using OpenSSL::Digest::SHA256
- Unique salt for each password
- No plaintext storage

```ruby
def password=(password)
  self.password_salt = SecureRandom.hex(16)
  self.password_hash = OpenSSL::Digest::SHA256.hexdigest(self.password_salt + password)
end
```

### File Access Control
- Users can only access their own files
- Shared files are read-only
- Secure token generation for sharing

### Session Management
- Manual session handling
- Authentication required for protected routes
- Proper session cleanup on logout

## 📊 Database Schema

### Users Table
```sql
id: integer (primary key)
username: string (unique, not null)
email: string (unique, not null)
password_hash: string (not null)
password_salt: string (not null)
name: string
created_at: datetime
updated_at: datetime
```

### UploadedFiles Table
```sql
id: integer (primary key)
filename: string (not null)
filepath: string (not null)
uploaded_at: datetime (not null)
public: boolean (default: false)
share_token: string (unique)
user_id: integer (foreign key)
created_at: datetime
updated_at: datetime
```

## 🎨 UI Features

### Modern Design
- Clean, responsive layout
- Grid-based file display
- Professional styling without CSS frameworks
- Intuitive navigation

### File Dashboard
- Upload area with drag-and-drop styling
- File cards showing:
  - Filename
  - Upload date (formatted: "23 May 2018")
  - Action buttons (Download, Share, Delete)
  - Share status indicator
  - Public URL for shared files

### Forms
- User-friendly signup/login forms
- Validation error display
- Profile editing with current data

## 🚀 Production Considerations

### File Storage
- Current implementation stores files locally
- For production, consider cloud storage integration
- File size limits and validation needed

### Performance
- Database indexing on frequently queried fields
- File upload progress indicators
- Pagination for large file lists

### Security Enhancements
- Rate limiting for login attempts
- File type validation
- Virus scanning for uploads
- HTTPS enforcement

## 📝 Implementation Details

### Manual Authentication
No Devise or bcrypt gems used. Custom implementation includes:
- Password complexity validation
- Secure password hashing
- Session management
- Authentication helpers

### Manual File Storage
No ActiveStorage or CarrierWave. Custom implementation:
- Direct file system storage
- User-specific directories
- Original filename preservation
- Secure file serving

### Testing Strategy
Comprehensive RSpec tests without factory_bot or faker:
- Manual test data creation
- Full controller and model coverage
- Integration-style testing

## 🏆 Requirements Compliance

✅ **Ruby 2.6.6** - Specified version
✅ **Rails 6.0.3.6** - Specified version  
✅ **No External Gems** - Only RSpec for testing
✅ **Manual Authentication** - OpenSSL password hashing
✅ **Manual File Storage** - No ActiveStorage
✅ **RSpec Testing** - Comprehensive test suite
✅ **All Features** - Complete implementation per specifications

## 👨‍💻 Development Notes

This application demonstrates:
- Building Rails apps without common gems
- Manual implementation of authentication
- Custom file handling
- Comprehensive testing practices
- Clean, maintainable code structure

The codebase serves as an excellent learning resource for understanding Rails fundamentals without the abstraction of popular gems.

# FileManager Application

## Overview
FileManager is a simple Ruby web application for uploading, managing, and sharing files. It uses a custom authentication system, manual file storage, and a minimal SQLite database. No external gems are used except for RSpec in tests.

---

## Endpoints

### Authentication & User Management

- **GET /** or **GET /login**
  - Shows the login page. If a user is already logged in, redirects to dashboard.
  - Error messages are shown if login fails.

- **POST /login**
  - Authenticates user credentials. On success, sets a session cookie and redirects to dashboard. On failure, redirects back to login with an error.

- **GET /signup**
  - Shows the signup page for new users.

- **POST /signup**
  - Creates a new user if all validations pass. On success, logs in the user and redirects to dashboard. On failure, redirects back to signup with an error.

- **GET /logout**
  - Logs out the user by clearing the session cookie and redirects to login with a message.

### Dashboard & File Management

- **GET /dashboard**
  - Shows the dashboard for the logged-in user. Lists all uploaded files, allows upload, download, share/unshare, and delete actions. Shows success/error messages as needed.

- **POST /upload**
  - Handles file upload. Stores the file in a user-specific directory, creates a database record, and redirects to dashboard with a success or error message.

- **GET /files/:id/download**
  - Downloads the file with the given ID if it belongs to the logged-in user. If not found or not owned, redirects to dashboard with an error.

- **GET /files/:id/share**
  - Marks the file as public (shared) in the database. Generates a share token if not present. Redirects to dashboard with a message.

- **GET /files/:id/unshare**
  - Marks the file as private (unshared) in the database. Redirects to dashboard with a message.

- **GET /files/:id/delete**
  - Deletes the file from disk and database if it is not shared. Redirects to dashboard with a message. Shared files must be unshared before deletion.

### Public File Sharing

- **GET /shared/:share_token**
  - Shows a public page for the shared file, including file info and a download link. Only works if the file is public and the token is valid. Otherwise, shows a 404 error page.

- **GET /shared/:share_token/download**
  - Downloads the shared file if the token is valid and the file is public. Otherwise, returns a 404 error.

---

## Database Structure

### users Table
| Column         | Type    | Description                       |
|---------------|---------|-----------------------------------|
| id            | INTEGER | Primary key, auto-increment       |
| username      | TEXT    | Unique username                   |
| email         | TEXT    | Unique email                      |
| name          | TEXT    | Full name                         |
| password_hash | TEXT    | SHA256 hash of password+salt      |
| password_salt | TEXT    | Random salt for password hashing  |
| created_at    | TEXT    | Timestamp                         |
| updated_at    | TEXT    | Timestamp                         |

### uploaded_files Table
| Column      | Type    | Description                                 |
|-------------|---------|---------------------------------------------|
| id          | INTEGER | Primary key, auto-increment                 |
| filename    | TEXT    | Original file name                          |
| filepath    | TEXT    | Path to file on disk                        |
| uploaded_at | TEXT    | Timestamp                                   |
| public      | INTEGER | 1 if shared, 0 if private                   |
| share_token | TEXT    | Unique token for public sharing             |
| user_id     | INTEGER | Foreign key to users.id                     |
| created_at  | TEXT    | Timestamp                                   |
| updated_at  | TEXT    | Timestamp                                   |

---

## What Happens When Endpoints Are Triggered

### User Signup
- Validates all fields (name, username, email, password complexity).
- Checks for unique username and email.
- Hashes password with a random salt.
- Inserts a new row in `users` table.
- Logs in the user and sets a session cookie.

### User Login
- Looks up user by username.
- Verifies password by hashing input with stored salt and comparing to stored hash.
- On success, sets a session cookie.

### File Upload
- Validates file presence and content.
- Saves file to `storage/:user_id/` directory with a unique name.
- Inserts a new row in `uploaded_files` table with `public=0` and a random `share_token`.

### File Download (User)
- Checks file ownership and existence.
- Serves file as a download if valid.

### File Share
- Sets `public=1` for the file in `uploaded_files`.
- The file can now be accessed via its `share_token`.

### File Unshare
- Sets `public=0` for the file in `uploaded_files`.
- The file is no longer accessible via its `share_token`.

### File Delete
- Only allowed if `public=0` (not shared).
- Deletes file from disk and removes row from `uploaded_files`.

### Public File View
- Looks up file by `share_token` and `public=1`.
- If found, shows file info and download link. Otherwise, shows 404.

### Public File Download
- Looks up file by `share_token` and `public=1`.
- If found, serves file as download. Otherwise, returns 404.

---

## Notes
- All timestamps are stored as text (ISO8601 format).
- All file actions are protected by session except public sharing endpoints.
- No external gems are used except for RSpec in tests.
- All file paths are relative to the app root and stored in the database.

---

For any questions or issues, please contact the maintainer.
