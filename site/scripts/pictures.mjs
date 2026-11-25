// The page's pictures, from the app's own renders: run `make renders` at the repo root first (it
// needs the Mac and Swift), then `npm run pictures`, look at public/shots, and commit them. The
// Openship build has no Swift, so the copies are committed; this is how they are refreshed.
//   public/shots/<name>-<light|dark>.webp  the menu (372 pt wide) and the Turn back on banner, at 2×
//   public/og.png                          the social preview (docs/img/social-preview.png)
//   public/icon-32.png, icon-64.png (the header's, sharp at 2×), apple-touch-icon.png  from docs/img/curtain-256.png
import sharp from "sharp";
import { existsSync, mkdirSync } from "node:fs";
import { fileURLToPath } from "node:url";

const at = (p) => fileURLToPath(new URL(p, import.meta.url));
const renders = at("../../build/renders/"), shots = at("../public/shots/"), pub = at("../public/");

/** Render name → name on the site. */
const pictures = {
  off: "off", // the hero: the monitor turned off, drapes closed on the map and its row
  "preview-turn-off": "preview", // the pointer on Turn off: the map shows it halfway
  on: "on", // the desk map, both screens on
  banner: "banner", // Turn back on
};

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
await sharp(at("../../docs/img/social-preview.png")).png({ palette: true, quality: 90 }).toFile(`${pub}og.png`);
await sharp(at("../../docs/img/curtain-256.png")).resize(32).png().toFile(`${pub}icon-32.png`);
await sharp(at("../../docs/img/curtain-256.png")).resize(64).png().toFile(`${pub}icon-64.png`);
await sharp(at("../../docs/img/curtain-256.png")).resize(180).png().toFile(`${pub}apple-touch-icon.png`);
console.log(`pictures: ${Object.keys(pictures).length * 2} shots, og.png and icons → public/`);
