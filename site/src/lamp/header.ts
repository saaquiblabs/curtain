// The pull cord under the header (#41): pull it and the drapes cross the page, close, and open on
// night or day. Until the visitor first moves, scrolls, taps or types, a still of the cord shows (a
// switch too); then the cord itself is fetched (src/lamp/pull-cord.mjs, about 35 KB) and takes its
// place. Nothing fetches it on a load alone, so the page stays inside tests/verify.mjs's budgets.

interface CurtainTheme {
  readonly chosen: boolean;
  readonly dark: boolean;
  choose(theme: "light" | "dark"): void;
  system: MediaQueryList;
}

const host = document.querySelector<HTMLElement>("[data-lamp]");
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
  const ease = "cubic-bezier(.65,0,.35,1)"; // --drape, the app's 720 ms drapes
  const move = (el: HTMLElement, from: string, to: string, ms: number) =>
    el.animate([{ transform: `translateX(${from})` }, { transform: `translateX(${to})` }], { duration: ms, easing: ease, fill: "forwards" }).finished;
  Promise.all([move(l, "-100%", "0", 520), move(r, "100%", "0", 520)])
    .then(() => {
      theme?.choose(night ? "dark" : "light");
      done();
      return new Promise((ok) => setTimeout(ok, 120));
    })
    .then(() => Promise.all([move(l, "0", "-100%", 720), move(r, "0", "100%", 720)]))
    .finally(() => drapes.remove());
}

if (host && theme) {
  const still = host.querySelector<HTMLButtonElement>(".lamp-still");
  let cord: { set(on: boolean, o?: { instant?: boolean }): unknown; root: HTMLElement } | null = null;
  const show = () => {
    still?.setAttribute("aria-checked", String(!theme.dark));
    cord?.set(!theme.dark, { instant: true });
  };
  show();

  let loading: Promise<void> | null = null;
  const load = () =>
    (loading ??= import("./pull-cord.mjs").then(({ PullCord }) => {
      const focused = document.activeElement === still;
      cord = new PullCord(host, { on: !theme.dark, label: "Lights", cordOnly: true, cord: 0.5, light: 0 });
      cord.root.addEventListener("change", (e) => sweep(!(e as CustomEvent).detail.on, show));
      still?.remove();
      if (focused) cord.root.focus();
    }));

  still?.addEventListener("click", () => {
    sweep(!theme.dark, show);
    load();
  });

  const first = ["pointermove", "pointerdown", "keydown", "scroll", "wheel", "touchstart", "focusin"];
  const go = () => {
    for (const t of first) removeEventListener(t, go, true);
    load();
  };
  for (const t of first) addEventListener(t, go, { capture: true, passive: true });

  // Not chosen yet: the cord follows the visitor's Mac, as the page does.
  theme.system.addEventListener("change", () => {
    if (!theme.chosen) show();
  });
}
