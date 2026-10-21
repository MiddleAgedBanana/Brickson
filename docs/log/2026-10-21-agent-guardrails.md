# Agent guardrails: a guard, a docs check, an issue form and a verifier

*2026-10-21. Pull request #17 (`claude/project-thread-v6agjh`). The
"Project guardrails" thread, from the repository review on PR #15.*

## What changed and why

Agents push and open pull requests as the owner's GitHub account, so
nothing on GitHub told an agent's merge from the owner's, and AGENTS.md's
"never" rules were advisory only (`docs/recon/2026-10-21/repo-review.md`,
sdlc-2, sdlc-6, sdlc-7, sdlc-12, sdlc-16). Nothing in the app changes.

- `.claude/settings.json` and `.claude/hooks/guard.py`: a Claude Code
  guard run before every Bash command and the GitHub tools that can merge
  or write. It refuses staging everything (`git add -A`, `--all`, `-u`,
  `.`, `git commit -a`), force pushes, any push that updates `main`
  (including `--repo`, `:` and a bare push from `main`), merging,
  auto-merging or approving a pull request through `gh`, the API, `curl`
  or a GitHub tool, Copilot reviews and tasks, and GitHub tools writing
  onto `main`. It reads wrapped shells (`env bash -c`, `$(...)`). The
  merge and Copilot tools are also in `permissions.deny`.
- `scripts/test-hooks.py`: tests that feed the guard the calls it must
  refuse and the ones it must let through, and that every guarded tool
  stays hooked.
- `scripts/test-docs.py`: every section cited by title and every relative
  Markdown link (with or without a title) must resolve, outside
  `docs/archive/` and `docs/recon/`. It found one broken citation on
  `main` (HANDOFF's *Known gaps* heading), fixed here before PR #15's
  rewrite.
- `scripts/test.sh` runs both before the unit tests, so the "Unit tests"
  job runs them; `.github/workflows` is unchanged.
- `.github/ISSUE_TEMPLATE/something-went-wrong.yml` and `config.yml`: the
  bug form, opening with a warning that issues are public. Blank issues
  are off.
- `.claude/agents/verifier.md`: a report-only subagent that runs the
  Python checks, reads the branch's CI run and lists what was not
  verified.
- AGENTS.md: *Guardrails for agents*, and a review rule against loosening
  the guard.

## Commits

`a256e4e`..`71de3cf`, then a merge of `main` after PRs #13 and #15. Fixes
for CodeQL's "Incomplete URL substring sanitization" alert (`6da08df`)
and Codex's seven findings (`00c9bf5`, `cfd8eb0`, `4555484`).

## Verified

- Linux cloud session, Python 3.13: `test-docs.py`, `test-hooks.py`,
  `test-site.py`, `test-runner.py` and `test-select-xcode.py` pass.
  Removing the guard's `gh pr merge` rule, or renaming the cited
  "Orientations" heading in DECISIONS.md, made the suites fail.
- GitHub CI on `651e197`: Unit tests and UI tests green, so the new
  checks ran inside `scripts/test.sh` on GitHub's Mac. CodeQL green on
  `71de3cf`. No Swift was built in the cloud session.

## Not verified

- The guard runs only in Claude Code sessions with one repository; Claude
  Code's documentation says a session cloning several ignores repository
  hooks. Codex, Jules and the owner are covered by review only.
- Whether this session's own Claude Code reloaded the new settings
  mid-session was not checked.
- The form adds GitHub's default `bug` label; the triage labels the review
  suggests do not exist yet.

## Follow-ups

- *(owner)* Create the triage labels (needs-triage, needs-info,
  ready-for-agent, ready-for-human, crash, device-check) under Issues,
  Labels, if wanted.
- A gap hunt on the guard was stopped early to save usage; Codex's next
  review is the remaining check.
