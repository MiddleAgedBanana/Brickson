# What a week of CI failures were, and the UI tests now wait for a settled Mac

*2026-11-19. Pull request #128 (`claude/project-thread-ltn8l9`). A
Claude Code cloud thread in the project, asked by the owner for one
investigation of the UI test failures on GitHub's machines that drafts
no other change. Nothing here ran outside GitHub CI.*

## What changed and why

**For someone working on Brickson:** each UI test job on GitHub now
waits, after the build and the warm-up launch, until the Mac is no
longer busy with the simulator's start, and only then runs its first
test. The wait is printed in the job's log, a line a minute, and
written into the simulator's record. Nothing a person using Brickson
sees changes.

**The question.** Since about 2026-11-12, UI test jobs kept failing on
pull requests that had not touched the failing test, and passing on a
second try. Each failure had been met with a fix or a longer wait in
that one test. The owner asked for one investigation, apart from any
pull request, of every failure side by side: is the trouble GitHub's or
ours, and what is the cause.

**What was read.** Every UI test job from 2026-11-12 to 2026-11-19
11:20 UTC that ran to an end and kept its results, 320 of them, passed
or not. From each, two files: the simulator's record
(`simulator-load-<family>[-part<n>].txt`, the Mac's load every five
seconds) and the result bundle's database (every test step with its
start and end). A step **stalled** when a
wait ran ten seconds or more past its own limit, or any single step
took thirty seconds or more. **Load** is the Mac's own count of tasks
running or waiting for a processor, averaged over a minute. The script
under *Verified* reads one job the same way.

### The failures, sorted

In that week 269 UI test jobs passed and 52 did not (51 of the 320,
and one stopped at its limit that kept no results):

| Kind | Jobs | Cause, and how sure | Whose | Now |
| --- | ---: | --- | --- | --- |
| A. A wait ran out while the Mac was still busy with the simulator's start | 19 | The tests start in the middle of the simulator's first start-up work (below). Strong: measured three ways, not yet shown by experiment | The work is iOS's and the small Mac GitHub's; when the tests start is ours | This pull request |
| B. The simulator was lost, or the job crawled to its 90-minute limit, on GitHub's new machine image | 5 | Image `xcode-27-arm64` 20261112.0361.1 (below). Proved | GitHub's | Rolled back by GitHub on 2026-11-16 |
| C. The simulator or the test runner was lost on the usual image | 4 | Unknown. 2026-11-13 once; 2026-11-17, three jobs between 17:27 and 18:02 UTC | By its signs GitHub's or Xcode's | Not seen since |
| D. The order test read Home in screen order | 8 | SwiftUI applied the order late; fixed by declaring Home in the order it is reached. Proved (#126). Every one came with the load at 350 to 580 | Ours | Fixed 2026-11-18; none since |
| E. The keyboard's suggestion bar had no words at the Library's audit | 7 | The keyboard's first showing on a new simulator; reproduced on the Mac. Proved (#125) | Apple's keyboard; our test | Fixed 2026-11-18; none since |
| F. XCTest's wait for UIKit's animations was never answered, to the 90-minute limit | 3 | Known since 2026-11-13 (docs/DECISIONS.md, "Tests") | Xcode's | Fixed by #107 on 2026-11-13 |
| G. New tests failing on the pull request that added them | 4 | The check-in card's own tests while it was written (2026-11-12) | That pull request's | Fixed there |
| H. Settings' idle test failing on a settled Mac | 1 | Not the start-up work: the load was 26. The lead in docs/HANDOFF.md, *Known gaps*, stands | Ours | Open |
| J. A part crawled to its limit with every test very slow | 1 | Unknown. Job 133941672628, 2026-11-17, once, on a commit since replaced | Unknown | Not seen again |

Besides those, **twelve jobs were cancelled** with nothing in their log
but "The operation was canceled.", while the rest of their run carried
on, with no new push and far from any time limit: eight "Unit tests"
jobs and four iPad UI jobs (kind K, below). Jobs cancelled because a
newer push replaced their run are not failures and are not counted.

So this was never one fault. Two real defects were found and fixed that
week (D, E), one day belonged to GitHub (B), and under all of it runs
one cause that is still there: A, and by the signs K, the same thing at
its worst.

### A. The tests start inside the simulator's first start-up work

GitHub's Mac has three processors and 7 GB of memory (it says so in
every result bundle). Each job gets a new machine, so each simulator
starts for the first time, and a first start begins hundreds of
background tasks: indexing, widgets, wallpapers, health, news, Screen
Time and more.

1. **Every job, passed or failed, is saturated at first.** From the
   moment the simulator has started, all three processors are busy and
   400 to 550 tasks wait for one. The middle job's load, by minutes
   since the record began (about four minutes into the job): about 500
   at once, 410 to 480 at 5 minutes, 350 to 420 at 10, and under 150
   only at 14 to 15 minutes when one job ran a whole family, 17 to 22
   minutes since the tests run in three parts (one job in ten: 24 to
   31).
2. **The tests begin at minute 5.** Building takes about five minutes,
   then the first test starts. A part's tests take 20 to 26 minutes, so
   since 2026-11-16 more than half of every part's tests run on a busy
   Mac; before, about a sixth of a family's did. The split into parts
   did not create the trouble: it put several times as many tests into
   it.
3. **Failures follow the load, step by step.** By the load when a test
   started, failures in each thousand runs: under 150, 0.1 (one in
   10,504); 150 to 250, 1.2; 250 to 350, 2.2; 350 to 450, 8.5; above
   450, 7.6. By time since the record began, failures in each thousand
   minutes of tests: 13.0 in minutes 0 to 5, 7.5 in 5 to 10, 2.6 in 10
   to 15, 1.3 in 15 to 20, 0.4 in 20 to 30, 0.2 after 30.
4. **No step stalled on a settled Mac.** In about 7,400 minutes of
   tests with the load under 250, none; in about 2,520 minutes above
   it, 50. Stalls happen in jobs that pass too (15 of 79 passing iPad
   part jobs): a job fails only when a stall lands on a step with a
   tight limit, which is why the same commit passes on a second try.
5. **The same test, moved into the busy time, began to fail.**
   `LaunchTests.testLargestTextKeepsQuickControlWordsVisible` never
   failed in 139 runs while it ran about 25 minutes in, at a load of
   about 44. In the last part it runs about 11 minutes in, at a load of
   about 380, and failed 5 of 58 times, on four branches, `main`'s run
   of 2026-11-18 among them; when it passes there it takes 60 seconds
   where it took 45. Across the 48 tests with ten or more passing runs
   each way, a test that started above a load of 350 took about 30%
   longer than the same test under 150.
   `HomeSizesTests.testHomeIsLargestUntilAnsweredAndTouchsOnceTouchIsChosen`
   moved from about minute 20 to about minute 7 and timed out four
   times, but all four on pull request #123's branch (4 of its 9 runs,
   none of 51 elsewhere), so that branch's own change is part of it and
   it is weaker evidence.
6. **What is busy.** Widget extensions by the dozen, `chronod`,
   `BackgroundShortcutRunner`, `healthappd`, `intents_helper`, Screen
   Time, News, Fitness, PosterBoard and the wallpaper extensions, with
   `diagnosticd` and `apsd` at 20% to 70% and 10% to 45% of a processor
   the whole job. The wallpaper extensions this repository pauses
   (docs/DECISIONS.md, "Tests", 2026-11-03) are a small part of it:
   under a fifth of the simulator's processor time at their busiest,
   and the timed-out audit on pull request #123 that had no wallpaper
   work in its record (job 135099789494) came at minute 6.5 with a load
   of 320 to 335. Pausing them has the cost
   `log/2026-11-04-watcher-without-ps.md` found: iOS starts new ones as
   they are paused, a middle of 57 times a job over about five minutes.

**Hypothesis.** UI tests time out because they run while the Mac is
still doing the simulator's first start-up work; a test that starts
once the load is under 150 behaves as it does late in a job.

**What it predicts** for a job that waits for that before its first
test:

1. the record shows the wait ending with the load under 150 within its
   twenty minutes;
2. no step stalls (the script below prints none);
3. each test takes about as long as it did under a load of 150, so a
   part's tests take about a sixth less time than now;
4. the timed-out waits of kind A stop.

**What would show it wrong.** A stall, or a kind A time-out, in a test
that started with the load under 150; or a load that climbs back over
250 once the tests begin, which would mean the tests themselves, not
the start-up work, make the queue.

**The fix.** `scripts/test.sh ui` now runs
`scripts/simulator-load.py settle` after the warm-up launch and before
the tests. It reads the load every five seconds and goes on once three
readings in a row are under 50 for each of the Mac's processors (150 on
GitHub's three), or after twenty minutes, saying which. It only waits.
No test is retried, skipped, given a longer limit or checked less; an
accessibility audit runs exactly as before. A Mac that does not settle
is tested anyway, with a warning, and so is one whose wait could not
run. On a Mac with more processors the limit is higher (700 on
fourteen), so the wait there is the ten seconds its three readings
take. The unit tests are not held: none of their failures that week
was a time-out. Decision: docs/DECISIONS.md, "Tests", 2026-11-19.

**What it costs.** Unknown until it has run, so this pull request's own
CI run is the first measurement. If the start-up work takes as long
with no tests beside it as it does now, the wait is about 12 to 16
minutes a job; it should be less, since the tests no longer compete for
the processors, and the tests themselves should take three or four
minutes less. A part's job takes 28 to 35 minutes today against a 90-minute
limit.

**Not chosen.**

- *Longer waits in the tests that failed.* That is what each failure
  got so far, and the next test to land in the busy time fails the same
  way. In pull request #123's newest failure a ten-second check was
  answered after 100 seconds.
- *Stopping iOS's background tasks* (`launchctl disable`, or ending
  `diagnosticd`), as some projects do. It changes the system the tests
  run on, and each task stopped would need its own proof that nothing
  the tests check depends on it.
- *Keeping a started simulator's data between runs*, so no start is a
  first start. This would remove the work instead of waiting for it
  and give the minutes back; it needs a workflow change with a cache
  and a new action, which the owner would have to put in, and its own
  experiment. It is the follow-up to weigh if the wait proves long.
- *A larger paid machine.* It would hide the cause at a monthly cost.
- *Dropping the wallpaper pausing.* It may no longer earn its place
  once the tests start on a settled Mac; one change at a time
  (*Follow-ups*).

### B. One day was GitHub's machine image

On 2026-11-16 from about 00:15 to 10:50 UTC, some jobs ran on image
`xcode-27-arm64` 20261112.0361.1 (macOS 27.2, build 26B123) instead of
20261104.0337.1 (macOS 27.0.1). Of this repository's jobs on it, most
failed: simulators took 5 to 11 minutes to start, a warm-up launch took
320 seconds, three UI jobs ran to the 90-minute limit, twice the
simulator had shut down by itself after every test had passed, and one
unit job ran no test. Other developers
reported the same that day, the simulator's runtime being unmounted
while it ran, in `actions/runner-images` issues 15334 and 15337; one
counted it on 20 of 27 jobs on the new image and none of 35 on the old.
GitHub answered in 15334 that a rollback to 20261104.0337.1 was in
progress and then complete, and Apple lists the fault as a known issue
in Xcode 27.3 beta 2's release notes (191574717). Three more jobs on
2026-11-17 between 17:27 and 18:02 UTC, on the old image, lost their
simulator or test runner in the same ways, and one on 2026-11-13 had
the simulator's service crash four minutes in (kind C); nothing in our
scripts explains those.

GitHub's status page showed Actions incidents on 2026-11-09, 10, 11 and
16 (11:59 to 16:26 UTC). None matches kind A, which is in every run.

**Watch for:** on 2026-11-19 GitHub published a pre-release image,
20261119.0378, again with macOS 27.2 (26B123). If jobs stop at their
limit or lose the simulator again, read the image's version at the top
of the job's log first ("Runner Image", "Version"): anything but
20261104.0337.1 on such a day is GitHub's, and a second try may land on
the old image.

### K. Twelve jobs cancelled by nobody

Jobs 131888864802, 132378333766, 132666697858, 132782961624,
133728538153, 133728538354, 133809038493, 133813222902, 133941760558,
135347957492, 135347957553 and 135524904860, from 2026-11-13 to
2026-11-19.

- Every one was cancelled 8.5 to 13 minutes after its simulator began
  to start. All twelve used the iPad simulator (the unit tests run on
  it too); no iPhone job was ever cancelled this way.
- Their records show a load of 550 to 860 where 500 is usual, and the
  record's own watcher, one small Python process, took up to seven
  minutes to start. One simulator took 13 minutes to start and another
  9.5.
- In eight of the twelve the build had run under two minutes or not
  begun, so the build is not what did it.
- Twice, two jobs of one run were cancelled within five minutes of each
  other.

**Lead, not proved:** GitHub's agent on the machine has to keep telling
GitHub's service that it still holds the job. Starved for about ten
minutes it cannot, and the service takes the job back. That would fit
the timing and the load, and other developers report jobs "cancelled"
with no useful error when a runner runs out of a resource (GitHub
community discussion 160680). The agent's own log is not ours to read,
so this stays a lead. It is kind A's cause at its worst, on the heavier
simulator.

The wait in this pull request does **not** fix these: they happen
before the tests, at the height of the start-up work. What could, each
needing its own experiment, is in *Follow-ups*.

## Commits

One commit: the wait (`scripts/simulator-load.py`, `scripts/test.sh`),
its tests (`scripts/test-runner.py`) and these records.

## Verified

- `python3 scripts/test-runner.py` on the cloud thread's Linux machine:
  115 tests, 5 skipped there because they need a Mac (GitHub's unit job
  runs them). Seven are new:
  - `PreparationTests.test_ui_tests_start_only_after_the_wait_for_the_mac_to_settle`
    and the list in `test_ui_tests_get_the_full_keyboard_and_a_warm_simulator`
    fail if the wait is dropped, or moved before the warm-up (tried);
  - `test_unit_tests_only_wait_for_the_simulator` fails if the unit
    tests wait too (tried);
  - `test_a_failed_wait_to_settle_is_reported_and_the_tests_still_run`
    fails if a wait that cannot run stops the tests or passes silently
    (tried);
  - `SettleTests`: the wait ends only after three readings in a row
    under the limit (fails with two, or with readings not in a row;
    tried), the limit is 50 for each processor (fails with a fixed 150;
    tried), a Mac that never settles is tested after twenty minutes with
    a warning and a line a minute meanwhile, a load that cannot be read
    holds nothing, and the real command runs.
- The other checks AGENTS.md lists for any machine passed on the same
  machine (`test-docs`, `test-hooks`, `test-privacy`,
  `test-forbidden-code`, `test-agent-bridge`, `test-site`,
  `test-select-xcode`).
- The figures above: each job's record and result bundle from GitHub,
  read with scripts kept outside the repository. This reads one job the
  same way (a result bundle unzipped from the job's "ui-test-results"
  download, and the record beside it):

  ```python
  import re, sqlite3, sys
  from datetime import datetime, timedelta, timezone

  bundle, record = sys.argv[1:3]
  # The bundle's times are seconds since the start of 2001, in UTC.
  START = datetime(2001, 1, 1, tzinfo=timezone.utc)
  loads = []  # (second of the day, load), from the record's lines
  for line in open(record, encoding="utf-8", errors="replace"):
      found = re.match(r"(\d\d):(\d\d):(\d\d) simulator .* load +([\d.]+) ", line)
      if found:
          hour, minute, second, load = found.groups()
          loads.append((int(hour) * 3600 + int(minute) * 60 + int(second), float(load)))

  def load_at(seconds):
      moment = START + timedelta(seconds=seconds)
      second = moment.hour * 3600 + moment.minute * 60 + moment.second
      near = min(loads, key=lambda entry: abs((entry[0] - second + 43200) % 86400 - 43200))
      return f"{moment:%H:%M:%S} load {near[1]:.0f}"

  db = sqlite3.connect(f"{bundle}/database.sqlite3")
  tests = db.execute(
      "select c.identifier, r.result, min(a.startTime) from TestCaseRuns r "
      "join TestCases c on r.testCase_fk = c.rowid "
      "join Activities a on a.testCaseRun_fk = r.rowid group by r.rowid order by 3").fetchall()
  print(f"{len(tests)} tests; the first started at {load_at(tests[0][2])}")
  for name, result, started in tests:
      if result != "Success":
          print(f"  {result}: {name}, started at {load_at(started)}")
  parents = {row[0] for row in db.execute("select distinct parent_fk from Activities")}
  for rowid, title, started, finished in db.execute(
          "select rowid, title, startTime, finishTime from Activities "
          "where startTime is not null and finishTime is not null order by startTime"):
      took, wait = finished - started, re.match(r"Waiting ([\d.]+)s for", title or "")
      if (wait and took - float(wait.group(1)) >= 10) or (
              not wait and rowid not in parents and took >= 30
              and not (title or "").startswith("Start Test")):
          print(f"  stalled {took:.0f} s at {load_at(started)}: {title[:70]}")
  ```

  On pull request #123's failed job of 2026-11-19 (135524773241) it
  prints: 25 tests, the first started at 11:29:04 with a load of 445;
  `HomeSizesTests.testHomeIsLargestUntilAnsweredAndTouchsOnceTouchIsChosen`
  failed, started at a load of 518; a ten-second wait for Family
  Setup's button took 100 seconds at a load of 528.

## Not verified

- **Whether the wait works.** Nothing here has run on GitHub's Mac
  yet. This pull request's first CI run is the experiment, and its
  result, against the four predictions above, is in the pull request's
  description. One run is six UI jobs: enough to see how long the wait
  is, whether steps stall and how long tests take, not enough to count
  failures that came once in ten jobs. That needs about twenty runs.
- How long the wait is, and so what a job now takes.
- That the wait is short on the owner's Mac: reasoned from its limit
  there (700), not run.
- Why the load takes longer to fall since the tests run in parts (a
  middle of 19 minutes against 14.5). More of our own jobs start at the
  same moment since then; whether that is the reason is not known.
- The cause of the twelve cancelled jobs (a lead only), of the one part
  that crawled to its limit (J), and of the three jobs of 2026-11-17
  and one of 2026-11-13 that lost their simulator on the usual image
  (C).
- The app was not built or run for this change, which changes no app
  code.

## Follow-ups

- **Read this pull request's CI run** with the script above and put the
  result in its description *(this thread)*.
- **After about twenty runs with the wait on `main`,** count kind A
  again. If stalls or time-outs remain in tests that started settled,
  the hypothesis is wrong for those and they need their own look *(the
  next thread on CI)*.
- **The cancelled jobs (K).** In the order to try them: keep a started
  simulator's data between runs, which removes the start-up work, the
  cancelled jobs' likely cause and most of the wait together, at the
  cost of a workflow change the owner pastes; give GitHub's agent a
  higher priority on CI, one line, if the lead about the agent holds;
  build before starting the simulator, which keeps the build out of
  the worst ten minutes (four of the twelve had five minutes of build
  in them). Until one is tried, a cancelled "Unit tests" or iPad job
  with only "The operation was canceled." in its log is this, and a
  second try is the remedy *(the owner chooses whether a thread takes
  it up)*.
- **Measure the wallpaper pausing again** once the tests start on a
  settled Mac, as docs/DECISIONS.md, "Tests" (2026-11-03) asks: if a
  run without it shows no stall, drop it and its restart loop *(a
  later thread, one change at a time)*.
- **Settings' idle test (H)** stays with its lead in docs/HANDOFF.md,
  *Known gaps*.
