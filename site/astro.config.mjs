import { defineConfig } from "astro/config";
import tailwindcss from "@tailwindcss/vite";
import sitemap from "@astrojs/sitemap";

export default defineConfig({
  site: "https://remotekube.patrykgolabek.dev",
  integrations: [
    sitemap({
      filter: (page) => !page.includes("/404"),
      changefreq: "weekly",
      priority: 1.0,
      lastmod: new Date(),
    }),
  ],
  vite: {
    plugins: [tailwindcss()],
  },
});