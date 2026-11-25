// CHANGELOG.md → the /changelog page, at build time, so the page is the file (tests/changelog.test.mjs).
// It reads only the shapes the file uses: "## <version> — <date>" headings, paragraphs, "- " lists
// whose items wrap onto lines indented by two spaces, **bold**, `code` and issue numbers (#20).
// Plain JS so `node --test` can import it without a build.

const esc = (s) => s.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;");

/** One line of the file as HTML: escaped, `code` kept literal, **bold**, #n linked to the issue. */
export function inline(text, repo) {
  return text
    .split("`")
    .map((part, i) =>
      i % 2
        ? `<code>${esc(part)}</code>`
        : esc(part)
            .replace(/\*\*(.+?)\*\*/g, "<b>$1</b>")
            .replace(/(^|[^\w&])#(\d+)\b/g, `$1<a href="${repo}/issues/$2">#$2</a>`),
    )
    .join("");
}

/**
 * @returns {{ version: string, date: string, blocks: ({ type: "p", html: string } | { type: "ul", items: string[] })[] }[]}
 */
export function parseChangelog(md, repo) {
  const versions = [];
  for (const section of md.split(/^## /m).slice(1)) {
    const [heading, ...rest] = section.split("\n");
    const [, version, date] = heading.match(/^(\S+)\s+—\s+(\S+)/) ?? [];
    if (!version) throw new Error(`CHANGELOG.md: can't read the heading "## ${heading}"`);
    const blocks = rest
      .join("\n")
      .split(/\n\s*\n/)
      .map((b) => b.trim())
      .filter(Boolean)
      .map((b) =>
        b.startsWith("- ")
          ? { type: "ul", items: b.slice(2).split(/\n- /).map((item) => inline(item.replace(/\s*\n\s*/g, " "), repo)) }
          : { type: "p", html: inline(b.replace(/\s*\n\s*/g, " "), repo) },
      );
    versions.push({ version, date, blocks });
  }
  return versions;
}
