# Load the Rails application.
require_relative "application"

APP_CONFIG = YAML.load_file(Rails.root.join('config/config.yml')) || {}
ecosystem_config = "#{APP_CONFIG['bot_dir']}/ecosystem.config.js"
APP_CONFIG['ecosystem_config'] = ecosystem_config
bot_name = `node -e "console.log(require(\\\"#{ecosystem_config}\\\").apps[0].name)"`.strip
if bot_name.nil? || bot_name.empty? || bot_name.match?(/[^a-zA-Z0-9_\-]/)
  abort("Invalid or missing BOT_NAME: #{bot_name.inspect}")
end
APP_CONFIG['bot_name'] = bot_name

# Initialize the Rails application.
Rails.application.initialize!
