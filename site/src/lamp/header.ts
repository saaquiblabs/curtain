// The pull switch under the header (#41). Pull its cord and the switch clicks at the bottom of the
// pull, and the page's own colours change, rippling out from the switch's lamp for day and back
// into it for night (owner, 2026-11-26: the page itself changes, nothing covers it; quick).
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

/**
 * The page itself changes, nothing covers it (owner, 2026-11-26): every colour on the page eases
 * from one look to the other, and the switch's lamp is where it starts. For day, what is nearest the
 * lamp turns first and the change ripples out across the page; for night it ripples back in and ends
 * at the lamp. About 0.6 s in all. With Reduce Motion it switches at once.
 */
const RIPPLE = 290; // ms from the nearest element to the farthest (owner: 10% slower than 260)
const EASE = 420; // ms each element takes (and 380 before)
function shift(night: boolean, from: DOMRect, done: () => void) {
  const apply = () => { theme?.choose(night ? "dark" : "light"); done(); };
  if (matchMedia("(prefers-reduced-motion: reduce)").matches) { apply(); return; }
  const root = document.documentElement;
  const x = from.left + from.width / 2;
  const y = from.top + from.height / 2;
  const far = Math.hypot(Math.max(x, innerWidth - x), Math.max(y, innerHeight - y));
  // What is on screen gets a delay by its distance from the lamp; the rest needn't wait.
  const delayed: HTMLElement[] = [];
  for (const el of document.body.querySelectorAll<HTMLElement>("*")) {
    const r = el.getBoundingClientRect();
    if (!r.width || r.bottom < 0 || r.top > innerHeight) continue;
    const d = Math.min(1, Math.hypot(r.left + r.width / 2 - x, r.top + r.height / 2 - y) / far);
    el.style.transitionDelay = `${Math.round((night ? 1 - d : d) * RIPPLE)}ms`;
    delayed.push(el);
  }
  root.classList.add("theming");
  root.style.setProperty("--theming", `${EASE}ms`);
  apply();
  genie(night, x, y, far);
  setTimeout(() => {
    root.classList.remove("theming");
    for (const el of delayed) el.style.transitionDelay = "";
  }, RIPPLE + EASE + 60);
}

/**
 * The genie (owner, 2026-11-26): a soft warm ring of light that rides the ripple's front. For day it
 * leaves the lamp and travels out with the change; for night it comes in from the edges and goes
 * back into the lamp, which glints as it goes dark. A ring, never a cover: the page shows through.
 */
function genie(night: boolean, x: number, y: number, far: number) {
  if (!CSS.registerProperty) return;
  document.querySelector(".genie")?.remove();
  const ring = document.createElement("div");
  ring.className = "genie";
  ring.setAttribute("aria-hidden", "true");
  ring.style.setProperty("--gx", `${x}px`);
  ring.style.setProperty("--gy", `${y}px`);
  document.body.append(ring);
  const out = ["0px", `${Math.ceil(far + 120)}px`];
  const ms = RIPPLE + EASE / 2;
  ring.animate([{ "--gr": night ? out[1] : out[0] } as Keyframe, { "--gr": night ? out[0] : out[1] } as Keyframe],
    { duration: ms, easing: night ? "cubic-bezier(.4,0,.8,.6)" : "cubic-bezier(.2,.4,.6,1)", fill: "forwards" });
  ring.animate([{ opacity: 0 }, { opacity: 1, offset: 0.15 }, { opacity: 1, offset: 0.75 }, { opacity: 0 }], { duration: ms, fill: "forwards" })
    .finished.finally(() => ring.remove());
  // The lamp in the switch: it lights as the genie leaves, glints as it returns.
  button?.querySelector(".glint")?.animate(
    [{ opacity: 0, transform: "scale(.5)" }, { opacity: 1, transform: "scale(1.6)", offset: 0.45 }, { opacity: 0, transform: "scale(1)" }],
    { duration: 460, delay: night ? ms - 280 : 0, easing: "ease-out" },
  );
}

if (button && theme) {
  const show = () => button.setAttribute("aria-checked", String(theme.dark));
  show();
  // The change starts the moment the switch clicks, from the lamp in the switch's box.
  const flip = () => shift(!theme.dark, button.querySelector(".lamp")!.getBoundingClientRect(), show);

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
