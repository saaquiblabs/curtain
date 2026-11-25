// The page and the README say the same things where they overlap (#42).
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const read = (p) => readFileSync(new URL(p, import.meta.url), "utf8");
const site = read("../src/site.ts");
const readme = read("../../README.md");
const fact = (key) => site.match(new RegExp(`export const ${key} = "([^"]+)"`))?.[1];

test("the page's install command is the README's", () => {
  const brew = fact("brew");
  assert.ok(brew, "src/site.ts exports brew");
  assert.ok(readme.includes("```bash\n" + brew + "\n```"), `README shows ${brew}`);
});

test("the README links to the page", () => {
  assert.ok(readme.includes(fact("origin")), `README links ${fact("origin")}`);
});

test("the page names the macOS the README needs", () => {
  assert.ok(readme.includes(`**Needs:** ${fact("needs")}`), `README: Needs: ${fact("needs")}`);
});

test("the pages name no other apps (owner's rule on #42)", () => {
  const others = /Vorssaint|BetterDisplay|Lunar|MonitorControl|DisplayBuddy|Monitorian/i;
  for (const p of ["index", "privacy", "404"]) {
    const src = read(`../src/pages/${p}.astro`);
    assert.doesNotMatch(src, others, `${p}.astro names another app`);
  }
});

test("the page explains Turn off against Disconnect, with Lenovo's published figures", () => {
  const page = read("../src/pages/index.astro");
  assert.match(page, /id="which"/, "a Turn off or Disconnect section");
  assert.match(page, /21\.7 W/, "Lenovo's typical figure");
  assert.match(page, /0\.5 W/, "Lenovo's sleep figure");
  assert.match(page, /psref\.lenovo\.com/, "the source is linked");
});

test("links into the changelog use ?v=, not #v (no #… in URLs, owner 2026-11-25)", () => {
  for (const p of ["pages/index.astro", "pages/changelog.astro"]) {
    assert.doesNotMatch(read(`../src/${p}`), /changelog#/, `${p} builds a /changelog#… URL`);
  }
  assert.match(read("../src/layouts/Base.astro"), /history\.replaceState/, "the layout drops #… on arrival");
});
