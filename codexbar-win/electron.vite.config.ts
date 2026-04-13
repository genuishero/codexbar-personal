import { resolve } from 'path';
import { defineConfig } from 'electron-vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  main: {
    build: {
      outDir: 'dist',
      rollupOptions: {
        input: resolve(__dirname, 'src/main/index.ts'),
        output: {
          entryFileNames: 'main.js'
        }
      }
    }
  },
  preload: {
    build: {
      outDir: 'dist',
      rollupOptions: {
        input: resolve(__dirname, 'src/main/preload.ts'),
        output: {
          entryFileNames: 'preload.js'
        }
      }
    }
  },
  renderer: {
    plugins: [react()],
    build: {
      outDir: 'dist/renderer'
    }
  }
});