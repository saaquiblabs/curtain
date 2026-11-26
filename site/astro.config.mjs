// Curtain's page, curtain.saaquiblabs.com: Astro static output, no UI framework. Ported from
// D-Tox's site/astro.config.mjs (itself from the saaquiblabs studio site).
import { defineConfig } from "astro/config";
import sitemap from "@astrojs/sitemap";

export default defineConfig({
  site: "https://curtain.saaquiblabs.com",
  output: "static",
  // No dev toolbar: the local preview should look like the live page.
  devToolbar: { enabled: false },
  // Pages are addressed as the site links them: /privacy, not /privacy/.
  trailingSlash: "never",
  // Styles go inline in each page (they are small), so no stylesheet blocks the first paint.
  build: { format: "directory", inlineStylesheets: "always" },
  cacheDir: "./.turbo/cache/astro",
  // Keep /*! … */ licence comments in the bundles: the header lamp is MIT code (src/lamp, #41).
  vite: { build: { rolldownOptions: { output: { comments: { legal: true } } } } },
  // Every page except the 404 page.
  integrations: [sitemap({ filter: (url) => !/\/404\/?$/.test(url) })],
});
