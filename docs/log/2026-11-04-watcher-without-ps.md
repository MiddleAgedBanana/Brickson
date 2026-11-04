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
10 s, at 00:55:55, with the Mac's three processors busy (the simulator
alone at 314% in the line at 00:55:56, six new extensions taking most
of it). It is the test the iPhone runs at that point; on `d3a4202` the
same test took 169.5 s in that window and passed. The `ps` probe also
ran in this run, twice every 5 s, and was itself part of the load.

At the end as many paused processes were left to resume as had been
paused first (13 and 16), but the record counted the ended ones without
naming them, so whether the ones iOS ended were exactly the new
instances is not known; the "Resumed" line now names them. What the
probe does not settle either: whether iOS ends a new instance because it
is paused, and would start fewer if they ran; and whether the new
instances come at the same rate in a run without the probe.

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
- This record, the corrections to the 2026-11-03 record, and the lines
  of `docs/HANDOFF.md` and `docs/DECISIONS.md` the change makes untrue.

## Verified

- On Linux (this cloud thread; no Xcode): `scripts/test-runner.py` (83
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
- On GitHub's Mac (run 41748946044's unit job, on `6eb2a8f`): the Mac
  tests that compare a stopped child process with what `/bin/ps` says
  of it (parent, stopped, name, arguments, path), that read an ended
  process as gone and that start no process all passed; the processor
  time test failed on `host_statistics`, which `2ac6ed2` replaced.
- The probe run above.

## Not verified

- The final watcher on a Mac: the Mac tests as they now stand
  (including the one that runs the watcher under `/usr/bin/python3`,
  the Mac's own Python, which `test.sh` uses), the check every second
  and the new lines all run first in this pull request's CI run. Until
  that run is green, treat them as untested.
- That checking every second keeps the UI tests from failing during a
  burst like the iPhone's. It shortens how long a new extension runs
  before it is paused; whether that is enough is for the runs to show
  ("paused ... after N s of processor time").
- What the check every second costs on a starved Mac. The summary's new
  line gives the watcher's own processor time per run.
- Which paused processes iOS ended, why, and whether it would start
  fewer new ones if they ran (above).
- `scripts/test.sh` with this watcher on the owner's Mac.

## Follow-ups

- Read the "paused ... after N s" lines and the watcher's own time in
  this pull request's CI run, and in the next runs, before changing the
  cadence again. If new extensions still take the processors while a
  test waits, the next option in
  [`2026-11-03-ui-test-stall.md`](2026-11-03-ui-test-stall.md),
  *Follow-ups*, is pausing PosterBoard, which asks for them, tried first
  in a probe run on GitHub's machine. Owner: whichever thread meets it.
