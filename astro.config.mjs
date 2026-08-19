// @ts-check

import tailwindcss from "@tailwindcss/vite"
import { defineConfig } from "astro/config"
import react from "@astrojs/react"

import sitemap from "@astrojs/sitemap";

// https://astro.build/config
export default defineConfig({
  compressHTML: true,
  vite: {
    plugins: [tailwindcss()],
    optimizeDeps: {
      exclude: ['astro/virtual-modules/prefetch.js']
    }
  },
  integrations: [react(), sitemap()],
  prefetch: true,
  site: "https://www.iwaningman.com",
})