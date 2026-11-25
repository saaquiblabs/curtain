// The /changelog page is CHANGELOG.md itself, read at build time (src/changelog.mjs), so the
// page and the file can't drift. These pin how the file's few shapes turn into the page.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { parseChangelog, inline } from "../src/changelog.mjs";

const repo = "https://github.com/saaquiblabs/curtain";

test("each ## heading is a version with its date", () => {
  const md = "# Changelog\n\n## 0.5.0 — 2026-11-25\n\nIntro.\n\n## 0.4.2 — 2026-11-22\n\n- One.\n";
  const v = parseChangelog(md, repo);
  assert.deepEqual(v.map((e) => [e.version, e.iso, e.date]), [["0.5.0", "2026-11-25", "25 November 2026"], ["0.4.2", "2026-11-22", "22 November 2026"]]);
});

test("intro paragraphs and items, wrapped lines joined; a bold opening is the headline", () => {
  const md = [
    "## 0.2.0 — 2026-11-21",
    "",
    "Switching a screen off no longer",
    "blanks every screen.",
    "",
    "- **Turn off fades** to",
    "  black.",
    "- Unplug, with no headline.",
    "",
  ].join("\n");
  const [e] = parseChangelog(md, repo);
  assert.deepEqual(e.intro, ["Switching a screen off no longer blanks every screen."]);
  assert.deepEqual(e.items, [
    { lead: "Turn off fades", rest: "to black." },
    { lead: "", rest: "Unplug, with no headline." },
  ]);
});

test("inline: escapes HTML, code stays literal, issue numbers link to GitHub", () => {
  assert.equal(inline("a < b & `make **x** #4` (#20)", repo),
    `a &lt; b &amp; <code>make **x** #4</code> (<a href="${repo}/issues/20">#20</a>)`);
  assert.equal(inline("⌃⌥⌘C, #25 and #26.", repo),
    `⌃⌥⌘C, <a href="${repo}/issues/25">#25</a> and <a href="${repo}/issues/26">#26</a>.`);
});

test("the real CHANGELOG.md: every version, newest first, none empty", () => {
  const md = readFileSync(new URL("../../CHANGELOG.md", import.meta.url), "utf8");
  const v = parseChangelog(md, repo);
  assert.equal(v.length, md.match(/^## /gm).length);
  assert.equal(v.at(-1).version, "0.1.0");
  for (const e of v) {
    assert.match(e.iso, /^\d{4}-\d{2}-\d{2}$/, e.version);
    assert.ok(e.items.length, e.version);
  }
});
