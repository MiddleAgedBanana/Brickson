# AGENTS.md rewritten short, the way the guides recommend

*2026-11-12. Pull request #100 (`codex/agents-md-trim`). Rewritten by a
Claude thread on the owner's Mac; Codex, through the agent bridge
(`scripts/agent-bridge.py`), did the first passes and a read-only review.*

## What changed and why

AGENTS.md went from 83,866 bytes and 1,328 lines to about 27,400 bytes
and 485 lines, one file, with the rules that protect people first. The
owner asked for it to follow the official documentation and reputable
guides, which agree on these points (all read on 2026-11-12):

- **agents.md** (https://agents.md): one AGENTS.md at the root, plain
  Markdown, holding what an agent needs, such as build and test commands,
  conventions, security points and pull request rules. Nested files only
  for the subprojects of a large monorepo.
- **OpenAI Codex**
  (https://developers.openai.com/codex/agent-configuration/agents-md):
  reads only AGENTS.md files, up to 32 KiB by default; code review rules
  go in a `## Code Review Rules` section, kept concise.
- **Anthropic Claude Code** (https://code.claude.com/docs/en/memory and
  https://code.claude.com/docs/en/best-practices): under about 200 lines;
  write only what Claude cannot find by reading the repository; leave out
  architecture and file layout; a rule that can have no exceptions
  belongs in a hook, not in louder words.
- **GitHub**, "How to write a great agents.md: lessons from over 2,500
  repositories" (github.blog, 2025-11-19): commands early, with flags;
  specific stack; clear always, ask-first and never boundaries.
- **AI Hero**, "A complete guide to AGENTS.md", Addy Osmani's "AGENTS.md"
  lesson and Phil Schmid's "Writing a good AGENTS.md": as small as
  possible (150 to 300 lines is the common advice); only what is relevant
  to every task; no stale or discoverable content.

An earlier version of this pull request kept every rule word for word in
one 81,406-byte file, and before that split the file into AGENTS.md and
a second document, `docs/AGENT-REFERENCE.md`. The owner rejected both.

## What was dropped or merged, by kind

- **History and incident stories** (which test failed on which day, which
  pull request found what): dropped. Each is in the `docs/log/` record or
  docs/DECISIONS.md entry that already tells it.
- **Measurements** (old run times, credit counts, contrast ratios of
  forbidden colours, the reference app's gaze sizes in points): dropped;
  they are in docs/DECISIONS.md and the logs.
- **How tools work inside** (what `scripts/test.sh` does step by step, CI's
  artifact names, the guard's full list of refusals, the privacy check's
  internals, the Mac build route through MobileBuildMCP, the keyboard and
  slide probes, how to read a result bundle): dropped or cut to the one
  rule an agent needs. The scripts, hooks and CI enforce or document them
  (`.claude/hooks/guard.py` lists every refusal).
- **Reasons and explanations** behind a rule: dropped where the rule
  itself stays; docs/DECISIONS.md and docs/LESSONS.md keep the why.
- **Duplicates merged**: the review rules that restated the invariants
  now name the invariant in one line each; the reference-app rule, said
  twice, is said once; *Where things are* is four lines.
- **Discoverable reference**: the document map, the list of plain testable
  types, the per-machine skill list and the documentation tools were cut
  to what an agent cannot find for itself.

What stays, shorter but with the same force: the twelve invariants, the
privacy rules, the layout, framework and dwell design rules, every *Code
Review Rules* item, the workflow (test first, staging, branches, pushes,
the privacy check, records), the reference app being read-only, the push
rounds and merge rules, how each reviewer is asked (no `@codex` comment,
reviewers never write code, one Copilot review only through
`request_copilot_review`), the guard rules, and the gotchas that are
places where the code or the tools mislead. Every title that other files
cite is still a heading or bold lead-in, so no other file changed for it.

Also in this pull request:

- **Antigravity's 24,000-byte cut** is named beside Codex's 32 KiB.
- **Codex's hook gap.** AGENTS.md and docs/SDLC.md now say that Codex's
  local hook does not see input typed into a command already running
  (`write_stdin` does not run `PreToolUse` again; Antigravity's
  `send_command_input` is checked), as docs/HANDOFF.md already said.
- **Two record corrections.** docs/log/2026-11-12-jules-wind-down.md:
  #94 was closed without merging at 2026-11-12T05:03Z, and HANDOFF's
  Codex exception is named. docs/log/2026-11-12-no-farther-out.md: the
  Mac was reachable, but CI built and tested the code.
- **Snapshot.** The AGENTS.md this replaces is
  `docs/archive/2026-11-12-before-agents-md-trim/AGENTS.md`, byte for
  byte.

## Commits

See the pull request's commit list. The bridge cannot yet let Codex
commit, so the Claude thread committed.

## Verified

On the owner's Mac (macOS, Python 3). No Swift changes, so nothing was
built outside CI.

- `python3 scripts/test-docs.py` passed: every cited title and link
  resolves, and the sections through *Working with the owner* end well
  inside 32 KiB.
- The new file was read against a checklist of every rule in the old one
  (1,579 single rules), and Codex reviewed it read-only for any rule in
  the privacy, invariant, reference-app, merge and review, or guard
  categories that was lost or weakened. It found twelve, all restored:
  among them the caregiver alerts' random service name, what happens to
  a bug found after the final push, the security-review wait for privacy
  or workflow changes pushed after opening, Copilot's before-opening
  review and no-retry rule, the limits on *Not findings*, a guard change
  that drops a deny rule, reading docs/DECISIONS.md at the start of a
  session, and the re-run-once rule for a timed-out CI run.
- `python3 scripts/privacy-check.py --outgoing` with the private list.

## Not verified

- Rules were rewritten in fewer words, so they were not checked word for
  word against the old file; the old file is in `docs/archive/`.
- Whether each agent follows the shorter file better is not measured.

## Follow-ups

- The same hook gap in `.claude/hooks/guard.py`'s docstring (a code
  change).
- The bridge cannot let a Codex write job commit yet.
