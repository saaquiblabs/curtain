// The pull switch under the header (#41). Pull its cord and the switch clicks at the bottom of the
// pull, and night or day spreads over the page from the switch in one quick swoosh (owner,
// 2026-11-26: no drapes every time; attention is short).
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
 * Night or day, in one quick swoosh: the new look spreads in a circle from the switch over the old
 * (a View Transition, ~0.5 s). Without View Transitions, or with Reduce Motion, it switches at once.
 */
function swoosh(night: boolean, from: DOMRect, done: () => void) {
  const apply = () => { theme?.choose(night ? "dark" : "light"); done(); };
  const doc = document as Document & { startViewTransition?: (cb: () => void) => { ready: Promise<void> } };
  if (!doc.startViewTransition || matchMedia("(prefers-reduced-motion: reduce)").matches) { apply(); return; }
  const x = from.left + from.width / 2;
  const y = from.top + from.height / 2;
  const r = Math.hypot(Math.max(x, innerWidth - x), Math.max(y, innerHeight - y));
  doc.startViewTransition(apply).ready.then(() => {
    document.documentElement.animate(
      { clipPath: [`circle(0px at ${x}px ${y}px)`, `circle(${r}px at ${x}px ${y}px)`] },
      { duration: 520, easing: "cubic-bezier(.65,0,.35,1)", pseudoElement: "::view-transition-new(root)" },
    );
  }).catch(() => {});
}

if (button && theme) {
  const show = () => button.setAttribute("aria-checked", String(theme.dark));
  show();
  // The swoosh starts the moment the switch clicks, from the switch's box.
  const flip = () => swoosh(!theme.dark, button.querySelector(".box")!.getBoundingClientRect(), show);

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
