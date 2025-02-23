# Load the Rails application.
require_relative "application"

APP_CONFIG = YAML.load_file(Rails.root.join('config/config.yml')) || {}
APP_CONFIG['ecosystem_config'] = "#{APP_CONFIG['bot_dir']}/ecosystem.config.json"
APP_CONFIG['bot_name'] = JSON.parse(File.read(APP_CONFIG['ecosystem_config'])).dig('apps', 0, 'name')

# Initialize the Rails application.
Rails.application.initialize!
