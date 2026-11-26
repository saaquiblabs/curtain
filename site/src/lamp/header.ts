// The pull switch under the header (#41). Pull its cord and the switch clicks at the bottom of the
// pull. For day, light spreads from the switch's lamp over the page; for night, it draws back
// into the lamp (owner, 2026-11-26: a genie's lamp, subtle and slow; no drapes every time).
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
 * The switch's lamp is the source of the light (owner, 2026-11-26: like a genie's lamp). Pulled for
 * day, warm light blooms from the lamp with a soft edge and slowly spreads over the whole page, the
 * page turns to day beneath it, and the light settles away. Pulled for night, the page fills with
 * that light, turns to night beneath it, and the light draws back into the lamp. Drawn live over the
 * page (no snapshot, so the page's weave never shimmers); with Reduce Motion, or without
 * registered custom properties, it switches at once.
 */
function glow(night: boolean, from: DOMRect, done: () => void) {
  const apply = () => { theme?.choose(night ? "dark" : "light"); done(); };
  if (matchMedia("(prefers-reduced-motion: reduce)").matches || !CSS.registerProperty) { apply(); return; }
  document.querySelector(".light")?.remove();
  const x = from.left + from.width / 2;
  const y = from.top + from.height / 2;
  // The soft edge's bright core is 55% of the radius: grow until the core covers the far corner.
  const far = `${Math.ceil(Math.hypot(Math.max(x, innerWidth - x), Math.max(y, innerHeight - y)) / 0.55)}px`;
  const light = document.createElement("div");
  light.className = "light";
  light.setAttribute("aria-hidden", "true");
  light.style.setProperty("--lx", `${x}px`);
  light.style.setProperty("--ly", `${y}px`);
  const root = document.documentElement;
  root.classList.add("glowing"); // the lamp stays in sight above its light
  document.body.append(light);
  const ease = "cubic-bezier(.45,0,.2,1)";
  const run = (k: Keyframe[], ms: number, easing = ease) => light.animate(k, { duration: ms, easing, fill: "forwards" }).finished;
  const end = () => { light.remove(); if (!document.querySelector(".light")) root.classList.remove("glowing"); };
  if (!night) {
    run([{ "--lr": "0px" } as Keyframe, { "--lr": far } as Keyframe], 1100)
      .then(() => { apply(); return run([{ opacity: 1 }, { opacity: 0 }], 500, "ease-out"); })
      .catch(() => apply()).finally(end);
  } else {
    light.style.setProperty("--lr", far);
    run([{ opacity: 0 }, { opacity: 1 }], 220, "ease-in")
      .then(() => { apply(); return run([{ "--lr": far } as Keyframe, { "--lr": "0px" } as Keyframe], 1100); })
      .catch(() => apply()).finally(end);
  }
}

if (button && theme) {
  const show = () => button.setAttribute("aria-checked", String(theme.dark));
  show();
  // The light starts the moment the switch clicks, from the lamp in the switch's box.
  const flip = () => glow(!theme.dark, button.querySelector(".lamp")!.getBoundingClientRect(), show);

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
