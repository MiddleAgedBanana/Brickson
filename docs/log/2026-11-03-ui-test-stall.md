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
simulators, and gives up on a process list that takes more than 10 s,
writing so in the record, so a hung `ps` never holds it (CodeRabbit's
review). A paused process rather than an ended one, because iOS
would start an ended extension again; the open-source CI tool `yeetd`
pauses the same extensions the same way. Brickson does not use it: a
script of its own does only this, only for the simulator under test,
and installs nothing on the machine. No test shows the lock screen,
and the simulator is shut down after its run, which ends the paused
processes. The unit run gets the same watcher, since the prewarm comes
during its tests too.

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
merge. Each family now builds the app on its own machine, about ten
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
the owner adds Copilot once, so it sees the fixed code and Codex's
threads; a pull request that changes only documents gets no Copilot
review. The owner turned automatic Copilot review off that day. AGENTS.md,
"Reviews and updates on GitHub", still said Copilot reviewed every pull
request when it opened; it, docs/DECISIONS.md (*Code review* and the
ruleset table), docs/SDLC.md and docs/HANDOFF.md now say what happens.
The guard still refuses an agent's Copilot request, so the agent tells
the owner when Codex's round is answered.

## Commits

- `4a9dea4` the temporary probe (removed by the next commit).
- `238d2fc` the watcher, its start and stop in `scripts/test.sh`, and
  their tests.
- `a47b95f` the records and the review order.
- `49bfdbd` the workflow split: the owner's commit of
  `.github/workflows/tests.yml`, the text the thread prepared.
- The commit after it: the process list's time limit (below) and these
  records made true once the split was in.

## Verified

- On Linux in the cloud session: `python3 scripts/test-runner.py`
  (the 13 new tests among them), `test-docs.py`, `test-hooks.py` and
  `test-site.py` pass. The new tests and the change each would fail on:
  `SimulatorLoadTests` (matching PosterBoard, pausing another
  simulator's or the Mac's own processes, pausing a stopped one or one
  twice, pausing without `--pause-posters`, totals instead of the time
  since the last reading, `start` not waiting for the watcher, `stop`
  not waiting for its summary, a watcher outliving the test run, a
  process list with no time limit or a time-out the watcher does not
  catch);
  `WatcherTests` (pausing on a simulator the run did not start, the
  watcher starting before the simulator finished starting or stopping
  after it, any exit path that skips the stop, a parent id that is not
  the script's own, a watcher failure that stops the tests or passes
  silently); `test_the_required_checks_stay_and_ui_tests_needs_both_families`
  (a renamed required job, a "UI tests" job without `if: always()`,
  one family missing, the gate not reading the family jobs' result, or
  not failing). Each mutation was run and failed its test. The workflow
  test passes on `main`'s `tests.yml` and on the split.
- On GitHub's Mac machine (run 41625185733, Xcode 27.1, iPad Pro 13-inch
  (M5), iOS 27.0, portrait and landscape at default and largest text,
  light and dark, the full software keyboard): the measurements above.
- This pull request's own CI runs are the first runs of `test.sh` with
  the watcher, on both families and in the unit job.

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
  that now takes more than 10 s is recorded as "could not read the
  process list", so a repeat will show whether `ps` was what waited.
- The iPhone family with the watcher first runs in this pull request's
  CI.
- The split's first runs are this pull request's CI runs from `49bfdbd`
  on; nothing ran it before. The new workflow test accepts both the old
  single job and the split.
- `scripts/test.sh` with the watcher on the owner's Mac.

## Follow-ups

- If an iPad stall comes back, read `simulator-load-ipad.txt` in the
  artifact first: whether the extensions were paused, and which process
  was busy. Owner of that: whichever thread meets it.
- When Apple fixes the prewarm on the simulator, or the machines get
  more processors, the pausing can be measured again and dropped if it
  no longer matters (docs/DECISIONS.md, "Tests").
- When the owner's Copilot subscription ends, the Copilot step in
  AGENTS.md, "Reviews and updates on GitHub", goes.
