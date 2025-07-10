# Load the Rails application.
require_relative "application"

APP_CONFIG = YAML.load_file(Rails.root.join('config/config.yml')) || {}
APP_CONFIG['bots'] = {}
APP_CONFIG['bot_dirs'].each do |bot_dir|
  ecosystem_config = "#{bot_dir}/ecosystem.config.js"
  bot_name = `node -e "console.log(require(\\\"#{ecosystem_config}\\\").apps[0].name)"`.strip
  if bot_name.nil? || bot_name.empty? || bot_name.match?(/[^a-zA-Z0-9_\-]/)
    abort("Invalid or missing BOT_NAME: #{bot_name.inspect}")
  end
  APP_CONFIG['bots'][bot_name] = { bot_dir: bot_dir, ecosystem_config: ecosystem_config }
end

APP_CONFIG['pm2_iface'] = Rails.root.join('lib/pm2_iface/pm2_iface.js')
APP_CONFIG['pm2_iface_sock'] = "/tmp/pm2_iface.sock"

# Initialize the Rails application.
Rails.application.initialize!
