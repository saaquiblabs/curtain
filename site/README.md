# site/

Curtain's page, `curtain.saaquiblabs.com` (#42): Astro static, no UI framework, built by Openship
with `rootDirectory: site`. Set up like D-Tox's (`../d-tox/site`), from which `astro.config.mjs`,
`tests/verify.mjs`, `tests/serve.mjs`, `scripts/sync-brand.mjs`, the layout and the 404 page are
ported. Pages: `/`, `/changelog`, `/privacy`, 404.

```sh
cd site
npm ci
npx playwright install chromium   # once, for Lighthouse
npm run dev                  # http://localhost:4321
npm run typecheck            # astro check
npm test                     # unit tests (node --test): the changelog reader, page vs README
npm run verify               # the gate: tests, build, links, Lighthouse (~1 min); runs before each push
npm run verify:deploy        # what the Openship deploy runs: the same minus Lighthouse
npm run pictures             # refresh public/menu etc. from `make renders` (Mac only)
npm run sync-brand           # refresh the Saaquib Labs mark (needs your access to saaquiblabs)
```

- **Lead:** Turn off, windows stay (owner's pick on #42, 2026-11-25). The page names no other app.
  Every claim on `/` is in the README: change both together. `tests/facts.test.mjs` checks the
  install line, the macOS it needs, and that the README links here.
- **Install:** Homebrew first, plus Build from source. No download button until Curtain is
  notarized (a downloaded, self-signed app is blocked by Gatekeeper; see "Homebrew is a cask" in
  `docs/STATUS.md`).
- **What's new** is `../CHANGELOG.md` itself, read at build time (`src/changelog.mjs`): a version
  bump updates the page with the next deploy. It reads only the shapes the file uses (`##
  <version> — <date>`, paragraphs, `- ` lists, `**bold**`, `` `code` ``, `#n`); keep to them.
- **Look:** Linen & Dusk, the app's (`Sources/Theme.swift`): light or dark from the visitor's
  setting, until they pull the lamp in the header (#41): lit is day, off is night, kept in
  `localStorage` until pulled again. `src/theme.mjs` applies it before the first paint (`<html
  data-theme>`, and the `media` of every `data-scheme` element); a new dark rule or picture must
  obey it too (`tests/theme.test.mjs` checks). The lamp is Tactile UI's Pull-cord Bulb (MIT,
  `src/lamp/pull-cord.mjs`, `public/lamp/LICENSE.txt`), fetched on the visitor's first move so
  Lighthouse never counts it; until then a still of it (`npm run lamp-stills` after changing the
  lamp, its size or its `--tui-obj-*` tokens). One stylesheet, `src/styles/site.css`, inlined into each page. Fonts are the app's,
  Manrope (variable) and Newsreader at 400, roman and italic, self-hosted latin subsets (OFL, `public/fonts/LICENSES.txt`).
- **Pictures:** `public/menu/*.webp` (light and dark, the renders' own names), `og.png` and the icons come from the app's
  renders and `docs/img`. Openship has no Swift, so they're committed; after a UI change run
  `make renders` at the root, then `npm run pictures`, look at them, commit.
- **Brand:** `public/brand/symbol-flat.svg` is a copy from the `saaquiblabs` repo, pinned in
  `src/brand/PINNED`. Don't edit it; run `npm run sync-brand [-- <sha>]` (with
  `BRAND_REPO=git@git-personal:najmushsaaquib/saaquiblabs.git` on the owner's Mac).
- **Analytics:** self-hosted Umami, cookieless. The tag is left out until `analytics.websiteId` in
  `src/site.ts` is set (step 1 below); Privacy then says so by itself. Lighthouse blocks it.
- **Verify:** D-Tox's budgets: Lighthouse 100 in all four categories on phone and desktop for every
  sitemap page, page JS < 50 KB, page < 400 KB, every link answers. Callers: the git pre-push hook
  (`.githooks/pre-push`, installed by `npm ci`; full gate on pushes that touch the site) and the
  Openship deploy (`verify:deploy`, no Lighthouse, about 2 minutes; as D-Tox's #55).
- **Versions:** exact pins only (`.npmrc`). Astro 7.4.7, Node ≥ 22.12, npm 11.19.1.

## Deploy

Manual, after a merge to `main` (no auto deploy), from any terminal that can reach the home VPS:

```sh
ssh najmush-oracle '~/.openship/bin/openship --local deploy --project <project id> --branch main --env production --watch'
```

The project id is in `docs/STATUS.md` once step 3 below is done.

## Going live: [HUMAN] steps

Copied from D-Tox's (`../d-tox/site/README.md`), green on the same box. Do them in order; tell
Claude after each.

1. **Umami website.** Open Umami (`analytics.saaquiblabs.com`) → **Settings** → **Websites** →
   **Add website**. Name `Curtain`, Domain `curtain.saaquiblabs.com` → **Save**. Open it → **Edit**
   → copy the **Website ID**. Give it to Claude, who puts it in `src/site.ts` (`analytics.websiteId`).
2. **Openship can read the repo.** `saaquiblabs/curtain` is public, so the clone needs no token.
   If the first build fails at the clone with `403`: github.com → avatar → **Settings** →
   **Developer settings** → **Personal access tokens** → **Fine-grained tokens** → the token
   Openship uses → **Edit** → add `saaquiblabs/curtain` under **Only select repositories**,
   **Contents: Read-only** → **Update**.
3. **The Openship project.** Openship → **New Project** → **Import project** → GitHub →
   `saaquiblabs/curtain`, branch `main`. Fill in:

   | Field | Value |
   |---|---|
   | Server | `home-vps` |
   | Name | `curtain.saaquiblabs.com` |
   | Framework | **Static site** |
   | Root directory | `site` |
   | Build image | `node:22` |
   | Install command | `npm ci --omit=dev` (no Chrome or test tools) |
   | Build command | `npm run verify:deploy` (tests, build, links; Lighthouse runs before each push) |
   | Output directory | `dist` |
   | Auto Deploy | off (deploy by hand after merges, like D-Tox) |

   → **Create project**. Then in the project's routing settings: **Hide .html extensions** on,
   **Trailing slash** off, **SPA fallback** off (a missing path gets `404.html` with status 404;
   left on, every missing page answers 200). → **Deploy**. Wait for green (about 2 minutes). A red build means the gate failed and the log says which page and
   why. Tell Claude either way. If any field isn't where this says, stop and tell Claude: it can
   create the project from the CLI over SSH instead, as for D-Tox.
4. **DNS, after step 3 is green.** Cloudflare (account `saaquiblabs`) → `saaquiblabs.com` → **DNS**
   → **Records** → **Add record**: Type **A**, Name `curtain`, IPv4 `144.24.124.152`, Proxy status
   **DNS only** (grey cloud), TTL Auto → **Save**. Don't look the name up yourself first: an early
   lookup caches "no such name" for up to 30 minutes. Tell Claude.
5. **Domain.** Openship → `curtain.saaquiblabs.com` project → **Domains** → **Add domain** →
   `curtain.saaquiblabs.com` → save, then verify it so Openship issues the certificate. D-Tox
   needed the domain added as the project's public endpoint before the edge served the real
   certificate. Or Claude does it over SSH.
6. **Check.** Open `https://curtain.saaquiblabs.com` in light and dark, and on a phone; then Umami
   → Curtain → **Realtime** shows the visit. Claude checks from outside: `/` 200, `/privacy` 200
   with no redirect, `/privacy/` 308 → `/privacy`, `/nope` 404.
