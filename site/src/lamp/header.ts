// The lamp in the header (#41): pull it and the page goes to night (off) or day (lit). Until the
// visitor first moves, scrolls, taps or types, the header shows a still of the lamp (a switch too);
// then the lamp itself is fetched (src/lamp/pull-cord.mjs, about 35 KB) and takes its place. Nothing
// fetches it on a load alone, so the page stays inside tests/verify.mjs's budgets.

interface CurtainTheme {
  readonly chosen: boolean;
  readonly dark: boolean;
  choose(theme: "light" | "dark"): void;
  system: MediaQueryList;
}

const host = document.querySelector<HTMLElement>("[data-lamp]");
const theme = (window as unknown as { curtainTheme?: CurtainTheme }).curtainTheme;

if (host && theme) {
  const still = host.querySelector<HTMLButtonElement>(".lamp-still");
  let lamp: { set(on: boolean): unknown; root: HTMLElement } | null = null;
  const show = () => still?.setAttribute("aria-checked", String(!theme.dark));
  show();

  let loading: Promise<void> | null = null;
  const load = () =>
    (loading ??= import("./pull-cord.mjs").then(({ PullCord }) => {
      const focused = document.activeElement === still;
      lamp = new PullCord(host, { on: !theme.dark, label: "Lights", warmth: 2600 });
      lamp.root.addEventListener("change", (e) => theme.choose((e as CustomEvent).detail.on ? "light" : "dark"));
      still?.remove();
      if (focused) lamp.root.focus();
    }));

  still?.addEventListener("click", () => {
    theme.choose(theme.dark ? "light" : "dark");
    show();
    load();
  });

  const first = ["pointermove", "pointerdown", "keydown", "scroll", "wheel", "touchstart", "focusin"];
  const go = () => {
    for (const t of first) removeEventListener(t, go, true);
    load();
  };
  for (const t of first) addEventListener(t, go, { capture: true, passive: true });

  // Not chosen yet: the lamp follows the visitor's Mac, as the page does.
  theme.system.addEventListener("change", () => {
    if (theme.chosen) return;
    show();
    lamp?.set(!theme.dark);
  });
}
