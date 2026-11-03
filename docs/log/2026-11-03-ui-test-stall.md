# Stop the iPad UI tests stalling on CI, and split the UI job

*2026-11-03. Pull request on `claude/project-thread-nv23wh`. Claude
thread "Fix the iPad UI test stall on CI"; the workflow change is the
owner's commit on the same branch, because a cloud agent cannot push
`.github/workflows/` (AGENTS.md, *Gotchas*).*

## What changed and why

Nothing changes in the app. Four CI runs in a row stalled on the iPad:
PR #75's two attempts (`HomeLayoutTests`, 333.7 s, failing its
10-second layout wait, then 308.7 s against 122 to 150 s on clean runs)
and both attempts of `main` at `17019ed` (run 41606540554: first
`GetAttentionOnHomeTests`' largest-text test, failing after 301.6 s with
"Timed out while evaluating UI query", three tries of 30 s; then
`HomeLayoutTests` at the default text size in portrait, "Home did not
finish laying out", its first launch holding the next off for about 3.5
minutes where about 35 s is usual). The app's own log in those bundles
showed its main thread pausing 0.3 to 3 s between lines of trivial
work, and the gaps between XCTest's element-matching lines were 44 and
136 ms where clean runs show 1 to 10: the app was not being given time
to run.

**The cause.** About five minutes after a simulator starts, iOS's
background scheduler (`dasd`) runs SpringBoard's task
`com.apple.springboard.posterboardupdate.prewarm`. PosterBoard then has
every lock-screen wallpaper extension (EmojiPosterExtension,
MercuryPosterExtension, GradientPosterExtension, KaleidoscopePoster and
ten more) render pictures for the wallpaper gallery, for about three
minutes. On GitHub's Mac machines, virtual machines with three
processors and 7 GB of memory, the whole simulator slows to a crawl
meanwhile. Each stalled test sat exactly inside that burst, read from
the poster accessibility notifications the test runner logs:

| Run | Poster notifications during the tests | The test running then |
|---|---|---|
| `main` `17019ed`, attempt 1 | 534, 09:02:48 to 09:04:23 | `GetAttentionOnHomeTests` largest text: failed, 301.6 s |
| `main` `17019ed`, attempt 2 | 882, 11:04:44 to 11:06:34 | `HomeLayoutTests` default text, portrait: failed (a launch held 11:03:48 to 11:07:18) |
| PR #75, attempt 1 | 432, 12:48:09 to 12:49:38 | `HomeLayoutTests`: failed, 333.7 s |
| PR #75, attempt 2 | 400, 14:30:11 to 14:31:24 | `HomeLayoutTests`: passed, 308.7 s |
| `main` `c15f2a4`, `42f4570`, PR #74 `2b1a9d5`, `main` `0ee85c8` | none | no stall |

The iPhone runs logged 12 such notifications each, or none, and never
stalled. In the clean iPad runs the burst most likely fell during the
build, before the test runner was attached; its log does not cover that
time.

**The proof.** One run started by hand (run 41625185733, a temporary
probe commit `4a9dea4`, since removed) did two things on a CI machine:

1. Booted the iPad and launched the app every minute for 17 minutes,
   with nothing paused, while a watcher read the simulator's processes
   every five seconds. The prewarm task was submitted 5.5 minutes after
   boot (11:15:24), ran from 11:15:55 and "ran for 2.8 mins". In those
   minutes PosterBoard and 14 extensions wrote about 68,000 log lines,
   and the watcher's own five-second readings came 26, 39 and 78 s apart
   (elsewhere every 5 or 6 s).
2. Erased the iPad, booted it again, paused (SIGSTOP) the 13 wallpaper
   extension processes it had started, and ran the whole iPad UI suite.
   The prewarm came during the tests, at about 11:39, and the runner
   logged 24 poster notifications instead of 400 to 534. All 64 tests
   ran, none failed (the two opt-in held-slide probes skipped, as
   always), in 38.8 minutes; the same 64 tests took 45.7, 50.9 and
   51.3 minutes in the three stalled runs. `HomeLayoutTests` took
   115.8 s, the largest-text Get Attention test 30.7 s, and the runner's
   log never paused for more than 10 s.

The records are in
[`ui-test-evidence/2026-11-03-stall/`](ui-test-evidence/2026-11-03-stall/):
both phases' process readings and the prewarm's scheduling lines.

**The fix.** `scripts/test.sh` starts `scripts/simulator-load.py` as
soon as a simulator has finished starting and stops it before the
simulator is shut down, however the run ends (a failed build, failed
tests, an unreadable summary, Control-C or a cancelled job). The
watcher pauses the lock-screen wallpaper extensions of a simulator the
run started itself, and only those: a simulator someone else started
is watched but never touched. It writes every reading to
`build/TestResults/simulator-load-<family>.txt`, beside the result
bundle, so CI keeps it in the artifact, and the run's log ends with
the processes that used the most time. It stops by itself once the
test run is gone, so a killed run never leaves it pausing other runs'
simulators, and gives up on a process list that takes more than 5 s,
writing so in the record, so a hung `ps` never holds it (CodeRabbit's
review: a reading lists processes twice, and both together stay inside
the 15 s that `stop` waits for the summary). A paused process rather than an ended one, because iOS
would start an ended extension again; the open-source CI tool `yeetd`
pauses the same extensions the same way. Brickson does not use it: a
script of its own does only this, only for the simulator under test,
and installs nothing on the machine. No test shows the lock screen.
When the watcher stops, after the tests and before the simulator is
shut down, it lets the paused extensions run again, so a simulator
whose shutdown fails is not left with them stopped (Copilot's review).
The unit run gets the same watcher, since the prewarm comes during its
tests too.

**The split.** Before, one job ran the iPad then the iPhone and took
about 105 of its 120 minutes (`main` 96, #75 101 and 106). Now each
family has a job of its own, "UI tests on iPad" and "UI tests on
iPhone", running at the same time with 90 minutes each (about 50 and 45
minutes of work), and their result bundles are kept as
`ui-test-results-ipad` and `ui-test-results-iphone`. The check the
`main` ruleset requires by name, "UI tests", is now a small job on a
Linux machine that waits for both and fails unless both passed. It runs
`if: always()`, because GitHub reads a skipped required check as
passed: without it, a failed family would skip it and let a pull request
merge. The owner's first commit of the split used a matrix, one job
definition run once per family. CodeRabbit's review pointed out that a
matrix reports one result for all its legs, and that a GitHub community
report (discussion 211624, 2026-10-30, not confirmed by GitHub) saw that
summary read as passed when a leg was never given a machine. So the
families are now two jobs written out in full, `ui-ipad` and
`ui-iphone`, and "UI tests" reads each one's own result; a workflow test
checks that the two stay the same apart from the family, so one cannot
drift from the other. Each family now builds the app on its own machine, about ten
minutes more machine time per run; GitHub's Mac machines cost nothing
for a public repository. Decision: docs/DECISIONS.md, "Tests".

**Not done, on purpose.** The 10-second wait in `HomeLayoutTests` stays:
the failure was a starved app, which a longer wait would only hide, and
the Get Attention failure was XCTest's own query time-out, which no
wait in a test changes. No other daemon is paused: `diagnosticd` and
`apsd` use about 30% and 15% of a processor throughout, but other
processes call them and could hang if they were paused; the wallpaper
extensions are called only for the lock screen and its gallery.

**Also in this pull request.** The owner's review order of 2026-11-03,
recorded where it was missing: Codex reviews when a pull request opens
and on each push; the agent answers and fixes Codex's round first; then
Copilot reviews once, so it sees the fixed code and Codex's threads; a
pull request that changes only documents gets no Copilot review. The
owner turned automatic Copilot review off that day. AGENTS.md, "Reviews
and updates on GitHub", still said Copilot reviewed every pull request
when it opened; it, docs/DECISIONS.md (*Code review* and the ruleset
table), docs/SDLC.md and docs/HANDOFF.md now say what happens.

At first the owner was to add Copilot, because the guard refused every
agent request for it. The owner asked whether agents could do it, since
the owner may be asleep when a pull request is ready, and chose (on a
decision card in the thread) that the agent requests it once per code
pull request. So `.claude/hooks/guard.py` and `.claude/settings.json`
now let through the GitHub tool `request_copilot_review`, and only it:
`gh pr edit --add-reviewer`, the API's `requested_reviewers` and a pull
request's reviewer field still refuse Copilot, and so do Copilot tasks
and issue assignments. One door keeps "once" easy to see in a thread's
history. Codex and CodeRabbit then pointed out that, with the deny rule
gone, nothing but AGENTS.md stopped a second request, which an agent
that had lost its context could make. So the guard now also runs after
the tool succeeds (a `PostToolUse` hook in `.claude/settings.json`) and
records the pull request in the Git folder of the session's project
(`CLAUDE_PROJECT_DIR`, the working directory only when none is named),
`.git/brickson-copilot-reviews.json`, which every worktree of the clone
shares and git never commits; before a request, it refuses one already
recorded. Only a request that ran is recorded: Claude Code runs
`PostToolUse` hooks after a tool succeeds and a separate event after one
fails, an MCP error result included (its hooks reference, read
2026-11-03). A failed request is not counted, but the agent still
follows AGENTS.md: it says so in the thread and the owner adds Copilot,
because a request that timed out may have reached GitHub. A request
that ran but could not be recorded exits 2, which shows the agent the
message after a tool has run, so it knows the guard would not refuse a
second one. A lock beside the record keeps two sessions of one clone
from losing each other's entries. A fresh clone, such as a new cloud
session, starts with an empty record.

An independent review of this change before it was pushed (subagents
in the thread, each finding checked by a second one) also found that the record followed the session's
working directory first, so a `cd` into another clone moved it, and that
`create_pull_request`'s reviewer field reached Copilot without the guard
running at all, while these records said the reviewer field was
refused. Both are fixed: the project comes first, and the guard now runs
before `create_pull_request` and refuses Copilot in its reviewers, as it
does for `update_pull_request`. It also made the guard check every call
whose event is not one of the two after a call, where it had skipped
any call not named `PreToolUse`.

`scripts/test-hooks.py` pins it all:
`test_copilots_review_is_requested_only_through_its_own_tool` (the tool
allowed, the other ways refused);
`test_copilots_review_is_requested_once_per_pull_request` (a second
request refused from the clone and its worktrees, whatever the case of
the names; other pull requests allowed);
`test_the_copilot_record_stays_with_the_sessions_project`;
`test_only_a_successful_copilot_review_request_counts` (nothing recorded
before the call, after a failure or for another tool);
`test_a_call_without_its_event_is_checked_before_it_runs`;
`test_a_request_the_guard_cannot_record_is_told_to_the_agent`;
`test_an_unusable_copilot_record_never_crashes_the_guard` (damaged and
deeply nested records, unusable pull request numbers);
`test_a_new_pull_request_cannot_ask_for_copilot`; and, in
`SettingsTests`, `test_the_guard_records_each_copilot_review_request_that_ran`,
`create_pull_request` among the tools the guard runs before, and the
review tool off the deny list.

**Copilot's review** (requested once by this thread, after Codex had
reviewed the last push with no findings) raised four points. Two are
fixed. The watcher read the simulator's launchd_sim and the process
list one after the other, so a simulator that stopped in between made it
raise and die without its summary; a simulator missing from the second
list is now "not running". And it never let the extensions it paused
run again, so a simulator whose shutdown failed stayed booted with them
stopped; it now resumes them (SIGCONT) when it stops, after the tests
and before the shutdown. Two are declined, each checked by a separate
agent asked to refute the decline:

- *Serialize the once-only check with a reservation* (High): two
  sessions of one clone could both pass the check before either records
  its request. Within one session that cannot happen: Claude Code runs
  a tool that is not read-only, as GitHub's `request_copilot_review` is
  not, only once the call before it has finished, its hooks after it
  included, so a second call in the same message meets the record. The
  race needs two agents on one clone asking Copilot to review the same
  pull request at the same moment, which AGENTS.md gives to one agent.
  A reservation written before the call would be left behind whenever
  no hook runs after it (a call refused at a permission prompt or by
  another hook, a session killed during the call), so it would need an
  expiry, a hook after failures, and would refuse a legitimate request
  meanwhile; the race's worst outcome is one extra review.
- *Allow only `mcp__github__request_copilot_review` by its exact name*
  (Medium): every GitHub rule in the guard matches the tool's name after
  the server's on purpose, so GitHub's own server and the GitHub
  plugin's (`mcp__plugin_github_github__`) are held to the same rules
  and share one record; an exact name would refuse the plugin's route.
  The refuting agent did find the real gap behind the finding: a request
  whose pull request the guard could not read (a same-named tool from
  another server with other argument names) was let through and never
  recorded, so it could be sent again and again. The guard now refuses
  such a request; GitHub's own tool always names `owner`, `repo` and
  `pullNumber` (`test_a_copilot_request_for_no_readable_pull_request_is_refused`).

## Commits

- `4a9dea4` the temporary probe (removed by the next commit).
- `238d2fc` the watcher, its start and stop in `scripts/test.sh`, and
  their tests.
- `a47b95f` the records and the review order.
- `49bfdbd` the workflow split: the owner's commit of
  `.github/workflows/tests.yml`, the text the thread prepared.
- `4070060` the process list's time limit (below); `d627781` these
  records made true once the split was in, and the fourth stalled run.
- `bb61376` the agent requests Copilot's review itself (the guard, its
  settings, their tests and these records).
- `3ea1eb7` the process list's limit lowered to 5 s, the workflow test
  for two family jobs, and these records.
- `5dc9d6d` the owner's commit of `tests.yml` with the two family jobs.
- The commit after it: the workflow test runs the "UI tests" job's own
  script with every pair of family results (CodeRabbit's review).
- The commit after that: the guard records each Copilot review request
  that ran and refuses a second one on the same pull request, and guards
  `create_pull_request`'s reviewers (Codex's, CodeRabbit's and the
  independent review).
- The commit after that: what the split's first run and this thread's
  Copilot request showed, including that the guard did not run in this
  cloud thread (AGENTS.md, *Guardrails for agents*).
- The commit after that: Copilot's review, the watcher's two fixes and
  the guard refusing a request whose pull request it cannot read.

## Verified

- On Linux in the cloud session: `python3 scripts/test-runner.py`
  (69 tests, 13 of them new), `test-docs.py`, `test-hooks.py` (134
  tests, 10 of them new) and
  `test-site.py` pass. The new tests and the change each would fail on:
  `SimulatorLoadTests` (matching PosterBoard, pausing another
  simulator's or the Mac's own processes, pausing a stopped one or one
  twice, pausing without `--pause-posters`, totals instead of the time
  since the last reading, `start` not waiting for the watcher, `stop`
  not waiting for its summary, a watcher outliving the test run, a
  process list with no time limit or a time-out the watcher does not
  catch, looking up a simulator gone from the second list, leaving the
  paused extensions stopped, resuming after "Stopped.", resuming another
  process, or stopping at one already ended);
  `WatcherTests` (pausing on a simulator the run did not start, the
  watcher starting before the simulator finished starting or stopping
  after it, any exit path that skips the stop, a parent id that is not
  the script's own, a watcher failure that stops the tests or passes
  silently); `test_the_required_checks_stay_and_ui_tests_needs_both_families`
  (a renamed required job, a "UI tests" job without `if: always()`,
  needing only one family, both jobs on the same family, a matrix, the
  two jobs differing apart from the family, the gate not reading one
  family's result, or a gate script that passes when one family did not,
  such as `&&` for `||`: the test runs the gate's own script with every
  pair of results, CodeRabbit's review). Each mutation was run and failed
  its test. The workflow test passes on `main`'s single job and on the
  two family jobs, and fails on the matrix. The new hook tests (named
  above) and the change each would fail on: not recording after a
  request, not checking the record, recording before the call, after a
  failure or for any tool, keeping the record per worktree, trying the
  working directory before the project, comparing names by case,
  skipping the checks for a call that names no event, a silent record
  failure (inside or outside a clone), a deeply nested record raising,
  `create_pull_request`'s reviewers let through, a request whose pull
  request cannot be read let through, and a settings file
  without the `PostToolUse` hook or without `create_pull_request` in the
  guard's matcher. Each mutation was run and failed its test. The lock is
  not pinned by a test: a race test would pass by luck without it; the
  review saw one entry of eight lost without it.
- On GitHub's Mac machine (run 41625185733, Xcode 27.1, iPad Pro 13-inch
  (M5), iOS 27.0, portrait and landscape at default and largest text,
  light and dark, the full software keyboard): the measurements above.
- This pull request's own CI runs are the first runs of `test.sh` with
  the watcher, on both families and in the unit job. The first run of
  the two family jobs (41643818607, on `5dc9d6d`, iPad Pro 13-inch (M5)
  and iPhone 17, iOS 27.0) was cancelled by the next push: the unit
  tests passed; on the iPhone all 64 UI tests ran (58 passed, 6
  skipped, none failed) in 36.5 minutes; on the iPad the watcher paused
  13 wallpaper extensions at 13:29:44, 3.2 minutes before the first
  test, and 57 of the 64 tests had passed, none failed, in 40.7 minutes
  when the job was cancelled (`HomeLayoutTests` 102.6 s). "UI tests"
  then failed, as it must when a family is cancelled. A cancelled
  bundle has no `database.sqlite3`; the counts came from the test
  runner's output in its `Staging` folder.
- The Copilot record, by hand: fed the guard this thread's own request
  (owner, repository and pull request number as the tool sent them) as
  a `PostToolUse` event, it recorded `middleagedbanana/brickson#76` in
  the clone's Git folder, then refused a second request on #76 and let
  one on #77 through.

## Not verified

- One probe run is one machine. The prewarm came 5.5 and about 11
  minutes after boot in the two phases; the stalled runs put it 8 to 13
  minutes in. Whether it can come before the watcher's first reading
  pauses the extensions was not seen: in the probe's second phase the
  first reading came 6.5 minutes after boot, on a machine slowed by the
  fresh start, and still before the prewarm.
- The watcher's readings once stopped for 113 s (11:38:45 to 11:40:38,
  during the paused prewarm) while the tests and the runner's log carried
  on at their usual pace; no new extension started then. Why its process
  listing was held up is not known. `scripts/simulator-load.py` reads
  every process's path each time, and slow memory is one guess. A list
  that now takes more than 5 s is recorded as "could not read the
  process list", so a repeat will show whether `ps` was what waited.
- A whole iPad run with the watcher in `test.sh`: the first one was
  cancelled by a push with 7 tests to go (above). Whether a matrix
  summary can really read as passed with a leg never run was not
  reproduced; the two jobs make the question moot.
- `scripts/test.sh` with the watcher on the owner's Mac.
- Whether the hook's `cwd` follows the session's `cd`, which no longer
  decides where the record is once `CLAUDE_PROJECT_DIR` is set.
- The record of Copilot review requests in a live session. This thread
  requested Copilot at 14:21 UTC, but the repository's hooks did not run
  in this cloud thread at all: a `git add -A --dry-run`, which the guard
  refuses, ran (Claude Code 2.1.317), and the request left no record.
  The environment's documentation says a cloud thread applies a
  repository's settings only in a project with one repository; this
  thread had cloned only Brickson, and whether the project lists
  another repository was not checked. The hook first runs for real in
  a session that loads the repository's hooks, such as Claude Code on
  the owner's Mac.

## Follow-ups

- If an iPad stall comes back, read `simulator-load-ipad.txt` in the
  artifact first: whether the extensions were paused, and which process
  was busy. Owner of that: whichever thread meets it.
- When Apple fixes the prewarm on the simulator, or the machines get
  more processors, the pausing can be measured again and dropped if it
  no longer matters (docs/DECISIONS.md, "Tests").
- When the owner's Copilot subscription ends, the Copilot step in
  AGENTS.md, "Reviews and updates on GitHub", goes.
- *(owner)* The guard did not run in this cloud thread, and most of
  Brickson's agent work happens in such threads, so there its rules may
  rest on the agent and on review alone. Whether the project can load
  it (the environment's documentation names a project with one
  repository) is the owner's call, in the project's settings.
