# Pull-cord switches on the web: what others built, and what a real one does

Research for #41 (Curtain's page, day/night pull cord). Written 2026-11-26. Sources are the
implementations' own code, READMEs and licence files. CodePen itself refuses automated fetches (HTTP
403), so pen code was read from the authors' own repos or from CodePen exports that carry CodePen's
generated MIT `LICENSE.txt`; anything not confirmed that way is marked **unverified**.

## Summary

- Two families exist. **Keyframed**: jh3y's Tuggable Light Bulb drags a straight line, snaps it back in
  0.1 s, then plays a fixed 0.8 s MorphSVG wobble. **Simulated**: Verlet ropes (lamp-mode, Kokonut UI)
  or a stiff spring chain with a detent (Tactile UI, our current base).
- The one that best answers "a plain click visibly pulls the cord" is **lamp-mode** (MIT, ~7 KB, no
  dependencies). Every click lets out string, yanks the knob down, flicks it sideways and lets a Verlet
  rope bounce and settle. Then it eases the rope back to vertical so it always ends hanging straight.
- Our port's click is a ~12 px dip over 0.17 s on a 96 px cord, with no overshoot. That number is
  estimated from its constants (see "Why ours feels wrong"). It doesn't read as a pull.
- Affordance is weak everywhere. The best cues are jh3y's hand-drawn "drag me." arrow, Kokonut's
  "On · pull the cord" caption, `cursor: grab`, and a fat invisible hit path along the cord.
- Accessibility done right: a real `<button role="switch" aria-checked>` (lamp-mode, Kokonut, Tactile).
  Keys get the same motion as a click (lamp-mode, Tactile) or a small tug (Kokonut).
- GSAP is free to use but not open source. GSAP core plus Draggable plus MorphSVG is ~124 KB, which
  breaks our 50 KB JS budget on its own. Port the idea, not the dependency.

## Comparison

| | Tuggable Light Bulb (jh3y) | Draggable Theme Toggle (jh3y) | Tactile UI Pull-cord Bulb | lamp-mode | Kokonut UI Pull Cord | 19 Rope Toggle (Framer) |
|---|---|---|---|---|---|---|
| Motion model | keyframes: drag line, 0.1 s snap back, 4 MorphSVG shapes | same, plus View Transition | spring chain at 16 kHz, plunger with detent | Verlet rope, 14 pts, slack-only links | Verlet chain, 12 links, bend stiffness | rope physics (closed) |
| Switches when | release after > 50 px drag | release after > 50 px drag | detent trips at 9 mm of 14 mm travel | on click (no drag) | during drag, past 22 px over length | full pull and release |
| Plain click | nothing (2020); button toggles, no cord motion (2023) | button toggles, no cord motion | programmed pull 0.17 s, held to 0.26 s | full yank, sway, settle | nothing; only the hidden button toggles | flips (no detail) |
| Overshoot/bounce | yes, keyframed (0.8 s) | yes, keyframed | small, physical | yes, physical; harder on rapid clicks | yes, physical | "swings until it settles" |
| Affordance | — | "drag me." arrow, grab handle | `cursor: grab`, 44 px grip | knob, state = cord length | caption "pull the cord", wide hit path | — |
| Sound | click.mp3 | click.mp3 | synthesised snap, off by default | none | `navigator.vibrate(8)` | optional click |
| A11y | none | `<button aria-pressed>` + sr-only label | `role=switch`, `aria-checked`, Space/Enter | `<button role=switch aria-checked>` | sr-only `role=switch` button | keyboard, reduced motion |
| Reduced motion | no | no | state flips, nothing moves | no animation | cord drops to rest | yes |
| Tech / deps | SVG; GSAP + Draggable + MorphSVG | SVG; GSAP 3.12 + Draggable + MorphSVG | canvas; none | SVG; none | SVG; React + Tailwind | Framer |
| Own code | ~3 KB JS | ~3 KB JS + 15 KB SVG | 85 KB (27 KB gz) | 7.1 KB | 15 KB TSX (5 KB gz) | n/a |
| Licence | MIT (CodePen public pen) | MIT (pen); deck repo has none | MIT | MIT | MIT | none stated; not portable |

## 1. Jhey Tompkins: Tuggable Light Bulb (2020)

Pen: [codepen.io/jh3y/pen/VwjgdLj](https://codepen.io/jh3y/pen/VwjgdLj). The pen ID comes from links in
others' code ([1](https://github.com/JamesPrenticez/port), [2](https://github.com/pranavupadhyay123/bookmark_mindmap)).
The code was read from a CodePen export: [SunShade123456/…/src/script.js](https://github.com/SunShade123456/tuggable-light-bulb-gsap-draggable-morphsvg)
and [stanwmusic's gist](https://gist.github.com/stanwmusic/e2f64cbc7fa9a8eb23c97eafaf03bda8).
- **Pull:** Draggable moves a hidden proxy `div`. On each drag event the SVG line's end (`x2,y2`) is set
  to the pointer, so the cord is a rubber band with no resistance and no limit. On release,
  `to(DUMMY_CORD, {attr:{x2:ENDX,y2:ENDY}, duration: 0.1})` snaps it back. Then, if the pointer
  travelled more than 50 px, a timeline runs: `CORDS[0]` morphs into 4 hand-drawn cord shapes, each
  `duration: 0.1, repeat: 1, yoyo: true`, so the bounce lasts ~0.8 s. GSAP's default ease applies.
- **Click:** the switch flips at the start of that timeline (`onStart`: `--on` flips, click.mp3 plays).
  So it switches after the release, not at the bottom of the pull. A plain click does nothing.
- **Affordance:** the bulb itself, and the light coming on (`--on` drives the colours). That's all.
- **A11y:** no role, no label, no keyboard ([gist summary](https://gist.github.com/stanwmusic/e2f64cbc7fa9a8eb23c97eafaf03bda8)).
- **Deps:** GSAP core 72 KB, Draggable 35 KB and MorphSVG 17 KB, minified
  ([jsDelivr dist](https://cdn.jsdelivr.net/npm/gsap@3.13.0/dist/)). Jhey credits the proxy trick to
  this demo in [Smashing, 2022](https://www.smashingmagazine.com/2022/04/what-if-sliders-actually-slid-html-element-input-range).
- **Licence:** public pen, so MIT ([CodePen licensing](https://blog.codepen.io/documentation/licensing/):
  "Public pens are automatically MIT licensed"). Exports carry the generated MIT `LICENSE.txt`.

## 2. Jhey Tompkins: Draggable Theme Toggle (2023) and his deck copy

Pen: [codepen.io/jh3y/pen/OJeRrKm](https://codepen.io/jh3y/pen/OJeRrKm), per
[pangqiang/code-shops README](https://github.com/pangqiang/code-shops/tree/main/Draggable-Theme-Toggle).
Jhey's own copy: [jh3y/deck …/tuggable-lightbulb](https://github.com/jh3y/deck/tree/main/src/pages/demos/tuggable-lightbulb)
(commit 6032003). The deck repo has **no licence file**, so use the pen's MIT, not the repo.
- Same pull, threshold and morph as #1, with three additions.
  - A real `<form><button aria-pressed>` with an sr-only "Toggle theme" label.
  - The theme change runs inside `document.startViewTransition`. A "flicker lights on" option eases the
    light view transition with a flicker curve (`_style.css`).
  - A visible hand-drawn arrow, "drag me.", plus a 48 px `.grab-handle`.
- **Click:** a click or Enter/Space on the button submits the form and toggles without moving the cord.
  The cord timeline is only reached from the drag path (`_script.js`). Whether a click on the grab
  handle inside the button also submits is **unverified** (not run in a browser).
- **Reduced motion:** none in the code. The deck README says the demos are "not production-ready".

## 3. Tactile UI: Pull-cord Bulb (our current base)

Repo: [cipriantitire/tactile-ui-free/pull-cord](https://github.com/cipriantitire/tactile-ui-free/tree/main/pull-cord)
(commit 0774661), MIT ([repo licence](https://github.com/cipriantitire/tactile-ui-free)). Demo and
options: [tactileui.dev/objects/pull-cord](https://tactileui.dev/objects/pull-cord).
- **Pull:** the cord is a chain of stiff, tension-only springs stepped at 1/16000 s, hung from a plunger.
  `SWITCH = {travel: 0.014, click: 0.009, reset: 0.0035, …, bump: 3, bumpAt: 0.78}` (metres, newtons).
  So the force rises with a detent bump, the latch trips at 9 of 14 mm and the force drops (the snap).
  It re-arms below 3.5 mm. The hand is a stiff spring to the acorn, so the acorn lags under load.
  The drag is clamped to `PULL_DEPTH + 3 cm` below rest (`pull-cord.mjs` header and `#move`).
- **Click:** "Space, Enter or a click anywhere run the same physical pull, animated"
  ([demo page](https://tactileui.dev/objects/pull-cord)). That pull is a smoothstep of the hand to
  `PULL_DEPTH` (travel + 14 mm = 28 mm) over 0.17 s, then the hand lets go at 0.26 s (`#frame`).
  Upstream ignores the click if the press moved more than 2 px or was held over 350 ms (`#up`).
- **Affordance:** `cursor: grab`/`grabbing`, and a 44 px grip round the acorn (`pull-cord.css`). With
  the lamp drawn, the filament warms red to white and the lamp sways. **Our cord-only mode removes both.**
- **Sound:** optional (off by default): a Web Audio bandpass noise snap (2.6 kHz) plus a 190→90 Hz body
  thump, and a softer 4.2 kHz tick on re-arm. Audio starts only after a gesture (`#sound`).
- **A11y / reduced motion:** `role="switch"`, `aria-checked`, a label and a `change` event. Under
  reduced motion the state flips instantly and nothing moves.
- **Size:** 85 KB source, 27 KB gzip. Canvas with per-pixel shading. No dependencies.

## 4. lamp-mode (Pranav Bharadwaj, 2026)

Repo: [rpbharadwaj99/lamp-mode](https://github.com/rpbharadwaj99/lamp-mode) (commit 04cd862), MIT
([LICENSE](https://github.com/rpbharadwaj99/lamp-mode/blob/main/LICENSE)). Single file `lamp-mode.js`,
7.1 KB, "~3 KB gzipped", no dependencies, SVG.
- **Rope:** 14 Verlet points, `GRAVITY 0.35`, `DAMP 0.965` per frame, 16 constraint passes. Links
  only pull, never push: "a string goes slack, it never pushes". The knob point has half weight (heavy).
- **Click = a visible pull:** `kick()` lets out 14 px of string (`len + 14`, capped at rest + 28). It
  yanks the knob 5 px a frame down and gives a random sideways flick to the tip and every other point.
  Then `len` springs back toward rest at 8% a frame, so the cord drops, bounces on its length and sways.
  It always ends straight: from 1.2 s after the kick, every point is eased back under the anchor over
  1.5 s (`pullK`), then snapped to vertical when calm. Clicks under 600 ms apart throw it harder.
- **State in the cord:** "Light is the short resting length; dark is the cord pulled further down"
  (72 vs 84 px). The knob's height shows the state ([README](https://github.com/rpbharadwaj99/lamp-mode#behavior)).
- **A11y / reduced motion:** a real `<button role="switch" aria-checked aria-label="Dark mode">`, so
  Space/Enter come free. Under reduced motion the rope is straightened and drawn with no animation.
- **Missing:** no drag at all (click only), no detent, no sound. It also kicks on page load, which we'd drop.

## 5. Kokonut UI: Pull Cord (Dorian Baffier, 2026)

Source: [kokonut-labs/kokonutui …/pull-cord.tsx](https://github.com/kokonut-labs/kokonutui/blob/main/components/kokonutui/pull-cord.tsx)
(commit 7e4bd77), MIT (file header and [repo licence](https://github.com/kokonut-labs/kokonutui)).
- **Rope:** a fixed 1/120 s step, 12 links of 8.5 px, `GRAVITY 1400`, `DAMPING 0.992` and 14 passes.
  Bend stiffness (points two links apart are kept at least 1.9 links apart) makes it curve instead of
  kink. `MAX_SPEED 4` px a step stops a stretched cord flinging into the shade on release.
- **Resistance:** past its length, the cord stretches as `34·(1−e^(−d/34))`: it "slows down instead of
  stopping at a wall". **The switch clicks during the pull, at 22 px past length, not on release.** It
  re-arms below 40% of that and fires `navigator.vibrate(8)`. You can grab the cord anywhere (the
  nearest link is held).
- **Click:** a press with no pull does nothing. Only the sr-only `<button role="switch">` toggles, and
  then it tugs the bead 5 px ("so the cord answers the key too").
- **Affordance:** a 22 px-wide invisible stroke copy of the cord, `cursor: grab`, a 20 px hit circle on
  the bead, a lamp whose bulb lights, and the caption "On · pull the cord".
- **Reduced motion:** on release the cord drops straight to rest. Depends on React and Tailwind.

## 6. Others looked at (not portable or not verified)

- **19 Rope Toggle** (BrandingUp, Framer): "A short tug only sways the rope". A full pull and release
  flips it. Tap, Enter and Space flip too, with keyboard and reduced-motion support and an optional
  click sound. Free, but no licence is stated and it is Framer-only
  ([listing](https://www.framer.com/marketplace/components/19-rope-toggle/)). Use it for ideas, not code.
- **Pull Lamp** (aqualang89, "ported to React from the original Web Component by Ship Notes"), MIT
  ([21st.dev](https://21st.dev/@aqualang89/components/pull-lamp.md)). Its source wasn't available
  without an account: **unverified**.
- **GSAP Draggable + Inertia rope demos**: no gsap.com pull-cord demo was found. GSAP is under the
  "Standard 'No Charge' GSAP License": commercial use is free, but it is not MIT, and Webflow keeps the
  IP ([gsap.com/licensing](https://gsap.com/licensing/)).

## Real pull-switch mechanics

- **Toggle per pull, by ratchet.** Each pull changes the state. In one common type the switch changes
  **during the pull**; in another, only **when the string is released after a full pull**
  ([Wikipedia, Pull switch](https://en.wikipedia.org/wiki/Pull_switch)). A cord pull turns a ratchet
  wheel one step. A leg spring returns the drive, and spring-loaded cams hold each position and stop the
  wheel turning back ([DE1905081B1](https://patents.google.com/patent/DE1905081B1/en)).
- **The return is the switch's own spring:** "As the rod is released, the pull switch will pull back the
  string" ([US6423919B1](https://patents.google.com/patent/US6423919B1/en)).
- **Travel, click position, force:** no manufacturer gives these. The Hager WMCS12 datasheet lists only
  "pull cord", 6 A ([PDF](https://assets.hager.com/step-content/P/PDS_160592332001EN/Document/std.lang.all/WMCS12_2001_en-GB.pdf)).
  "A short stroke of 1–2 cm, clicking near the bottom" is common experience and **unverified**.
  Tactile UI models 14 mm travel with the click at 9 mm; that is one author's model, not a measurement.
- **What follows physically:** the hand pulls against a rising spring. The latch trips with a snap and
  the force drops, so the hand overshoots slightly. On release the spring pulls the cord back up, the
  bob overshoots past rest, and the cord bounces on its own elasticity and swings as a pendulum. A
  sideways pull makes it swing. Then it hangs still.

## Why ours feels wrong (from our code, estimated, not measured on screen)

Our box is 96 px tall (`.pull-in`, `site.css`), and the cord is `cord: 0.5` (13 cm). From `layout` in
`src/lamp/pull-cord.mjs`, that is about 440 px per metre. So a click's 28 mm pull is **~12 px of hand
travel in 0.17 s**, and the switch's 14 mm is ~6 px. The acorn lags the hand, and the cord's top is
fixed in cord-only mode. So the visitor sees a twitch of under an eighth of the cord, then a tiny damped
return with no visible bounce. The lamp, the filament and the sway are the parts that made the
original read as a switch, and cord-only mode removes them.

## What to learn for Curtain

1. **Base: lamp-mode's rope** (MIT, 7 KB, SVG, no deps). Keep its slack-only Verlet links, its heavy knob,
   its "always ends hanging straight" settle and its `<button role="switch">`. Add a drag from Kokonut UI
   (MIT): grab the nearest link, exponential stretch past length, click at a threshold during the pull,
   re-arm on the way back, and cap the speed on release. Both together are well under 15 KB. That
   replaces a 35 KB lazy canvas port. Credit both in `NOTICE` and the file header.
2. **A plain click plays a whole pull** (Space and Enter too, all one function). The cord is drawn down a
   clearly visible distance, ~25–35% of its length (≥ 24 px on a 96 px cord), over ~120–160 ms with
   ease-in. The switch clicks at the bottom (switch the state there and start the drapes). Then the cord
   is let go: it springs up, overshoots above rest by a few px, bounces 1–2 times, and settles inside
   ~0.8–1 s with a small random sideways sway. That is lamp-mode's kick, made deeper and given a clear
   bottom. jh3y's 0.8 s wobble is the right length for the after-bounce.
3. **Make the drag honest**: rising resistance, then a click past a threshold during the pull (Kokonut,
   like the "switches during the pull" type of real switch). A short tug that doesn't reach it only
   sways and springs back, with no switch (19 Rope Toggle).
4. **Affordance:** `cursor: grab`/`grabbing`; a ≥ 44 px hit area on the acorn plus a wide invisible
   stroke along the cord; a visible `title`/label ("Pull for night" / "Pull for day"). Add one gentle
   hint sway after first interaction or on hover (not on load: no motion before the visitor acts). Option:
   lamp-mode's idea of letting the resting length show the state.
5. **Avoid:** a rubber-band cord with no limit (jh3y). Switching only after the release animation
   (jh3y's switch lags the gesture). A click that does nothing (Kokonut, jh3y 2020). Kicking on page load
   (lamp-mode). GSAP: ~124 KB for core, Draggable and MorphSVG, and not MIT.
6. **A11y and reduced motion:** a real `<button role="switch" aria-checked>` with a visible focus ring
   on the acorn. Under reduced motion, switch at once and draw the cord at rest. The drapes already
   skip under reduced motion (`header.ts`). Sound stays off: optional at most, made with Web Audio after
   a gesture, like Tactile UI.
