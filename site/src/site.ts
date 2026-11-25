// Every link and fact the pages share, in one place so the header, footer and pages can't drift.
// Pattern ported from D-Tox's site/src/site.ts. tests/facts.test.mjs checks the install command
// against the README's.
export interface Link {
  label: string;
  href: string;
}

export const name = "Curtain";
export const promise = "Turn off a screen. Its windows stay.";
export const origin = "https://curtain.saaquiblabs.com";

export const repo = "https://github.com/saaquiblabs/curtain";
/** The one install people copy (owner's pick on #42: Homebrew first; no download until notarized). */
export const brew = "brew install saaquiblabs/tap/curtain";
export const source: Link = { label: "Build from source", href: `${repo}#install` };
export const email = "hello@saaquiblabs.com";
export const mailto = `mailto:${email}`;
export const studio: Link = { label: "Saaquib Labs", href: "https://saaquiblabs.com" };
export const needs = "macOS 13 Ventura or newer";

export const footer: Link[] = [
  { label: "Privacy", href: "/privacy" },
  { label: "What’s new", href: "/changelog" },
  { label: "GitHub", href: repo },
];

/** Self-hosted Umami (as D-Tox), cookieless. One website per site in analytics.saaquiblabs.com.
 * `domains` keeps local builds, previews and the checks from counting. The tag is left out until
 * `websiteId` is filled in (a [HUMAN] step in site/README.md). */
export const analytics = {
  src: "https://analytics.saaquiblabs.com/script.js",
  websiteId: "",
  domains: "curtain.saaquiblabs.com",
};
