unless Rake.application.top_level_tasks.include?('assets:precompile')
  Thread.new do
    `NODE_PATH=$(npm root -g) SOCKET_PATH=#{APP_CONFIG['pm2_iface_sock']} node #{APP_CONFIG['pm2_iface']}`
  end
end
