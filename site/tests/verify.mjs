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

// --- Day or night (#41): the pull switch under the header switches the page, and the choice is kept. ---
{
  const browser = await pw.chromium.launch({ executablePath: chromePath });
  const fail = (what) => problems.push(`switch: ${what}`);
  try {
    const ctx = await browser.newContext({ colorScheme: "light", viewport: { width: 1280, height: 800 } });
    const page = await ctx.newPage();
    const errors = [];
    page.on("pageerror", (e) => errors.push(e.message));
    const look = () => page.evaluate(() => ({
      theme: document.documentElement.dataset.theme ?? null,
      bg: getComputedStyle(document.body).backgroundColor,
      hero: document.querySelector("main picture img")?.currentSrc ?? "",
      night: document.querySelector("[data-lamp]")?.getAttribute("aria-checked"),
      live: document.querySelector("[data-lamp]")?.hasAttribute("data-live"),
    }));
    // The light from the lamp: done when it has gone.
    const settled = () => page.waitForFunction(() => !document.querySelector(".light"), null, { timeout: 4000 }).catch(() => {});
    await page.goto(base + "/");
    let s = await look();
    if (s.theme !== null || s.night !== "false" || s.live) fail(`on load (Mac light): want day, nothing chosen, no motion fetched; got ${JSON.stringify(s)}`);
    // Before the motion arrives, a click switches too (a bare click: nothing fetched it first).
    await page.evaluate(() => document.querySelector("[data-lamp]").click());
    await page.waitForFunction(() => document.querySelector("[data-lamp]").hasAttribute("data-live"));
    await settled();
    s = await look();
    if (s.theme !== "dark" || s.bg !== "rgb(25, 28, 39)" || !s.hero.includes("-dark") || s.night !== "true")
      fail(`first click: want night; got ${JSON.stringify(s)}`);
    // Count every switch from here on, and follow the acorn.
    await page.evaluate(() => {
      window.switches = 0;
      new MutationObserver(() => window.switches++).observe(document.documentElement, { attributes: true, attributeFilter: ["data-theme"] });
      const acorn = document.querySelector("[data-lamp] .acorn");
      window.acornY = () => +/translate\(\S+ ([-\d.]+)\)/.exec(acorn.getAttribute("transform"))[1];
    });
    const acornAt = async () => {
      const b = await page.locator("[data-lamp] .acorn .body").boundingBox();
      return { x: b.x + b.width / 2, y: b.y + b.height / 2 };
    };
    // A press, how a hand or a trackpad makes it, then the pull and the light run their course.
    const press = async (how, { hold = 60, dx = 0, dy = 0 } = {}) => {
      const a = await acornAt();
      await page.evaluate(() => { window.switches = 0; window.lowest = 0; window.highest = 0;
        const rest = window.acornY(); const f = () => { const y = window.acornY() - rest; window.lowest = Math.max(window.lowest, y); window.highest = Math.min(window.highest, y); if (performance.now() - t0 < 1500) requestAnimationFrame(f); }; const t0 = performance.now(); f(); });
      await page.mouse.move(a.x, a.y);
      await page.mouse.down();
      await page.waitForTimeout(hold);
      if (dx || dy) await page.mouse.move(a.x + dx, a.y + dy, { steps: Math.max(3, Math.round(Math.abs(dy) / 3)) });
      await page.mouse.up();
      await page.waitForTimeout(800); // the pull, and the light from its click
      await settled();
      await page.waitForTimeout(1200);
      return page.evaluate(() => ({ switches: window.switches, down: window.lowest, up: -window.highest }));
    };
    // A click is a whole pull: the cord goes visibly down, clicks once, and is thrown back up past rest.
    for (const [how, o] of [["tap", {}], ["held click", { hold: 400 }], ["click drifting sideways", { hold: 150, dx: 3 }], ["click drifting up", { hold: 150, dy: -3 }]]) {
      const r = await press(how, o);
      if (r.switches !== 1) fail(`a ${how} on the acorn switched ${r.switches} times, want once`);
      if (r.down < 20 || r.up < 2) fail(`a ${how}: the acorn went ${r.down.toFixed(1)} px down and ${r.up.toFixed(1)} px back up past rest; want ≥ 20 and ≥ 2`);
    }
    // A real pull, by dragging, clicks once; a short tug that stops before the click doesn't.
    let r = await press("drag", { hold: 80, dy: 60 });
    if (r.switches !== 1) fail(`dragging the acorn 60 px down switched ${r.switches} times, want once`);
    r = await press("short tug", { hold: 80, dy: 10 });
    if (r.switches !== 0) fail(`a 10 px tug switched ${r.switches} times, want none`);
    // Let go where the release never reaches the switch (owner, 2026-11-26: it stayed held, taut, up
    // and to the left): it must still let go, and never be taken up above its box.
    await page.evaluate(() => document.querySelector("[data-lamp]").addEventListener("pointerup", (e) => e.stopImmediatePropagation(), true));
    {
      const a = await acornAt();
      await page.mouse.move(a.x, a.y);
      await page.mouse.down();
      await page.mouse.move(a.x - 90, a.y - 80, { steps: 12 });
      const top = await page.evaluate(() => window.acornY());
      if (top < 11) fail(`the acorn was taken up to ${top.toFixed(1)}, above the box`);
      await page.mouse.up();
      await page.waitForTimeout(400);
      await settled();
      await page.waitForTimeout(1500);
      const t = await page.evaluate(() => document.querySelector("[data-lamp] .acorn").getAttribute("transform"));
      const [, x, y] = /translate\(([-\d.]+) ([-\d.]+)\)/.exec(t);
      if (Math.abs(x - 24) > 0.5 || Math.abs(y - 65.5) > 1.5) fail(`after a release that missed the switch, the acorn is at ${x}, ${y}, not hanging at rest`);
    }
    await page.reload();
    await page.mouse.move(5, 790);
    await page.waitForFunction(() => document.querySelector("[data-lamp]").hasAttribute("data-live"));
    await page.evaluate(() => (window.acornY = () => 0));
    // Space, from the keyboard: the same pull.
    await page.locator("[data-lamp]").focus();
    await page.evaluate(() => { window.switches = 0; new MutationObserver(() => window.switches++).observe(document.documentElement, { attributes: true, attributeFilter: ["data-theme"] }); });
    await page.keyboard.press("Space");
    await page.waitForTimeout(800); // the pull, and the light from its click
    await settled();
    if ((await page.evaluate(() => window.switches)) !== 1) fail("Space didn't switch exactly once");
    // Whatever was chosen last is kept on the next page, on a light Mac, with no flash.
    const chosen = (await look()).theme;
    await page.goto(base + "/changelog");
    s = await look();
    const want = chosen === "dark" ? ["true", "rgb(25, 28, 39)"] : ["false", "rgb(250, 250, 247)"];
    if (!chosen || s.theme !== chosen || s.night !== want[0] || s.bg !== want[1]) fail(`${chosen} kept on /changelog; got ${JSON.stringify(s)}`);
    await ctx.close();
    const dark = await browser.newContext({ colorScheme: "dark", viewport: { width: 1280, height: 800 } });
    await dark.addInitScript(() => localStorage.setItem("curtain-theme", "light"));
    const p2 = await dark.newPage();
    await p2.goto(base + "/");
    const d = await p2.evaluate(() => ({ bg: getComputedStyle(document.body).backgroundColor, hero: document.querySelector("main picture img")?.currentSrc ?? "" }));
    if (d.bg !== "rgb(250, 250, 247)" || !d.hero.includes("-light")) fail(`day chosen on a dark Mac: got ${JSON.stringify(d)}`);
    await dark.close();
    if (errors.length) fail(`page errors: ${errors.join("; ")}`);
  } finally {
    await browser.close();
  }
  console.log("verify: pull switch checked (clicks, drags, keys, kept across pages)");
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
