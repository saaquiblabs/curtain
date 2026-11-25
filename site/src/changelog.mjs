// The /changelog page is ../CHANGELOG.md itself, read at build time, so the page and the file can't
// drift. Reads the shapes that file uses: `## 0.5.0 — 2026-11-25`, intro paragraphs, `- ` items
// wrapped over several lines, **bold**, `code` and #25-style issue numbers (linked). An item's bold
// opening is its headline (`lead`) and the rest its detail (`rest`): the page folds them, as
// openship.io's changelog does. Tested in tests/changelog.test.mjs.
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
const escape = (s) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

/** One line of Markdown to HTML: code first (nothing inside it is touched), then bold, then issues. */
export function inline(text, repo) {
  return text
    .split(/(`[^`]+`)/)
    .map((part) => part.startsWith("`") && part.endsWith("`")
      ? `<code>${escape(part.slice(1, -1))}</code>`
      : escape(part)
          .replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>")
          .replace(/#(\d+)\b/g, `<a href="${repo}/issues/$1">#$1</a>`))
    .join("");
}

/** @returns {{version: string, iso: string, date: string, intro: string[], items: {lead: string, rest: string}[]}[]} */
export function parseChangelog(markdown, repo) {
  const versions = [];
  let current, block = [], kind;

  const flush = () => {
    if (current && kind && block.length) {
      const text = block.join(" ").replace(/\s+/g, " ").trim();
      if (kind === "para") current.intro.push(inline(text, repo));
      else {
        const m = text.match(/^\*\*(.+?)\*\*\s*(.*)$/);
        current.items.push(m ? { lead: inline(m[1], repo), rest: inline(m[2], repo) } : { lead: "", rest: inline(text, repo) });
      }
    }
    block = []; kind = undefined;
  };

  for (const line of markdown.split("\n")) {
    const head = line.match(/^## (\S+) — (\d{4})-(\d{2})-(\d{2})/);
    if (head) {
      flush();
      const [, version, y, m, d] = head;
      current = { version, iso: `${y}-${m}-${d}`, date: `${+d} ${months[+m - 1]} ${y}`, intro: [], items: [] };
      versions.push(current);
    } else if (line.startsWith("- ")) {
      flush(); kind = "item"; block.push(line.slice(2));
    } else if (!line.trim()) {
      flush();
    } else if (current && !line.startsWith("#")) {
      kind ??= "para";
      block.push(line.trim());
    }
  }
  flush();
  return versions;
}

/** The repo's CHANGELOG.md. Astro runs from site/ (dev, build, Openship's rootDirectory). */
export const readChangelog = (repo) => parseChangelog(readFileSync(resolve(process.cwd(), "../CHANGELOG.md"), "utf8"), repo);
