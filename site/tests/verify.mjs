// The launch gate, ported from D-Tox's site/tests/verify.mjs (itself from the saaquiblabs studio
// site, saaquiblabs ADR 0014): link check + Lighthouse with the studio's budgets, on the built site.
// `npm run verify` runs the unit tests, builds, then runs this; the git pre-push hook runs it
// (.githooks/pre-push). The Openship deploy runs `npm run verify:deploy` (`--links`): the same minus
// Lighthouse, no Chrome, so a deploy takes about two minutes (as D-Tox's #55, from the studio site's
// #89). Keep every budget here.
//
// Budgets: Lighthouse 100 in all four categories, page JS < 50 KB, page < 400 KB. Bytes are what the
// page loads, measured uncompressed (the local server doesn't gzip), so the live page is lighter.
//
// Chrome: CHROME_PATH, else Playwright's Chromium (`npx playwright install chromium`).
import { readFile, readdir, access } from "node:fs/promises";
import { join, relative } from "node:path";
import { serve, dist } from "./serve.mjs";

const origin = "https://curtain.saaquiblabs.com";
const budget = { score: 1, js: 50_000, page: 400_000 };
// Lighthouse never reaches the real Umami: no counted visits, no third party in the numbers.
const blocked = ["*analytics.saaquiblabs.com*"];
const problems = [];
const kb = (n) => `${(n / 1000).toFixed(1)} KB`;

const server = await serve();
const { base } = server;

// Every page the sitemap lists (astro.config.mjs: every page but the 404).
const sitemap = await readFile(join(dist, "sitemap-0.xml"), "utf8");
const listed = [...sitemap.matchAll(/<loc>([^<]+)<\/loc>/g)].map((m) => new URL(m[1]).pathname);
// `node tests/verify.mjs / /privacy` runs Lighthouse on those pages only (for debugging; the gate runs all).
// `--links` (the deploy): the link check only.
const linksOnly = process.argv.includes("--links");
const args = process.argv.slice(2).filter((a) => a !== "--links");
const pages = args.length ? args : listed;
if (!listed.length) problems.push("sitemap lists no pages");

// --- Links: every href/src/srcset in every built HTML file, internal and external. ---
async function htmlFiles(dir) {
  const out = [];
  for (const e of await readdir(dir, { withFileTypes: true })) {
    const p = join(dir, e.name);
    if (e.isDirectory()) out.push(...(await htmlFiles(p)));
    else if (e.name.endsWith(".html")) out.push(p);
  }
  return out;
}

const links = new Map(); // url → first page that uses it
for (const file of await htmlFiles(dist)) {
  const rel = "/" + relative(dist, file).replace(/(^|\/)index\.html$/, "").replace(/\.html$/, "");
  const html = await readFile(file, "utf8");
  const found = [
    ...[...html.matchAll(/\s(?:href|src)="([^"]*)"/g)].map((m) => m[1]),
    ...[...html.matchAll(/\ssrcset="([^"]*)"/g)].flatMap((m) => m[1].split(",").map((s) => s.trim().split(/\s+/)[0])),
    ...[...html.matchAll(/<meta[^>]+content="(https?:\/\/[^"]+)"/g)].map((m) => m[1]),
  ];
  for (const raw of found) {
    const v = raw.replaceAll("&amp;", "&");
    if (!v || /^(mailto:|tel:|data:|#|javascript:)/.test(v)) continue;
    let u = new URL(v, origin + rel);
    if (u.origin === origin) u = new URL(u.pathname + u.search, base); // ours: check the build, not the live site
    u.hash = "";
    if (!links.has(u.href)) links.set(u.href, rel);
  }
}

async function ok(url) {
  for (let attempt = 0; attempt < 2; attempt++) {
    try {
      const r = await fetch(url, { redirect: "follow", signal: AbortSignal.timeout(15_000), headers: { "user-agent": "Mozilla/5.0 (link check)" } });
      if (r.status < 400) return null;
      if (attempt) return String(r.status);
    } catch (e) {
      if (attempt) return e.cause?.code ?? e.name;
    }
  }
}
const queue = [...links];
await Promise.all(Array.from({ length: 8 }, async () => {
  for (let item; (item = queue.shift()); ) {
    const [url, page] = item;
    const bad = await ok(url);
    if (bad) problems.push(`link: ${url.replace(base, "")} on ${page}: ${bad}`);
  }
}));
console.log(`verify: ${links.size} links checked`);

if (linksOnly) {
  server.close();
  if (problems.length) {
    console.error(`verify: ${problems.length} problem(s)\n  ` + problems.join("\n  "));
    process.exit(1);
  }
  console.log("verify: ok (links only; Lighthouse runs before each push)");
  process.exit(0);
}

const { default: lighthouse } = await import("lighthouse");
const { default: desktop } = await import("lighthouse/core/config/desktop-config.js");
const { launch } = await import("chrome-launcher");
const { default: pw } = await import("playwright");

const chromePath = process.env.CHROME_PATH ?? pw.chromium.executablePath();
if (!(await access(chromePath).then(() => true, () => false))) {
  console.error(`verify: no Chrome at ${chromePath}. Run \`npx playwright install chromium\` or set CHROME_PATH.`);
  process.exit(1);
}

// --- Day or night (#41): the pull cord under the header switches the page, and the choice is kept. ---
{
  const browser = await pw.chromium.launch({ executablePath: chromePath });
  const fail = (what) => problems.push(`lamp: ${what}`);
  try {
    const ctx = await browser.newContext({ colorScheme: "light", viewport: { width: 1280, height: 800 } });
    const page = await ctx.newPage();
    const errors = [];
    page.on("pageerror", (e) => errors.push(e.message));
    const look = () => page.evaluate(() => ({
      theme: document.documentElement.dataset.theme ?? null,
      bg: getComputedStyle(document.body).backgroundColor,
      hero: document.querySelector("main picture img")?.currentSrc ?? "",
      checked: document.querySelector("[data-lamp] [role=switch]")?.getAttribute("aria-checked"),
      live: !!document.querySelector("[data-lamp] .pc"),
    }));
    await page.goto(base + "/");
    let s = await look();
    if (s.theme !== null || s.checked !== "true" || s.live) fail(`on load (Mac light): want day, the still, nothing chosen; got ${JSON.stringify(s)}`);
    // Before the lamp arrives, the still switches too (a bare click: no move or focus to fetch the lamp first).
    await page.evaluate(() => document.querySelector(".lamp-still").click());
    await page.waitForFunction(() => document.querySelector("[data-lamp] .pc"));
    // The drapes close, the page switches behind them, they open again.
    await page.waitForFunction(() => document.documentElement.dataset.theme === "dark", null, { timeout: 3000 }).catch(() => {});
    await page.waitForFunction(() => !document.querySelector(".sweep"), null, { timeout: 3000 }).catch(() => {});
    s = await look();
    if (s.theme !== "dark" || s.bg !== "rgb(25, 28, 39)" || !s.hero.includes("-dark") || s.checked !== "false" || !s.live)
      fail(`still pressed: want night with the live lamp; got ${JSON.stringify(s)}`);
    // The live cord: a click on it pulls; the switch clicks a moment later, then the drapes sweep.
    const box = await page.locator("[data-lamp]").boundingBox();
    await page.mouse.click(box.x + box.width / 2, box.y + 40);
    await page.waitForFunction(() => document.documentElement.dataset.theme === "light", null, { timeout: 3000 }).catch(() => {});
    s = await look();
    if (s.theme !== "light" || !s.hero.includes("-light") || s.checked !== "true") fail(`lamp pulled: want day; got ${JSON.stringify(s)}`);
    // And Space, from the keyboard, once the cord is back (a pull mid-pull is ignored, as by a hand).
    await page.waitForTimeout(600);
    await page.locator("[data-lamp] .pc").focus();
    await page.keyboard.press("Space");
    await page.waitForFunction(() => document.documentElement.dataset.theme === "dark", null, { timeout: 3000 }).catch(() => {});
    // Every way a hand presses the cord switches exactly once: a tap, a firm click held still, one
    // that drifts a few pixels (a trackpad's press does). Before this check, only the tap did.
    await page.waitForTimeout(800);
    await page.evaluate(() => { window.switches = 0; document.querySelector("[data-lamp] .pc").addEventListener("change", () => window.switches++); });
    const grip = await page.locator("[data-lamp] .pc-grip").boundingBox();
    const gx = grip.x + grip.width / 2, gy = grip.y + grip.height / 2;
    for (const [how, hold, dx, dy] of [["tap", 60, 0, 0], ["held click", 400, 0, 0], ["drifting sideways", 150, 3, 0], ["drifting up", 150, 0, -3]]) {
      await page.evaluate(() => (window.switches = 0));
      await page.mouse.move(gx, gy);
      await page.mouse.down();
      await page.waitForTimeout(hold);
      if (dx || dy) await page.mouse.move(gx + dx, gy + dy, { steps: 3 });
      await page.mouse.up();
      await page.waitForTimeout(1800); // the pull, then the drapes' sweep
      const n = await page.evaluate(() => window.switches);
      if (n !== 1) fail(`a ${how} on the acorn switched ${n} times, want once`);
    }
    // Kept across a reload and other pages, whatever the Mac says, with no flash of day.
    await page.goto(base + "/changelog");
    s = await look();
    if (s.theme !== "dark" || s.bg !== "rgb(25, 28, 39)" || s.checked !== "false") fail(`night kept on /changelog; got ${JSON.stringify(s)}`);
    await page.goto(base + "/");
    s = await look();
    if (!s.hero.includes("-dark")) fail(`night kept on /: hero picture ${s.hero}`);
    if (errors.length) fail(`page errors: ${errors.join("; ")}`);
    await ctx.close();
  } finally {
    await browser.close();
  }
  console.log("verify: lamp checked (still, pull, kept across pages)");
}

// --- Lighthouse, phone and desktop, every page. ---
// --disable-dev-shm-usage: the Openship build runs in Docker, whose /dev/shm is 64 MB; Chrome
// crashed every page there (TARGET_CRASHED) until it wrote to /tmp instead (#48).
const chrome = await launch({
  chromePath,
  chromeFlags: ["--headless=new", "--no-sandbox", "--disable-dev-shm-usage"],
});
const audit = async (url, config) =>
  (await lighthouse(url, { port: chrome.port, logLevel: "error", blockedUrlPatterns: blocked }, config)).lhr;
// Inline <script> bytes: Lighthouse lists only script files, but inline JS is JS too (JSON-LD is data).
const inlineJs = async (path) =>
  [...(await (await fetch(base + path)).text()).matchAll(/<script(?![^>]*\bsrc=)(?![^>]*application\/ld\+json)[^>]*>([\s\S]*?)<\/script>/g)]
    .reduce((n, m) => n + Buffer.byteLength(m[1]), 0);
try {
  // The first run in a fresh Chrome is slow (measured: home on phone 91, then 100 every time after).
  await audit(base + "/");
  for (const path of pages) {
    for (const [form, config] of [["phone", undefined], ["desktop", desktop]]) {
      const tag = `${path} ${form}`;
      let lhr = await audit(base + path, config);
      // Performance is timing, so it wobbles; one more run before calling it a failure. The other
      // three categories are deterministic and never get a second try.
      const others = (l) => Object.values(l.categories).every((c) => c.id === "performance" || c.score >= budget.score);
      if (!lhr.runtimeError && lhr.categories.performance.score < budget.score && others(lhr)) {
        console.log(`verify: ${tag}: performance ${Math.round(lhr.categories.performance.score * 100)}, running again`);
        lhr = await audit(base + path, config);
      }
      if (lhr.runtimeError) { problems.push(`${tag}: Lighthouse: ${lhr.runtimeError.code}`); continue; }
      const scores = Object.values(lhr.categories).map((c) => [c.id, Math.round(c.score * 100)]);
      for (const c of Object.values(lhr.categories)) {
        if (c.score >= budget.score) continue;
        const failing = c.auditRefs
          .filter((r) => r.weight > 0 && lhr.audits[r.id].score !== null && lhr.audits[r.id].score < 1)
          .map((r) => r.id + (lhr.audits[r.id].displayValue ? ` (${lhr.audits[r.id].displayValue})` : ""));
        problems.push(`${tag}: ${c.id} ${Math.round(c.score * 100)}, want 100: ${failing.join(", ") || "see the report"}`);
      }
      const reqs = lhr.audits["network-requests"].details?.items ?? [];
      const js = reqs.filter((r) => r.resourceType === "Script").reduce((n, r) => n + r.transferSize, 0) + (await inlineJs(path));
      const all = reqs.reduce((n, r) => n + r.transferSize, 0);
      if (js >= budget.js) problems.push(`${tag}: ${kb(js)} of JS, want < ${kb(budget.js)}`);
      if (all >= budget.page) problems.push(`${tag}: page ${kb(all)}, want < ${kb(budget.page)}`);
      console.log(`verify: ${tag.padEnd(22)} ${scores.map(([id, s]) => `${id} ${s}`).join(" · ")} · JS ${kb(js)} · page ${kb(all)}`);
    }
  }
} finally {
  await chrome.kill();
  server.close();
}

if (problems.length) {
  console.error(`verify: ${problems.length} problem(s)\n  ` + problems.join("\n  "));
  process.exit(1);
}
console.log(`verify: ok (${pages.length} pages × phone + desktop)`);
