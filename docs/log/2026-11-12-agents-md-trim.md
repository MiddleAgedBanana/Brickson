# AGENTS.md kept as one file, with its history cut

*2026-11-12. Pull request #100 (`codex/agents-md-trim`). Written by Codex
through the agent bridge (`scripts/agent-bridge.py`), checked and finished
by a Claude thread on the owner's Mac.*

## What changed and why

AGENTS.md stays one file holding every rule. Only history, incident
stories and measurements that a record already holds were removed, each
replaced by a pointer to that record. It went from 83,866 to 81,406
bytes and from 1,328 to 1,302 lines.

The pull request first tried to fit Antigravity's 24,000-byte cut. That
attempt moved the long reference material into a second document,
`docs/AGENT-REFERENCE.md`, and left short rules and pointers in
AGENTS.md (35,475 bytes). The owner rejected a rule file split across two
documents and asked for AGENTS.md to follow https://agents.md, OpenAI's
Codex documentation and Anthropic's Claude Code documentation. What they
say, read on 2026-11-12:

- **agents.md:** one AGENTS.md at the root of the repository, in plain
  Markdown with no required fields, holding what an agent needs: build
  and test commands, conventions, security points, pull request rules,
  "anything you'd tell a new teammate". The only split it names is
  nested AGENTS.md files for the subprojects of a large monorepo, where
  the file nearest the edited code wins. It says nothing about size or
  about linking to other documents.
- **Codex:** reads the AGENTS.md files from the repository root down to
  its working folder, up to `project_doc_max_bytes` (32 KiB by default),
  and no other file. When instructions pass the limit, it says to raise
  the limit or split them across nested folders. Code review rules go in
  a `## Code Review Rules` section of AGENTS.md, kept concise.
- **Claude Code:** reads AGENTS.md (here through `CLAUDE.md`, which
  imports it, a documented setup). It suggests keeping an instruction
  file under 200 lines, because longer files cost context and are
  followed less closely, and moving multi-step procedures or rules for
  one part of the code into skills or path-scoped rules.

None of them forbids a second document, but none loads one, so a rule
that lives only there is a rule no agent reads unless it chooses to. So
every rule stays in AGENTS.md, and docs/AGENT-REFERENCE.md is gone.

The cost, said plainly. Keeping every rule makes the file far longer
than Codex reads by default and than Claude Code suggests. What protects
people still comes first: the invariants end at byte 8,473 and *Code
Review Rules* at byte 25,133, and the sections Codex must read end at
byte 32,215, inside its default 32 KiB (`scripts/test-docs.py` checks
that). A Codex at its default setting reads no further; on the owner's
Mac Codex reads 131,072 bytes, so all of it. Claude Code and the
reviewers load all of it. Antigravity reads its first 24,000 bytes,
which end inside *Code Review Rules*, and on the owner's Mac a standing
rule makes it read the rest. Making the file much shorter means deciding
that some rules are not needed, which is the owner's choice and is not
made here.

Also in this pull request:

- **Antigravity's cut** is named beside Codex's 32 KiB in the
  introduction.
- **Codex's hook gap.** AGENTS.md (*Guardrails for agents*, *The guard*)
  and docs/SDLC.md said git-ignored hooks hold Codex and Antigravity to
  what the guard refuses with no exception. They now say that Codex's
  hook does not see input typed into a command already running (its
  `write_stdin` does not run `PreToolUse` again; Antigravity's
  `send_command_input` is checked), as docs/HANDOFF.md already said, and
  that it acts only inside a Brickson checkout.
- **Two record corrections.** docs/log/2026-11-12-jules-wind-down.md
  claimed more than docs/HANDOFF.md said, and said #94 is reviewed like
  any other pull request; #94 was closed without merging at
  2026-11-12T05:03Z. docs/log/2026-11-12-no-farther-out.md said its
  session had no route to a Mac; the Mac was reachable, but CI built and
  tested the code.
- **Snapshot.** The AGENTS.md this replaces is in
  `docs/archive/2026-11-12-before-agents-md-trim/AGENTS.md`, byte for
  byte.

## What was removed

Only sentences that state no rule and that a record already holds:
dated incident stories (for example how a RocketSim tap, a voice
service or a wallpaper task failed on a given day), measurements (the
unit job's old run times, credit counts) and the pull request numbers
they happened on. Each place now cites the record that tells the story.
Nothing in the twelve invariants or *Code Review Rules* changed.

## Commits

See the pull request's commit list. The bridge cannot yet let Codex
commit (its sandbox cannot write a worktree's git folder), so the Claude
thread committed after checking.

## Verified

On the owner's Mac (macOS, Python 3). No Swift changes, so nothing was
built outside CI.

- A gate built from a checklist of every rule in the old AGENTS.md (1,579
  single rules, each listed by one agent and checked for gaps by a
  second): each of the 910 binding ones (obligations, prohibitions,
  exceptions and limits) still has its exact words in AGENTS.md, and the
  invariants and *Code Review Rules* are unchanged. The introduction was
  checked by hand.
- Each removed story and measurement was looked up in the record it
  now cites (the longest fourteen by searching for their own words).
- `python3 scripts/test-docs.py` and
  `python3 scripts/privacy-check.py --outgoing` (with the private list).

## Not verified

- The 669 facts and pointers in the checklist were not gated word for
  word: the removed ones are the stories and measurements above, each
  held by the record it cites.
- Whether Codex's review on GitHub or Codex cloud reads past 32 KiB is
  still not documented.
- Nothing was built or run: there is no Swift change. CI is the build.

## Follow-ups

- **The owner:** whether to make AGENTS.md shorter by dropping rules
  that are not needed in every session, or by moving folder-specific
  ones into nested AGENTS.md files, which agents.md and Codex name for
  this case. Either is a choice about rules.
- **A later code change:** the same hook gap in the docstring of
  `.claude/hooks/guard.py`.
- **The bridge:** let a Codex write job commit (recorded as the bridge's
  next item).
