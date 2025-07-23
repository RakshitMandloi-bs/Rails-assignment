Rails.application.configure do
  config.cache_classes = true
  config.eager_load = true
  config.consider_all_requests_local = false
  config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].present?
  config.force_ssl = false
  config.log_level = :info
  config.log_tags = [ :request_id ]
  config.cache_store = :memory_store
  config.active_record.dump_schema_after_migration = false
end
