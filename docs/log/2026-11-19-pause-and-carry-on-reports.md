# The synthesizer's pause and carry-on reports are logged

*2026-11-19. Pull request #129 (`claude/speech-start-and-pause-signals`),
built on pull request #123 and to be merged after it. A Claude thread
running on the owner's Mac with Xcode 27.2.*

## What changed and why

Apple's speech synthesizer tells its delegate when it pauses an
utterance and when it carries on after a pause
(`speechSynthesizer(_:didPause:)` and `speechSynthesizer(_:didContinue:)`).
Brickson listened to neither, so nothing recorded whether the system
sends them when a phone call, Siri or another app's alarm pauses speech.
Brickson never pauses speech itself: it stops it, and never calls
`pauseSpeaking(at:)`, the one case Apple documents the pause report for.

Now both reports are forwarded through the same seam as the others
(`SpeechSynthesisEvent.paused` and `.continued`), each stamped with
`ContinuousClock` as it arrives, before it crosses to the main thread
(docs/LESSONS.md, "Timers use ContinuousClock"). The speech service logs
each one, without the phrase's words, saying whether it was for the
phrase still current and how long the report waited to be handled: "The
synthesizer paused the current utterance (report waited N ms)", "The
synthesizer carried on with the current utterance (...)", or the same for
"an utterance that is no longer current". It also logs "An audio
interruption began" when the interruption notice is handled, and "The
audio output in use became unavailable" when headphones or a speaker go,
so a device's log shows which came first. Nothing else changes: a paused phrase is
still found by the interruption notice or by the speech watchdog, as
before. Whether a pause report may be read as a cut-off is for device
check S2, step 4, to decide (docs/DECISIONS.md, "A phrase the system
cuts off", *Pause and carry-on reports are logged, not acted on yet*).

**A new phrase is never queued behind the last one.** A real
synthesizer queues an utterance handed to it while it still holds
another, speaking or paused, and speaks it only when that one ends.
Brickson already stops the last phrase first; a new test pins it, the
paused case included, with a stand-in synthesizer that counts every
request handed over while an earlier one is still held. No app code
changed for this.

**What pull request #123 already does.** Pull request #123 forwards the
start report (`speechSynthesizer(_:didStart:)`, as
`SpeechSynthesisEvent.started`) and makes it the direct sign that a
phrase began, beside its first word, in its check for a phrase that never
starts. This pull request adds one test to that rule: a start or word
reported after the start limit has stopped the phrase does not bring
"Speaking" back. A separate type for the states of an utterance (idle,
will speak, speaking, paused) was considered and not added:
`SpokenUtteranceTracker` already holds the first three (no utterance, one
not yet begun, one begun), and nothing acts on a pause yet.

**Ducking other audio in the mixing fallback was not built.** When the
plain `.playback` session is refused (during a call), Brickson retries
mixing with other audio. Adding `.duckOthers` there would lower other
audio while Brickson speaks, but Apple's documentation for that option
says ducking lasts until the session is deactivated, and to set it only
for a few seconds at a time. Brickson never deactivates its session in
1.0 (docs/DECISIONS.md, "Background audio", *When the session is
released*), so other audio, a call included, would stay lowered after
the phrase ended. It belongs with the decision to release the session
when idle, which waits for its own device check.

This is a small change in one pull request, so it has no work file
(docs/work/README.md).

## Commits

- `32bd067` Forward the synthesizer's pause and carry-on reports, and
  log them (the change and its tests).
- `af6f56f` Pin that a new phrase never queues and a stopped phrase
  stays stopped (tests only).
- `1b4369f` Record the pause reports, ducking in the fallback, and the
  device check: docs/DECISIONS.md, docs/DEVICE-CHECKS.md (S2, step 4),
  docs/HANDOFF.md and this record.
- The commit answering Codex's review before the pull request opened
  (`codex review` on the owner's Mac, against #123's tip): the reports
  stamped as they arrive and the wait logged, as docs/LESSONS.md asks of
  framework callbacks, so a notice handled while a report waited cannot
  look as if it came first; device check S2 reads both kinds of log
  line and keeps watching until the interruption ends; and output loss
  logged for the headphone part of that check.

## Verified

On the owner's Mac with Xcode 27.2, on an iPad Pro 13-inch (M5)
simulator with iOS 27.2:

- **Before the change**, on pull request #123's branch at `0b78e1f`:
  `scripts/test.sh unit`, 1076 tests, 0 failed (1 skipped and 12
  expected failures, as on that branch).
- **The new tests first, before the forwarding existed** (the delegate
  methods present but empty): `SpeechServiceTests` and
  `OffMainThreadCallbackTests`, 94 tests, with
  `pauseAndCarryOnReportsCanArriveOnABackgroundThread` failing on its
  arrival and its two reports. After the change: 94 tests passed.
- **The whole unit suite after the change**: `scripts/test.sh unit`, with
  its Python checks, 1081 tests, 0 failed (1 skipped, 12 expected
  failures), no build warnings, String Catalog unchanged; and again after
  the commit answering Codex's review, with the same result.
- **The stamp**: the background-thread test checks each report's instant
  falls between the moment before the calls and the moment the
  background task finished them, in order, so a stamp taken after the
  hop to the main thread would fall outside it.
- **Each new test fails without what it guards** (one change at a time,
  the test run alone, then put back):
  - a pause report acted on as a cut-off:
    `pauseAndCarryOnReportsChangeNothingYet` fails;
  - a pause report that makes the service forget the phrase without a
    warning: `theWatchdogStillStopsAPhrasePausedWithAReport` fails;
  - the earlier phrase stopped only while audible, so a paused one is
    left holding the synthesizer:
    `aNewPhraseIsNeverQueuedBehindTheLastOne(lastIsPaused: true)` fails;
  - a start report that takes a stopped phrase up again:
    `aStartReportedAfterTheLimitStoppedThePhraseDoesNotBringItBack`
    fails;
  - the forwarding missing: the background-thread test above.
- `scripts/forbidden-code.py`, `test-site.py`, `test-select-xcode.py`
  and `test-runner.py` passed; `test-docs.py`, `test-hooks.py`,
  `test-privacy.py`, `test-agent-bridge.py` and
  `test-forbidden-code.py` passed inside the unit run.

## Not verified

- **Whether the system sends a pause or carry-on report** when a call,
  Siri or an alarm pauses speech, and in which order with the
  interruption notice. Device check S2, step 4.
- **The log lines.** No test reads them: the app's logger cannot be read
  in a unit test. Device check S2, step 4, reads them.
- **Real speech and a real synthesizer's queue.** Every test here uses a
  stand-in synthesizer; simulators prove nothing about sound.

## Follow-ups

- After device check S2, step 4: decide whether a pause report for the
  current phrase is read as a cut-off (stopped, with "Stopped — Again"),
  and whether a carry-on report after Brickson stopped a phrase needs the
  synthesizer stopped again. *(the next speech thread)*
- Ducking other audio in the mixing fallback, together with releasing
  the session when idle (docs/DECISIONS.md, "Background audio").
  *(the next audio thread, after its device check)*
