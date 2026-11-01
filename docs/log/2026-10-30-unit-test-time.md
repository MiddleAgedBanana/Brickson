# The unit tests' time, and the unit job's limit

*2026-10-30. Pull request #71 (`claude/project-thread-8upbq8`). A cloud
thread, with the owner pasting the workflow change.*

## What changed and why

GitHub's unit job had reached its 40-minute limit. `main`'s run after
#69 (44e68a6) took 38.0 minutes; #70's first run was stopped at 40 with
no test failed, and its re-run took 38.6; `main`'s run after #70
(9fe02ef, run 41115662253) took 36.2. About 16 of those minutes are
starting the simulator and building, and about 18.5 are the tests
themselves (docs/log/2026-10-30-sizes-switched-on.md, *This pull
request's unit tests*). Two changes:

1. **The unit job's limit goes from 40 to 60 minutes.** The longest
   complete run measured was 38.6 minutes, and a slow machine has added
   up to six minutes to building on its own. Sixty leaves room for that
   and for new tests, and still stops a hung run within the hour. The UI
   job keeps its 120 (docs/HANDOFF.md said 75; that line is corrected
   here). GitHub's own ceiling for a job on its machines is six hours.
   A cloud agent cannot push `.github/workflows/`, so the owner committed
   this one line on the branch (AGENTS.md, *Gotchas*). Decision:
   docs/DECISIONS.md, "Tests".
2. **The dwell chain engine costs about half as much, with every result
   the same.** The unit tests run it millions of times, in a build that
   is not optimised, and it was most of the tests' time. Nothing it
   scores, follows or finds changed; only how it gets there:
   - `SettingsChains.starts(in:home:)` builds starts for Settings'
     screens and the Home state Settings closes onto, through the new
     `ChainMap.starts(in:)`. It used to build every start of the merged
     map, all of Home's 120 states with typing (tens of thousands), and
     keep a few hundred.
   - `CompiledMap` makes each state ready the first time a chain reaches
     it. It used to prepare every state of the map for each call, and a
     sweep through Settings calls it once per window, 630 windows.
   - `ChainEngine.nearest` and `points(across:)` use plain loops over
     frames. Closures over generic arrays cost far more in an
     unoptimised build.
   - The walk keeps the chain it follows, and the places it has met,
     in arrays it overwrites in place rather than appends to and
     removes from; one walk serves every start of a call; a run of
     starts on the same control finds its place in the map once.

Every existing test, and what it covers, is unchanged. Four small tests
are added, each pinning one shortcut against the plain way (*Verified*).

## Where the time went

From the result bundle of `main`'s run on 44e68a6, the iPad's unit
tests (the `TestCaseRuns` table of the `.xcresult`'s
`database.sqlite3`; each case's `duration`, in seconds, summed by test;
because the tests share the main thread, these add up to the tests'
wall time: 1,113 seconds over 823 cases):

| Test | Seconds on CI |
|---|---|
| `finalHomeFramesAddNoSettingsHazardPaths(boldText:)` | 276 |
| `typingChainsMeetOnlyClearAndPutBackByCentreFromTheDimmedPhrases(boldText:)` | 191 |
| `noSweptWindowClosesSettingsOrSavesAnAnswerUnderTheLook()` | 129 |
| `noChainAtALargerProfileMeetsANewHazard(profile:)` | 77 |
| `yesAndNoStillBorderTheMessage(modes:)` | 74 |
| `noChainOnTheEnginesFramesMeetsAHazardButStopsWell(boldText:)` | 59 |
| Everything else | 307 |

The query, for the next time:

```sh
sqlite3 'file:unit-ipad.xcresult/database.sqlite3?mode=ro' \
  "select tc.name, round(sum(r.duration)) from TestCaseRuns r
   join TestCases tc on r.testCase_fk = tc.rowid
   group by tc.name order by 2 desc limit 20"
```

## Commits

- c69ad55: the engine's speedup and its four tests.
- e1cd546: this record, docs/HANDOFF.md, AGENTS.md's gotcha and
  docs/DECISIONS.md.
- a538f41: answers to review (the starts test compared with the plain
  way) and this record tidied.
- 3feb192, the owner's: the unit job's limit raised from 40 to 60
  minutes in `.github/workflows/tests.yml`.
- The commit after it: GitHub CI's results (*GitHub CI*) added to this
  record, docs/HANDOFF.md and AGENTS.md before merging, at the owner's
  choice.

## Verified

This thread runs in the cloud and cannot build with Xcode, so GitHub CI
is the build (*GitHub CI*, below). On Linux (Swift 6.4.1, four cores),
a Swift package linked to the repository's own files: `ChainEngine`,
`HomeChains`, `SettingsChains`, the layout types they score, and the
unit tests that drive them (`ChainEngineTests`, the layout engine's,
`ProfileChoiceTests`, `SettingsReservedRegionChainTests` and the rest
of `BricksonTests/Layout` that build without Apple's frameworks: 177
tests). It was built unoptimised, with the project's Swift 6 settings
(default main-actor isolation), and run one test at a time. The package
itself is not committed.

- **Every result is the same.** A harness-only probe took 1,542 of the
  sweeps' own inputs (432 Home windows of the layout engine, with and
  without typing; 50 windows of the larger profiles; 1,060 merged maps
  of Settings' swept windows closing onto Home's states) and, for each,
  counted and fingerprinted (FNV-1a over each description, in order)
  its starts, every chain, its hazards, its hazards at a shorter depth
  and its findings. The probe's output was byte-for-byte the same before
  and after.
- **The same tests pass and fail.** On Linux, three layout tests fail
  in the same places before and after (`backToTalkingUsesTheFinalPhrasesFrame()`,
  `keyboardAndBackUseTheFinalOccupiedFrames()`,
  `everyMeasuredTextSizeAndBoldTextKeepsTargetsClear(scenario:)`): 965
  issues, 117 of them known, at the same lines. None of them scores a
  chain; they compare frames, and their cause on Linux was not looked
  into. They pass on CI.
- **The time, on Linux, the whole run of 177 tests:** 1,181 seconds
  before, 634 after.

  | Test | Before (s) | After (s) |
  |---|---|---|
  | `finalHomeFramesAddNoSettingsHazardPaths(boldText:)` | 295 | 13 |
  | `typingChainsMeetOnlyClearAndPutBackByCentreFromTheDimmedPhrases(boldText:)` | 222 | 110 |
  | `noSweptWindowClosesSettingsOrSavesAnAnswerUnderTheLook()` | 128 | 101 |
  | `noChainAtALargerProfileMeetsANewHazard(profile:)` | 100 | 45 |
  | `noChainOnTheEnginesFramesMeetsAHazardButStopsWell(boldText:)` | 73 | 47 |
  | `heldActivationsAddNoHazardPaths(boldText:)` | 27 | 13 |

  Before CI ran, scaling each of CI's test times by its own Linux ratio
  gave an estimate of about 10.4 minutes of tests instead of 18.5, and
  a job of about 28 to 31 minutes. CI then measured about 12.4 minutes
  of tests and jobs of 24.4 and 28.2 minutes (*GitHub CI*).
- **The new tests,** each run on Linux and seen failing on the change
  named:
  - `ChainEngineTests.oneStatesStartsAreEveryStartsForIt()`: compares
    `everyStart()` and each state's starts with the plain way, as
    `everyStart()` was written before; fails if `starts(in:)` drops a
    state's resting places or lists them before its controls (both
    tried).
  - `ChainEngineTests.chainsFromARunOfStartsAreEachStartsOwn()`: fails
    if a run of starts reuses the place of a control with the same name
    (tried: the second phrase tile lost every chain), or of the same
    control in the state before (tried).
  - `HomeChainsTests.hazardsAreTheChainsThatEndInOne()`: fails if
    keeping only hazards keeps anything else (tried).
  - `SettingsChainsTests.startsThroughSettingsAreEveryStartOnItsScreens()`:
    fails if the Home state Settings closes onto gives starts other than
    its Settings button (tried).
- `scripts/test-docs.py`, `scripts/test-hooks.py` and
  `scripts/test-site.py` pass.

### GitHub CI

Both runs used GitHub's `xcode-27` image with Xcode 27.1 (its iOS 27.1
SDK): the unit tests on the iPad Pro 13-inch (M5) simulator, the UI
tests on it and on the iPhone 17, all iOS 27.0. Each test's time is
from the run's result bundle (the query above). The comparison is
`main`'s run on 9fe02ef (run 41115662253), whose unit job took 36.2
minutes.

- **a538f41** (run 41123722058): both jobs green, so the build (warnings
  are errors) passed. The unit job took 24.4 minutes. The UI job took
  73.0 minutes on the iPad and the iPhone, including
  `SettingsOnHomeTests`, which runs the engine on the running app's
  frames.
- **3feb192**, with the owner's limit (run 41271701390): both jobs
  green. `tests.yml` differs from `main` only in the unit job's
  `timeout-minutes`, 40 to 60; both job names, which the `main` ruleset
  requires, are unchanged. The unit job took 28.2 minutes, under the
  new limit and the old one. Its tests took as long as on a538f41; the
  3.8 minutes more were spent outside them, building, starting the
  simulator and in the Python checks. The UI job took 70.4 minutes,
  with the same passes and skips as on `main`.
- **The same results on both:** 827 tests (`main`'s 823 and the four
  new), whose runs end as on `main`: 1,139 passed (`main`'s 1,135 and
  the four new), 17 expected failures and 1 skip.

| Test | `main` (s) | a538f41 (s) | 3feb192 (s) |
|---|---|---|---|
| All unit tests | 1,143 | 746 | 737 |
| `finalHomeFramesAddNoSettingsHazardPaths(boldText:)` | 237 | 15 | 16 |
| `typingChainsMeetOnlyClearAndPutBackByCentreFromTheDimmedPhrases(boldText:)` | 183 | 139 | 121 |
| `noSweptWindowClosesSettingsOrSavesAnAnswerUnderTheLook()` | 169 | 106 | 97 |
| `yesAndNoStillBorderTheMessage(modes:)` | 90 | 86 | 91 |
| `noChainAtALargerProfileMeetsANewHazard(profile:)` | 72 | 41 | 45 |
| `noChainOnTheEnginesFramesMeetsAHazardButStopsWell(boldText:)` | 68 | 49 | 46 |
| `heldActivationsAddNoHazardPaths(boldText:)` | 21 | 15 | 14 |

## Not verified

- A Release build. CI builds Debug only. Only test-target files and
  documents changed; `scripts/test.sh device -configuration Release` on
  a Mac would show any warning only Release sees.
- The Linux results by anyone else: the fingerprint and each new test
  seen failing on its change ran in this thread's package, which is not
  committed. A Mac run with each change applied would repeat the
  second.
- How near the job comes to 60 minutes on a slow machine. Two runs are
  measured, 24.4 and 28.2 minutes.

## Follow-ups

- **The Settings sweep's remaining cost is the app's layout, not the
  engine.** `noSweptWindowClosesSettingsOrSavesAnAnswerUnderTheLook()`
  still takes about 100 seconds on Linux, about 78 of them in
  `SetupAnswersPlace` working out the first step for each of 630
  windows, and building `SettingsRowPlaceTests.everyWindow` takes about
  20. Making those cheaper changes app code, so it is a pull request of
  its own, for the next Settings thread.
- **An optimised test build would roughly halve the rest.** Built with
  `-O` on Linux, the same 177 tests took 390 seconds instead of 634.
  It changes how `BricksonTests` is built (`project.yml`), and
  debugging a test gets harder, so it is left for the thread that next
  finds the unit job near its limit.
- **Running suites side by side.** The unit tests share the main thread
  because of the project's default isolation. Marking the long sweeps
  `nonisolated` would let them run in parallel; it is a larger change
  to how the tests run, and nothing needs it yet. The same thread
  weighs it against `-O`.
