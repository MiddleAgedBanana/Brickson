# UI tests in three parts per family, and a clean-up that a stopped simulator cannot fail

*2026-11-16. The pull request from `claude/project-thread-wdyl8w`. A
Claude thread on the owner's Mac (Xcode 27.2).*

## What changed and why

From the morning of 2026-11-16 the required "UI tests" check could not
pass, so nothing could merge:

- `main`'s run on `dc11030` (run 43831844515) was stopped at the iPad
  job's 90-minute limit, and its iPhone job took 89 of its 90 minutes.
- Pull request #114's run on `17a6b2a` (run 43838572035) was stopped at
  the iPad job's limit too. Its iPhone job passed all 81 tests and was
  then failed by the script's clean-up: the simulator had already shut
  down, and `simctl shutdown` refused with CoreSimulator error 405
  ("Unable to shutdown device in current state: Shutdown").
- The same app code had passed the night before in 72 minutes (pull
  request #116's run 43770804978).

**Where the time went.** Every UI job spent 10 to 19 minutes before its
first test, then ran all 81 tests one after another:

| Run | Job | Start simulator, keyboard | Build | Warm-up | Tests | Job |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| 43770804978 (11-15) | iPad | 6.0 | 2.8 | 1.2 | 60.8 | 71.5 |
| 43831844515 (11-16) | iPad | 6.6 | 3.1 | 5.4 | stopped after 74 | 90, stopped |
| 43831844515 (11-16) | iPhone | 9.2 | 7.1 | 2.2 | 69.4 | 88.7 |
| 43838572035 (11-16) | iPad | 10.7 | 2.9 | 1.1 | stopped after 75 | 90, stopped |
| 43838572035 (11-16) | iPhone | 4.2 | 3.7 | 1.0 | 50.4 | 59.7 |

Minutes, from the jobs' logs. Inside the tests, the app was launched
117 times on the iPad (109 on the iPhone), about 9.6 seconds each:
about 19 of the iPad's 58 minutes of tests.

**Why that day was slower.** Each slow job's Mac was saturated for its
first 20 to 40 minutes: the simulator-load records show the Mac at 300%
of its three processors with a load average in the hundreds, falling
only after 30 to 40 minutes, where the fast iPhone job of run
43838572035 settled within 20. All the slow jobs ran on GitHub's new
machine image (`xcode-27-arm64` version 20261112.0361.1, which added an
Xcode 27.3 beta), and the last fast run before them on the one before
(20261104.0337.1). But the fast iPhone job ran on the new image too, so
the image is not shown to be the cause: how quickly a fresh machine
settles varies from machine to machine. Throughout every run, fast and
slow alike, two simulator processes used about 60% of one processor
between them (`diagnosticd` about 38%, `apsd` about 21%); this change
leaves them alone.

**The slow iPad jobs also had failing tests,** which the comment on
#114 missed. On run 43838572035,
`FoldOffsetUITests.testTheFirstRowClearsATopDivisionInDarkMode`
("Timed out while evaluating UI query") and
`HomeLayoutTests.testTheStarterLibraryFitsWithoutScrolling` ("Home did
not finish laying out", a wait that ran out); on `main`'s run
43831844515, `HomeLayoutTests.testTheStarterLibraryFitsWithoutScrolling`
again and `SettingsTests.testAnIdleSettingsReturnsToItsFirstScreenAndStaysOpen`
("failed to compute hit point" for Family Setup, its frame not yet
laid out). Three of the four failures came within a slow job's first
35 minutes, while its Mac was saturated; the Settings one about 75
minutes in. All three tests pass on the normal runs. On `main`'s run
the first test class also started twice, nine minutes apart, as if the
first launch of the test runner had not come up. This change does not touch them: each part
still starts on a fresh machine. If they come back on the parts, they
need their own fix (*Follow-ups*).

**What changed.**

1. **Three parts per family** (docs/DECISIONS.md, "Tests").
   `scripts/ui-test-parts.py` names the test classes of parts 1 and 2;
   part 3 runs every other class, so a class added later runs there
   until someone places it, and no class can be left out. The parts
   are balanced by the measured times below. `scripts/test.sh` runs one
   part when `UI_TEST_PART` names it, with the part's classes passed to
   the test run only (the build builds them all), and writes
   `ui-<family>-part<n>.xcresult` and
   `simulator-load-<family>-part<n>.txt`; without `UI_TEST_PART` it
   runs everything, as before. `.github/workflows/tests.yml` runs the
   three parts on both families as six jobs at once, each with 90
   minutes, and "UI tests" passes only when all six passed. Nothing is
   dropped: every test still runs on both families on every pull
   request.
2. **The clean-up.** When `simctl shutdown` fails, `scripts/test.sh`
   reads the simulator's state; a simulator already shut down counts as
   cleaned up, and one still running fails the run as before.

**What to expect.** About 16 to 24 minutes of tests per part (table
below) after the same 10 to 19 minutes of starting and building: about
30 minutes on a normal day and about 40 to 45 on a day like this one,
against a 90-minute limit. The cost: each part starts its own simulator
and builds the app, so a run uses about a third more Mac time (about
230 Mac minutes against 175), and GitHub runs at most five Mac jobs at
once, so with the unit job two parts wait for a free machine.

## Every test's time

Seconds per test on run 43770804978 (2026-11-15, the last normal day,
iPad Pro 13-inch (M5) and iPhone 17 on iOS 27.2) and on `main`'s slow
iPhone job of 2026-11-16 (run 43831844515), with the app launches each
test made on the iPad and the part it now runs in. Read from the jobs'
result bundles (`xcresulttool get test-results tests` and
`activities`).

| Test | iPad, s | iPhone, s | iPhone, slow day, s | Launches (iPad) | Part |
| --- | ---: | ---: | ---: | ---: | ---: |
| `SettingsTests/testTheCheckInCardDrawsItsWordsWholeAndPassesTheAudit()` | 89 | 201 | 177 | 3 | 1 |
| `HomeRestBoardTests/testTheRestBoardPassesTheAuditAndDrawsItsWordsWhole()` | 97 | 122 | 160 | 5 | 2 |
| `LibraryTests/testAPhraseNamedLikeAControlIsSavedWithANote()` | 112 | 118 | 139 | 1 | 2 |
| `HomeRestBoardTests/testABoardOfEightPassesTheAuditAndDrawsItsWordsWhole()` | 101 | 117 | 145 | 5 | 2 |
| `HomeLayoutTests/testTheStarterLibraryFitsWithoutScrolling()` | 115 | 56 | 104 | 4 | 3 |
| `SettingsTests/testGoThroughSetupAgainOpensItsStepWhereItShowed()` | 52 | 107 | 120 | 2 | 1 |
| `SettingsTests/testAnsweringTheAskButtonMovesNothing()` | 88 | 99 | 114 | 2 | 1 |
| `LibraryTests/testAPhraseIsAddedChangedMovedAndDeleted()` | 80 | 96 | 115 | 1 | 2 |
| `LibraryTests/testCategoriesStayBetweenThreeAndFour()` | 88 | 92 | 91 | 1 | 2 |
| `LibraryTests/testNoHeldLookChangesTheLibraryAtTheLargestText()` | 60 | 88 | 92 | 1 | 2 |
| `LibraryTests/testTheLibrarysScreensPassTheAuditInLight()` | 77 | 88 | 84 | 1 | 2 |
| `SettingsTests/testFamilySetupGuidesPassTheAccessibilityAudit()` | 84 | 76 | 78 | 1 | 1 |
| `SettingsTests/testTheStepByStepSetupPassesTheAccessibilityAudit()` | 80 | 58 | 59 | 1 | 1 |
| `SettingsOnHomeTests/testOpeningSettingsWithACheckInDueAtDefaultText()` | 75 | 56 | 61 | 1 | 3 |
| `LibraryTests/testNoHeldLookChangesTheLibraryAtDefaultText()` | 64 | 73 | 76 | 1 | 2 |
| `HomeRestBoardTests/testTheRestBoardShowsOneCategoryAndEveryCategoryPutsHomeBack()` | 67 | 73 | 109 | 1 | 2 |
| `SettingsTests/testSettingsScreensPassTheAccessibilityAudit()` | 69 | 59 | 56 | 2 | 1 |
| `SettingsTests/testAnsweringTheCheckInKeepsItsPlace()` | 66 | 60 | 63 | 3 | 1 |
| `HomeSizesTests/testTheLargerSizesPassTheAuditAndDrawTheirWordsWhole()` | 66 | 64 | 91 | 4 | 1 |
| `PhraseDragTests/testDefaultDark()` | 63 | 50 | 58 | 2 | 3 |
| `PhraseDragTests/testDefaultLight()` | 63 | 45 | 55 | 2 | 3 |
| `SettingsOnHomeTests/testOpeningSettingsWithACheckInDueAtTheLargestText()` | 62 | 36 | 41 | 1 | 3 |
| `PhraseDragTests/testAX5Light()` | 62 | 49 | 60 | 2 | 3 |
| `SettingsTests/testFamilySetupOpensWithSetUpStepByStepOverTheWholeRootRow()` | 61 | 56 | 65 | 2 | 1 |
| `PhraseDragTests/testAX5Dark()` | 57 | 52 | 58 | 2 | 3 |
| `SettingsTests/testTheFirstStepOpensWithLearnAboutEachWayOverSetUpStepByStep()` | 54 | 55 | 53 | 2 | 1 |
| `HomeReachabilityTests/testEveryHomeStateAtDefaultTextInLandscape()` | 54 | 50 | 58 | 1 | 2 |
| `SettingsOnHomeTests/testOpeningSettingsFromHomeAtDefaultText()` | 50 | 43 | 53 | 1 | 3 |
| `SettingsOnHomeTests/testOpeningSettingsFromHomeAtTheLargestText()` | 50 | 35 | 40 | 1 | 3 |
| `HomeSizesTests/testHomeIsLargestUntilAnsweredAndTouchsOnceTouchIsChosen()` | 49 | 44 | 86 | 2 | 1 |
| `SettingsOnHomeTests/testOpeningSettingsFromHomeInLandscape()` | 49 | skipped | skipped | 1 | 3 |
| `HomeReachabilityTests/testEveryHomeStateAtDefaultTextInPortrait()` | 45 | 47 | 81 | 1 | 2 |
| `HomeReachabilityTests/testEveryHomeStateAtTheLargestTextInPortrait()` | 47 | 44 | 68 | 1 | 2 |
| `HomeReachabilityTests/testEveryHomeStateAtTheLargestTextInLandscape()` | 46 | 45 | 112 | 1 | 2 |
| `TypingOnHomeTests/testEmergencyPhrasesAndSettingsLeaveTypingAndKeepTheMessage()` | 45 | 35 | 39 | 1 | 3 |
| `LibraryTests/testASampleBackupIsAdded()` | 44 | 37 | 49 | 1 | 2 |
| `SettingsOnHomeTests/testVoiceSettingsFromAScrolledFamilySetup()` | 34 | 44 | 49 | 1 | 3 |
| `LibraryTests/testTheLibrarysScreensPassTheAuditInDark()` | 37 | 43 | 44 | 1 | 2 |
| `LaunchTests/testLargestTextKeepsQuickControlWordsVisible()` | 42 | 37 | 69 | 2 | 3 |
| `FoldOffsetUITests/testTheFirstRowClearsATopDivisionInDarkMode()` | 41 | 39 | 61 | 2 | 3 |
| `TypingOnHomeTests/testSpeakAndReturnSayTheMessageAndKeepIt()` | 39 | 33 | 41 | 1 | 3 |
| `SettingsTests/testSettingsOpensOnTheWayBackAndFamilySetup()` | 39 | 28 | 23 | 2 | 1 |
| `TypingOnHomeTests/testTheMessageSurvivesARelaunch()` | 39 | 32 | 54 | 2 | 3 |
| `KeyboardProbeTests/testLandscapeAtDefaultTextSize()` | 37 | skipped | skipped | 2 | 1 |
| `GetAttentionOnHomeTests/testTheAlarmStartsAndStopsAtDefaultText()` | 32 | 35 | 53 | 1 | 3 |
| `GetAttentionOnHomeTests/testTheAlarmStartsAndStopsInLandscape()` | 33 | skipped | skipped | 1 | 3 |
| `SettingsTests/testTheStepByStepSetupWalksToTheEnd()` | 32 | 28 | 32 | 1 | 1 |
| `SettingsTests/testVoiceSettingsPassesTheAccessibilityAudit()` | 32 | 23 | 28 | 1 | 1 |
| `TypingOnHomeTests/testClearAndPutBack()` | 30 | 21 | 25 | 1 | 3 |
| `GetAttentionOnHomeTests/testTheAlarmStartsAndStopsAtTheLargestText()` | 28 | 30 | 46 | 1 | 3 |
| `HomeAccessibilityOrderTests/testQuickControlsComeFirstInEveryStateAtDefaultText()` | 28 | 28 | 38 | 1 | 1 |
| `KeyboardProbeTests/testPortraitAtDefaultTextSize()` | 27 | 27 | 64 | 2 | 1 |
| `HomeAccessibilityOrderTests/testQuickControlsComeFirstInEveryStateAtTheLargestText()` | 26 | 24 | 38 | 1 | 1 |
| `FoldOffsetUITests/testTheFirstRowClearsATopDivisionInLightMode()` | 26 | 23 | 33 | 2 | 3 |
| `KeyboardProbeTests/testLandscapeAtLargestTextSize()` | 26 | skipped | skipped | 2 | 1 |
| `SettingsTests/testChoosingASpeedMovesNoSpeedChoice()` | 24 | 26 | 25 | 1 | 1 |
| `KeyboardProbeTests/testPortraitAtLargestTextSize()` | 25 | 26 | 39 | 2 | 1 |
| `SlowPressTests/testASlideFromYesOntoNoNeverSaysNo()` | 24 | 13 | 22 | 1 | 1 |
| `TypingOnHomeTests/testTypeOpensTheKeyboardAndMovesNothing()` | 23 | 15 | 20 | 1 | 3 |
| `SettingsTests/testTheWayBackKeepsItsFrameOnEveryScreen()` | 23 | 20 | 23 | 1 | 1 |
| `SettingsTests/testASpeedChosenTwiceStaysChosen()` | 23 | 22 | 24 | 1 | 1 |
| `LaunchTests/testTheTextSizeSettingTakesEffect()` | 21 | 22 | 33 | 2 | 3 |
| `SettingsOnHomeTests/testTheFirstRunHintShowsUntilFamilySetupOpens()` | 20 | 16 | 18 | 1 | 3 |
| `LaunchTests/testTheAppearanceSettingTakesEffect()` | 20 | 18 | 33 | 2 | 3 |
| `SettingsTests/testAnIdleSettingsReturnsToItsFirstScreenAndStaysOpen()` | 20 | 14 | 23 | 1 | 1 |
| `SettingsTests/testThePrivacyPolicyIsInsideTheApp()` | 20 | 18 | 18 | 1 | 1 |
| `SettingsTests/testNumberedStepsAreReadWithTheirNumbers()` | 19 | 17 | 16 | 1 | 1 |
| `SlowPressTests/testASlowPressSpeaksAtTheLargestTextSize()` | 19 | 13 | 18 | 1 | 1 |
| `PhraseDragTests/testASidewaysSlideOnAPhraseSaysThatPhrase()` | 17 | 18 | 12 | 1 | 3 |
| `PhraseDragTests/testASmallWobbleOnAPhraseStillSpeaks()` | 16 | 17 | 12 | 1 | 3 |
| `LaunchTests/testTheEmergencyPhrasesPassTheAccessibilityAudit()` | 16 | 13 | 24 | 1 | 3 |
| `SettingsTests/testBackToTalkingReturnsToHome()` | 15 | 13 | 14 | 1 | 1 |
| `PhraseDragTests/testAHeldPhraseSpeaksAtAX5()` | 14 | 15 | 20 | 1 | 3 |
| `LaunchTests/testHomeInDarkModePassesTheAccessibilityAudit()` | 14 | 11 | 22 | 1 | 3 |
| `LaunchTests/testHomePassesTheAccessibilityAudit()` | 14 | 12 | 23 | 1 | 3 |
| `LaunchTests/testAPhraseSpeaksOnTheFirstTap()` | 12 | 11 | 19 | 1 | 3 |
| `LaunchTests/testEmergencyShowsTheEmergencyPhrases()` | 12 | 11 | 16 | 1 | 3 |
| `LaunchTests/testHomeShowsTheQuickControlsAndStarterPhrases()` | 9 | 10 | 15 | 1 | 3 |
| `HeldSlideProbeTests/testHome()` | skipped | skipped | skipped | – | 3 |
| `HeldSlideProbeTests/testSettingsGearAlone()` | skipped | skipped | skipped | – | 3 |
| `PhraseDragProbeTests/testDrags()` | skipped | skipped | skipped | – | 3 |

| Class | iPad, min | iPhone, min | iPhone, slow day, min | Part |
| --- | ---: | ---: | ---: | ---: |
| `SettingsTests` | 14.9 | 16.3 | 16.8 | 1 |
| `LibraryTests` | 9.4 | 10.6 | 11.5 | 2 |
| `SettingsOnHomeTests` | 5.7 | 3.8 | 4.4 | 3 |
| `PhraseDragTests` | 4.9 | 4.1 | 4.6 | 3 |
| `HomeRestBoardTests` | 4.4 | 5.2 | 6.9 | 2 |
| `HomeReachabilityTests` | 3.2 | 3.1 | 5.3 | 2 |
| `TypingOnHomeTests` | 2.9 | 2.3 | 3.0 | 3 |
| `LaunchTests` | 2.7 | 2.4 | 4.2 | 3 |
| `HomeSizesTests` | 1.9 | 1.8 | 3.0 | 1 |
| `KeyboardProbeTests` | 1.9 | 0.9 | 1.7 | 1 |
| `HomeLayoutTests` | 1.9 | 0.9 | 1.7 | 3 |
| `GetAttentionOnHomeTests` | 1.5 | 1.1 | 1.7 | 3 |
| `FoldOffsetUITests` | 1.1 | 1.0 | 1.6 | 3 |
| `HomeAccessibilityOrderTests` | 0.9 | 0.9 | 1.3 | 1 |
| `SlowPressTests` | 0.7 | 0.4 | 0.7 | 1 |
| `HeldSlideProbeTests` | 0.0 | 0.0 | 0.0 | 3 |
| `PhraseDragProbeTests` | 0.0 | 0.0 | 0.0 | 3 |
| All | 58.0 | 54.9 | 68.4 | |

| Part | iPad, min | iPhone, min | iPhone, slow day, min |
| --- | ---: | ---: | ---: |
| 1 | 20.3 | 20.3 | 23.4 |
| 2 | 17.0 | 18.9 | 23.7 |
| 3 | 20.8 | 15.7 | 21.2 |

## UI tests a unit test might replace

A first sort of the 81 tests by what each one asserts, to size a later
clean-up. These are judgements from reading the code, not measurements,
and nothing here was moved. "Screen" means only a running app on a
screen can show it: a real activation through a standard control, a
control being reachable and hittable, Apple's accessibility audit, words
drawn whole, the live software keyboard, the order the system gives
VoiceOver, rotation. "Unit" means a plain type in the app already
decides it, and a unit test can check that type directly.

- **Screen only, 34 tests.** Every accessibility audit and rendered-words
  test (in `LaunchTests`, `LibraryTests`, `HomeRestBoardTests`,
  `HomeSizesTests`, `SettingsTests`), every `PhraseDragTests` and
  `SlowPressTests` test, `KeyboardProbeTests`, the Library's held-look
  chains on the frames the app really draws,
  `LaunchTests.testAPhraseSpeaksOnTheFirstTap`, and the two opt-in probes.
- **Candidates, 5 tests,** whose checks a unit test already makes:
  `LibraryTests.testAPhraseNamedLikeAControlIsSavedWithANote`
  (`LibraryEditTests`, `LibraryEditorWordsTests`),
  `LibraryTests.testCategoriesStayBetweenThreeAndFour` (`LibraryEditTests`,
  `CategorySelectionTests`),
  `SettingsTests.testAnIdleSettingsReturnsToItsFirstScreenAndStaysOpen`
  (`SettingsIdleClockTests`), `SettingsTests.testASpeedChosenTwiceStaysChosen`
  (`SpeedChoiceTests`), `TypingOnHomeTests.testClearAndPutBack`
  (`MessageComposerTests`). Each would keep at most one check that the
  control is wired to that type.
- **Partly, 42 tests:** a screen check (a real tap, hittable, on screen)
  wrapped round placement or state that a unit test already covers:
  frames from `HomeLayout` (`HomeLayoutEngineTests`,
  `HomeReservedRegionTests`), Settings frames and places
  (`SettingsScreenFramesTests`, `SettingsRowPlaceTests`,
  `SettingsLeadInTests`, `SetupAnswersPlaceTests`), the check-in rule
  (`SetupRecordTests`), the rest board (`CategorySelectionTests`,
  `RestBoardTests`), typing (`MessageComposerTests`, `DraftStoreTests`).
  The screen part stays; the repeated configurations are what could go.

The biggest savings in app launches, if the clean-up goes ahead:

1. `HomeLayoutTests.testTheStarterLibraryFitsWithoutScrolling` launches
   four times on the iPad; the slot and floor arithmetic is in
   `HomeLayoutEngineTests`, so one launch could keep the drawn check.
2. `FoldOffsetUITests`' light and dark tests (four launches) measure the
   same frames; whether dark mode needs its own run is for the clean-up
   to decide.
3. `SettingsTests.testAnsweringTheCheckInKeepsItsPlace` (three launches):
   the 30-day rule is in `SetupRecordTests`.
4. `LaunchTests.testTheTextSizeSettingTakesEffect` and
   `testTheAppearanceSettingTakesEffect` (four launches) check the test
   launch arguments, which `LaunchArgumentsTests` covers.
5. The four `HomeReachabilityTests` and the `SettingsOnHomeTests` ways
   in and out repeat one check across text sizes and orientations; the
   unit tests cover the arithmetic, so fewer configurations might do.

## Commits

- `8dfaebe` Count a simulator that already shut down as cleaned up
- `923a4f3` Run the UI tests in three parts per family, each on its own machine
- This record and the documents.

## Verified

On the owner's Mac, Xcode 27.2:

- `scripts/test-runner.py` (106 tests), `scripts/test-docs.py`,
  `scripts/test-hooks.py`, `scripts/test-forbidden-code.py`: pass.
- New tests, each failing on the change named beside it in
  `scripts/test-runner.py`: a simulator that already shut down counts
  as cleaned up (it failed on the old script, the run's status 1);
  every UI test class runs in exactly one part; unsound parts (a
  misspelled class, a class named twice, an empty part, every class
  named) are reported; a part passes its classes to the test run only
  and keeps its own bundle; the last part skips exactly the named
  classes; without a part nothing is filtered; an unknown part, or a
  part of the unit tests, stops before anything starts.
- The workflow check catches each of seven broken workflows: a part
  missing from the gate's `needs`, `&&` for `||`, a part's job missing,
  one part's job differing (its time limit), a job name that miscounts
  the parts, two jobs running the same part, and the gate without
  `if: always()`.
- `xcodebuild -enumerate-tests` with each part's arguments, on an iPad
  Pro 13-inch (M5) and an iPhone 17 simulator (iOS 27.2): parts of 29,
  15 and 37 tests, 81 in all on each, every test exactly once.
- LOCALRUN

## Not verified

- CI's run of the six parts, when this was written: the pull request's
  checks and its description have the result.
- How long a part takes on a slow day like 2026-11-16: the estimate
  above comes from the measured classes, not from a slow run.
- Whether the slow iPad jobs' failing tests (above) come back on the
  parts.
- Whether pausing `diagnosticd` or `apsd` in the simulator would speed
  the tests: not tried.

## Follow-ups

- If a part's job takes more than about 45 minutes on a normal day,
  move classes between parts or add one (docs/DECISIONS.md, "Tests").
  `SettingsTests` alone is about 15 minutes, the floor for its part
  until it is split.
- The tests that a unit test might replace (above) are the start of a
  later clean-up that cuts app launches; each move needs its own pull
  request and keeps the screen check where only the screen can show it.
- The three iPad failures on slow machines: if they recur on the parts,
  a thread looks at each one's wait.
- The unit job takes 34 to 43 of its 60 minutes; it is not changed
  here.
