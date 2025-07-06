const net = require('net');
const pm2 = require('pm2');
const fs = require('fs');

const SOCKET_PATH = process.env.SOCKET_PATH;

if (!SOCKET_PATH) {
  console.error('SOCKET_PATH environment variable is not defined.');
  process.exit(1);
}

if (fs.existsSync(SOCKET_PATH)) {
  fs.unlinkSync(SOCKET_PATH);
}

pm2.connect(function(err) {
  if (err) {
    console.error('Failed to connect to pm2 daemon:', err);
    process.exit(2);
  }
  console.log('Connected to pm2 daemon');

  const server = net.createServer((conn) => {
    pm2.list((err, list) => {
      if (err) {
        conn.write(JSON.stringify({ error: err.message }));
      } else {
        conn.write(JSON.stringify(list));
      }
      conn.end();
    });
  });

  server.listen(SOCKET_PATH, () => {
    console.log(`PM2 iface server listening on ${SOCKET_PATH}`);
  });
});
