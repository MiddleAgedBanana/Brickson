# Reconcile the agent guardrails and close the review gaps

*2026-10-22. Pull request #17 (`claude/project-thread-v6agjh`), prepared
on `codex/pr17-reconcile`. Codex.*

## What changed and why

Merged `main` at `5abdd9f` into PR #17 without rebasing, preserving the
guardrail work and the changes that landed afterwards, including Voice
Settings. The pending merge was refreshed when `main` advanced; the guard
fixes were saved and verified before restoring them over the new merge.
The original account stays in [`2026-10-21-agent-guardrails.md`](2026-10-21-agent-guardrails.md).
This separate reconciliation record was requested for the handoff between
agents. It adds no app behaviour and makes no new product decision.

The nine open Codex findings were ordinary command forms the guard did
not understand. The fixes keep the same rules in AGENTS.md, *Guardrails
for agents*:

- Push destinations are checked as both short branch names and complete
  refs, including wildcard patterns. A bare push reads the selected
  remote's configured refspecs and `push.default`; repository selectors
  and command-local Git configuration also apply to the read-only queries.
- Wrapper options keep their operands together, so `env -u` and
  `timeout 5s` cannot hide a command. A failed `cd` preserves the previous
  working directory; `&&` and `||` choose the possible outcomes before
  checking the next command.
- Copilot issue assignments and attached reviewer options are refused,
  as are attached true approval flags. Removing a Copilot assignment or
  requesting a human reviewer remains allowed.
- GitHub API bodies read from files are inspected too, including gh
  typed fields and curl/wget payloads. JSON escapes are decoded. Stdin,
  unreadable files, non-regular files and payloads above one MiB are
  refused because the hook cannot inspect them reliably. The guard
  remains a check against mistakes, not a shell sandbox.
- The throwaway test repository disables signing and hooks for its one
  fixture commit, so personal Git settings cannot make that test need
  interaction. The user's repository settings are untouched.

The report-only verifier and independent review found four adjacent
ordinary forms before the Xcode runs. The guard now also carries Git
environment selectors through command prefixes and nested shells, reads
separate `sudo` option operands, inspects Copilot assignees on issue
create/update endpoints, and refuses REST branch merges whose base is
`main` or `master`. Feature-branch pushes and merges, human assignments,
and comments mentioning Copilot remain allowed. GitHub documents the
[issue assignment endpoints](https://docs.github.com/en/enterprise-cloud%40latest/copilot/how-tos/use-copilot-agents/cloud-agent/use-cloud-agent-via-the-api)
and the [branch merge endpoint](https://docs.github.com/en/rest/branches/branches#merge-a-branch).
The test script's old "take a second" comment was inaccurate for the
expanded guard suite; it now says only that these checks need no simulator.

The two temporary DECISIONS exceptions in `scripts/test-docs.py` are
removed: "Home's slot plan" and "First launch opens Home; setup lives in
Settings" now exist on `main`. The two reference-app exceptions remain.
Running the checker after the merge found two stale citation titles in
`SettingsIdleClock.swift` and the phone-layout record. Their exact titles
are corrected; the historical record otherwise stays as written. The
verifier now describes the UI script's iPad and iPhone runs and asks for
the actual text-size, appearance and orientation coverage of each test.

At the owner's request, AGENTS.md now records the shared collaboration
habits: fetch and read the current main briefing, handoff, decisions and
newest logs at session start; start each piece of work from main; merge
moving main with a merge commit, never rebase; preserve an existing PR
body's first two attribution lines; rerun the appropriate test script
before each push and batch commits to avoid cancelling CI. Incorrect
documentation must be recorded with a proposed correction rather than
silently worked around. These clarify workflow without weakening any
invariant, review rule or test gate. The existing work-log and HANDOFF
requirements remain.

## Commits

- `1b6ccb6`: PR #17 before reconciliation.
- `5abdd9f`: the `main` revision included in the merge.
- The merge and review fixes are prepared together. The full local unit
  and both device UI gates are green; final CI is pending.

## Verified

On a Mac; Python checks used Python 3.15.0 unless noted:

- Added the reproductions before changing the guard: 33 failing subcases
  across the first 25 test methods. Two related API-path tests then
  reproduced five more failures before their fix. Independent review
  caught the broader `refs/*:refs/*` pattern; its new subcase failed before
  the canonical-ref match was added.
- `scripts/test-hooks.py`: 31 tests passed in 7.543 seconds after the final
  adjacent fixes. Issue create/update reproduced 10 failing subcases first;
  Git environment selectors, sudo operands and REST merges reproduced
  14 more failing subcases before their fixes. The commands under test are
  supplied as strings to the hook; no push, review, Copilot request or
  other remote mutation is executed. Git fixtures use temporary local
  repositories and configuration only.
- Independent review then checked 28 inline/environment/sudo/API commands
  and four file-backed payloads. The reported unsafe forms were denied;
  feature pushes and merges, unsetting the Git selector, named-path
  staging, human assignments and comment reviews remained allowed. No
  actionable regression was found in those changes.
- `scripts/test-docs.py`: 11 tests passed after deleting the obsolete
  exceptions and correcting the two citations; all 11 passed again after
  the owner-requested workflow clarifications and adjacent guard fixes.
- Earlier, after refreshing the merge to `5abdd9f`, reran the affected checks:
  27 hook tests passed in 6.163 seconds and 11 documentation tests passed
  in 0.519 seconds. The preserved tracked edits were compared with the
  saved patch; only HANDOFF line positions changed. The new Voice Settings
  source, decision text and log match `main`.
- `scripts/test-site.py`: four tests passed.
- `scripts/test-select-xcode.py`: 21 tests passed using fixture data.
- `scripts/test-runner.py`: 51 tests passed in 220.551 seconds in the
  report-only verification, before the final four adjacent guard fixes.
  Its xcodebuild and xcrun commands are fixtures; it boots no simulator.
- The full `scripts/test.sh unit` run exited successfully. Its Python
  3.9.6 gate passed 11 documentation tests in 0.575 seconds and 31 hook
  tests in 6.211 seconds. These are the only Python suites run by the unit
  script; CI runs the other suites separately.
- Native unit tests: **460 passed, 0 failed, 0 skipped, 0 expected
  failures**, using Xcode 27.1 (27A9275), XcodeGen 2.46.0, and an iPad Pro
  13-inch (M5) simulator on iOS 27.0. App line coverage was 62.6%
  (3,540 of 5,659 lines). The String Catalog was up to date and unchanged.
- Full UI suites passed on iPad Pro 13-inch (M5) and iPhone 17, both on
  iOS 27.0 with the same Xcode and XcodeGen versions: **37 tests discovered
  per device, 33 passed, 0 failed, 4 skipped, 0 expected failures**. The
  skips are the unchanged, opt-in `KeyboardProbeTests`; no new test was
  skipped. XCTest suite wall times were 565.062 seconds on iPad and
  498.959 seconds on iPhone. The unchanged Home layout test took 84.823
  and 41.457 seconds respectively.
- `scripts/test.sh ui` completed the iPad suite before the app session
  was interrupted during iPhone setup, before iPhone test cases began.
  The iPhone family was then run in full with
  `SIMULATOR_FAMILY=iphone TEST_RESULTS_DIR=build/TestResultsResumed scripts/test.sh ui`,
  which exited successfully with `All UI tests passed.` The result bundles
  are `build/TestResults/ui-ipad.xcresult` and
  `build/TestResultsResumed/ui-iphone.xcresult`.
- Both devices ran full screen. Home geometry and reachability covered
  default Large and largest accessibility (AX5) text in light appearance,
  iPad portrait and landscape, and iPhone portrait; the iPhone reachability
  tests also confirmed that rotating it leaves the app in portrait. Home
  accessibility audits covered light and dark at default and AX5 text.
  Settings, Family Setup and Privacy Policy audits covered light and dark
  at default text. Settings entry, the Family Setup opening and the Voice
  Settings Ask transition covered default and AX5 text in light appearance.
  Voice Settings' audit ran at default text in light appearance. The
  runner configured the full software keyboard; these tests did not enter
  typing, and the separate keyboard measurements remained opt-in. This is
  the coverage of the existing suite, not every window/text/appearance
  combination.

Each new guard test has a concrete failure trigger:

| Test name after `test_` | Change that makes it fail |
|---|---|
| `wildcard_pushes_cannot_include_a_protected_branch` | Check only exact branch names, or omit complete refs |
| `copilot_issue_assignments_are_denied` | Limit Copilot checks to PR reviewers |
| `attached_copilot_reviewer_options_are_denied` | Read only separate option values |
| `wrapper_operands_do_not_hide_commands` | Treat an option operand or a duration as the executable |
| `push_queries_use_the_selected_repository` | Drop the Git repository selectors |
| `configured_push_destinations_are_checked` | Ignore a remote's configured push refspec |
| `matching_push_default_is_denied` | Treat matching as a current-branch push |
| `push_remote_selection_and_command_configuration_are_preserved` | Ignore the push remote or command-local config |
| `attached_boolean_approval_options_are_denied` | Compare only the unadorned approval token |
| `a_failed_cd_keeps_the_previous_push_destination` | Assume every cd succeeds |
| `api_bodies_loaded_from_files_are_checked` | Inspect only the command-line text |
| `other_api_clients_check_the_same_approval_payloads` | Inspect file payloads only for gh |
| `api_assignment_payloads_cannot_start_copilot` | Inspect only reviewer API endpoints |
| `issue_create_and_update_payloads_cannot_assign_copilot` | Ignore assignees outside the dedicated assignees endpoint |
| `git_environment_selects_the_repository_for_push_checks` | Drop Git environment selectors from read-only queries |
| `sudo_option_operands_do_not_hide_commands` | Treat the user or group operand as the executable |
| `rest_branch_merges_cannot_target_main` | Ignore the base branch in REST branch-merge requests |

## Not verified

- CI for the final reconciliation commit is pending. Check its current-head
  Unit tests, UI tests and CodeQL results after the tested merge is pushed.
  Earlier green CI on `1b6ccb6` does not verify these edits or the merged code.
- No live Claude Code session was used to confirm hook reloading. The
  settings wiring and hook decisions are tested directly.
- The rendered GitHub issue form has not been checked. Its required
  privacy text and blank-issue setting pass the local documentation tests;
  the rendered form needs a live check after the configuration lands.
- No simulator result proves sound, gaze comfort, pointer snapping or
  physical-device behaviour; this guardrail change claims none of them.

## Follow-ups

1. Codex: push the tested merge, answer the nine review threads with the
   corresponding test evidence, then check the new CI and review results.
2. In a live Claude Code session, confirm hook reloading; after the issue
   configuration lands, inspect the rendered bug form and its privacy text.
3. The owner already enabled auto-merge on this PR. Its setting stays as
   it is; GitHub can merge after all required checks and conversations
   pass. Agents do not enable auto-merge or call the merge action.
