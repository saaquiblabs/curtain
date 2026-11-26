/*! Curtain's pull switch (#41). The rope is after lamp-mode (https://github.com/rpbharadwaj99/lamp-mode,
 * commit 04cd862, MIT, Copyright (c) 2026 Rohan Bharadwaj) and the drag after Kokonut UI's Pull Cord
 * (https://github.com/kokonut-labs/kokonutui, components/kokonutui/pull-cord.tsx, commit 7e4bd77, MIT,
 * Copyright (c) 2025 kokonutUI). Licences: /lamp/LICENSE.txt. */
//
// A ceiling pull switch under the header (src/components/Header.astro draws it at rest; this moves
// it). How a real one works, and so this one: the cord hangs from a spring-loaded plunger inside the
// box. Pull the cord and the plunger travels down against its spring; near the bottom of its travel
// the switch clicks. Let go and the plunger snaps back up to its seat; the cord, a loose string, is
// thrown up past where it hangs, falls back onto its own length and bounces, sways a little, and
// hangs straight again. A plain click (or Space, or Enter) is a whole pull: down, click, let go.
//
// From lamp-mode: a Verlet string whose links go slack and never push (that is the bounce), a heavy
// knob, and easing it back under its anchor so it always ends straight. From Kokonut UI: holding the
// link nearest the pointer, resistance that grows the further the hand pulls, a speed cap on
// release, and a bend limit so the cord curves instead of kinking. The plunger and the click at the
// bottom of its travel are Curtain's. Everything here is in CSS px, in the switch's own SVG frame.

export const GEOMETRY = Object.freeze({
  anchor: { x: 24, y: 11 }, // where the cord leaves the box
  links: 10,
  link: 5.4, // so the cord hangs 54 px
  acorn: 17, // its length below the last link
});
export const SWITCH = Object.freeze({
  travel: 22, // the plunger's travel, px
  click: 18, // it clicks here, on the way down
  rearm: 7, // and re-arms above here, on the way back
  give: 6, // past full travel the hand meets a firm, flattening stop
  spring: 900, // the plunger's return spring (1/s²)
  damping: 50, // and its damping (1/s): back on its seat in about 150 ms, no rebound
});
const STEP = 1 / 120;
const GRAVITY = 1400; // px/s²
const DAMPING = 0.988; // per step
const MAX_SPEED = 3.5; // px per step (7 px a 60 Hz frame): a released cord can't fling into the box
const BEND_MIN = 1.9; // two links apart, points stay at least this many links apart
const BEND_STIFFNESS = 0.6;
const ITERATIONS = 12;
const STRAIGHTEN_AFTER = 0.75; // s after the last release, ease the cord back under its anchor
const PULL = Object.freeze({ down: 0.15, hold: 0.05 }); // a click's pull: s down (ease-in), s held

const damp = (d, max) => max * (1 - Math.exp(-d / max));

/** A switch at rest: the plunger seated, the cord hanging straight, armed. */
export function makeSwitch() {
  const { anchor, links, link } = GEOMETRY;
  const n = links + 1;
  const s = {
    xs: new Float64Array(n), ys: new Float64Array(n), pxs: new Float64Array(n), pys: new Float64Array(n),
    e: 0, ev: 0, armed: true, held: -1, hx: 0, hy: 0, t: 0, released: -Infinity, run: null,
  };
  for (let i = 0; i < n; i += 1) { s.xs[i] = s.pxs[i] = anchor.x; s.ys[i] = s.pys[i] = anchor.y + i * link; }
  return s;
}

/** Where the hand may hold link `i`: within the cord's length plus the plunger's travel, then a firm give. */
function reach(s, i, x, y) {
  const { anchor, link } = GEOMETRY;
  // A hand can't take the cord up into the ceiling: it stays below the box.
  const dx = x - anchor.x;
  const dy = Math.max(y, anchor.y + 4) - anchor.y;
  const dist = Math.hypot(dx, dy) || 1e-6;
  const len = i * link;
  const free = len + SWITCH.travel;
  const allowed = dist <= free ? dist : free + damp(dist - free, SWITCH.give);
  return { x: anchor.x + (dx / dist) * allowed, y: anchor.y + (dy / dist) * allowed, pull: Math.max(0, allowed - len) * Math.max(0, dy / dist) };
}

/** Pull link `i` (and the plunger with it) toward the hand at (x, y). */
export function hold(s, i, x, y) {
  s.held = i;
  const r = reach(s, i, x, y);
  s.hx = r.x;
  s.hy = r.y;
}

export function release(s, sway = 0) {
  if (s.held < 0) return;
  s.held = -1;
  s.released = s.t;
  // A hand never lets go dead straight: the knob leaves with a little sideways flick.
  const n = GEOMETRY.links;
  s.pxs[n] = s.xs[n] - sway;
}

/** Start a whole pull (a click, Space, Enter): the hand takes the acorn and draws it down. */
export function startPull(s) {
  if (s.run || s.held >= 0) return false;
  const n = GEOMETRY.links;
  s.run = { t0: s.t, x: s.xs[n], y: s.ys[n] };
  return true;
}

/**
 * Advance `dt` seconds. Returns the events that happened: "click" when the switch clicked on the way
 * down, "rest" when everything came to rest. `sway` is the sideways flick a scripted pull lets go with.
 */
export function advance(s, dt, sway = 0) {
  const events = [];
  const { anchor, links, link } = GEOMETRY;
  s.carry = (s.carry ?? 0) + Math.min(dt, 0.05);
  while (s.carry >= STEP) {
    s.carry -= STEP;
    s.t += STEP;
    // The scripted hand: down past the click with ease-in, a beat at the bottom, then let go.
    if (s.run) {
      const k = Math.min(1, (s.t - s.run.t0) / PULL.down);
      hold(s, links, s.run.x, s.run.y + (SWITCH.travel + 2) * k * k);
      if (s.t - s.run.t0 >= PULL.down + PULL.hold) { s.run = null; release(s, sway); }
    }
    // The plunger: held, it goes where the cord takes it; let go, its spring sends it home.
    const prevE = s.e;
    if (s.held >= 0) {
      const dist = Math.hypot(s.hx - anchor.x, s.hy - anchor.y);
      s.e = Math.min(SWITCH.travel, Math.max(0, dist - s.held * link));
      s.ev = (s.e - prevE) / STEP;
    } else if (s.e > 0 || s.ev !== 0) {
      s.ev += (-SWITCH.spring * s.e - SWITCH.damping * s.ev) * STEP;
      s.e += s.ev * STEP;
      if (s.e <= 0) { s.e = 0; s.ev = 0; } // on its seat
    }
    if (s.armed && s.e >= SWITCH.click) { s.armed = false; events.push("click"); }
    else if (!s.armed && s.e <= SWITCH.rearm) s.armed = true;

    // The string (Verlet): each free point keeps its velocity, plus gravity; the held one goes to the hand.
    const ax = anchor.x;
    const ay = anchor.y + s.e;
    const late = s.held < 0 && !s.run ? Math.min(1, Math.max(0, (s.t - s.released - STRAIGHTEN_AFTER) / 0.6)) : 0;
    for (let i = 1; i <= links; i += 1) {
      if (i === s.held) { s.pxs[i] = s.xs[i]; s.pys[i] = s.ys[i]; s.xs[i] = s.hx; s.ys[i] = s.hy; continue; }
      let vx = (s.xs[i] - s.pxs[i]) * DAMPING;
      let vy = (s.ys[i] - s.pys[i]) * DAMPING;
      const v = Math.hypot(vx, vy);
      if (v > MAX_SPEED) { vx *= MAX_SPEED / v; vy *= MAX_SPEED / v; }
      s.pxs[i] = s.xs[i];
      s.pys[i] = s.ys[i];
      s.xs[i] += vx;
      s.ys[i] += vy + GRAVITY * STEP * STEP;
      if (late) { const k = 0.12 * late; s.xs[i] += (ax - s.xs[i]) * k; s.pxs[i] += (ax - s.pxs[i]) * k; }
    }
    for (let it = 0; it < ITERATIONS; it += 1) {
      s.xs[0] = ax;
      s.ys[0] = ay;
      for (let i = 0; i < links; i += 1) relax(s, i, i + 1, link, false);
      for (let i = 0; i + 2 <= links; i += 1) relax(s, i, i + 2, link * BEND_MIN, true);
    }
  }
  if (atRest(s)) events.push("rest");
  return events;
}

/** Move points a and b toward `len` apart: a link only pulls (a string goes slack), a bend only pushes. */
function relax(s, a, b, len, bend) {
  const aFixed = a === 0 || a === s.held;
  const bFixed = b === s.held;
  if (aFixed && bFixed) return;
  const dx = s.xs[b] - s.xs[a];
  const dy = s.ys[b] - s.ys[a];
  const dist = Math.hypot(dx, dy) || 1e-6;
  if (bend ? dist >= len : dist <= len) return;
  const diff = ((dist - len) / dist) * (bend ? BEND_STIFFNESS : 1);
  // The acorn is heavy: the cord gives way to it, not it to the cord.
  const wa = aFixed ? 0 : bFixed ? 1 : b === GEOMETRY.links ? 0.8 : 0.5;
  s.xs[a] += dx * diff * wa;
  s.ys[a] += dy * diff * wa;
  s.xs[b] -= dx * diff * (1 - wa);
  s.ys[b] -= dy * diff * (1 - wa);
}

/** Nothing held or running, the plunger seated, the cord still and straight under its anchor. */
export function atRest(s) {
  if (s.held >= 0 || s.run || s.e > 0) return false;
  const { anchor, links } = GEOMETRY;
  for (let i = 1; i <= links; i += 1) {
    if (Math.abs(s.xs[i] - s.pxs[i]) + Math.abs(s.ys[i] - s.pys[i]) > 0.01) return false;
    if (Math.abs(s.xs[i] - anchor.x) > 0.05) return false;
  }
  return true;
}

/** The acorn's tip (the end of the cord) and its angle, radians from vertical. */
export function acornOf(s) {
  const n = GEOMETRY.links;
  return { x: s.xs[n], y: s.ys[n], angle: Math.atan2(s.xs[n] - s.xs[n - 1], s.ys[n] - s.ys[n - 1]) };
}

/** The cord as a smooth SVG path. */
export function cordPath(s) {
  const n = GEOMETRY.links;
  const { anchor } = GEOMETRY;
  // From the hole in the box: what the plunger pulls out comes out of the box.
  let d = `M${anchor.x} ${anchor.y}L${s.xs[0].toFixed(2)} ${s.ys[0].toFixed(2)}`;
  for (let i = 1; i < n; i += 1) {
    d += `Q${s.xs[i].toFixed(2)} ${s.ys[i].toFixed(2)} ${((s.xs[i] + s.xs[i + 1]) / 2).toFixed(2)} ${((s.ys[i] + s.ys[i + 1]) / 2).toFixed(2)}`;
  }
  return `${d}L${s.xs[n].toFixed(2)} ${s.ys[n].toFixed(2)}`;
}

// ---------------------------------------------------------------- the page

/**
 * Bring the drawn switch to life. `root` is the <button role="switch"> holding the SVG, with
 * `[data-cord]` paths (the cord, drawn as a few strokes, and its wide invisible hit stroke), `.acorn`
 * (a group drawn hanging from 0,0) and `.plunger` (a group moved down with the plunger). `onSwitch()` is called when the switch clicks.
 */
export function attach(root, onSwitch) {
  const svg = root.querySelector("svg");
  const paths = root.querySelectorAll("[data-cord]");
  const acorn = root.querySelector(".acorn");
  const plunger = root.querySelector(".plunger");
  const reduce = matchMedia("(prefers-reduced-motion: reduce)");
  const s = makeSwitch();
  let raf = 0;
  let last = 0;
  let press = null;

  const draw = () => {
    const d = cordPath(s);
    for (const p of paths) p.setAttribute("d", d);
    const a = acornOf(s);
    acorn.setAttribute("transform", `translate(${a.x.toFixed(2)} ${a.y.toFixed(2)}) rotate(${((-a.angle * 180) / Math.PI).toFixed(2)})`);
    plunger?.setAttribute("transform", `translate(0 ${s.e.toFixed(2)})`);
  };
  const sway = () => (Math.random() < 0.5 ? -1 : 1) * (0.2 + Math.random() * 0.2);
  const frame = (t) => {
    raf = 0;
    const dt = last ? (t - last) / 1000 : STEP;
    last = t;
    const ev = advance(s, dt, sway());
    draw();
    if (ev.includes("click")) onSwitch();
    if (ev.includes("rest")) { last = 0; return; }
    raf = requestAnimationFrame(frame);
  };
  const wake = () => { if (!raf) { last = 0; raf = requestAnimationFrame(frame); } };

  const local = (e) => {
    const r = svg.getBoundingClientRect();
    return { x: e.clientX - r.left, y: e.clientY - r.top };
  };
  /** A whole pull; with Reduce Motion the switch just clicks and nothing moves. */
  const pull = () => {
    if (reduce.matches) { onSwitch(); return; }
    if (startPull(s)) wake();
  };

  root.addEventListener("pointerdown", (e) => {
    if (e.button !== 0 || reduce.matches || s.run) return;
    const p = local(e);
    // Hold the link nearest where the cord was taken (the acorn, from anywhere on it).
    let best = GEOMETRY.links;
    let bd = Math.hypot(s.xs[best] - p.x, s.ys[best] + GEOMETRY.acorn / 2 - p.y);
    for (let i = 2; i < GEOMETRY.links; i += 1) {
      const d = Math.hypot(s.xs[i] - p.x, s.ys[i] - p.y);
      if (d < bd) { bd = d; best = i; }
    }
    press = { id: e.pointerId, x: p.x, y: p.y, dx: s.xs[best] - p.x, dy: s.ys[best] - p.y, i: best, moved: 0 };
    try { root.setPointerCapture(e.pointerId); } catch { /* synthetic */ }
    root.classList.add("held");
    hold(s, best, s.xs[best], s.ys[best]);
    wake();
  });
  root.addEventListener("pointermove", (e) => {
    if (!press || e.pointerId !== press.id) return;
    const p = local(e);
    press.moved = Math.max(press.moved, Math.hypot(p.x - press.x, p.y - press.y));
    hold(s, press.i, p.x + press.dx, p.y + press.dy);
    wake();
  });
  /** The hand lets go. `click`: a real release, which may be a click; otherwise the press was lost. */
  const letGo = (click) => {
    if (!press) return;
    const { moved } = press;
    const switched = !s.armed; // the plunger went past the click during this press
    press = null;
    root.classList.remove("held");
    release(s, sway());
    // A click (a press that hardly moved and didn't pull the switch) is a whole pull. A real tug that
    // stopped short of the click just springs back, as a real cord does.
    if (click && !switched && moved < 8) { s.armed = true; pull(); }
    wake();
  };
  // The release is heard on the whole window, not only on the switch: in a real browser it doesn't
  // always reach the switch (owner, 2026-11-26: the cord stayed held, taut, after letting go). And a
  // press that went missing any other way (focus lost, capture lost, the pointer moving with no
  // button down, the page hidden) lets go too, without a click.
  addEventListener("pointerup", (e) => { if (press && e.pointerId === press.id) letGo(true); }, true);
  addEventListener("pointercancel", (e) => { if (press && e.pointerId === press.id) letGo(false); }, true);
  // A mouse moving with no button down has been let go of; touch is left alone (mobile Safari has
  // reported no button during a touch drag).
  addEventListener("pointermove", (e) => { if (press && e.pointerId === press.id && e.pointerType === "mouse" && e.buttons === 0) letGo(false); }, true);
  addEventListener("blur", () => letGo(false));
  document.addEventListener("visibilitychange", () => { if (document.hidden) letGo(false); });
  root.addEventListener("lostpointercapture", () => setTimeout(() => letGo(false)));
  // Keyboard and assistive tech: Space and Enter on the button arrive as a click with no pointer.
  root.addEventListener("click", (e) => { if (e.detail === 0) pull(); });
  draw();
  return { pull };
}
