# Curtain

## One ticket per chat

Each chat implements exactly one GitHub issue (usually via `/implement #N`), so context stays small and controllable.

- Don't start the next ticket in the same chat, even if it's unblocked.
- When the ticket is done (acceptance criteria met, reviewed, committed, owner's decision recorded on the issue), close it and end with a ready-to-paste prompt for the next ticket, e.g. `/implement #4`, plus one line on what it covers. The owner runs it in a fresh chat.
- Anything the next chat needs to know goes on the issues or in the repo (comments, docs, commits), never only in this chat.

## Agent skills

### Issue tracker

Issues live in GitHub Issues for saaquiblabs/curtain (via `gh`). See `docs/agents/issue-tracker.md`.

### Triage labels

Default five-role vocabulary (needs-triage, needs-info, ready-for-agent, ready-for-human, wontfix). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `CONTEXT.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.
