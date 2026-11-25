// Every link and fact the pages share, in one place so the header, footer and pages can't drift.
// Pattern ported from D-Tox's site/src/site.ts.
export interface Link {
  label: string;
  href: string;
}

export const name = "Curtain";
export const promise = "Turn a screen off. Its windows stay.";
export const origin = "https://curtain.saaquiblabs.com";

export const brew = "brew install saaquiblabs/tap/curtain";
export const repo = "https://github.com/saaquiblabs/curtain";
export const email = "hello@saaquiblabs.com";
export const mailto = `mailto:${email}`;
export const studio: Link = { label: "Saaquib Labs", href: "https://saaquiblabs.com" };
export const needs = "macOS 13 Ventura or newer";

/** Self-hosted Umami (saaquiblabs ADR 0007), cookieless. The tag stays out until `websiteId` is
 * filled in (a [HUMAN] step: make the website in analytics.saaquiblabs.com). */
export const analytics = {
  src: "https://analytics.saaquiblabs.com/script.js",
  websiteId: "",
  domains: "curtain.saaquiblabs.com",
};
