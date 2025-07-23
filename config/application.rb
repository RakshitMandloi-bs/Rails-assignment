require_relative 'boot'

require 'rails/all'

Bundler.require(*Rails.groups)

module FileSharingApp
  class Application < Rails::Application
    config.load_defaults 6.0
    
    # Disable Active Storage since we're handling files manually
    config.active_storage.variant_processor = nil
    
    # Session configuration
    config.session_store :cookie_store, key: '_file_sharing_app_session'
    
    # Skip generators we don't need
    config.generators do |g|
      g.assets false
      g.helper false
      g.test_framework :rspec
    end
  end
end
