// Curtain's page, curtain.saaquiblabs.com: Astro static output, no UI framework. Set up like D-Tox's
// (../d-tox/site/astro.config.mjs, itself from the saaquiblabs studio site).
import { defineConfig } from "astro/config";
import sitemap from "@astrojs/sitemap";

export default defineConfig({
  site: "https://curtain.saaquiblabs.com",
  output: "static",
  // Pages are addressed as the site links them: /privacy, not /privacy/. Canonical tags, the
  // sitemap and Openship's routing (cleanUrls, trailingSlash false) agree.
  trailingSlash: "never",
  // Styles go inline in each page (they are small), so no stylesheet blocks the first paint.
  build: { format: "directory", inlineStylesheets: "always" },
  // Every page except the 404 page.
  integrations: [sitemap({ filter: (url) => !/\/404\/?$/.test(url) })],
});
