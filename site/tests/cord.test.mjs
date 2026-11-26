// The pull switch's feel, in numbers (#41, owner 2026-11-26: "it should be properly pulled and
// then pushed back, the way an actual lamp works"). src/lamp/cord.mjs, without a page.
import { test } from "node:test";
import assert from "node:assert/strict";
import { makeSwitch, advance, startPull, hold, release, acornOf, atRest, GEOMETRY, SWITCH } from "../src/lamp/cord.mjs";

const REST_Y = GEOMETRY.anchor.y + GEOMETRY.links * GEOMETRY.link;
const FRAME = 1 / 60;

/** Run frames until `until(t)` or rest; record the acorn and events. */
function run(s, seconds, { sway = 0.8, onFrame } = {}) {
  const trace = [];
  for (let t = 0; t < seconds; t += FRAME) {
    const ev = advance(s, FRAME, sway);
    const a = acornOf(s);
    trace.push({ t, y: a.y, x: a.x, e: s.e, click: ev.includes("click"), rest: ev.includes("rest") });
    onFrame?.(t, s);
    if (ev.includes("rest")) break;
  }
  return trace;
}

test("at rest the cord hangs straight, its full length, and stays put", () => {
  const s = makeSwitch();
  const trace = run(s, 0.5);
  assert.ok(trace.at(-1).rest, "comes to rest");
  assert.ok(Math.abs(acornOf(s).y - REST_Y) < 1, `acorn at ${acornOf(s).y}, want ${REST_Y}`);
  assert.ok(Math.abs(acornOf(s).x - GEOMETRY.anchor.x) < 0.05);
});

test("a click is a whole pull: visibly down, one click at the bottom, let go, back up past rest, settled straight in time", () => {
  const s = makeSwitch();
  run(s, 0.5);
  assert.ok(startPull(s));
  const trace = run(s, 3);
  const clicks = trace.filter((f) => f.click);
  assert.equal(clicks.length, 1, "the switch clicks exactly once");
  const lowest = Math.max(...trace.map((f) => f.y));
  assert.ok(lowest - REST_Y >= 20, `pulled ${(lowest - REST_Y).toFixed(1)} px down, want ≥ 20`);
  const atClick = clicks[0].y - REST_Y;
  assert.ok(atClick >= 0.75 * (lowest - REST_Y), `clicks near the bottom (${atClick.toFixed(1)} of ${(lowest - REST_Y).toFixed(1)} px)`);
  assert.ok(clicks[0].t > 0.08 && clicks[0].t < 0.25, `clicks ${Math.round(clicks[0].t * 1000)} ms into the pull`);
  const after = trace.filter((f) => f.t > clicks[0].t + 0.05);
  const highest = Math.min(...after.map((f) => f.y));
  assert.ok(REST_Y - highest >= 2, `thrown ${(REST_Y - highest).toFixed(1)} px above rest on release, want ≥ 2`);
  const end = trace.at(-1);
  assert.ok(end.rest, "comes to rest");
  assert.ok(end.t <= 1.6, `at rest after ${end.t.toFixed(2)} s, want ≤ 1.6`);
  assert.ok(Math.abs(end.x - GEOMETRY.anchor.x) < 0.05 && Math.abs(end.y - REST_Y) < 1, "hangs straight, full length");
});

test("no frame jumps: the acorn never moves more than a few px between frames", () => {
  const s = makeSwitch();
  run(s, 0.5);
  startPull(s);
  const trace = run(s, 3);
  for (let i = 1; i < trace.length; i += 1) {
    const d = Math.hypot(trace[i].x - trace[i - 1].x, trace[i].y - trace[i - 1].y);
    assert.ok(d <= 9, `${d.toFixed(1)} px in one frame at ${Math.round(trace[i].t * 1000)} ms`);
  }
});

test("a short tug that stops before the click only springs back", () => {
  const s = makeSwitch();
  run(s, 0.5);
  const a = acornOf(s);
  let clicks = 0;
  for (let k = 0; k <= 10; k += 1) {
    hold(s, GEOMETRY.links, a.x, a.y + k);
    clicks += advance(s, FRAME).filter((e) => e === "click").length;
  }
  release(s, 0.5);
  clicks += run(s, 3).filter((f) => f.click).length;
  assert.equal(clicks, 0);
  assert.ok(atRest(s));
});

test("a hand pulling hard clicks once and can't pull the cord out of the box", () => {
  const s = makeSwitch();
  run(s, 0.5);
  const a = acornOf(s);
  let clicks = 0;
  let lowest = 0;
  for (let k = 0; k <= 120; k += 2) {
    hold(s, GEOMETRY.links, a.x, a.y + k);
    clicks += advance(s, FRAME).filter((e) => e === "click").length;
    lowest = Math.max(lowest, acornOf(s).y);
  }
  assert.equal(clicks, 1);
  assert.ok(lowest - REST_Y <= SWITCH.travel + SWITCH.give + 0.5, `stretched to ${(lowest - REST_Y).toFixed(1)} px`);
  release(s, 0);
  run(s, 3);
  assert.ok(atRest(s));
});
