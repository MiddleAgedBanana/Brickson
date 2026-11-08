# One Copilot review per code pull request; AI Scan off

*2026-11-08. Pull request #90 (`claude/project-thread-nkpzsd`). A
Claude Code thread on the owner's Mac, asked by the coordinator after
the owner's decision of 2026-11-08.*

## What changed and why

The owner keeps the Copilot Pro plan, so the decision of 2026-11-04
("Copilot is no longer a reviewer") no longer holds. From GitHub's AI
usage page, the owner's figures: AI Scan for pull requests used 1,044
of the plan's 1,500 monthly AI credits in October and 1,288 in the
first three days of November, and found nothing; Copilot's 16 reviews
used 644 credits (about 31 to 46 each) and caught real bugs on pull
requests #72, #73, #75 and #76. So the owner turned AI Scan off, keeps
Copilot Autofix (CodeQL's suggested fixes, no credits) on, and has room
for 35 to 50 Copilot reviews a month (docs/DECISIONS.md, "Reviews,
updates and GitHub settings", *Code review*, the 2026-11-08 bullet).

- **The rule** (AGENTS.md, "Reviews and updates on GitHub"): the agent
  that opens a pull request that changes code asks for Copilot's
  review once, right after opening it, through the GitHub tool
  `request_copilot_review` only. Before opening, it runs Codex's local
  review (`codex review --base origin/main`) and answers its findings;
  Codex's automatic review on GitHub, set up in the owner's Codex app,
  is not part of the step: it reviews in its own time, and once, on
  pull request #89, it posted a one-off setup notice instead of a
  review, so waiting for it could leave the request waiting for
  nothing (decided in the thread on 2026-11-08, after the pull request
  opened). It is active: it reviewed pull request #91. A pull request that changes only
  documents gets none. A request that fails for lack of credits is said
  in the pull request and the thread, with no retry.
- **The guard** (`.claude/hooks/guard.py`) lets that one tool through
  again and holds it to one request per pull request, as it did from
  2026-11-03 to 2026-11-04 (commits `bb61376` and `62c69d8`, removed by
  `2acde95`). After a request succeeds, a hook records
  `owner/repo#number` in `brickson-copilot-reviews.json` in the clone's
  Git folder, which every worktree of the clone shares and git never
  commits; before a request, the guard refuses one already recorded. A
  request it cannot read the pull request of (no owner, repo or whole
  number) is refused, because nothing could record it. A failed request
  is not recorded, and one that ran but could not be recorded is told
  to the agent (exit 2). Every other door to Copilot stays shut: `gh`,
  the REST API, a GitHub tool's reviewer or assignee field, a GraphQL
  agent assignment, and every Copilot task.
- **What changed from the 2026-11-03 version:** the Git folder is asked
  for as an absolute path (`--path-format=absolute`), so a session
  started in a folder inside a worktree records in the same place; a
  pull request number must be a whole number above zero (`12.5`, `0`
  and `true` no longer pass as #12, #0 and #1); the error shown when
  the record cannot be written names the kind of error, not its text,
  which can hold a home folder; the lock is skipped where Python has
  no `fcntl`, rather than the guard failing to start, which would block
  every call; and a record that exists but cannot be read (damaged,
  not a list of pull requests, or not a file) refuses every request and
  is never overwritten, where the earlier version read it as empty,
  which let a second request through and then wrote over every earlier
  entry. The refusal says what to do: the owner reads the file and
  moves it aside.
- **`.claude/settings.json`** no longer denies `request_copilot_review`,
  and runs the guard after it (`PostToolUse`), with `onFailure: "block"`
  like every policy hook, so a crash while recording is shown to the
  agent rather than passing unseen.
- **No `@codex` comments.** AGENTS.md said, since pull request #88,
  that a pull request changing privacy or a workflow asks for
  `@codex security review` in a comment, credited to the owner. It was
  the coordinator's recommendation, and the owner withdrew it on
  2026-11-08: Codex's review runs from the owner's Codex app, and no
  agent writes an `@codex` comment of any kind. The sentence is gone
  from AGENTS.md, and docs/DECISIONS.md, *Code review*, records the
  withdrawal. None was posted on this pull request.
- **AI Scan** is off. Its lines in AGENTS.md, `docs/SDLC.md`,
  `docs/HANDOFF.md`, `README.md` and docs/DECISIONS.md, *Code scanning*
  and *`main` ruleset*, now say so.

## Codex's local review

`codex review --base origin/main`, read-only, on the owner's Mac (Codex
CLI 0.167.0), before the pull request opened. Its log records no token
use, so its cost is not known. Two P2 findings, no P0 or P1:

- *A record that cannot be read lets a second request through and loses
  its entries.* Fixed (above), with a failing test first:
  `test_a_damaged_copilot_record_refuses_and_is_kept`, and
  `test_a_request_the_guard_cannot_record_is_told_to_the_agent` now
  expects the refusal.
- *Two sessions asking for the same pull request at the same moment can
  both pass the check before either is recorded.* Declined. Reserving
  the pull request before the call would need the reservation released
  when the call does not run, and when the person declines a call at its
  permission prompt no hook runs after it, so the pull request would be
  refused for good. One agent opens and shepherds each pull request, so
  two at once means an agent broke the rule in AGENTS.md, which review
  holds; the cost at worst is one extra review.

## CodeQL: which setup is live

Checked through GitHub's API on 2026-11-08 (`code-scanning/default-setup`
and every analysis on the repository). CodeQL runs as default setup,
`configured`, for `actions` and `python`, weekly and on every pull
request and push to `main`; its last analyses on `main` were that day,
and no CodeQL alert is open. There is no CodeQL
workflow of the project's own in `.github/workflows`. The stale entry on
the Tool status page is the `/language:swift` configuration: three
failed default-setup analyses on `main` on 2026-10-10, already recorded
in *Code scanning* ("The failed Swift attempt left an error on the Tool
status page"). Deleting it cannot be undone, so the thread asked; with
the owner's yes it was deleted the same day through GitHub's API, the
three analyses newest first (`DELETE
repos/MiddleAgedBanana/Brickson/code-scanning/analyses/<id>?confirm_delete`).
Afterwards the API listed no `/language:swift` analysis, and default
setup was still `configured` for `actions` and `python`.

## Commits

See the pull request: one commit for the guard, its settings and their
tests, one for the documents, and one for each review round.

## Verified

On the owner's Mac (macOS 27.2, Python 3.15.2), in a worktree of the
branch:

- `python3 scripts/test-hooks.py`: 232 tests, all passed, with the
  change. Before the guard and settings changed, the new and changed
  tests failed (22 failures): `test_copilots_review_is_requested_only_through_its_own_tool`,
  `test_copilots_review_is_requested_once_per_pull_request`,
  `test_the_copilot_record_stays_with_the_sessions_project`,
  `test_only_a_successful_copilot_review_request_counts`,
  `test_a_request_the_guard_cannot_record_is_told_to_the_agent`,
  `test_an_unusable_copilot_record_never_crashes_the_guard` (since
  split into `test_a_damaged_copilot_record_refuses_and_is_kept` and
  `test_a_call_with_no_usable_pull_request_records_nothing`),
  `test_the_guard_records_each_copilot_review_request_that_ran` and
  `test_merging_and_copilot_tools_are_denied_outright`. Each names, in
  its comment, the change that makes it fail. Two pin the refusals and
  passed before as after: a request with no readable pull request, and
  a call that names no event or an unknown one.
- The tests start every guard with no `CLAUDE_PROJECT_DIR`, or with a
  throwaway one; after the run, the clone's own Git folder held no
  record file.
- `python3 scripts/test-docs.py` (57 tests), `scripts/test-privacy.py`
  (151) and `scripts/test-runner.py` (99): all passed.
  `python3 scripts/privacy-check.py --outgoing`, with the owner's
  private list: passed.
- AGENTS.md: the sections Codex must read still end at byte 32,112 of
  the 32 KiB it reads; the file grew by about 650 bytes, all past the
  cut.

How it was made: Claude Code's auto mode stopped the agent twice from
editing the guard and its settings, the rules that watch over the agent
itself. The change was prepared and tested in a scratch copy of the
repository, and the owner replied "go ahead and edit the guard" in the
thread before it was applied here. This worktree's own setting pointed
`core.hooksPath` at the main checkout's hooks, so pushes from it would
have skipped its own privacy hook (`privacy-check.py --status`); it was
set to `.githooks` for this worktree only (`git config --worktree`).

## Not verified

- CI, until it runs on the pull request.
- The Tool status page itself: the Swift configuration's deletion was
  checked through GitHub's API only.
- That Claude Code runs the guard after a real `request_copilot_review`
  call and writes the record: no Copilot review was requested, because
  the policy is not merged. The first code pull request after the merge
  is the first real run; its agent checks that the record file exists
  in the clone's Git folder afterwards.
- That AI Scan is off: GitHub's API shows no setting for it, and no AI
  Scan run appears among the repository's workflow runs since
  2026-11-05. The change is the owner's, as the owner described it.
- Whether a failed Copilot request reaches the hook as
  `PostToolUseFailure` or as a `PostToolUse` whose response carries the
  error. A `PostToolUse` is recorded either way, which can only refuse a
  second request, never allow one.

## Follow-ups

- The first agent to ask for Copilot's review after the merge: check
  that `brickson-copilot-reviews.json` appeared in the clone's Git
  folder (`git rev-parse --git-common-dir`), and say so in its record.
