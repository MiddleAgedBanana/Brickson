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

## Follow-up for blockquoted references

The next review identified a Markdown reference definition inside a block
quote that the checker missed. This was reproduced before changing the
checker: a missing file returned no problem, and the focused regression
then produced nine failing cases. CommonMark's
[example 218](https://spec.commonmark.org/0.31.2/#example-218) confirms that
these definitions apply throughout the document. The checker now removes
quote markers before checking definitions and removing fenced examples,
while retaining indentation that marks code. Missing files and headings
are checked with plain, nested, indented and spaceless quote markers, as
well as a destination on the next quoted line. Existing destinations,
quoted fences and four-space code examples remain accepted. Removing
quote normalization makes the new reference test fail; stripping code
indentation or scanning a quoted fence makes the negative test fail.

All 18 documentation tests passed with system Python 3.9.6 in 0.779
seconds. The fresh `scripts/test.sh unit` gate then passed 460 native
unit tests, with no failures, skips or expected failures and 62.6% app
line coverage (3,540/5,659). It used Xcode 27.1 (27A9275), XcodeGen
2.46.0 and iPad Pro 13-inch (M5), iOS 27.0; its Python checks passed
18 documentation tests in 0.734 seconds and 41 hook tests in 8.979
seconds. The String Catalog was unchanged. App, guard and UI-test
sources have not changed. The ten previous follow-up
threads were answered and resolved on `f872635`; this new finding remains
open until the tested correction is published. CI on `4415827` finished
its unit job successfully, but its unfinished UI job was cancelled by the
required `f872635` review-fix push. Current-head CI is still running.

## Refresh after the audit timing fix landed

The owner-enabled merge of PR #31 advanced `main` to `479175d`. The
current main briefing, handoff, decisions and audit record were read
before preparing a merge commit. Git merged the shared AGENTS and
HANDOFF changes without conflicts; both the audit guidance and guardrail
records remain. The main delta adds a settle step before accessibility
audits and their existing timeout retry, waits for speech to finish,
and adds two audit-runner tests plus evidence and guidance. It changes
UI tests, not the app, native unit sources, scripts or workflows.
The earlier local UI counts describe the earlier UI sources; they do
not claim to run the newly merged audit helper. The fresh native unit
gate for this merge passed: 460 tests, no failures, skips or expected
failures, 62.6% app line coverage (3,540/5,659), and no String Catalog
change. It used Xcode 27.1 (27A9275), XcodeGen 2.46.0 and iPad Pro
13-inch (M5), iOS 27.0. Its Python gate passed 18 documentation tests in
0.807 seconds and 41 hook tests in 9.167 seconds. Current UI validation
and final-head review remain pending in CI.

## Review of the audit-merge head

The completed Codex review of `a15b4c5` found nine additional gaps. Each
was checked against the current source before changing it:

- Exclusion-only Git pathspecs select from an implicit whole-tree set.
  Add and commit now require at least one positive named path when an
  exclusion appears; an explicitly named path with exclusions remains
  allowed. Git documents the [exclusion rule](https://git-scm.com/docs/gitglossary.html#def_pathspec).
- `xargs` options with required operands now consume those operands,
  exposing the actual command. Separate and attached forms are checked,
  including the local `xargs` manual's argument-count, replacement,
  process-count and size options. Optional GNU long-option values stay
  attached; bare optional flags do not swallow the command.
- Read-only `gh api` GET/HEAD checks of a PR's merge status are allowed.
  PUT merges and GraphQL merge mutations are still refused. The
  [CLI's method rules](https://cli.github.com/manual/gh_api) distinguish
  explicit methods from the GET default and payload-driven POST default.
- The shell lexer keeps a hash inside a word as data, including unquoted
  URL fragments followed by request bodies. Comments at word starts are
  removed while quoted text and the next line remain intact.
- A child shell's operandless `cd` uses its effective HOME, including
  command-prefix and `env` assignments. The possible failed-directory
  outcome remains checked, and the child environment never changes the
  outer command's repository.
- Attached inherited `gh -R` options are removed at each command level,
  so they cannot hide a merge, approval or Copilot task command.
- Inline Markdown links now capture angle-bracketed destinations with
  spaces. No current repository link uses that form, but it falls under
  the checker's existing relative-link claim and is a small alternative
  in its existing destination pattern, not a new Markdown parser.
- Both policy hooks now use `onFailure: "block"`; a configuration
  regression pins both entries. The
  [official hook documentation](https://code.claude.com/docs/en/hooks#block-the-action-when-a-hook-fails)
  requires Claude Code 2.1.295 or later for startup errors, crashes,
  invalid output and timeouts to block the action. The installed CLI
  reported 2.1.308; live hook reloading and cloud runtime versions remain
  unverified. Permissions and their denied tools are unchanged.
- The new report-only verifier was calling a unit command that can
  rewrite the tracked String Catalog. The caller is new in this PR,
  even though catalog synchronization already exists on main. It now
  invokes `CI=true scripts/test.sh unit` (and the UI command with the
  same environment), checks final status/diffs against its starting
  snapshot, and reports unexpected tracked changes without repairing
  or reverting them. Ignored generated build outputs are expected.

Six command-hook regression methods produced 31 failures before the
fixes. The hook-configuration check failed for both entries, and the
inline-link check failed on a missing destination with spaces. The full
system-Python gates then passed 48 hook tests in 12.913 seconds and
19 documentation tests in 0.860 seconds. An independent reviewer checked
the six changed command paths and the configuration test: all seven
focused tests passed, with no additional actionable defect in that
bounded review. No test command performs a real remote action. The
six existing mocked String Catalog tests passed in 82.698 seconds,
including CI mismatch reporting without rewriting the catalog. The
fresh `scripts/test.sh unit` gate then passed 460 native tests with no
failures, skips or expected failures; coverage was 62.6% (3,540/5,659)
and the String Catalog was unchanged. It used Xcode 27.1 (27A9275),
XcodeGen 2.46.0 and iPad Pro 13-inch (M5), iOS 27.0. Its Python gate
passed 19 documentation tests in 0.813 seconds and 48 hook tests in
12.628 seconds. These additions remain advisory checks against ordinary
mistakes, not a shell sandbox.

The new regressions fail if exclusion-only pathspecs count as named
paths, xargs values hide the executable, merge-status reads are denied,
embedded hashes discard payloads, operandless cd ignores the child's
HOME, inherited attached repository flags hide the subcommand, either
policy hook loses its failure-block setting, or angle-bracket targets
stop at their first space.

## Not verified

- CI on `a15b4c5` passed units (460/460, no failures or skips, 62.6%
  coverage) on Xcode 27.1 (27A9275), XcodeGen 2.46.0 and iPad Pro 13-inch
  (M5), iOS 27.0; its UI job is still running. Its code review completed
  with the nine findings above, which remain unresolved until this
  locally tested follow-up is published. Current UI tests and final-head CI
  and review are still required; earlier results do not verify this batch.
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

1. Codex: the latest review batch's native unit gate passed. Check
   current main and the PR branch, publish together, then answer and
   resolve the nine new findings and check final-head CI/review.
   All nine original review threads were resolved on
   `7d6b3e1`, ten later threads on `f872635` and the blockquote thread
   on `7458118`; preserve complete CI results when available.
2. In a live Claude Code session, confirm hook reloading; after the issue
   configuration lands, inspect the rendered bug form and its privacy text.
3. Auto-merge is now disabled, using the owner's explicit discretion
   to keep main stable while the combined branches are validated. The
   remote setting was verified disabled. This PR waits for the owner's
   merge after green final-head checks and resolved reviews; agents do
   not enable auto-merge or call the merge action.


## Final command and Markdown review batch

The next review of `3c379f1` identified nine concrete parser cases. Eight
new hook test methods and one documentation test reproduced them before
implementation (56 hook tests: eight failures; 20 docs tests: one failure).
The guard now consumes the separate recurse-submodules mode, inspects
ordinary env split-string commands and shell condition lists, and carries
sudo's working-directory option into its read-only Git queries. Dry-run
pushes are allowed only when the dry-run flag is an actual option, not an
option value.

API checks now distinguish endpoint arguments, effective request methods
and operation fields from prose. Curl GET/HEAD merge-status reads and issue
text mentioning merge operations are allowed; actual PUT merges, approval
fields, protected branch merges and GraphQL merge operations remain denied.
Here-document data is not treated as executable shell commands. Unquoted
command substitutions and direct shell receivers remain checked; complex
shell pipelines are conservatively declined rather than assigned a guessed
execution directory. This remains an advisory guard for common mistakes,
not a complete shell parser or security boundary.

The documentation checker skips ordinary indented code while continuing to
check paragraph and list continuation links. A paired list case caught and
fixed an intermediate regression. Multiline quoted text and escaped
substitutions also have coverage. Final focused results before the context edge case: all 56 hook tests
and all 20 documentation tests passed; the native gate passed all 460 units.
A further paired regression reproduces outer-shell substitutions in an
unquoted shell here-document versus a literal quoted child script. The
fix keeps their repository contexts distinct. The combined main-merge
gate below includes this additional test (57 hook tests total). No app, UI, String Catalog or workflow changes are
part of this batch; no new product decision is adopted.

CI on the preceding `3c379f1` passed: 460 units and 35 enabled UI tests on
each device, with four existing opt-in keyboard-probe skips per device.
Its nine later review conversations remain open until this correction is
published. The new commit requires its own CI run. Auto-merge remains off.


### Incorporating landed PR #32

The owner merged PR #32 as main `313de2c` after its exact-head CI passed.
This batch merges that main revision without rebasing, retaining its
75-minute UI allowance, bounded Home queries and diagnostic attachments.
Main's AGENTS and DECISIONS are unchanged; the new handoff and log were
read before merging. The combined gate passed 460 native unit tests, 57 hook tests and 20
documentation tests, with no failures and an unchanged String Catalog.
Xcode 27.1 (27A9275), iPad Pro 13-inch (M5), iOS 27.0; app line coverage
remains 62.6% (3,540/5,659). New-head CI remains required. This is a
local branch merge; no agent merged a GitHub pull request or pushed main.


### Follow-up review: redirected commands and indirect configuration

Five findings on `d8ac558` reproduced before the fixes: four new hook test
methods and one documentation method failed. Shell here-strings now expose
their command text to the existing checks, including attached redirection
and the selected child working directory. Literal data passed to `cat`
and ordinary read-only shell commands remain allowed.

Plain Git aliases in both supported configuration spellings are read using
the same repository, command configuration
and environment as the requested operation, with bounded expansion. Built-in
commands take precedence over aliases. The test fixture initially used
`stage`, which is itself Git's built-in synonym for `add`; the fixture now
uses an unambiguous alias. The installed Git and its official documentation
confirmed the alternate `alias.<name>.command` form; a further failing
reproduction was fixed before publication. `git stage -A` is also denied (the prior guard
allowed it). Shell aliases are conservatively refused with a request to use
the underlying command explicitly; the guard never executes an alias.

Explicit curl configuration-file options are conservatively refused before
host detection, including stdin and attached forms. Agents can use explicit
command-line options instead. This avoids silently trusting URLs and methods
hidden in a separate curl configuration language. GraphQL add/submit review
mutations now check their event, including JSON input variables; APPROVE is
refused, while COMMENT and REQUEST_CHANGES remain allowed. An unresolved
variable is refused rather than guessed. Existing merge checks remain intact.

Relative Markdown destinations must resolve inside the repository, including
symlink targets, before their existence or heading is checked. A temporary
fixture covers existing and missing outside files, an escaping symlink and
a valid internal link. No host file contents are read by those tests.

The final `scripts/test.sh unit` gate passed all 460 native unit tests,
61 hook tests and 21 documentation tests, with zero failures/skips and an
unchanged String Catalog. Xcode 27.1 (27A9275), iPad Pro 13-inch (M5),
iOS 27.0; app line coverage remains 62.6% (3,540/5,659). This batch changes
no app or UI source. New-head hosted CI remains required. No new product decision or review-rule exception is adopted. The
owner re-enabled auto-merge on this PR after the earlier off-state record;
agents leave that setting in place and do not invoke a GitHub merge.


### Follow-up review: command variants and Markdown examples

Eleven findings on `19eca4f` reproduced before correction: ten new hook
methods plus the existing hook-matcher test failed, and one new Markdown
test failed. The fixes are confined to the reported command and code-example
forms; no app/UI source or product decision changes.

- GNU xargs consumes the process-slot variable operand, and `gh issue new`
  uses the existing create/assignment checks.
- Git push short options stop parsing flags when `-o` begins its attached
  value: `-on` is a push option value, while a preceding real `-n` remains
  a dry run. Existing force and protected-destination checks stay in place.
- Shell `/dev/stdin` and `/dev/fd/0` operands expose redirected command text.
  Leading file redirections are removed before executable classification.
  Ordinary pushd/popd operations retain both successful and failed directory
  transitions and their stack; an inherited stack destination is unknown,
  so a bare push there is refused rather than guessed. Indexed/stack-only
  pushd forms remain conservatively refused.
- HTTPie reads methods after flags and their operands, then decodes data
  request items for the existing approval, merge and Copilot checks. Plain
  and JSON fields, ordinary array items and bounded file-backed fields are
  recognized; unsupported nested/file-upload forms are refused. Headers and
  URL query items are not JSON body fields. Explicit GET/read-only commands
  and non-approving reviews remain allowed.
- API dot segments are normalized before endpoint checks. Conditional
  Copilot intent assignment is wired into the hook: only an explicit boolean
  `is_suggestion: true` is allowed, because it records an intent rather than
  launching the billed agent. The unconditional permission-deny entries
  remain unchanged, so they do not prohibit that suggestion-only form.
- Link checking skips inline code spans and backtick/tilde fenced code,
  including longer and unclosed fences, while a real link outside the code
  still fails. This also keeps headings inside those fences out of citations.

The final `scripts/test.sh unit` gate passed all 460 native unit tests,
71 hook tests and 22 documentation tests, including paired allowed paths,
with no failures/skips and an unchanged String Catalog. Xcode 27.1
(27A9275), iPad Pro 13-inch (M5), iOS 27.0; app line coverage is 62.6%
(3,540/5,659). New-head hosted CI remains required. The known local audio limitation
is unchanged; there is no audio workaround or weakened accessibility check.
The owner has now re-enabled auto-merge on both #14 and #17. Agents leave
those settings in place and will incorporate whichever branch lands first
into the remaining branch when required.


### Follow-up review: request methods, command context and citations

Main `cc35c30` (PR #29's CI artifact documentation) was read and merged
without conflicts. Seven executable regressions reproduced before fixing
eight findings; the remaining finding corrects the verifier's initial
snapshot to record `git diff --cached`, matching its final comparison.

The guard now checks APPROVE on pending-review event submission as well as
review creation, recognizes curl uploads' implicit PUT (an explicit method
still wins), and includes IPv4/IPv6 digits in Git push flag clusters without
consuming attached push-option data as flags. Official API and CLI sources:
[review submission](https://docs.github.com/en/rest/pulls/reviews#submit-a-review-for-a-pull-request),
[curl upload](https://curl.se/docs/manpage.html#-T), and
[gh aliases](https://cli.github.com/manual/gh_alias_set).

Native gh aliases are read through `gh alias list` in the selected HOME,
GH_CONFIG_DIR or XDG_CONFIG_HOME context, without executing an expansion.
Simple aliases are expanded and checked; shell/parameterized aliases and
unsupported YAML forms require the explicit underlying command. The tests
use a disposable configuration, including an empty one. Literal exports and
unsets retain relevant Git/gh environment across shell segments and
conditional paths; child shells keep their own changes. This remains an
advisory mistake guard, not a complete shell parser or security sandbox.

Citation checking ignores inline, indented and blockquoted fenced examples
while retaining real citations whose file name alone is formatted as code.
Markdown heading links include duplicate suffixes and collisions. Paired
checks retain missing real citations/anchors and ordinary allowed commands.

The final full local unit gate passed all 460 native tests (zero failures
or skips), 76 hook tests and 24 documentation tests. Xcode 27.1 (27A9275),
iPad Pro 13-inch (M5), iOS 27.0; app coverage remains 62.6%
(3,540/5,659) and the catalog is unchanged. A final alias check includes
repository flags inside the expansion. No app/UI source, product decision
or review-rule exception changes. New-head hosted CI
remains required; no local audio setting or accessibility assertion changed.


### Follow-up review: operation and shell boundaries

Eight findings on `4936c0f` reproduced before correction: six failing hook
methods and two documentation tests. The fixes remain in the guard and
documentation checker; no app, UI or audio behaviour changes.

- curl `--next` and `-:` start separate operations, each checked with its
  own URL, method and body. Flag operands containing the separator text
  remain operands.
- REST contents writes require an explicit branch and reject main/master.
  Git-reference create/update/delete paths reject protected heads as well.
  Read-only requests and explicit feature branches have allowed-path tests.
- Parenthesized subshells restore outer directory, directory stack and
  exported context when they finish, while commands inside are still
  checked in their changed context. Conditional success/failure outcomes
  remain separate.
- Bash ANSI-C quoted words are decoded before command inspection, including
  escaped whitespace. Literal data stays data; no shell expansion executes
  in the guard. Here-document delimiters use the complete shell word,
  including punctuation, so following commands cannot disappear into a
  mistakenly unterminated body.
- Wrapper short-option clusters consume the first value-taking flag's
  attached or following operand before locating the child command.
- Relative Markdown paths are percent-decoded before the existing
  repository-boundary check. Setext headings join ATX headings for both
  citations and duplicate-aware anchors, excluding fenced code.

The full local unit script passed 460 native tests with zero failures/skips,
using Xcode 27.1 (27A9275), iPad Pro 13-inch (M5), iOS 27.0. The catalog
is unchanged; app line coverage remains 62.6% (3,540/5,659). Final guard
and documentation checks passed 82 and 26 tests, including a follow-up
null-branch case: null also selects an unspecified default and is refused. New-head hosted CI and fresh review remain
required. No new product decision or review-rule exception is introduced.


### Library main refresh and fresh review, 2026-10-23

PR #14 final head `f45a33a` passed hosted run `39887840347`: 560 native
unit tests passed with the existing issue #19 skip; all 35 enabled UI tests
passed on each of iPad and iPhone with four existing opt-in probe skips per
device. All 21 review conversations were resolved and owner-enabled
auto-merge landed it as `48bcf73`. This branch merges that main revision
with a merge commit, retaining the refusal of Replace import until its
safety-copy and owner-decision prerequisites are satisfied.

Ten fresh findings on `2e497bf` were assessed. Nine are corrected:
exhaustive glob pathspec staging; curl long form fields; final dry-run
option precedence; process-substitution child commands and directory
scope; GraphQL ref/commit writes; generic MCP issue assignments to Copilot;
asynchronous REST merges; indented ATX headings; and relative links with
query components. Failing reproductions preceded the fixes, paired with
allowed commands or valid links. Removing these checks makes their focused
regressions fail. Queries, literal command-like text, human issue assignees
and explicit bounded paths remain allowed.

The xargs finding is rejected: GNU documents `--max-lines[=max-lines]`,
with an optional attached argument; `--max-lines 1 git ...` selects `1` as
the command. Consuming that separate word as an option value would instead
hide `git` in the valid `xargs --max-lines git add -A` case. The original
regression caught that error before publication; it remains intact, with
additional paired coverage for attached `=1` and mandatory `-L 1` values.
See [GNU xargs options](https://www.gnu.org/software/findutils/manual/html_node/find_html/xargs-options.html).

GraphQL writes require explicit Git commands because this advisory guard
does not resolve opaque ref IDs or variable targets. This is a bounded
implementation limitation, not a security sandbox or a new product rule.
The remaining changes enforce existing rules; no review exception, app
behaviour, audio setting or assertion is weakened.

The full local `scripts/test.sh unit` gate passed 560 native tests, zero
failures and one existing issue #19 crash-probe skip (561 total), plus 90
hook and 28 documentation tests. Xcode 27.1 (27A9275), XcodeGen 2.46.0,
iPad Pro 13-inch (M5), iOS 27.0. The catalog is unchanged and app line
coverage is 66.9% (4,400/6,577). New-head hosted checks and fresh review
remain required; no new local UI or sound claim is made.


### Merge queues and shell input boundaries, 2026-10-23

Five new findings on `227cda9` reproduced as five failing focused tests
before correction. Main remains `48bcf73`; no app code changes.

- GraphQL `enqueuePullRequest` is a merge action and is now refused;
  read-only queries and mutation names inside comment text remain allowed.
- Exceeding three nested shell inspections refuses the uninspectable
  command instead of silently accepting it. Shallower readable commands
  remain supported. This limit also refuses benign deeply nested commands.
- curl short-option clusters expand before method, body, upload and config
  inspection. Attached/separate values stay bound to their options, so a
  header or output name resembling `-XPUT` cannot change the parsed method.
- CDPATH is tracked through environment prefixes, exports, plain assignment
  and unset. A CDPATH-dependent relative `cd` makes its repository unknown;
  the guard refuses an implicit push rather than guessing. `./` paths,
  absolute paths and ordinary read-only commands remain usable. The guard
  does not predict which search-path directory an earlier command creates.
- Shells that take their program from a pipe or input file require explicit
  inspectable code. `-c`, literal here-documents and here-strings keep their
  existing checks. Input to a named script remains data for that script;
  this change does not claim to inspect arbitrary script files. Shell help
  and version commands remain allowed.

Each focused test pairs the reported failure with supported commands and
would fail if its new check were removed. No blocked remote operation is
executed by these tests. The complete local unit script passed 560 native
tests with zero failures and the existing issue #19 skip, plus 95 hook
and 28 documentation tests. Xcode 27.1 (27A9275), iPad Pro 13-inch (M5),
iOS 27.0; catalog unchanged and app line coverage 66.9% (4,400/6,577).
New-head hosted CI and fresh review remain required. These are advisory
parser limits enforcing existing rules,
not a security sandbox or a new invariant/exception.

Sources: [GitHub merge queue mutation](https://docs.github.com/en/enterprise-cloud@latest/graphql/reference/pulls#enqueuepullrequest),
[curl option syntax](https://curl.se/docs/manpage.html#Options),
[Bash cd/CDPATH](https://www.gnu.org/software/bash/manual/html_node/Bourne-Shell-Builtins.html),
and [Bash invocation](https://www.gnu.org/software/bash/manual/html_node/Invoking-Bash.html).


### Framework main refresh and API input forms, 2026-10-23

Main moved to `b6be682` (PR #34) during this follow-up. Its current-framework
rules, exceptions, handoff and record were read, then merged without
conflicts or rebasing. This includes the new shared Vision recognizer and
its fixture tests, the audit tests moved to Swift Testing, and the measured
screen colour. No additional framework migration or product change is
part of this reconciliation.

Eight fresh findings on `e98e95a` reproduced first: seven failing guard
tests and one failing documentation test. Corrections:

- External time wrappers consume their format/output option operands.
- Here-document delimiter quote removal handles ANSI-C quoted segments
  before locating the terminator, preserving later executable commands.
- Inline Markdown destinations use balanced parentheses, including three
  nested levels and backslash escapes; missing files/anchors still fail.
- GitHub curl URL globs require explicit URLs or effective `--globoff`.
  This conservative guard does not expand an unbounded generated URL set.
- curl GET/HEAD negations are evaluated in order, so the final settings
  determine whether an approval body is a write.
- HTTPie redirected regular files use the bounded body reader. Pipes,
  descriptor redirections, here-strings and here-documents require an
  explicit inspectable body or `--ignore-stdin`; comment-only bodies and
  reads with ignored stdin remain allowed.
- POST requests to GitHub's agent-task collection are owner-only Copilot
  actions; listing tasks and reading their status remain allowed.
- GraphQL issue-assignment mutations with `agentAssignment` are refused,
  including JSON variable inputs. Human issue inputs and discussion of
  that field inside ordinary strings remain allowed.

The focused reproductions now pass. The full local unit script passed
570 native tests with zero failures and the existing issue #19 crash-probe
skip (571 total), including PR #34's inherited tests; 102 hook and 29
documentation tests passed. Xcode 27.1 (27A9275), iPad Pro 13-inch (M5),
iOS 27.0; catalog unchanged, app line coverage 66.9% (4,400/6,577).
Current-head hosted CI and fresh review remain required. This adds no
product decision, review-rule
exception or claim that the advisory guard is a security sandbox. Replace
import remains refused, and no audio setting or test assertion is weakened.

Sources: [GNU time](https://www.gnu.org/software/time/manual/time.html),
[Bash here-documents](https://www.gnu.org/s/bash/manual/html_node/Redirections.html),
[CommonMark links](https://spec.commonmark.org/spec#links),
[curl URL syntax](https://curl.se/docs/url-syntax.html#globbing-letters),
[curl methods](https://curl.se/docs/manpage.html#-G),
[HTTPie raw input](https://httpie.io/docs/cli/sessions#raw-request-body),
and [GitHub agent APIs](https://docs.github.com/en/enterprise-cloud@latest/copilot/how-tos/use-copilot-agents/cloud-agent/use-cloud-agent-via-the-api).

## Explicit configuration and link spelling, 2026-10-23

Seven fresh findings on `62b79b5` reproduced before correction: five
failing hook tests and two failing documentation tests. Main remains
`b6be682`; no new merge was needed.

- Wget execute/config directives now require explicit request options;
  GitHub requests require `--no-config` so implicit startup files cannot
  change the method either. Separate, attached, clustered and abbreviated
  execute options are covered.
- GitHub curl requests require `-q` or `--disable` as the first argument,
  before the client reads an implicit configuration. Explicit config
  files remain refused. Existing method/body fixtures now use leading
  `-q`, so they continue exercising their original checks, including
  multiple curl operations.
- `git send-pack` is refused with directions to use the inspected
  `git push` path and an explicit feature branch.
- Locale-translated shell strings are refused with directions to use
  ordinary quotes. Treating them as untranslated text would still guess
  the command when a translation exists; literal text and ordinary
  quoted commands remain covered.
- Abbreviated all-tree add/stage options and pathspec-file options are
  refused; explicit file names following `--` remain valid.
- Inline link text accepts balanced and escaped brackets before checking
  its destination and anchor. Escaped non-links remain ignored.
- Link paths are compared with the exact spelling of directory entries,
  including decoded components, so a case-insensitive local filesystem
  cannot approve a link that will be missing on GitHub.

Each regression fails if its corresponding check is removed; allowed
request, branch and link cases guard against indiscriminate refusal.
Focused tests and the full local unit script pass: 570 native tests, zero
failures and the existing issue #19 crash-probe skip (571 total), plus
107 hook tests and 31 documentation tests. Xcode 27.1 (27A9275), iPad Pro
13-inch (M5), iOS 27.0; catalog unchanged and app line coverage 66.9%
(4,400/6,577). Current-head hosted checks and fresh review remain required. No app behaviour,
review-rule exception or product decision changed. The hook remains an
advisory check, not a complete shell parser or security sandbox.

Sources: [Wget startup options](https://www.gnu.org/software/wget/manual/html_node/Basic-Startup-Options.html)
and the installed client's `--help`,
[curl configuration](https://curl.se/docs/manpage.html#-q),
[Git send-pack](https://git-scm.com/docs/git-send-pack),
[Bash locale translation](https://www.gnu.org/software/bash/manual/html_node/Locale-Translation.html),
[Git option abbreviations](https://git-scm.com/docs/gitcli), and
[CommonMark links](https://spec.commonmark.org/0.31.2/#links).
