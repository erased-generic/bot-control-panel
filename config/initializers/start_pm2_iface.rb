Thread.new do
  `NODE_PATH=$(npm root -g) SOCKET_PATH=#{APP_CONFIG['pm2_iface_sock']} node #{APP_CONFIG['pm2_iface']}`
end
