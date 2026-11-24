# A one-line index of every decision

*2026-11-24. This pull request (`claude/project-thread-enbeij`). Claude,
first in a cloud project thread with no Mac, then on the owner's Mac.*

## What changed and why

Nothing changes for a person using Brickson. For the people and agents
working on it: docs/DECISIONS.md has grown to nearly a hundred entries, and
an agent that never reads the right one makes a choice the owner already
settled, or asks the owner to explain it again. Every agent is now sent
to a one-line summary of each decision before it decides anything, and
from there to the full entries its work touches (docs/DECISIONS.md, "A
one-line index of every decision").

- `docs/DECISIONS-INDEX.md` holds one line per `##` and `###` entry of
  docs/DECISIONS.md, in 19 groups by subject, each naming the entry's
  exact title and what it chose, over what and why. Entries the layout
  engine replaced say so and point to it. 13,964 bytes, under a 15 KiB
  limit.
- `AGENTS.md`, which every agent reads at the start of every session,
  points to it twice. Its opening says to read the groups the work
  touches before deciding anything, and *Workflow rules* starts each
  session with those groups and their full entries, in place of reading
  all of docs/DECISIONS.md, which at over 500 KB no session did. The
  same section says every recorded decision gets its line in the index,
  and that after a summary an agent re-reads the index first.
  `AGENTS.md` stays under its 32 KiB limit (32,683 bytes), and both
  pointers fall inside the first 24,000 bytes, which is all Antigravity
  reads.
- The first commit loaded the whole index into every Claude Code session
  through a symlink, `.claude/rules/decision-index.md`. The review
  commit removes it: whatever loads at the start stays with a job for its
  whole length, whether or not it decides anything; the pointer in
  `AGENTS.md` reaches Codex and Antigravity as well; and `AGENTS.md`
  says agent instructions never go in an agent-specific file.
- `scripts/test-docs.py` gains `decision_index_problems` and 10 tests in
  `DecisionIndexTests`. It fails when a decision has no line, when a line
  names a title that is not a heading of docs/DECISIONS.md, when a title
  appears twice, when a line breaks the `- "Title": ...` form, when a
  `see "Title"` pointer, in either case, names no decision, when the
  index passes its size limit, or when `AGENTS.md` stops naming the
  index in its first 24,000 bytes. Each test expects its own problem and
  no other, so none passes on a problem its edit happens to cause. CI
  already runs this script, so no workflow changed.
- Titles in the index are quoted for a text search rather than linked.
- `docs/HANDOFF.md` records the state and this record.

## Review

Nine review conversations on the first commit, all answered on the pull
request:

- Three asked for the owner's decision on a new file agents read. The
  rule leaves it to the owner, so the pull request lists the index and
  the changed start of a session for the owner, and the merge is that
  decision. The symlink that loaded the index into every session is
  gone.
- The start of a session now reads the index (above).
- A capitalised `See "Title"` pointer was not checked; it is now, with a
  test.
- A test of the line form passed on another problem its edit caused;
  every index test now expects its own problem and no other.
- The line for "Show Borders and the Large Content Viewer on Home" left
  out that Home's controls, except Settings' gear, never get the Large
  Content Viewer; it says so now.
- This record's *Commits* now names its commits.

## Commits

- `aea358c`: the index, the symlink that loaded it, `decision_index_problems`
  and its tests, the `AGENTS.md` rule, this record, docs/DECISIONS.md
  and docs/HANDOFF.md.
- The commit that adds this line: the answers to the review above, the
  symlink replaced by the pointers in `AGENTS.md`, the decision renamed
  "A one-line index of every decision", and this record, docs/DECISIONS.md
  and docs/HANDOFF.md brought up to date.

## Verified

- First commit, in the cloud session (Linux, no Mac):
  `python3 scripts/test-docs.py` passed 71 tests.
- Review commit, on the owner's Mac: the five Python checks as
  `scripts/test.sh` runs them before the unit tests (`test-docs.py`,
  `test-hooks.py`, `test-privacy.py`, `test-agent-bridge.py`,
  `test-forbidden-code.py`) all pass; `test-docs.py` runs 70 tests, 10
  of them in `DecisionIndexTests`, which read the real files too: the
  index matches docs/DECISIONS.md (98 `##` and 12 `###` entries, 110
  lines) and `AGENTS.md` names it in its first 24,000 bytes. With the
  decision renamed in docs/DECISIONS.md and not yet in the index, the
  check failed on both lines, as it should.
- The privacy check on the outgoing commits and on the pull request
  text.

## Not verified

- No Swift build or test ran here; no app code changed. CI is the build.
- Whether Codex and Antigravity read the index when `AGENTS.md` sends
  them to it, and whether every Claude Code job does before deciding.

## Follow-ups

- The next jobs show whether agents read the index before deciding;
  where one does not, the fix is a sharper pointer in `AGENTS.md`'s
  opening, never the whole index loaded into every session.
