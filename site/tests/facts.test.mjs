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
