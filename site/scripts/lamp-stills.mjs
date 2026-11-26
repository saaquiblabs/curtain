// The pull cord's stills (#41): public/lamp/day.webp and night.webp, drawn by the cord's own code
// (src/lamp/pull-cord.mjs, `cordOnly`) at rest, at its size and 2×, so the still and the live cord
// that replaces it match. Run after changing the cord, its options here and in src/lamp/header.ts,
// its size in src/styles/site.css (.pull-in) or its tokens (--tui-obj-*): `npm run lamp-stills`.
//
// The page draws the lamp's light and glow with `screen`; on a still there is no page underneath,
// so the glow is screened onto the lamp here and the wall light (invisible on linen) is left out.
import { chromium } from "playwright";
import { createServer } from "node:http";
import { readFile, writeFile } from "node:fs/promises";
import { extname, join, normalize } from "node:path";
import { fileURLToPath } from "node:url";

const site = fileURLToPath(new URL("..", import.meta.url));
const types = { ".html": "text/html", ".css": "text/css", ".mjs": "text/javascript", ".woff2": "font/woff2" };
const page = `<!doctype html><html data-theme="THEME"><head><link rel="stylesheet" href="/src/styles/site.css"></head>
<body style="margin:0;background:transparent"><div class="pull-in" data-lamp></div>
<script type="module">
  import { PullCord } from "/src/lamp/pull-cord.mjs";
  const host = document.querySelector("[data-lamp]");
  const lamp = new PullCord(host, { on: ON, label: "Lights", cordOnly: true, cord: 0.5, light: 0 });
  await new Promise((r) => setTimeout(r, 600));
  const [shadow, , body, glow] = lamp.root.querySelectorAll("canvas");
  const out = document.createElement("canvas");
  out.width = body.width; out.height = body.height;
  const g = out.getContext("2d");
  g.drawImage(shadow, 0, 0, out.width, out.height);
  g.drawImage(body, 0, 0);
  g.globalCompositeOperation = "screen";
  g.drawImage(glow, 0, 0);
  window.still = out.toDataURL("image/webp", 0.92);
</script></body></html>`;

const server = createServer(async (req, res) => {
  const path = normalize(decodeURIComponent(new URL(req.url, "http://x").pathname));
  if (path.startsWith("/still-")) {
    const theme = path.slice(7);
    res.writeHead(200, { "content-type": "text/html" });
    return res.end(page.replace("THEME", theme).replace("ON", String(theme === "light")));
  }
  try {
    const body = await readFile(join(site, path.startsWith("/fonts/") ? "public" : "", path));
    res.writeHead(200, { "content-type": types[extname(path)] ?? "application/octet-stream" }).end(body);
  } catch { res.writeHead(404).end(); }
}).listen(0);
const base = `http://127.0.0.1:${server.address().port}`;

const browser = await chromium.launch();
const ctx = await browser.newContext({ deviceScaleFactor: 2, viewport: { width: 200, height: 300 } });
for (const [theme, name] of [["light", "day"], ["dark", "night"]]) {
  const p = await ctx.newPage();
  p.on("pageerror", (e) => { console.error(e); process.exitCode = 1; });
  await p.goto(`${base}/still-${theme}`);
  const url = await p.waitForFunction(() => window.still, null, { timeout: 10_000 }).then((h) => h.jsonValue());
  const file = join(site, "public/lamp", `${name}.webp`);
  await writeFile(file, Buffer.from(url.split(",")[1], "base64"));
  console.log(`lamp-stills: ${file.replace(site, "")}`);
}
await browser.close();
server.close();
