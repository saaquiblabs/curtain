// Each page's title and description, so the head and the pages can't drift (shape from D-Tox's site).
import { name, origin, promise } from "./site";

export interface PageMeta {
  /** Page name; the home page has none. The <title> reads `Title — Curtain`. */
  title?: string;
  description: string;
}

export const pages = {
  "/": {
    description: `${promise} Curtain switches any screen off in half a second and back on, sets every monitor's brightness, and lives in your Mac's menu bar. Free, open source, sends nothing anywhere.`,
  },
  "/privacy": {
    title: "Privacy",
    description: `${name} collects nothing and sends nothing anywhere. Its settings stay on your Mac. What this site counts, and how.`,
  },
  "/changelog": {
    title: "What’s new",
    description: `Every version of ${name}, newest first.`,
  },
} satisfies Record<string, PageMeta>;

export const urlOf = (path: string) => origin + path;
