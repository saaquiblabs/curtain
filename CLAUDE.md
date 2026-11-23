# Curtain

## One ticket per chat

Each chat implements exactly one GitHub issue (usually via `/implement #N`), so context stays small and controllable.

- Don't start the next ticket in the same chat, even if it's unblocked.
- When the ticket is done (acceptance criteria met, reviewed, committed, owner's decision recorded on the issue), close it and end with a ready-to-paste prompt for the next ticket, e.g. `/implement #4`, plus one line on what it covers. The owner runs it in a fresh chat.
- Anything the next chat needs to know goes on the issues or in the repo (comments, docs, commits), never only in this chat.

## Backlog rules (owner, 2026-11-21)

- **No new issues while the open ones are being worked down.** The set is capped (under 10). New
  findings go as a comment on the closest open issue, or into that issue's scope; only the owner
  lifts the cap. 2026-11-22: lifted once for step 3 (umbrella #20 + #21–#27).
  2026-11-22: lifted once more for #29 (critical: never leave every screen black; no v0.3.1 tag until it's fixed).
  2026-11-22: lifted once more for #37 (high: install fails on macOS 26, codesign finds no identity; hotfix 0.4.2).
  2026-11-23: lifted once more for step 6 (umbrella #41 + #42, Curtain's page at curtain.saaquiblabs.com).
- **Every issue sits under an umbrella** as a GitHub sub-issue, never as a loose issue. Umbrella
  today: #20 (Step 3, a menu you understand by looking) and #41 (Step 6, Curtain on the web). Closed: #1 (identity, owner signed off
  2026-11-22) and #6 (Ship 0.3.0).
- **Every issue and umbrella has a severity label**: `severity:critical` (broken or unsafe),
  `severity:high` (core feature fails, can't install or find Curtain), `severity:medium` (works but
  feels unfinished), `severity:low` (polish, can wait). Work goes highest severity first.
- **Code review only when the owner asks**, even though `/implement` says to run it. Ask first.

## Agent skills

### Issue tracker

Issues live in GitHub Issues for saaquiblabs/curtain (via `gh`). See `docs/agents/issue-tracker.md`.

### Triage labels

Default five-role vocabulary (needs-triage, needs-info, ready-for-agent, ready-for-human, wontfix). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `CONTEXT.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.
