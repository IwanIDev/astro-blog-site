// @ts-check

import tailwindcss from "@tailwindcss/vite"
import { defineConfig } from "astro/config"
import react from "@astrojs/react"

// https://astro.build/config
export default defineConfig({
  compressHTML: true,
  vite: {
    plugins: [tailwindcss()],
    optimizeDeps: {
      exclude: ['astro/virtual-modules/prefetch.js']
    }
  },
  integrations: [react()],
  prefetch: true,
  site: "https://www.iwaningman.com",
})
