import { defineConfig } from "astro/config";
import tailwindcss from "@tailwindcss/vite";

export default defineConfig({
  site: "https://remotekube.patrykgolabek.dev",
  vite: {
    plugins: [tailwindcss()],
  },
});
