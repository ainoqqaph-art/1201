// @ts-check
import { defineConfig } from "astro/config";
import tailwindcss from "@tailwindcss/vite";
// http://astro.build/config
export default defineConfig({vite: {
    plugins: [tailwindcss()],
  },})