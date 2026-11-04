# Keep the simulator watcher seeing when GitHub's Mac stalls

*2026-11-04. Pull request #78 (`claude/project-thread-7j42mb`). Claude,
project thread "Keep the simulator watcher seeing during stalls".*

## What changed and why

`scripts/simulator-load.py`, the watcher that `scripts/test.sh` runs
beside each simulator, pauses iOS's lock-screen wallpaper extensions so
their prewarm cannot starve the UI tests, and records which processes
used the Mac's processors
([`2026-11-03-ui-test-stall.md`](2026-11-03-ui-test-stall.md)). Nothing
in the app changes; this is test machinery only.

**Why it went blind.** The watcher read the process list by running
`/bin/ps` twice a reading, giving up after 5 s. On GitHub's three-processor
Macs, while the simulator starved the machine, `ps` ran past that limit
reading after reading, and Python, having killed a `ps` that ran too long,
still waits for it to end before going on. The old record could not
say how long each reading took, but in the green run on `ec21266`
(41669225544) one iPad reading took about 160 s and one in the unit job
about 175 s (the gaps between lines in
[its records](../evidence/2026-11-04-watcher/), less the 5 s
between readings), and the iPhone's watcher could read no list for its
first two minutes. Extensions iOS started meanwhile were not paused.

**What it does now.** It reads the process list with the Mac's own
process calls, made from Python through `ctypes` (the standard library's
way to call C functions), and starts no process at all:

- `proc_listpids` and `proc_pidinfo` (with `PROC_PIDT_SHORTBSDINFO`) list
  every process with its parent, its state and its name. The kernel
  gives these for any process, whoever runs it.
- For the simulator's own processes only, `proc_pidinfo` (with
  `PROC_PIDTASKINFO`) gives each one's processor time, and
  `proc_pidpath` its program's path, which is what the pausing matches.
- The `sysctl` `KERN_PROCARGS2` reads `launchd_sim`'s arguments, which
  name the simulator's device folder. That reads another process's
  memory, so it is done once and kept while that `launchd_sim` runs.
- `host_processor_info` counts each processor's busy time, for the
  "mac" column.

Each line now also says how long its reading took (`list 0.01 s`), so a
slow reading shows in the record instead of hiding in a gap.

Two details of the Mac's calls had to be got right, and each has a test:

- A process's processor time comes in Mach time units, which are
  nanoseconds on an Intel Mac but not on Apple silicon (GitHub's Macs);
  `mach_timebase_info` converts them.
- The first version counted the Mac's busy time with
  `host_statistics`. For a program that is not part of macOS, the kernel
  answers that call from a copy up to a second old once it has been asked
  a few times in that second (`rate_limit_host_statistics` in xnu's
  `osfmk/kern/host.c`). On GitHub's machine it gave the same counts
  before and after half a second of work, and the unit job's new Mac
  test failed on it (run 41748946044). `host_processor_info` has no such
  limit.

**Checking every second, between lines.** The probe run below showed
that iOS starts new wallpaper extensions during the prewarm even while
the first ones are paused: 49 on the iPhone and 17 on the iPad. The new
watcher paused every one of them, but each ran flat out until a reading
found it, and on the iPhone its readings in the burst's first minute
were up to 13 s apart (5 s between readings, plus readings of up to
4 s, plus the watcher's own wait for a processor). From 00:54:30 to
00:59:00 the extensions used at least 178 of the simulator's 544
processor-seconds (a line names only the six busiest processes), and
Brickson 53 that the lines show, and one iPhone test's 10 s wait ran out
at 00:55:55, inside the burst. A reading now takes about 10 ms when the
Mac is not starved (the median time a reading took), so while pausing
the watcher also reads the list every second between its five-second
lines. Those
in-between readings pause what they find and write nothing else. Each
"paused" line now says how much processor time the extension had used
by then, and the summary says how much the watcher used itself, so this
pull request's own run, and every run after it, shows what the cadence
saves and what it costs.

**Each process counted over its own time.** In this pull request's CI
run one iPhone reading took 13.67 s (at 02:04:16, with the Mac's load
average at 421), and the line after it put the simulator at 845% of a
Mac that has 300%. A reading reads each process's time at its own
moment, but a line divided every process's time by the time between the
two lines' ends: a process read early in the slow reading had seconds
counted that were not in the line, and one that started during it had
its whole life counted in the 3 s that followed. Now a line counts each
process over the time between its own two readings, and a new one over
the time since the list it was not in was read, the longest it can have
run unseen. The summary's totals were right before and are unchanged.
The probe's iPhone record has the same fault once (314% at 00:55:56,
below).

**What the green run's records say about which `ps` list was slow.** In
the run on `ec21266` every time-out in the UI jobs was the first of a
reading's two lists (`pid=,args=`: 6 on the iPad, 28 on the iPhone), and
in the unit job 16 were the first and 2 the second
(`pid=,ppid=,stat=,time=,comm=`). The first list runs first, so it is
the one a stall meets first; the records do not show that it is the
slower of the two.

**Corrections to the 2026-11-03 record.** Its own pull request had
merged, so the corrections are marked in place, as `docs/log/README.md`
allows:

- "a hung `ps` never holds" the watcher was too strong: Python waits for
  a `ps` it has killed (above).
- "once the watcher begins it pauses the extensions already running"
  confused beginning to watch with pausing: on `ec21266`'s iPhone, the
  first list the watcher could read came two minutes after it began.
- Two of its *Not verified* items are covered by the green run on
  `ec21266`: a whole iPad suite with the watcher (it passed, with 13
  extensions paused), and a watcher that `start` left to begin (on the
  iPhone; it began 11 s later).
- Its gap about which process held the watcher, and its gap about new
  instances getting past the pausing, now point here.

## The probe run

Run 41748946044 (on `6eb2a8f`, started by hand) ran the new watcher as
the real one and, beside it on the same simulator, `main`'s `ps`
watcher, watching only (no pausing), writing
`simulator-load-<family>-ps.txt`. Its records are in
[`docs/evidence/2026-11-04-watcher/`](../evidence/2026-11-04-watcher/)
(`probe-*`), with the green run's (`ec21266-*`). Its unit job stopped at
the `host_statistics` test above, so only the UI jobs ran; they ran the
5-second version, before the check every second, and its "mac" column
came from `host_statistics`.

| | iPad | iPhone |
|---|---|---|
| New watcher: readings, longest gap between lines | 492, 9 s | 421, 13 s |
| New watcher: time a reading took (median, 95th percentile, longest) | 0.01, 0.32, 2.46 s | 0.01, 0.76, 4.25 s |
| New watcher: first pause after it began | 2 s (13 extensions) | 3 s (16 extensions) |
| `main`'s `ps` watcher beside it: time-outs, longest gap | 9, 38 s | 12, 22 s |
| New extensions iOS started later, all paused | 17 (00:55:25 to 00:57:20) | 49 (00:55:23 to 00:58:23) |
| Paused processes still there to resume at the end | 13 of 30 | 16 of 65 |
| Poster notifications in the test runner's log | 15, from 3 extensions | 115: 109 from 18 extensions, 6 from 2 that no reading saw |
| Tests | 62 passed, 2 skipped | 57 passed, 6 skipped, 1 failed |

Each paused extension's notifications came before the reading that
paused it, 0 to 4 s earlier, and none after. The iPhone's last two
extensions (00:58:44) were never in a reading: they started just after
one and had gone before the next. For comparison, the
iPhone on `d3a4202`, whose 27 new instances escaped the `ps` watcher,
logged 728, and the stalled iPad runs of 2026-11-03 400 to 882.

The failed test was `HomeAccessibilityOrderTests`'
quick-controls test at default text: "Needs was not selected" after
10 s, at 00:55:55, with the Mac's three processors busy (295% in the
line at 00:55:56, whose six busiest processes were six new extensions;
its 314% for the simulator alone is more than the Mac has, the fault
described above, after a 4.25 s reading). It is the test the iPhone
runs at that point; on `d3a4202` the
same test took 169.5 s in that window and passed. The `ps` probe also
ran in this run, twice every 5 s, and was itself part of the load.

At the end as many paused processes were left to resume as had been
paused first (13 and 16), but the record counted the ended ones without
naming them, so the probe could not show whether the ones iOS ended were
exactly the new instances; the "Resumed" line now names them, and this
pull request's run shows they were (below). What neither run settles:
whether iOS ends a new instance because it is paused, and would start
fewer if they ran.

## This pull request's run

Run 41757279440, on `4a69e1a`: the final watcher, with the check every
second, before the counting fix above. All three jobs passed: the unit
job in 31 minutes, the iPad's UI tests in 38 and the iPhone's in 47
(51 and 48 in the green run on `ec21266`). Its records are in
[`docs/evidence/2026-11-04-watcher/`](../evidence/2026-11-04-watcher/)
(`4a69e1a-*`).

| | iPad | iPhone | Unit job (iPad) |
|---|---|---|---|
| Watched | 01:57:15 to 02:33:08 | 01:59:16 to 02:41:31 | 02:04:48 to 02:25:58 |
| Readings, longest gap between lines | 371, 8 s | 431, 22 s | 219, 14 s |
| Time a reading took (median, 95th percentile, longest) | 0.01, 0.10, 0.96 s | 0.01, 0.54, 13.67 s | 0.01, 0.64, 6.19 s |
| Paused at the watcher's first reading | 18 | 24 | 13 |
| Paused after it | 85, until 02:03:33 | 101, until 02:07:33 | 10, 02:12:14 to 02:13:45 |
| Their processor time when paused: median, longest, all | 1.0, 2.8, 85 s | 1.4, 4.6, 161 s | 1.1, 5.0, 22 s |
| Still there to resume at the end | 13 of 103 | 16 of 125 | 13 of 23 |
| The watcher's own processor time | 12.0 s | 19.4 s | 6.9 s |
| Tests | 62 passed, 2 skipped | 58 passed, 6 skipped | 1,215 passed, 17 known issues, 1 skipped |

**Which instances iOS ended.** On each simulator the ones still there at
the end were the 13 or 16 with the lowest pids, all paused at the
watcher's first reading, the same counts as in the probe. Every other
paused instance had ended, including 5 on the iPad and 8 on the iPhone
from that first reading. So iOS ended exactly the instances it started
after its first set.

**How long it went on.** New instances came in groups about every 20 s
(on the iPad at 01:57:35, 01:57:57, 01:58:19, 01:58:41, 01:59:03 and
on), for 6 minutes on the iPad and 8 on the iPhone after the first
pause: 85 and 101 of them, against 17 and 49 over 2 and 3 minutes in
the probe. A guess the records cannot confirm: iOS replaces, on a timer,
an instance that does not answer, and ends the one it replaced. One run
each, with the probe's `ps` watcher adding to the load in the probe,
does not show whether pausing sooner made iOS start more.

**Tests in the burst.** On the iPad the burst ran over the build, the
warm-up and the first four test classes (HomeAccessibilityOrderTests
began at 02:02:40); on the iPhone over the build, the warm-up and the
first two classes (FoldOffsetUITests and GetAttentionOnHomeTests, from
02:04:46). Every test passed. Two of the iPhone's took about twice as
long as in the probe, where they ran before its burst: the fold test in
light mode 65.9 s against 38.6 s, the alarm at default text 81.4 s
against 32.6 s. The test that failed in the probe ran after the burst
this time (from 02:08:29) and took 26.1 s.

**What the watcher costs.** 12.0, 19.4 and 6.9 processor-seconds over
36, 42 and 21 minutes: about 0.5% to 0.8% of one processor. On the
iPhone, one reading took 13.67 s with the Mac's load average at 421,
and the next, 3 s after it, paused the four extensions started
meanwhile; the line it wrote is the 845% one above.

## Commits

- `4127b50` List the simulator's processes with the Mac's own calls, not
  `ps`.
- `6eb2a8f` Probe the new watcher beside main's `ps` watcher
  (temporary).
- `2ac6ed2` Count the Mac's busy time with `host_processor_info`.
- `5cbf637` Make the watcher's tests catch what a review found they
  missed.
- `364854c` Remove the probe of main's `ps` watcher.
- `11c280f` Look for new wallpaper extensions every second between
  lines.
- `c620915` Name the paused processes that had ended when the watcher
  stops.
- `4a69e1a` This record, the corrections to the 2026-11-03 record, and
  the lines of `docs/HANDOFF.md` and `docs/DECISIONS.md` the change
  makes untrue.
- `f5db260` Move the evidence records to `docs/evidence/`
  (CodeRabbit's review: `docs/log/README.md` asks each pull request to
  add one file to `docs/log/`).
- `7b39b65` Count each process over its own time between readings.
- This pull request's run in this record, with its load records.

## Verified

- On Linux (this cloud thread; no Xcode): `scripts/test-runner.py` (85
  tests; the 5 that need a Mac skipped), `scripts/test-docs.py`,
  `scripts/test-hooks.py`, `scripts/test-site.py` and
  `scripts/test-select-xcode.py`, all passing.
- Fifteen faults planted in the watcher, one at a time, each failing
  the test named beside it: a line's reading time that leaves out the
  details and counts (*each line reports the time used since the
  last*); `launchd_sim`'s arguments read every reading (*the simulator
  is found once*); a reused pid counted as the old process, or busy
  counts not taken round their 32-bit wrap (*each line reports*);
  pausing an extension already stopped (five tests); an error from a
  reading escaping the watcher (*a process list that cannot be read*);
  the kernel name one byte short, or a task's system time read as 32
  bits (*the structures have the kernel's sizes*, which now checks
  where each field the watcher reads starts and how long it is, since
  padding hid both from the sizes); no checks between lines (*a new
  extension is paused at the next check*, which pauses this test's own
  child processes for real); a check that writes a line, or that moves
  the time the next line counts from (*a check between lines*); "not
  running" written on every check (*a check while the simulator is not
  running*); a "paused" line without the processor time (*a check
  between lines*); no line for the watcher's own processor time
  (*start waits for the watcher*); and a "Resumed" line that does not
  name the ones that had ended (*the paused extensions run again*).
- Six more for `7b39b65`, each failing *a slow reading does not swell
  the next line* or the test named beside it: a known process counted
  over the time between the lines' ends (the fault itself, which that
  test reproduced first, at 233% and 200%); a new one counted from the
  last line's end, or from after its list; every process's reading time
  taken at the start of the reading; the list's time not kept after a
  line (four tests); and not kept when the simulator is not running
  (*a simulator that starts while watched*, where it would stop the
  watcher).
- On GitHub's Mac (run 41748946044's unit job, on `6eb2a8f`): the Mac
  tests that compare a stopped child process with what `/bin/ps` says
  of it (parent, stopped, name, arguments, path), that read an ended
  process as gone and that start no process all passed; the processor
  time test failed on `host_statistics`, which `2ac6ed2` replaced.
- On GitHub's Mac (this pull request's run 41757279440, on `4a69e1a`):
  every Mac test, including the one that runs the watcher under
  `/usr/bin/python3`, the Mac's own Python, which `test.sh` uses; the
  check every second, the new lines and both UI suites (above).
- The probe run and this pull request's run above.

## Not verified

- `7b39b65`'s counting on a Mac: it runs there first in this pull
  request's next CI run. Its tests use a stand-in clock and process
  list, there as here.
- That checking every second keeps a test's short wait from running out
  inside a burst. In this pull request's run every test passed, but the
  one that failed in the probe ran after the burst.
- Why iOS ends the instances it started later, and whether it would
  start fewer if they ran (above).
- `scripts/test.sh` with this watcher on the owner's Mac.

## Follow-ups

- If new extensions still take the processors while a test waits (in
  this pull request's run they slowed two iPhone tests about twofold and
  failed none), the next option in
  [`2026-11-03-ui-test-stall.md`](2026-11-03-ui-test-stall.md),
  *Follow-ups*, is pausing PosterBoard, which asks for them, tried first
  in a probe run on GitHub's machine. Read the "paused ... after N s"
  and "Resumed" lines of the run that shows it first: in this pull
  request's run, with its later instances paused, iOS went on replacing
  them for 6 to 8 minutes.
  Owner: whichever thread meets it.
