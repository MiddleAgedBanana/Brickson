# The unit job's time, item 8's status, and external TestFlight in the handoff

*2026-10-30. Pull request on `claude/project-thread-ffwagr`, after #69
merged. The thread that built Wave 3 item 8.*

## What changed and why

Nothing a person using Brickson sees. Two records for whoever works here
next:

- **docs/HANDOFF.md** now says, in the three places that name the open
  dwell hazards, that they must be gone or accepted before a build with
  the larger sizes goes to App Review **or to an external TestFlight
  group**. docs/ROADMAP.md (R0's *Release gate*) and docs/DECISIONS.md
  (*Dwell safety, measured*) already said both since #69; the handoff
  said only App Review. CodeRabbit found the mismatch in its review of
  #69's last push, outside that push's diff, and it was left for a later
  pull request rather than restart #69's CI for wording.
- **AGENTS.md**, *Gotchas*, gains "The unit job uses most of its 40
  minutes", because a cancelled unit job is easy to misread as a broken
  change.
- **Item 8's status, now that #69 has merged with CI green:** Wave 3's
  item 8 in docs/ROADMAP.md, the Wave 3 sentence in docs/HANDOFF.md, the
  work file's status and seven rows of docs/ACCESSIBILITY.md said
  "untested until CI runs it". They now say what CI ran: the unit tests
  for every profile and the flags' suggestion, and for the gaze profile
  and the family's answer also the UI test that follows the answer on
  test storage (`HomeSizesTests`). The sizes are still held, so no
  person's Home has them yet.

## What happened to #69's unit tests

#69's last push (4d81491) ran its UI tests green on the iPad and the
iPhone, but its unit job (run 41042583501) was cancelled by GitHub at
the job's 40-minute limit ("The job has exceeded the maximum execution
time of 40m0s") while the tests were still running. No test had failed.
The machine was slow, measured on steps this change did not touch:

| Step | main at 5c07480 | #69's first run | the cancelled run | its re-run |
|---|---|---|---|---|
| `test-hooks.py`, 124 tests | 71.5 s | 57.2 s | 132.6 s | 83.4 s |
| `test-runner.py`, 56 tests (54 on #69's first run) | 33.7 s | 23.5 s | 46.2 s | 24.5 s |
| Starting the simulator and building | 10.3 min | 10.3 min | 16.3 min | 14.5 min |
| The tests | about 14 min | about 15 min | stopped after 20 min | about 16 min |
| The whole job | 26.8 min | 27.7 min | stopped at 40 min | 33.3 min |

The job was re-run once, on the same commit, and passed: 823 tests,
814 passed, 0 failed, 1 skipped and 8 expected failures (main had 804,
with the same skip and expected failures). Avery merged #69 after it.

Why the tests take about the sum of their times: the unit tests are
main-actor isolated by default (`project.yml`), so they share the main
thread. On Linux with four cores, `ProfileChoiceTests` took 165 seconds
of wall time and 164 seconds of processor time, and every test in it
reported finishing after 165 seconds; run alone, its word sweep took
30 seconds, its place sweep 35 and its chain sweep 73. #69 added about
two minutes to a normal run.

## Commits

- 1e537fe: Name external TestFlight beside App Review in the handoff's
  hazard lines (written on 2026-10-30 before #69 merged, carried onto
  the merged `main`).
- The commit that adds the gotcha, item 8's status and this record.

## Verified

- `python3 -I scripts/test-docs.py`, `scripts/test-hooks.py` and
  `scripts/test-site.py` pass in the cloud session. Nothing was built
  there; GitHub CI is the build.
- The timings above come from the GitHub Actions logs of runs
  41040560867 (main), 41031065358 and 41042583501 (both attempts).

## Not verified

- Why that machine was slow. GitHub does not say which machine a job
  ran on.
- How CI's speed compares with the Linux timings: they show what each
  sweep costs relative to the others, not CI's minutes.

## Follow-ups

- If unit jobs keep ending near 40 minutes on normal machines, raising
  the limit is a change to `.github/workflows/tests.yml`, which the owner
  pastes (AGENTS.md, *Gotchas*). Cutting what a sweep costs without
  weakening it is the other way. Neither is needed yet.
