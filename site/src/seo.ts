// Each page's title and description, so the head and the pages can't drift.
import { name, origin } from "./site";

export interface PageMeta {
  /** Page name; the home page has none. The <title> reads `Title — Curtain`. */
  title?: string;
  description: string;
}

export const pages = {
  "/": {
    description: `${name} sits in your Mac's menu bar. Switch any screen off in half a second with its windows where they are, set every screen's real brightness, and press ⌃⌥C to darken every screen but yours. Free, open source, sends nothing.`,
  },
  "/privacy": {
    title: "Privacy",
    description: `${name} collects nothing and sends nothing anywhere: it has no network code at all. What it keeps on your Mac, and what this site counts.`,
  },
  "/changelog": {
    title: "What’s new",
    description: `Every version of ${name}, newest first.`,
  },
} satisfies Record<string, PageMeta>;

export const urlOf = (path: string) => origin + path;
