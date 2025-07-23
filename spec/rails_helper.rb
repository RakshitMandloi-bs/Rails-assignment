require_relative '../config/environment'
require 'rspec/rails'

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
  
  config.before(:each) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end
end

class DatabaseCleaner
  def self.strategy=(strategy)
    # Simple implementation without gem
  end
  
  def self.start
    # Begin transaction
  end
  
  def self.clean
    # Clean up test data manually
    UploadedFile.delete_all
    User.delete_all
  end
end
