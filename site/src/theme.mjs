// Day or night on Curtain's page (#41, 2026-11-26). The page follows the visitor's light/dark
// setting until they pull the lamp in the header; their choice is kept (localStorage) until they
// pull it again. `boot` runs inline at the top of <head> (src/layouts/Base.astro), so a kept choice
// is in place before the first paint: no flash of day at night.
//
// What it sets: <html data-theme="light|dark"> (src/styles/site.css follows it), and the `media`
// of every element marked `data-scheme="light|dark"`: the menu pictures' <source>s, the hero's
// preloads, `theme-color`, the lamp's still. While nothing is chosen they keep their own
// prefers-color-scheme query, so with no script at all the page still follows the visitor's Mac.

export const KEY = "curtain-theme";

/** The `media` for an element meant for `scheme`, with the visitor's `choice` (or none). */
export function mediaFor(scheme, choice) {
  if (choice !== "light" && choice !== "dark") return `(prefers-color-scheme: ${scheme})`;
  return choice === scheme ? "all" : "not all";
}

/** A stored value, as a choice: "light", "dark", or null for none (or anything else). */
export function choiceOf(value) {
  return value === "light" || value === "dark" ? value : null;
}

/**
 * Runs in the page, self-contained (it is inlined with its helpers passed in). Applies a kept
 * choice and exposes `window.curtainTheme` for the lamp.
 */
export function boot(key, mediaFor, choiceOf) {
  const root = document.documentElement;
  let choice = null;
  try { choice = choiceOf(localStorage.getItem(key)); } catch { /* storage blocked: follow the Mac */ }
  const sync = (el) => el.setAttribute("media", mediaFor(el.dataset.scheme, choice));
  const apply = () => {
    if (choice) root.dataset.theme = choice; else delete root.dataset.theme;
    document.querySelectorAll("[data-scheme]").forEach(sync);
  };
  apply();
  if (choice) {
    // Elements below this script aren't parsed yet: set each as it arrives, before its picture is
    // picked (the observer's microtask runs before the image's), then stop at DOMContentLoaded.
    const mo = new MutationObserver((records) => {
      for (const r of records) for (const n of r.addedNodes) if (n.nodeType === 1 && n.dataset.scheme) sync(n);
    });
    mo.observe(root, { childList: true, subtree: true });
    addEventListener("DOMContentLoaded", () => { mo.disconnect(); apply(); }, { once: true });
  }
  const system = matchMedia("(prefers-color-scheme: dark)");
  window.curtainTheme = {
    /** Whether the visitor has chosen (pulled the lamp), rather than following their Mac. */
    get chosen() { return choice !== null; },
    /** Whether the page is at night now. */
    get dark() { return choice ? choice === "dark" : system.matches; },
    /** Keep `theme` ("light" or "dark") until the next pull. */
    choose(theme) {
      choice = choiceOf(theme);
      try { localStorage.setItem(key, choice); } catch { /* kept for this page only */ }
      apply();
    },
    system,
  };
}

/** The inline script for <head>. */
export const bootScript = `(${boot})(${JSON.stringify(KEY)}, ${mediaFor}, ${choiceOf});`;
