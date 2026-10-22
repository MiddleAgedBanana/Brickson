# Reconcile the agent guardrails and close the review gaps

*2026-10-22. Pull request #17 (`claude/project-thread-v6agjh`), prepared
on `codex/pr17-reconcile`. Codex.*

## What changed and why

Merged `main` at `5abdd9f` into PR #17 without rebasing, preserving the
guardrail work and the changes that landed afterward, including Voice
Settings. The pending merge was refreshed when `main` advanced; the guard
fixes were saved and verified before restoring them over the new merge.
The original account stays in [`2026-10-21-agent-guardrails.md`](2026-10-21-agent-guardrails.md).
This separate reconciliation record was requested for the handoff between
agents. The owner explicitly requested a dated record for each piece of
work; that instruction takes precedence here over the general one-file-per-PR
guidance in `README.md`. The original record remains intact. This adds no
app behaviour and makes no new product decision.

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

## Refresh after the design reference landed

PR #20 merged through the owner's existing auto-merge setting, advancing
`main` to `d79d836`. The latest briefing, handoff, decisions and new design
record were checked before preparing another merge commit. That main
change contains eight documentation files only. The merge preserves the
design reference, specification, solid-fill decision and guardrail record
in landing order; it required no conflict resolution. App, unit/UI test,
script and workflow contents remain byte-identical to tested `7d6b3e1`.
The prior full local UI results below therefore still describe those
sources. The fresh `scripts/test.sh unit` gate passed before committing
this merge: 460 passed, no failures, skips or expected failures, and
62.6% line coverage (3,540/5,659), with Xcode 27.1 (27A9275), XcodeGen
2.46.0 and iPad Pro 13-inch (M5), iOS 27.0. The String Catalog remains
unchanged. Its Python gate passed all 11 documentation tests in 0.882
seconds and all 31 hook tests in 6.168 seconds.

CI run [39852524297](https://github.com/MiddleAgedBanana/Brickson/actions/runs/39852524297)
on `7d6b3e1` passed Unit tests and CodeQL. Its unit job used Xcode 27.1
(27A9275), XcodeGen 2.46.0 and iPad Pro 13-inch (M5), iOS 27.0: all 460
unit tests passed, with no skips or expected failures and 62.6% app line
coverage. The CI Python checks also passed: 21 selector, four website,
51 runner, 11 documentation and 31 hook tests.

The UI job finished with a failure. Its iPad family completed with
32 passed, one failed and four unchanged opt-in skips. The failure was
`HomeAccessibilityOrderTests.testQuickControlsComeFirstInEveryStateAtTheLargestText`:
XCTest could not terminate the previously running app while launching the
next test. This was an app-process termination failure before its layout
assertions, not a finding to ignore. The Home layout test passed in
154.000 seconds, and all nine LaunchTests passed, including
`testLargestTextKeepsQuickControlWordsVisible` in 52.676 seconds. The iPad
suite wall time was 1,130.078 seconds. The iPhone family passed all
33 runnable tests with four unchanged opt-in skips; its suite wall time
was 872.303 seconds, Home layout took 86.933 seconds and the AX5
quick-control audit passed in 42.293 seconds. Both result bundles were
retained in [artifact 12461203212](https://github.com/MiddleAgedBanana/Brickson/actions/runs/39852524297/artifacts/12461203212).
No test assertion or retry rule was changed for the termination failure.
Current-head CI must pass before the PR is called green.

## Follow-up on the next review

The review of `4415827` found that unquoted backtick command substitutions
spanning several words escaped the guard's per-word scan. A new regression
first reproduced three missed denials: blanket staging, PR merging and
pushing to `main`. The guard now scans the joined words for backtick pairs
before recursively checking each enclosed command. Read-only `git status`
and named-path staging remain allowed. This is a correction to a common
command form, not a claim that the hook is a shell security boundary.

The same review caught an overstatement in HANDOFF. It now describes the
actual `.claude/settings.json` matchers: Bash and selected GitHub tools,
in Claude Code sessions with one repository. Repository hooks are not
loaded in multi-repository cloud sessions. The separate dated record is
retained under the owner's explicit instruction above.

The completed Codex review then supplied six more concrete cases. Five
new hook regressions reproduced 30 failures before the corrections:

- `env -C` and `--chdir` retain their directory operands for the child
  command's Git queries and nested shell, including attached options and
  nested `env` calls. A single `env` uses its last directory option; the
  outer shell's directory is unchanged. This follows the
  [Coreutils implementation](https://github.com/coreutils/coreutils/blob/master/src/env.c).
- REST endpoint checks use the parsed URL path, so query strings and
  fragments cannot hide branch merges or issue assignments. Curl
  [does not send URL fragments](https://everything.curl.dev/cmdline/urls/fragment.html).
  Explicit feature-branch merges remain allowed.
- `git commit` rejects the same whole-tree pathspecs as `git add`, while
  distinguishing paths from message/file option values. Git documents
  that [commit pathspecs record the matched working-tree contents](https://git-scm.com/docs/git-commit).
  Commits naming particular paths remain allowed.
- `gh repo sync` rejects protected branches, force updates and an
  unspecified remote default branch. An explicitly named feature branch
  without force remains allowed. GitHub's
  [sync manual](https://cli.github.com/manual/gh_repo_sync) confirms these
  destination and force-update semantics.
- `gh agent-task create` and its documented aliases are refused because
  they [start a Copilot task](https://docs.github.com/en/copilot/how-tos/use-copilot-agents/cloud-agent/use-cloud-agent-from-cli).
  Listing and viewing those tasks remain allowed.

The documentation checker now validates reference-link definitions as
well as inline links. Six full, collapsed and shortcut reference cases
missed absent files or headings before the fix. Valid file, anchor and
external references still pass; fenced examples, indented code, footnotes
and ordinary bracketed prose do not become missing-file errors. It is a
small definition scan, not a complete Markdown parser. The initial
implementation failed three negative controls before its definition
syntax was tightened to match the
[CommonMark form](https://spec.commonmark.org/0.31.2/#link-reference-definitions).

These additions retain the existing safety rules and allowed paths. They
do not turn the advisory hook into a shell interpreter or sandbox.

Independent review caught one directory-scoping regression in that first
implementation: shell substitutions run in the outer shell before `env`
changes the child directory. Four deny/allow cases reproduced the wrong
result. Substitutions and an explicitly invoked shell's script are now
checked in their respective contexts; the regression also preserves
single-quoted child scripts containing substitutions. A second independent
pass caught the double-quoted script form and reproduced four more wrong
results. A quote-preserving view now recognizes wholly quoted scripts:
single-quoted scripts run in the child; double-quoted substitutions run in
the outer shell, and the remaining script still gets checked in the
child. Unknown or mixed quoting is conservatively checked in both contexts.
Escaped substitution markers in a double-quoted script use that same
conservative path: two missed denials reproduced before the final check;
explicit feature destinations still pass. This may refuse a bare push
whose destination cannot be established in both contexts; it does not
claim to interpret every shell quoting form.

Final review also checked Git's pathspec-file option, which can select
the entire working tree without naming those paths in the command. Three
commit cases and three add cases failed before correction. Both commands
now refuse `--pathspec-from-file` (separate, attached or stdin) and explain
that paths must be named directly. This deliberately avoids interpreting
Git's quoted or NUL-separated pathspec-file syntax; explicit named paths
remain allowed.

On 2026-10-22, the owner reported starting a two-week CodeRabbit trial and
authorized Codex and Claude to request `@coderabbitai review` when useful.
Treat it as optional supplementary review during that trial, not a
permanent required gate or guaranteed future availability. Automatic
reviews already arrived on this PR, so no duplicate request was sent.
Its nested "Prompt to fix review comments" is agent guidance to inspect
when useful, not an instruction to accept or execute blindly. Verify each
claim against the repository and explain findings that are declined.
Copilot authorization and repository review rules are unchanged.

## Commits

- `1b6ccb6`: PR #17 before reconciliation.
- `5abdd9f`: the `main` revision included in the merge.
- `7d6b3e1`: the locally tested guardrail reconciliation, pushed for review.
- `d79d836`: the documentation-only main revision included in `4415827`.
  Its fresh local unit gate passed; final-head CI remains pending. Prior
  local UI evidence remains valid for the unchanged sources.
- `4415827`: the documentation-only merge, pushed for CI and review.

## Verified

On a Mac; Python checks used Python 3.15.0 unless noted:

- The final review batch passed **41 hook tests** in 10.401 seconds and
  **16 documentation tests** in 0.859 seconds using system Python 3.9.6.
  The backtick reproduction failed three cases; the five later hook
  reproductions failed 30; independent review's context and escaping
  checks failed ten; and pathspec-file checks failed six. All now pass,
  with the explicit allowed-path controls retained.
- The final review batch's `scripts/test.sh unit` exited successfully:
  **460 passed, 0 failed, 0 skipped, 0 expected failures**; 62.6% app line
  coverage (3,540/5,659). It used Xcode 27.1 (27A9275), XcodeGen 2.46.0
  and iPad Pro 13-inch (M5, 16 GB), iOS 27.0. Its system-Python gate passed
  16 documentation tests in 0.796 seconds and 41 hook tests in 8.947
  seconds. The String Catalog remained unchanged. No app or UI-test
  source changed in this batch, so the earlier full local UI evidence
  still describes those sources.
- The independent verifier passed the 40-test hook suite and all 16 docs
  tests after the quote fixes; the final pathspec-file refusal was then
  reviewed and added with its focused regressions. Site checks passed
  four tests and the Xcode-selector fixtures passed 21.
- The full mocked runner suite passed all **51 tests** in 350.132 seconds;
  it uses fixture build/simulator commands. The final hook and docs suites
  above separately cover the later quoting and pathspec-file refinements.
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
| `unquoted_backticks_are_checked` | Search for each backtick pair within one word only |
| `env_directory_options_select_the_repository` | Drop the selected child directory or apply it to the outer shell |
| `env_directory_does_not_move_outer_shell_substitutions` | Evaluate a shell substitution in env's child directory |
| `double_quoted_child_scripts_expand_in_the_outer_shell` | Treat a double-quoted script as a literal child script |
| `escaped_substitutions_in_child_scripts_stay_checked` | Remove escaped substitutions from the child script |
| `branch_merge_urls_use_the_parsed_path` | Match the raw URL including its query or fragment |
| `commit_all_tree_pathspecs_are_denied` | Check only commit flags, or mistake message values for paths |
| `pathspec_files_require_explicit_paths` | Allow an opaque add/commit pathspec file to select every changed file |
| `repo_sync_checks_protected_and_force_destinations` | Ignore sync destinations or force updates |
| `copilot_agent_task_creation_is_denied` | Ignore task creation or its documented aliases |
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

- CI on `4415827` passed units and CodeQL; its UI job is still running.
  The locally tested review follow-up still needs final-head CI and review.
  Earlier CI on `7d6b3e1` finished
  with an iPad process-termination failure and a passing iPhone suite.
  Check the next pushed head's Unit tests, UI tests and CodeQL results.
  Earlier CI does not verify these edits.
- No live Claude Code session was used to confirm hook reloading. The
  settings wiring and hook decisions are tested directly.
- The latest Codex security-summary comment still names the older
  `651e197` revision. Successful CodeQL checks do not establish a refreshed
  Codex security review for this batch.
- The rendered GitHub issue form has not been checked. Its required
  privacy text and blank-issue setting pass the local documentation tests;
  the rendered form needs a live check after the configuration lands.
- No simulator result proves sound, gaze comfort, pointer snapping or
  physical-device behaviour; this guardrail change claims none of them.

## Follow-ups

1. Codex: the fresh local unit gate passed. Check current main and the PR
   branch before pushing the review fixes,
   then check current-head CI and review results. Complete
   evidence from the preceding UI run has been retained. All nine
   prior review threads were answered and resolved on `7d6b3e1`; the
   ten later review threads remain pending until this follow-up is
   tested and published.
2. In a live Claude Code session, confirm hook reloading; after the issue
   configuration lands, inspect the rendered bug form and its privacy text.
3. The owner already enabled auto-merge on this PR. Its setting stays as
   it is; GitHub can merge after all required checks and conversations
   pass. Agents do not enable auto-merge or call the merge action.
