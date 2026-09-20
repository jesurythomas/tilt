import { createServer } from 'vite';

async function start() {
  const server = await createServer({
    root: process.cwd(),
    server: {
      port: 5173,
      host: '0.0.0.0'
    }
  });

  await server.listen();
  console.log('Persistent server listening on port 5173');
  server.printUrls();

  setInterval(() => {}, 60000);
}

start().catch((err) => {
  console.error('Failed to start server:', err);
  process.exit(1);
});
