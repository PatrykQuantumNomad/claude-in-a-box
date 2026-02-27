import { defineConfig } from "astro/config";
import tailwindcss from "@tailwindcss/vite";
import sitemap from "@astrojs/sitemap";

export default defineConfig({
  site: "https://remotekube.patrykgolabek.dev",
  integrations: [
    sitemap({
      filter: (page) => !page.includes("/404"),
      changefreq: "weekly",
      lastmod: new Date(),
      serialize(item) {
        if (item.url.endsWith(".dev/")) {
          item.priority = 1.0;
        } else if (item.url.endsWith("/docs/") || item.url.endsWith("/docs/getting-started/")) {
          item.priority = 0.8;
        } else {
          item.priority = 0.6;
        }
        return item;
      },
    }),
  ],
  vite: {
    plugins: [tailwindcss()],
  },
});