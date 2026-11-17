# A phrase that does not start is stopped and named

*2026-11-17. Pull request #<n> (`claude/project-thread-4tes2b`). A
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
(`SpokenUtteranceTracker.startLimit`). One that has sent neither Apple's
start report (`speechSynthesizer(_:didStart:)`, newly forwarded) nor a
word report by then is stopped, after a second look half a second later,
and treated as cut off: Home shows the existing "Stopped — Again" (or
"Stopped: Phrases" while typing, "Stopped — Back" under a screen), a
voice sample only clears "Speaking", and "Audio failed" stays when the
session never activated. A phrase that began is never stopped by the
limit. Again, or the same tile, then speaks at once: before this change
the same tile was absorbed, for up to 20 seconds, as a repeat of the
phrase still "speaking".

The 15 seconds, why the phrase is stopped rather than left to sound, and
what the limit does not catch are in docs/DECISIONS.md, "A phrase that
does not start". No new words appear on screen; a plainer warning is
left to the owner (docs/HANDOFF.md, *Known gaps*). A start slower than
one second is logged with its milliseconds, and a phrase the limit stops
is logged as an error, numbers only, so later CI runs and device check
P3 show how close real starts come to the limit.

`SpeechService` now takes its clock (`now`) like its `sleep`, so tests
move time by hand (`ManualClock` in `AudioTestDoubles`); the app passes
`ContinuousClock.now`. The fake synthesizer reads the same clock.

This is a small fix in one pull request, so it has no work file
(docs/work/README.md).

## Evidence for the limit

From the app's own log in that run's result bundle
(`ui-test-results-ipad-part3`), the time from a phrase's voice lookup to
the first audio line of each launch that spoke:

| Launch (process) | Voice lookup | First audio | Gap |
| --- | --- | --- | ---: |
| 20173, AX5 light, Yes | 07:49:21 tap; lookup answered 07:52:09 | none before 07:52:49 | stuck |
| 27296, AX5 dark, Yes | 07:53:15.71 | 07:53:20.59 | 4.9 s |
| 29483 | 07:55:20.93 | 07:55:22.99 | 2.1 s |
| 29901 | 07:55:51.08 | 07:55:53.02 | 1.9 s |
| 30630 | 07:56:12.66 | 07:56:14.65 | 2.0 s |
| 50701, Speak | 08:06:49.64 | 08:06:52.91 | 3.3 s |

The 2026-10-25 speech diagnostic's simulator controls reported their
start 0.03 to 0.08 seconds after asking and their first word 0.6 to 1
second after. The slowest healthy start, 4.9 seconds, rounded up to 5,
times three is the 15-second limit; it stays under the 20-second
`repeatWindow`.

## Commits

See the pull request: one commit with the change and its tests, one
with these records.

## Verified

- **Linux, Swift 6.4.2, not the iOS build.** The speech files and their
  tests (`SpokenUtteranceTracker`, `SpeechService`,
  `SpeechSynthesizing`, the audio session types and the alarm player,
  with stand-ins for AVFoundation and `Logger`) compiled with no
  warnings in a throwaway package outside the repository, with Swift 6
  language mode, main-actor default isolation and the project's upcoming
  features. 118 tests passed: every test in `SpokenUtteranceTrackerTests`
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
    `aVoiceSampleThatNeverBeginsOnlyClearsTheIndicator`.
- The repository's Python checks (see the pull request).

## Not verified

- **The iOS build and every test on iOS.** Untested until CI passes.
- **Whether the stuck service on CI withheld Apple's start report.**
  Brickson did not log it then. The log shows the voice lookup for the
  phrase blocked and no audio, which is consistent with no start; if the
  system did send a start for a phrase it never voiced, this limit does
  not catch it (docs/DECISIONS.md, *What it does not catch*). The next
  stall on CI will show: the app now logs slow starts.
- **Real devices.** How long phrases take to begin after a restart, in a
  Personal Voice, and on the oldest supported device: device check P3,
  step 3 (docs/DEVICE-CHECKS.md).
- **The UI tests that met the stuck service.** `LaunchTests`'s
  `testLargestTextKeepsQuickControlWordsVisible` waits for "Speaking" to
  go; with this change a stuck phrase now ends after about 16 seconds,
  showing "Stopped — Again", so the test goes on to its audit with that
  warning on screen. Whether that screen passes the audit at AX5 is for
  CI to show.

## Follow-ups

- A plainer warning for a phrase that never began, such as "Not spoken
  — Again" with its own sentence. *(owner: new words on Home)*
- A phrase that began and then stays "speaking" with no finish (the
  2026-10-25 diagnostic) is still open. *(the next speech thread)*
