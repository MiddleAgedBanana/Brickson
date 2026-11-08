# Repository-wide security review context

*2026-11-08. `codex/security-policy`, based on fetched `main`
at `83abbb5ef8d987caacd8c28c5e81bcde77e69123`.*

## What changed and why

Added root [SECURITY.md](../../SECURITY.md) as approved in the policy chat,
including the existing restriction on third-party keyboard extensions.
The existing [.github/SECURITY.md](../../.github/SECURITY.md) remains
unchanged: it explains private reporting and supported versions, while
the root policy provides review context for the app, tooling, CI and
website. docs/DECISIONS.md, "Security review context", records the split;
docs/HANDOFF.md links the policy beside the code-scanning limits.

The policy summarizes existing requirements and decisions, with no new
accepted risks, blanket exclusions, severity caps or review commands.
No app behavior, accessibility API, privacy promise, workflow, guard or
release gate changes. AGENTS.md remains the shared source of review rules.

This task makes no checkout changes or file edits in the primary checkout.
Work lives in a separate local worktree. After approving the local files,
the owner authorized committing them, pushing the topic branch and opening
a draft pull request into `main`, then requesting CodeRabbit's review.
No Copilot review is requested for this documentation-only change, and no
Greptile or cubic request, merge, approval or auto-merge is authorized.

## Commits

One commit for the policy and its companion documentation; see the pull
request's commit list.

## Verified

On the owner's Mac, macOS 27.2 and Python 3.15.2:

- `CI=true scripts/test.sh unit`: passed with Xcode 27.2 (27B52) and
  XcodeGen 2.46.0 on the iPad Pro 13-inch (M5) simulator, iOS 27.2.
  950 cases ran: 939 passed, zero failed, one existing documented skip
  and ten expected failures. The String Catalog stayed unchanged.
  This was a unit run, not a UI-flow or keyboard measurement. The
  script also passed 57 docs, 232 hook and 151 privacy-check tests.
- `python3 -B scripts/test-docs.py`: 57 tests passed.
- `python3 -B scripts/test-hooks.py`: 232 tests passed.
- `python3 -B scripts/test-privacy.py`: 151 tests passed.
- `python3 -B scripts/test-site.py`: 7 tests passed.
- `python3 -B scripts/test-select-xcode.py`: 23 tests passed.
- `python3 -B scripts/test-runner.py`: 99 tests passed with host process
  access. The first sandboxed run had two errors because `/bin/ps` was
  blocked; the unchanged suite passed with the required permission.
- `python3 -B scripts/privacy-check.py --outgoing`: no findings, using
  the private list and built-in patterns. Separate `--text` checks of the
  new policy and this record also found nothing with both controls.
- `git diff --check`: passed.
- This worktree explicitly sets `core.hooksPath` to `.githooks` in its
  worktree configuration, so its pre-push privacy hook runs.
- The installed Codex Security policy resolver lists exactly `SECURITY.md`
  and `.github/SECURITY.md`. Root, app, scripts and website scopes resolve
  to the root policy. The workflow scope resolves root first, then the
  unchanged reporting policy. Both are regular files inside the checkout
  and below the resolver's 1 MiB limit. The reporting policy matches its
  base-commit bytes.

## Not verified

- No UI suite or physical-device check: this change is documentation only.
- No security scan, hosted CI or external review. Policy resolution
  establishes which context applies, not that security properties hold.

## Follow-ups

- Keep the pull request a draft until its current-head CI and applicable
  reviews are complete. The root policy is reviewer instructions, not a
  completed security review. Under AGENTS.md, if Codex's bot posts only
  its environment-setup notice instead of reviewing, this pull request
  waits for the owner's security review from the Codex app before merging.
  The owner reads the diff and decides whether to merge.
