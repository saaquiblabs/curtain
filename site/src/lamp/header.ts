// The pull switch under the header (#41). Pull its cord and the switch clicks at the bottom of the
// pull; once the cord has sprung back, the drapes cross the page, close, and open on night or day.
// The switch is drawn in the HTML at rest (src/components/Header.astro); its motion
// (src/lamp/cord.mjs, a few KB) is fetched when the visitor first moves, scrolls, taps or types, so
// a load alone fetches nothing and the page stays inside tests/verify.mjs's budgets. A click before
// then still switches, without the motion.

interface CurtainTheme {
  readonly chosen: boolean;
  readonly dark: boolean;
  choose(theme: "light" | "dark"): void;
  system: MediaQueryList;
}

const button = document.querySelector<HTMLButtonElement>("[data-lamp]");
const theme = (window as unknown as { curtainTheme?: CurtainTheme }).curtainTheme;

/** Draw the drapes across the page, switch while they're closed, open them again. */
function sweep(night: boolean, done: () => void) {
  if (matchMedia("(prefers-reduced-motion: reduce)").matches) {
    theme?.choose(night ? "dark" : "light");
    done();
    return;
  }
  const drapes = document.createElement("div");
  drapes.className = "sweep";
  drapes.setAttribute("aria-hidden", "true");
  const l = drapes.appendChild(document.createElement("span"));
  const r = drapes.appendChild(document.createElement("span"));
  l.className = "l";
  r.className = "r";
  document.body.append(drapes);
  const ease = "cubic-bezier(.65,0,.35,1)"; // --drape, the app's drapes
  const move = (el: HTMLElement, from: string, to: string, ms: number) =>
    el.animate([{ transform: `translateX(${from})` }, { transform: `translateX(${to})` }], { duration: ms, easing: ease, fill: "forwards" }).finished;
  Promise.all([move(l, "-100%", "0", 520), move(r, "100%", "0", 520)])
    .then(() => {
      theme?.choose(night ? "dark" : "light");
      done();
      return new Promise((ok) => setTimeout(ok, 120));
    })
    .then(() => Promise.all([move(l, "0", "-100%", 720), move(r, "0", "100%", 720)]))
    .finally(() => {
      drapes.remove();
    });
}

if (button && theme) {
  const show = () => button.setAttribute("aria-checked", String(theme.dark));
  show();
  // The drapes wait for the cord to be let go and spring back (~0.45 s after the click), so the pull
  // is seen before they cover the page, switch included.
  // Clicks that come faster than the drapes each flip from the last one asked for.
  let asked: boolean | null = null;
  const flip = () => {
    const night = (asked = !(asked ?? theme.dark));
    setTimeout(() => sweep(night, () => { show(); if (asked === night) asked = null; }), live ? 450 : 0);
  };

  let live = false;
  let loading: Promise<void> | null = null;
  const load = () =>
    (loading ??= import("./cord.mjs").then(({ attach }) => {
      attach(button, flip);
      live = true;
      button.dataset.live = "";
    }));

  // Before the motion arrives, a click still switches.
  button.addEventListener("click", () => {
    if (live) return;
    flip();
    load();
  });

  const first = ["pointermove", "pointerdown", "keydown", "scroll", "wheel", "touchstart", "focusin"];
  const go = () => {
    for (const t of first) removeEventListener(t, go, true);
    load();
  };
  for (const t of first) addEventListener(t, go, { capture: true, passive: true });

  // Not chosen yet: the switch follows the visitor's Mac, as the page does.
  theme.system.addEventListener("change", () => {
    if (!theme.chosen) show();
  });
}
