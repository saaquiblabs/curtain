// The page's pictures, from the app's own renders: run `make renders` at the repo root first (it
// needs the Mac and Swift), then `npm run pictures`, look at public/shots, and commit them. The
// Openship build has no Swift, so the copies are committed; this is how they are refreshed.
//   public/menu/<name>-<light|dark>.webp   the menu (372 pt wide) and the Turn back on banner, at 2×,
//                                          under the renders' own names (src/components/Menu.astro)
//   public/og.png                          the social preview (docs/img/social-preview.png)
//   public/icon-32.png, icon-64.png (the header's, sharp at 2×), apple-touch-icon.png  from docs/img/curtain-256.png
import sharp from "sharp";
import { existsSync, mkdirSync } from "node:fs";
import { fileURLToPath } from "node:url";

const at = (p) => fileURLToPath(new URL(p, import.meta.url));
const renders = at("../../build/renders/"), shots = at("../public/menu/"), pub = at("../public/");

/** The renders the page shows: the hero (off, banner) and the six steps of See it. */
const pictures = Object.fromEntries(
  ["off", "banner", "lit", "preview-turn-off", "disconnected", "preview-slider", "preview-quit"].map((n) => [n, n]),
);

mkdirSync(shots, { recursive: true });
for (const [from, to] of Object.entries(pictures)) {
  for (const look of ["light", "dark"]) {
    const src = `${renders}${from}-${look}.png`;
    if (!existsSync(src)) {
      console.error(`pictures: ${src} not found. Run \`make renders\` at the repo root first.`);
      process.exit(1);
    }
    await sharp(src).webp({ quality: 82, alphaQuality: 90 }).toFile(`${shots}${to}-${look}.webp`);
  }
}
// The hero's menu also at 640 px wide, for phones (src/pages/index.astro srcset): half the bytes, still sharp.
for (const look of ["light", "dark"]) {
  await sharp(`${renders}off-${look}.png`).resize(640).webp({ quality: 62, alphaQuality: 80 }).toFile(`${shots}off-${look}-640.webp`);
}
await sharp(at("../../docs/img/social-preview.png")).png({ palette: true, quality: 90 }).toFile(`${pub}og.png`);
await sharp(at("../../docs/img/curtain-256.png")).resize(32).png().toFile(`${pub}icon-32.png`);
await sharp(at("../../docs/img/curtain-256.png")).resize(64).png().toFile(`${pub}icon-64.png`);
await sharp(at("../../docs/img/curtain-256.png")).resize(180).png().toFile(`${pub}apple-touch-icon.png`);
console.log(`pictures: ${Object.keys(pictures).length * 2} shots, og.png and icons → public/`);
