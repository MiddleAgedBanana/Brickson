# The simulator's start runs in the background, so GitHub's agent keeps in touch

*2026-11-22. Pull request #132 (`claude/ci-start-in-background`).
Claude, in a project thread, on the owner's Mac; the CI results from the
third commit's runs on were added by Claude in a cloud thread.*

## What changed and why

Nothing changes for a person using Brickson. For the people working on
it: GitHub's Mac test jobs kept being cancelled with nothing in their log
but "The operation was canceled.", and a second try was the only remedy.
Pull request #131 caught why: GitHub's own agent on the machine (the
runner program that holds the job's session with GitHub) had its
requests time out, lost its session, and cancelled the job itself as it
shut down ([`2026-11-21-github-agent-log.md`](2026-11-21-github-agent-log.md)).
This pull request finds what starves the agent and keeps it from
starving.

`scripts/test.sh` now, on a simulator it starts itself:

1. starts the simulator watcher (`scripts/simulator-load.py`) **before**
   the simulator, so the record covers its first minutes, which it never
   did (in the jobs that were cancelled, the watcher began 8 to 11
   minutes after the boot, or never);
2. as soon as `simctl boot` has succeeded, tells the watcher this run
   started the simulator (the claim), and once `simctl bootstatus` says
   the simulator has started, says that too, each by creating a file
   with the shell alone, which the watcher reads every second; from the
   claim the watcher pauses the wallpaper extensions, as before, and
   from the start, or a minute after the claim if `bootstatus` has not
   said so by then, it puts every process of the simulator in macOS's
   **background band**, its `launchd_sim` first, and each new one within
   a second;
3. after the build (and, for UI tests, the warm-up launch), returns every
   process of the simulator to normal priority, **checks that it is
   there**, and writes the result into the record (`restore`); if that
   cannot be confirmed, the run stops before its first test and fails,
   saying why;
4. then waits for the Mac to settle, for the unit tests too now: the
   Mac's load leaves out work in the background band, so the wait comes
   after the return (*What this pull request's CI runs showed*);
5. tests, as before.

Each line of the record now also says how much of a processor GitHub's
agent got since the last line, at what priority, and how many of its
threads were running or waiting; its first lines name the agent's two
programs and their priority. Decision: docs/DECISIONS.md, "Tests",
2026-11-22.

### What starves the agent: the simulator's own start, not our work

The brief was to cut what each job does at once in its
first ten minutes: the build, the simulator's start, indexing and
background work, parallel jobs. Measured first, before any change:

**Seven self-cancelled jobs whose timeline could be read** (each job's
own log, times in minutes after the simulator began to start):

| Job | Run | Cancelled at | `bootstatus` began | Build at the cancel |
| --- | --- | ---: | ---: | --- |
| iPad, part 2 | 44808545851, 2026-11-20 | 10.3 | never | not started |
| Unit tests (`main`) | 44902798573, 2026-11-21 | 11.0 | 2.7 | 6 seconds in |
| Unit tests (#130) | 44904762672, attempt 1 | 8.1 | 2.3 | 12 seconds in |
| Unit tests (#130) | 44904762672, attempt 2 | 8.4 | 2.5 | 18 seconds in |
| iPad, part 1 (#131) | 44916610210, 2026-11-21 | 10.1 | 3.6 | not started |
| iPad, part 1 (#131) | 44978309832, 2026-11-22 | 10.9 | 3.3 | not started |
| iPad, part 3 (`main`) | 44987905703, 2026-11-22 | 9.3 | 1.4 | not started |

In none of them had the build done anything. In the four UI jobs the
only programs of ours that had started were `simctl bootstatus`, the
watcher and, in one of them, the two `simctl spawn` keyboard settings,
still unfinished six and a half minutes later. The three with an agent log (the
last three rows) show the agent renewing its hold on the job every
minute for the first three to four and a half minutes, then **no line
at all for four to six minutes**, then requests "timed out after 100
seconds" written minutes late, then "Runner session is invalid": the
agent's own process was hardly running. Their loads were 752 to 861 on
three processors. Even `simctl bootstatus`, a small program, took 1.3 to
5.4 minutes to print its first line after the boot in 70 jobs of six
recent runs, passed or not.

**What the simulator's start costs**, measured on the owner's Mac (M4
Pro, 14 processors, Xcode 27.2, a new iPad Pro 13-inch (M5) simulator
on iOS 27.2, every process's processor time read every five seconds):

- a first start: about 725 processor-seconds of work in 388 processes
  within about two and a half minutes (on GitHub's three slower
  processors, five to eight minutes of all of them); wallpaper
  extensions 20%, widget extensions 9%, logging 7%, and 232 other
  daemons and apps the rest;
- a second start of the same simulator: about 417 processor-seconds,
  the wallpaper extensions again among the busiest; so keeping a
  started simulator between runs would remove less than half;
- the device's folder after a first start: 2.8 GB.

So no ordering or limit of our own steps can make the early load clearly
lower: the load is iOS's, and it arrives within seconds of the boot.
Neither does raising GitHub's agent with `nice`: on the owner's Mac a
renice changed the task's priority but not the threads', which carry a
quality-of-service class (and a program `launchctl` starts ran at 20,
below a simulator's daemons at 31, whatever its nice value).

### The fix: the start-up work yields

macOS's background band (`setpriority` with `PRIO_DARWIN_PROCESS` and
`PRIO_DARWIN_BG`, what `taskpolicy -b` sets) is the system's own way to
say "run this only when nothing else wants to": a process in it runs,
reads, writes and uses the network only when nothing outside it is
waiting, so GitHub's agent, the build, `xcrun` and the watcher come
first, and the start-up work still has every moment they leave. A
process takes the band from the process it is started from, so with
`launchd_sim` in it, every process the simulator starts later is in it
from its first instruction (checked on the owner's Mac: Settings,
launched under a lowered `launchd_sim`, ran at priority 4).

iOS itself runs about two thirds of a started simulator's processes in
that band already (on the owner's Mac, 131 of 201 after a start;
`launchd_sim`, SpringBoard, backboardd, `diagnosticd`, `apsd` and
`chronod` at 31). The heavy ones on GitHub's Macs, the widget
extensions, `diagnosticd` and `apsd`, are among the rest. This adds them
for the start-up only.

**When it begins.** Held in the band from the boot itself, a first start
on the owner's Mac had not finished after six minutes and 46 seconds,
and finished two seconds after its return to normal priority (on Apple
silicon the system runs background work on the efficiency cores when it
can, here four of fourteen); at normal priority it takes 19 seconds
there. In the captured jobs the agent kept in touch for the first three
to four and a half minutes. So the band begins once `bootstatus` says
the simulator has started, or a minute after the boot, whichever comes
first: on GitHub's machines `bootstatus` itself began 1.3 to 5.4 minutes
after the boot, too late in some jobs, so there the minute decides.

**Why files, and not a command.** A first version told the watcher with
a small command run once `bootstatus` had returned. In the seven jobs
above, the program in that place (the old watcher's start) came up only
7.9 to 10.9 minutes after the boot in five, never in a sixth, and at 2.5
minutes in the seventh: a minute or less before the cancel, or never. A
running program fares far better: the watcher, once going, wrote its
lines five to nine seconds apart at a load of 850. So the script, which
is running too, creates the two files with its own redirection (`: >`),
starting nothing, and the watcher, started before the boot on a quiet
Mac, looks for them every second.

**The return is checked, not assumed** (a condition of this plan):
`restore` first makes the watcher stop lowering and waits for it to say
so (a watcher that does not answer within 15 seconds is
stopped, so it can lower nothing after the return). It then returns
`launchd_sim` and every process under it, in passes, until a pass finds
no process it had not returned, so a process started during a pass is
returned by the next; it reads `launchd_sim`, SpringBoard and backboardd
back, which iOS never runs in the background, and writes what it found.
Returning a process clears only the setting the watcher made: on the
owner's Mac, twice, every one of a settled simulator's 209 processes
read back at the priority it had before a lower-and-return round trip,
and the real `restore` returned 234 processes of a lowered simulator in
one pass and 0.2 seconds. If the return cannot be confirmed (no
`launchd_sim`, a process that could not be returned, one of the three
still in the band, or new processes still appearing after five passes),
the run stops before its first test: on a throttled simulator the strict
limits of the tests that prove a phrase speaks on the first activation
could run out and read as the app's fault, while a failed job that says
why is seen and run again. If the watcher stops first (a failed build,
say), it returns what it lowered itself.

**Unit tests now wait for the Mac to settle.** Once the simulator is
returned to normal priority after the build, the rest of its start-up
work would meet the unit tests at full priority, and twelve of the
twenty jobs cancelled this way since 2026-11-13 were "Unit tests". This reverses the 2026-11-19
line "the unit tests do not wait" (docs/DECISIONS.md, "Tests"). On this
pull request's three runs on `c362cd0` the wait cost 3.4 to 5.5 minutes
(*What this pull request's CI runs showed*).

**What the gauge is.** The load average counts work in the band too, so
it stays high while the simulator starts; the change is judged by no
job cancelled by itself, by how soon the start-up work is lowered after
the boot (the record's "put ... in the background" line, a minute at
most), by how soon an ordinary program starts while the simulator does
(`bootstatus`'s first line; the agent's share in the record), and by the
record saying when the simulator was returned.

**Not chosen.** Building before the simulator starts, or with fewer
parallel tasks: none of the seven jobs had built. Telling the watcher
with a command, or a signal sent by one: above. Keeping a started
simulator between runs: a new action and a cache, for less than half the
work. `nice` on GitHub's agent: no effect on its threads' priority.
Stopping iOS's own background tasks: declined on 2026-11-19, as it
changes the system the tests run on; this changes only when the
start-up work runs, and it is undone, and checked, before any test.
Lowering from the boot: far too slow on a Mac with efficiency cores
(above).

## What this pull request's CI runs showed

**The first run** (44999954298, on `25f59fd`, image `xcode-27-arm64`
20261104.0337.1):

- **No job cancelled itself.** The six UI jobs passed. "Unit tests"
  failed in its script tests, before any simulator started:
  `MacProcessesTests.test_a_reading_starts_no_process` found the
  watcher's new line naming GitHub's agent, which only GitHub's Macs
  have. Fixed in the next commit (the test allows that line).
- **GitHub's agent runs at priority 20.** In every job, the record's
  first line read "Runner.Listener ... at priority 20, Runner.Worker ...
  at priority 20": the utility band, below the 31 of SpringBoard,
  `diagnosticd`, `apsd` and the rest of a simulator's daemons. So before
  this change the simulator's start-up work outranked GitHub's agent,
  which is why the agent, and not only our tests, starved.
- **Lowering came on time.** In all six jobs it began 61 to 63 seconds
  after the claim: the minute decided, not `bootstatus`. `bootstatus`
  printed its first line 1.0 to 1.1 minutes after the boot (1.3 to 5.4
  before), and the simulator finished starting 1.1 to 5.9 minutes after
  the boot. The returns: 237 to 276 processes in one to three passes,
  `launchd_sim`, SpringBoard and backboardd at 31 every time.
- **But the wait to settle no longer waited.** While the simulator was
  lowered the Mac's load read 21 to 202, mostly under 100: the load
  leaves out threads in the background band. So every wait ended on its
  first three readings, 10 seconds, the return came 4.3 to 8.3 minutes
  after the boot, and the start-up work, back at normal priority, ran
  during the tests: loads of 203 to 454 in minutes 6 to 16. Every test
  passed, but that is where 2026-11-19 found failures eight times as
  often. The second commit tried adding the lowered simulator's threads
  running or waiting for a processor to the load; the third moves the
  return before the wait instead (below).
- **Job times** were 20.6 to 30.1 minutes (iPad 22.2, 30.1 and 22.3;
  iPhone 27.4, 20.6 and 28.4), against 28 to 45 before, because the
  tests started at once; the wait as fixed gives some of that back.

**The second run** (45004753307, on `e47b8d9`): **green, and again no
job cancelled itself**; GitHub's agent at 20 in every job; lowering 60 to
64 seconds after the claim; returns of 194 to 282 processes in one or two
passes, all read-backs at 31. "Unit tests" ran 1112 tests (1099 passed,
none failed, 1 skipped, 12 expected failures) in 33.9 minutes. But the
added count did not hold the wait: at the wait the lowered simulator had
only 14 to 35 threads running or waiting, so every UI wait ended in 10
seconds (the unit job's in 30), and after the return the loads during
the tests reached 179 to 419 in the UI jobs and 527 in the unit job.
Work held in the band also waits on the disk and the network, which a
count of runnable threads does not see. So the third commit returns the
simulator to normal priority first, after the build and the warm-up
launch, and then waits on the plain load, as calibrated on 2026-11-19:
the rest of the start-up work is then counted in the load, and the tests
start after it. Job times on this run: iPad 32.8, 23.6 and 25.6 minutes;
iPhone 32.0, 25.8 and 26.3.

**The third run** (45028192794, on `c362cd0`): **green, and no job
cancelled itself**; the step that keeps GitHub's agent log after a
cancel was skipped in every job. The return now comes before the wait,
and the wait waited: in the unit job the load was 134 when the wait
began, iOS's post-boot work took it to 270 during the wait, and the
record reads "the Mac settled after 205 s: load 119.6", so the wait cost
about 3.4 minutes. After it the unit job's load stayed at or under 120
for its tests, fell to about 20 within nine minutes and ended at 8 to
14 (527 on `e47b8d9`'s run). The return: 165 processes in three
passes, `launchd_sim`, SpringBoard and backboardd at 31. Job times: iPad
35.0, 23.1 and 37.3 minutes; iPhone 17.2, 25.8 and 25.3; "Unit tests"
28.2 (its build-and-test step 26.5). Two of the seven Mac jobs (iPad
part 2 and the unit job) waited for a machine first, as they do when a
run has more jobs than GitHub gives it at once.

**The fourth run** (45033062240, started by hand on `c362cd0`):
**green, and no job cancelled itself**. The wait cost more this time: in
the unit job the load was 146 when the wait began, iOS's post-boot work
took it to 657 during the wait, and the record reads "the Mac settled
after 330 s: load 123.3", so the wait cost about 5.5 minutes. After it
the load fell to about 20 within three minutes and ended at 16 to 24.
The return: 162 processes in two passes, the same three at 31. Job
times: iPad 31.6, 29.4 and 28.3 minutes; iPhone 29.7, 31.6 and 15.3;
"Unit tests" 35.0 (its build-and-test step 32.8). iPad part 3 and the
unit job waited for a machine first.

**The fifth run** (45040621441, started by hand on `c362cd0` after the
fourth ended): **green, and no job cancelled itself**. In the unit job
the load was 166 when the wait began, iOS's post-boot work took it to
391 during the wait, and the record reads "the Mac settled after 315 s:
load 127.4", so the wait cost about 5.3 minutes. After it the load rose
once to 163, fell under 50 within five minutes and stayed between 20
and 84 while the tests ran. The return: 160 processes in four passes,
the same three at 31. Job times: iPad 30.9, 16.4 and 27.1 minutes;
iPhone 31.9, 25.5 and 30.3; "Unit tests" 41.9 (its build-and-test step
39.3). iPad part 1 and the unit job waited for a machine first.

**What the three runs on `c362cd0` show.** None of their 21 Mac jobs
cancelled itself. The wait before the unit tests cost 3.4, 5.5 and 5.3
minutes, about 4.7 on average, and each time it ended with the load
under 150 after iOS's post-boot work had peaked at 270 to 657.

## Commits

- `25f59fd`: the watcher's lowering, its claim and start files and
  `restore`, the agent's lines, the new order in `scripts/test.sh`,
  their tests in `scripts/test-runner.py`, these records,
  docs/DECISIONS.md, docs/HANDOFF.md (with its state line) and
  `README.md`.
- `e47b8d9`: from the first CI run, the wait to settle counted a
  lowered simulator's threads (since removed), and the test that saw
  GitHub's agent allows its line; from the reviews (Codex, CodeRabbit
  and Gitar), `restore` ends a watcher that has not begun (it would
  lower the simulator once it began), asks a silent watcher to stop
  before killing it (so it lets the wallpaper extensions it paused run
  again), and a watcher that stops first returns every process now under
  the simulator, not only the ones it lowered; and a test the first
  commit dropped by mistake is back.
- `c362cd0`: from the second CI run, the return to normal priority
  comes before the wait to settle, which reads the plain load again; the
  lowered-thread count is removed (CodeRabbit's review of `e47b8d9` also
  found it counted the simulator twice when the watcher had not
  started).

## Verified

- On the owner's Mac (macOS 27.2, Xcode 27.2, `/usr/bin/python3` 3.9):
  `python3 scripts/test-runner.py`, 152 tests, OK, 17 of them new and
  several changed (one renamed, with its checks kept); `test-docs`, `test-hooks`, `test-privacy`,
  `test-forbidden-code`, `test-agent-bridge`, `test-site` and
  `test-select-xcode`, all OK; `shellcheck scripts/test.sh` clean.
- Each new test was seen to fail when its rule was broken on purpose:
  lowering before the claim; lowering at the claim, before the start;
  a ten-minute deadline; the claim or start file ignored; no claim after
  the boot; no start file; the files left behind; tests after a failed
  return; `launchd_sim` not first; `restore` without its confirming
  pass; no read-back; the agent found by a looser name; no return when
  the watcher stops first; lowering after `restore` asked it to stop; a
  silent watcher left running; a refused process tried at every reading;
  a newcomer lowered only at the next line; and, in the later commits, a
  watcher that has not begun left running; a silent one killed without
  being asked; an early stop returning only what it lowered; the wait
  before the return.
- `e47b8d9` also puts back
  `test_a_failed_wait_to_settle_is_reported_and_the_tests_still_run`,
  which the first commit dropped by mistake.
- The real commands on a real simulator, on the owner's Mac: the watcher
  started before the boot, lowering (44 processes at once, then every
  new one; the simulator ran at priority 4), and `restore` (above).
- `scripts/test.sh unit` on the owner's Mac with Xcode 27.2, on an iPad
  Pro 13-inch (M5) simulator, iOS 27.2, erased first so its start was a
  first start, which the run started itself: 1112 tests ran, 1099
  passed, none failed, 1 skipped, 12 expected failures; the String
  Catalog was up to date. Its record: the watcher began before the boot
  and was claimed a second later; the simulator had finished starting
  17 seconds after that, at normal priority, when 206 of its processes
  were lowered at once (214 in all); the Mac settled after 10 seconds;
  and `restore` returned 211 processes in one pass with `launchd_sim`,
  SpringBoard and backboardd at 31. (A run of the first version, on the
  same simulator not erased, passed the same way.) This change touches
  no app code.
- `codex review --base origin/main` could not run in this session: its
  permission to send the branch to Codex was refused, so the pull
  request says so.

## Not verified

- Whether this ends the cancels. No job cancelled itself in the three
  runs on `c362cd0` (*What this pull request's CI runs showed*), but
  three runs cannot prove it: about twenty runs on `main` decide it
  (*Follow-ups*).
- How GitHub starts its agent, and so the priority its threads run at:
  the record's first lines on CI say.
- Whether a process GitHub's image or iOS puts in the band by the same
  setting as this script would be returned by `restore` too: none was
  seen on the owner's Mac (the round trips above), and iOS's own
  background processes stayed in the band there.

## Follow-ups

- **After about twenty runs on `main`,** count the jobs cancelled by
  themselves, and read the agent's lines in the records: a job cancelled
  again, with the start-up in the band, means the agent starves on
  something else (memory, say), and its `github-agent-log.txt` and the
  record's agent lines are where to start *(the next thread on CI)*.
- **The unit job's Python checks** (about nine minutes before the
  simulator starts) could run while the simulator starts, which would
  give back most of the unit job's new wait *(a later thread on CI
  speed)*.
- **Measure the wallpaper pausing again,** as 2026-11-19 asked: with the
  start-up in the band, pausing may cost more (iOS starts new
  extensions as they are paused) than it saves *(a later thread, one
  change at a time)*.
