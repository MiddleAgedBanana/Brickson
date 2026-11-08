# Ask Copilot right after opening; no `@codex` comments

*2026-11-08. Pull request #92 (`claude/project-thread-nkpzsd`). The same
Claude Code thread as pull request #90, on the owner's Mac. Pull request
#90 merged at its first push, before this round, so its round goes in
this pull request.*

## What changed and why

- **When Copilot is asked.** Pull request #90 said the agent asks for
  Copilot's review "after Codex's review is answered". Codex's
  automatic review on GitHub, set up in the owner's Codex app, reviews
  in its own time, and on pull requests #89 and #92 it posted a notice
  to set up an environment instead of a review, so a request waiting
  for it could wait for nothing. Decided in the thread on 2026-11-08: the agent runs
  Codex's local review before opening a pull request that changes code
  (`codex review --base origin/main`, read-only, where the Codex CLI is
  installed, as on the owner's Mac), answers its findings, and asks for
  Copilot's review right after opening it. Codex's review on GitHub is
  not part of the step. It reviewed pull requests #90 and #91; why it
  posted the notice on #89 and #92 is not known. This answers the first follow-up in
  [`2026-11-08-copilot-review-policy.md`](2026-11-08-copilot-review-policy.md).
  AGENTS.md ("Reviews and updates on GitHub"), docs/DECISIONS.md
  (*Code review*, the 2026-11-08 Copilot bullet), `docs/SDLC.md`,
  `docs/HANDOFF.md`, the guard's refusal message and a test comment say
  so.
- **No `@codex` comments.** AGENTS.md said, since pull request #88, that
  a pull request changing privacy or a workflow asks for
  `@codex security review` in a comment, credited to the owner. It was
  the coordinator's recommendation, and the owner withdrew it on
  2026-11-08: Codex's review runs from the owner's Codex app, and no
  agent writes an `@codex` comment of any kind, as some have Codex push
  code. The sentence is gone from AGENTS.md, and docs/DECISIONS.md,
  *Code review*, records the withdrawal. Codex's local review of this
  pull request flagged that this drops a security review for privacy
  and workflow changes (a weakened review rule, which *Code Review
  Rules* sends to the owner). Something already does that job: Codex's
  GitHub review runs a security review by itself when a pull request
  opens (its summary on pull request #90: "Security Review", trigger
  "PR opened"), so AGENTS.md now says so. CodeRabbit's review of this
  pull request (Major) then pointed out that on this very pull request
  Codex posted the environment notice instead, so nothing ran: it asked
  for a fallback. AGENTS.md and docs/DECISIONS.md now have one: the
  agent says so in the pull request and the thread, and a pull request
  that changes privacy or a workflow waits for the owner to run Codex's
  security review from the Codex app, or another security review,
  before it merges. CodeRabbit's second review (Minor) added that
  Codex's security review runs only when a pull request opens, so a
  privacy or workflow change pushed later is never seen by it; such a
  pull request now waits for the owner's security review too. The
  owner decides; the pull request flags it.

- **Where the guard runs on the Mac.** Right after opening this pull
  request, the agent asked for Copilot's review once, through
  `request_copilot_review`. The guard refused it with its old message
  ("Copilot is not part of Brickson's reviews"), which #90 had removed:
  the session, started from the desktop app in a worktree, ran the
  guard and settings of `~/code/brickson`, the owner's checkout, still
  on `main` from before #90 (`56f228d`), not the worktree's copy. The
  call never ran, so no credits were spent, and it was not retried.
  AGENTS.md, *Guardrails for agents* ("Where the guard runs"), now says
  so, and docs/HANDOFF.md's owner steps say to bring that checkout up
  to date after a merge that changes the guard. The same explains the
  auto-mode refusals in #90's record: editing the worktree's guard
  never changed the guard that was running.

## Commits

See the pull request: one commit for when Copilot is asked, one for the
withdrawn comment, one for saying Codex's review is active, and one that
gives this round its own record, leaving #90's as it merged.

## Verified

On the owner's Mac (macOS 27.2, Python 3.15.2):
`scripts/test-hooks.py`'s Copilot tests (21), `scripts/test-docs.py`
(57) and `scripts/privacy-check.py --outgoing` with the owner's private
list: passed. The guard's change is its refusal message only, which no
test reads word for word. AGENTS.md's sections Codex must read still
end at byte 32,112.

On GitHub: CI passed on `f237ec1`. On `339d6a1` the unit tests and
the iPad UI tests passed, and the iPhone UI tests failed one test of
72, `FoldOffsetUITests/testTheFirstRowClearsATopDivisionInDarkMode`:
"Timed out while launching application via Xcode", before the app
showed anything. Neither commit changes app code, and the same app
passed every UI test on `f237ec1`, so it is the slow-launch failure
AGENTS.md, *Gotchas*, describes; the next push ran the suite again.
Codex's code review and security review of `339d6a1`, asked for from
the owner's account, found no issues.

## Not verified

- CI, until it runs on this pull request.

## Follow-ups

- The owner: bring `~/code/brickson` up to date with `main`
  (docs/HANDOFF.md, *Next steps, in order*, step 5), so Mac sessions
  run #90's guard.
- The first agent to ask for Copilot's review after that: check that
  the guard writes its record (#90's record, *Follow-ups*).
