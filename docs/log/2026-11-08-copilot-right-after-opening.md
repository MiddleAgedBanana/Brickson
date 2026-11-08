# Ask Copilot right after opening; no `@codex` comments

*2026-11-08. Pull request #92 (`claude/project-thread-nkpzsd`). The same
Claude Code thread as pull request #90, on the owner's Mac. Pull request
#90 merged at its first push, before this round, so its round goes in
this pull request.*

## What changed and why

- **When Copilot is asked.** Pull request #90 said the agent asks for
  Copilot's review "after Codex's review is answered". Codex's
  automatic review on GitHub, set up in the owner's Codex app, reviews
  in its own time, and once, on pull request #89, it posted a one-off
  setup notice instead of a review, so a request waiting for it could
  wait for nothing. Decided in the thread on 2026-11-08: the agent runs
  Codex's local review before opening a pull request that changes code
  (`codex review --base origin/main`, read-only, where the Codex CLI is
  installed, as on the owner's Mac), answers its findings, and asks for
  Copilot's review right after opening it. Codex's review on GitHub is
  not part of the step; it is active (it reviewed pull requests #90 and
  #91). This answers the first follow-up in
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
  "PR opened"), so AGENTS.md now says so. The owner decides; the pull
  request flags it.

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

## Not verified

- CI, until it runs on this pull request.

## Follow-ups

None new. The other follow-up of #90's record (check that the guard
writes its record after a real Copilot request) stays with the first
agent that asks for one.
