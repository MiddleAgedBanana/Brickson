# A one-line index of every decision, loaded by every agent

*2026-11-24. This pull request (`claude/project-thread-enbeij`). Claude,
in a cloud project thread, with no Mac.*

## What changed and why

Nothing changes for a person using Brickson. For the people and agents
working on it: docs/DECISIONS.md has grown to nearly a hundred entries, and
an agent that never reads the right one makes a choice the owner already
settled, or asks the owner to explain it again. A job now starts knowing
every decision in one line each, at a fraction of the cost of reading
the whole file (docs/DECISIONS.md, "A decision index every agent loads").

- `docs/DECISIONS-INDEX.md` holds one line per `##` entry of
  docs/DECISIONS.md, in 19 groups by subject, each naming the entry's
  exact title and what it chose, over what and why. Entries the layout
  engine replaced say so and point to it. About 13.8 KB, under a 15 KB
  limit.
- `.claude/rules/decision-index.md` is a relative symlink to it, so
  Claude Code loads it at the start of every session, in cloud threads
  and on the Mac alike, with no change to `CLAUDE.md`, which stays
  exactly `@AGENTS.md`.
- `AGENTS.md`, *Workflow rules*, now says every recorded decision gets
  its line in the index, and that after a summary an agent re-reads the
  index first. That pointer is how Codex and Antigravity find it.
  `AGENTS.md` stays under its 32 KiB limit (32,512 bytes).
- `scripts/test-docs.py` gains `decision_index_problems` and 11 tests
  in `DecisionIndexTests`. It fails when a `##` entry has no line, when
  a line names a title that is not a heading of docs/DECISIONS.md, when
  a title appears twice, when the index passes its size limit, or when
  the rules symlink is missing or points elsewhere. CI already runs
  this script, so no workflow changed.
- The index holds no relative links, because the link check would read
  them from the symlink's folder; titles are quoted for a text search
  instead.
- `docs/HANDOFF.md` records the state and this record.

## Commits

One commit on `claude/project-thread-enbeij`; see the pull request.

## Verified

In this cloud session, Linux, no Mac:

- `python3 scripts/test-docs.py`: 71 tests pass, 11 of them new. Eight
  build a small decisions file and index and expect the check to fail
  when a decision loses its line, a line names a title that is gone, a
  title has two lines, a line breaks the `- "Title": ...` form, a
  pointer names a title that is gone, or the index passes its limit; and
  to pass for a complete index and for a `##` inside a code block. Three
  read the real files: the index matches docs/DECISIONS.md (98 `##`
  entries, 110 lines, 13,789 bytes), the rules file is a symlink to the
  index, and `AGENTS.md` names it.
- The other Python checks in *Build and test* and the privacy check, as
  the pull request lists.

## Not verified

- No Swift build or test ran here; no app code changed. CI is the build.
- That Claude Code loads a symlinked rules file was read in its
  documentation, not observed in a session started after the merge.
- Whether Codex and Antigravity read the index when they follow the
  `AGENTS.md` pointer.

## Follow-ups

- The first thread started after the merge confirms the index appears
  in its context (Claude, the next job).
