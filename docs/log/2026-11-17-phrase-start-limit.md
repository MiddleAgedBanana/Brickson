# A phrase that does not start is stopped and named

*2026-11-17. Pull request #123 (`claude/project-thread-4tes2b`). A
Claude cloud thread, which cannot build or run the app.*

## What changed and why

When the system's speech service accepted a phrase and never began it,
Brickson showed "Speaking" for as long as the service stayed silent, with
nothing to say the phrase was not heard. The speech watchdog only acted
on a synthesizer that had gone quiet, and this one kept saying it was
speaking. On CI (pull request #122, run 44037184309, "UI tests on iPad,
part 3 of 3") Yes was tapped at 07:49:21, the synthesizer's voice lookup
did not answer until 07:52:09, and no audio started before the test
relaunched the app at 07:52:49. On a device that is a phrase the person
never heard, and one that could sound minutes later, out of turn.

Now the watchdog also gives each utterance 15 seconds to begin
(`SpokenUtteranceTracker.startLimit`), counted from the moment the app is
asked to speak it, before it stops any earlier phrase or activates
audio. One that has sent neither Apple's
start report (`speechSynthesizer(_:didStart:)`, newly forwarded) nor a
word report by then is stopped, after a second look half a second later,
and treated as cut off: Home shows the existing "Stopped — Again" (or
"Stopped: Phrases" while typing, "Stopped — Back" under a screen), a
voice sample only clears "Speaking", and "Audio failed" stays when the
session never activated. A phrase that began in time is never stopped
by the limit. Because a slow audio activation or voice lookup holds the
main thread, where the watchdog runs, the limit is also checked outside
it: a phrase held up for 15.5 seconds or more (the limit and its second
look) is never handed to the synthesizer, and one that reports its start
that late is stopped as soon as the report arrives, so at most its first
moment is heard. Again, or the same tile, then speaks at once: before this change
the same tile was absorbed, for up to 20 seconds, as a repeat of the
phrase still "speaking".

The 15 seconds, why the phrase is stopped rather than left to sound, and
what the limit does not catch are in docs/DECISIONS.md, "A phrase that
does not start". No new words appear on screen; a plainer warning is
left to the owner (docs/HANDOFF.md, *Known gaps*). A start of one
second or more is logged with its milliseconds, whichever report shows
it first, and a phrase the limit stops is logged as an error, numbers
only, so later CI runs and device check P3 show how close real starts
come to the limit.

`SpeechService` now takes its clock (`now`) like its `sleep`, so tests
move time by hand (`ManualClock` in `AudioTestDoubles`); the app passes
`ContinuousClock.now`. The fake synthesizer reads the same clock.

This is a small fix in one pull request, so it has no work file
(docs/work/README.md).

**One UI test wait made longer.** After `main` was merged in again
(`99bbd98`), `HomeSizesTests.testHomeIsLargestUntilAnsweredAndTouchsOnceTouchIsChosen()`
failed on the iPad in all three CI attempts. The first time, Apple's
audit of Settings timed out with no finding. The second and third times,
Settings' Family Setup row was still in the accessibility hierarchy 10
seconds after Family Setup's title appeared. In both of those runs,
`simulator-load-ipad-part1.txt` shows iOS redrawing its lock-screen
wallpapers (PosterBoard at 60 to 80% and the wallpaper extensions it
starts) during that step, five to eight minutes after the simulator
started. The same test passed on `main` (run 624) and on #124 (run 625).
There the redraw had run about three minutes after the start, long
before the step, and the step took about a second at the same or higher
load. In the third attempt the screen recording shows Family Setup
already drawn, without the row, by about 02:46:55 UTC, while the test
still found the row at 02:47:04. On the owner's Mac the step passed 64
of 64 times, 32 on `main` and 32 on this branch, with the row gone in
about 0.1 seconds. The step runs no speech code, because the test speaks
nothing before it. So `open(_:waitingFor:in:context:)` now waits up to
60 seconds for the row to go, not 10. It still fails if the screen never
finishes opening, and no audit is retried or loosened. The redraw does
not explain the first failure, the audit timeout. That came about seven
minutes after the start, with no redraw logged then, and this change
does not touch it.

## Evidence for the limit

From that run's result bundle (`ui-test-results-ipad-part3`): when the
test began each tap or press, from the test's own log; and the phrase's
voice lookup and the first audio line of each launch that spoke, from the
app's log. The limit counts from the moment the app asks for the phrase
to be spoken, before it activates audio and looks up the voice, which
falls between the test's tap and the voice lookup, so the two right-hand columns bound
each start from below and above.

| Launch (process) | Tap or press began | Voice lookup | First audio | From lookup | From tap or press |
| --- | --- | --- | --- | ---: | ---: |
| 20173, AX5 light, Yes | 07:49:21.58 | answered 07:52:09 | none before 07:52:49 | stuck | stuck |
| 27296, AX5 dark, Yes | 07:53:15.20 | 07:53:15.66 | 07:53:20.59 | 4.9 s | 5.4 s |
| 29483, press of 1.5 s | 07:55:19.06 | 07:55:20.93 | 07:55:22.99 | 2.1 s | 3.9 s |
| 29901, press and drag | 07:55:48.11 | 07:55:51.08 | 07:55:53.02 | 1.9 s | 4.9 s |
| 30630, press and drag | 07:56:11.58 | 07:56:12.67 | 07:56:14.65 | 2.0 s | 3.1 s |
| 50701, Speak | 08:06:49.20 | 08:06:49.64 | 08:06:52.92 | 3.3 s | 3.7 s |

The 2026-10-25 speech diagnostic's simulator controls reported their
start 0.03 to 0.08 seconds after asking and their first word 0.6 to 1
second after. The slowest healthy start therefore took between 4.9 and
5.4 seconds from the ask. The 15-second limit is nearly three
times the longer figure (2.8 times) and stays under the 20-second
`repeatWindow`. (The first version of this record measured from the
voice lookup only and called 15 seconds three times 5; a review on the
pull request pointed out that the limit counts from earlier, so the tap
is now measured too. The limit did not change.)

## Commits

- `75d4577` Stop a phrase the speech service never begins, and say so
  (the change and its tests).
- `d50d523` Record the start limit, its evidence and its device check.
- The review-fix commit after them: the start measured from the test's
  tap as well as the voice lookup, the threshold for new evidence worded
  the right way round, a slow start logged whichever report shows it
  first, where the count starts stated (docs/DECISIONS.md, "A phrase
  that does not start"), two more tracker tests, and the hashes and
  checks in this record.
- The second review's two commits: the count starts before the earlier
  phrase is stopped and audio is activated, as the rule says (the first
  version started it after activation), with a test that makes a slow
  activation count; the start-log thresholds worded as the code measures
  them (one second or more); a review's proposal to order reports by
  their stamps declined, with the reason, in docs/DECISIONS.md.
- The third review's commit: the limit checked outside the watchdog, so
  a phrase held up past it on the main thread is never handed over and
  one that begins that late is stopped as it begins (docs/DECISIONS.md,
  "A phrase that does not start"), with three tests.
- The CI wait commit, after `main` was merged in again: `HomeSizesTests`
  waits up to 60 seconds, not 10, for the row a screen was opened from to
  leave the accessibility hierarchy (above), and docs/HANDOFF.md records
  why. Test code and records only, no app code.

## Verified

- **Linux, Swift 6.4.2, not the iOS build.** The speech files and their
  tests (`SpokenUtteranceTracker`, `SpeechService`,
  `SpeechSynthesizing`, the audio session types and the alarm player,
  with stand-ins for AVFoundation and `Logger`) compiled with no
  warnings in a throwaway package outside the repository, with Swift 6
  language mode, main-actor default isolation and the project's upcoming
  features. 124 tests passed: every test in `SpokenUtteranceTrackerTests`
  and `SpeechServiceTests` (except one about launch storage, which needs
  `LaunchOptions`) and the speech test from `OffMainThreadCallbackTests`.
- **Each new test fails without the change it covers** (run on the same
  harness, one change at a time):
  - the limit never acting, which is the app before this change:
    `aPhraseThatNeverBeginsNamesAgainOnceTheStartLimitPasses`,
    `againSpeaksAtOnceAfterTheStartLimitStoppedThePhrase`,
    `aVoiceSampleThatNeverBeginsOnlyClearsTheIndicator`,
    `whenAudioNeverStartedTheStartLimitLeavesAudioFailedShowing`,
    `aStartThatLandsDuringTheGraceKeepsThePhrase` and the tracker's
    `aPhraseWithNoStartReportFailsOnlyOnceTheStartLimitHasPassed` and
    `reportsForAReplacedUtteranceDoNotStartTheNewOne` fail;
  - a word report not counting as a start: `aWordReportAlsoCountsAsAStart`
    and `aPhraseThatReportsAWordIsNeverStoppedByTheStartLimit`;
  - `>` in place of `>=` at the limit: the boundary tests;
  - no second look: `aStartThatLandsDuringTheGraceKeepsThePhrase` and the
    missed-finish watchdog's own tests;
  - the start report not forwarded: `synthesizerReportsCanArriveOnABackgroundThread`;
  - the service ignoring the start report: `aSlowStartInsideTheLimitKeepsSpeaking`;
  - a limit of 8 seconds: `theStartLimitLeavesRoomForASlowFirstPhrase`;
  - recovery that does not stop the synthesizer:
    `aPhraseThatNeverBeginsNamesAgainOnceTheStartLimitPasses` and
    `aVoiceSampleThatNeverBeginsOnlyClearsTheIndicator`;
  - a start report not counted as progress, so a repeat of a phrase that
    began late stops being absorbed too soon:
    `aLateStartKeepsAbsorbingARepeatFromWhenItBegan`;
  - a word report never returning the start measurement, and every report
    returning it: `aWordReportThatComesFirstSaysHowLongThePhraseTookToBegin`;
  - the count starting after the audio session activates:
    `aSlowAudioActivationCountsAgainstTheStartLimit`;
  - a phrase handed to the synthesizer however long it was held up, and
    the check written `<=` at its boundary:
    `aPhraseHeldUpPastTheLimitIsNeverHandedToTheSynthesizer`;
  - a late start or word kept, and `>` in place of `>=` at the boundary:
    `aStartReportedPastTheLimitStopsThePhraseAsItBegins` and
    `aFirstWordReportedPastTheLimitStopsThePhraseToo`;
  - only the start report checked against the limit:
    `aFirstWordReportedPastTheLimitStopsThePhraseToo`;
  - no second look in that check (15 seconds, not 15.5):
    `aStartThatLandsDuringTheGraceKeepsThePhrase`.
- **The repository's Python checks**, on Linux in this cloud session,
  all passed: `scripts/test-docs.py`, `test-hooks.py`, `test-privacy.py`,
  `test-forbidden-code.py`, `forbidden-code.py`, `test-runner.py`,
  `test-agent-bridge.py`, `test-site.py` and `test-select-xcode.py`.
  `privacy-check.py --outgoing --no-list` found nothing; no private list
  exists in a cloud session, so the list was not checked.

## Not verified

- **The iOS build and every test on iOS.** Untested until CI passes.
- **Whether the stuck service on CI withheld Apple's start report.**
  Brickson did not log it then. The log shows the voice lookup for the
  phrase blocked and no audio, which is consistent with no start; if the
  system did send a start for a phrase it never voiced, this limit does
  not catch it (docs/DECISIONS.md, *What it does not catch*). The next
  stall on CI will show: the app now logs slow starts.
- **The two log lines.** No test reads them: the app's logger cannot be
  read in a unit test. The tracker tests pin the measurement they print;
  device check P3, step 3 reads the lines themselves.
- **Real devices.** How long phrases take to begin after a restart, in a
  Personal Voice, and on the oldest supported device: device check P3,
  step 3 (docs/DEVICE-CHECKS.md).
- **The UI tests that met the stuck service.** `LaunchTests`'s
  `testLargestTextKeepsQuickControlWordsVisible` waits for "Speaking" to
  go; with this change a stuck phrase now ends after about 16 seconds,
  showing "Stopped — Again", so the test goes on to its audit with that
  warning on screen. Whether that screen passes the audit at AX5 is for
  CI to show.
- **The longer Family Setup wait on CI.** Whether 60 seconds covers the
  wallpaper redraw when it lands on that step is for CI to show; the
  redraw's link to the lag is a strong match in the runner's records,
  not a proof. The Settings audit timeout of the first attempt is not
  explained.

## Follow-ups

- A plainer warning for a phrase that never began, such as "Not spoken
  — Again" with its own sentence. *(owner: new words on Home)*
- A phrase that began and then stays "speaking" with no finish (the
  2026-10-25 diagnostic) is still open. *(the next speech thread)*
