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
   A cloud agent cannot push `.github/workflows/`, so the owner commits
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

The tests and their coverage are unchanged. Four small tests are added,
each pinning one shortcut against the plain way (*Verified*).

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

- The engine's speedup and its four tests.
- This record, docs/HANDOFF.md, AGENTS.md's gotcha and
  docs/DECISIONS.md.
- The owner's commit raising the limit in `.github/workflows/tests.yml`.

## Verified

Nothing here was built with Xcode: this thread runs in the cloud, so
GitHub CI is the build. On Linux (Swift 6.4.1, four cores), a Swift
package linked to the repository's own files: `ChainEngine`,
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

  Scaling each of CI's test times by its own Linux ratio gives about
  10.4 minutes of tests instead of 18.5, so a job of about 28 to 31
  minutes. That is an estimate until CI measures it.
- **The new tests,** each run on Linux and seen failing on the change
  named:
  - `ChainEngineTests.oneStatesStartsAreEveryStartsForIt()`: fails if
    `starts(in:)` drops a state's resting places (tried).
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

## Not verified

- Any of it with Xcode, on a Mac or on CI, until this pull request's
  CI run: the build (warnings are errors), the unit tests' results and
  the unit job's new time.
- The UI tests that use the engine (`SettingsOnHomeTests`, Home's
  chains on the running app's frames). The engine is shared, and its
  results are the same, but they run only on CI.
- That the job's limit is 60 until the owner's commit to
  `.github/workflows/tests.yml` is on the branch.

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
  debugging a test gets harder, so it is a choice for later, if the job
  grows again.
- **Running suites side by side.** The unit tests share the main thread
  because of the project's default isolation. Marking the long sweeps
  `nonisolated` would let them run in parallel; it is a larger change
  to how the tests run, and nothing needs it yet.
