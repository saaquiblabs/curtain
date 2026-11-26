// Day or night (#41): what each look-dependent element gets, with and without a kept choice.
// The page itself (a kept choice before first paint, pictures following it) is checked in a real
// browser by tests/verify.mjs.
import { test } from "node:test";
import assert from "node:assert/strict";
import { mediaFor, choiceOf, bootScript, KEY } from "../src/theme.mjs";

test("with nothing chosen, each element keeps its own prefers-color-scheme query", () => {
  assert.equal(mediaFor("dark", null), "(prefers-color-scheme: dark)");
  assert.equal(mediaFor("light", null), "(prefers-color-scheme: light)");
});

test("a choice turns the matching look on and the other off, whatever the Mac says", () => {
  assert.equal(mediaFor("dark", "dark"), "all");
  assert.equal(mediaFor("light", "dark"), "not all");
  assert.equal(mediaFor("light", "light"), "all");
  assert.equal(mediaFor("dark", "light"), "not all");
});

test("only light and dark count as a choice", () => {
  assert.equal(choiceOf("light"), "light");
  assert.equal(choiceOf("dark"), "dark");
  for (const v of [null, "", "auto", "Dark", "null"]) assert.equal(choiceOf(v), null);
  assert.equal(mediaFor("dark", "auto"), "(prefers-color-scheme: dark)");
});

test("the inline script is one self-contained expression", () => {
  assert.doesNotThrow(() => new Function(bootScript));
  assert.ok(bootScript.includes(JSON.stringify(KEY)));
});

test("everything that reads light or dark from the Mac also obeys the lamp", async () => {
  const { readFileSync, readdirSync } = await import("node:fs");
  const dir = new URL("../src/", import.meta.url);
  const files = readdirSync(dir, { recursive: true }).filter((f) => /\.(astro|css)$/.test(f));
  for (const f of files) {
    const text = readFileSync(new URL(f, dir), "utf8");
    for (const m of text.matchAll(/prefers-color-scheme:\s*(light|dark)\)?(.{0,80})/g)) {
      const line = m[0];
      // An element's media query: it must carry data-scheme for theme.mjs to set it.
      if (/media="\(prefers-color-scheme/.test(text.slice(m.index - 7, m.index + 1)) || line.includes('"')) {
        assert.ok(line.includes(`data-scheme="${m[1]}"`), `${f}: ${line.trim()} needs data-scheme="${m[1]}"`);
      } else {
        // A CSS rule: night only while the visitor hasn't chosen day.
        assert.ok(line.includes(":root:not([data-theme=light])"), `${f}: ${line.trim()} must also check :root:not([data-theme=light])`);
      }
    }
  }
});
