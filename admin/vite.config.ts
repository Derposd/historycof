import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    // В dev запросы /api и /uploads проксируются на backend
    proxy: {
      '/api': process.env.API_PROXY ?? 'http://localhost:3000',
      '/uploads': process.env.API_PROXY ?? 'http://localhost:3000',
    },
  },
})
