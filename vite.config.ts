import { defineConfig } from 'vite';

export default defineConfig({
  server: {
    port: 5173,
    open: false,
    allowedHosts: [
      'guaranteed-paperback-bidding-largest.trycloudflare.com',
      '.trycloudflare.com',
      'ec4c-180-190-5-45.ngrok-free.app',
      '.ngrok-free.app',
    ],
  },
  build: {
    target: 'esnext',
  }
});
