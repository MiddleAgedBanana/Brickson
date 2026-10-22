# The Personal Voice engine: asking, reading again, keeping one voice

*2026-10-21. Pull request not open yet (`claude/project-thread-1ly6dd`).
Personal Voice foundation thread: the speech work's third pull request,
engine side only.*

## What changed and why

Nothing new is on screen. What a person will notice:

- **A voice allowed while Brickson waits is used when they come back.**
  The engine reads the system's Personal Voice answer at launch (so
  someone who allowed it before speaks in their own voice from the first
  phrase), after every answer, and each time the app comes back to the
  front (`SpeechService.refreshPersonalVoiceAvailability()`, called from
  `BricksonApp`), and reads the voice list again each time.
- **A turned-off voice is never asked for.** Without permission no
  Personal Voice is a candidate for a phrase, a voice sample or
  Automatic, even one a stale list still shows
  (`VoiceSelection.usableVoices`); the phrase speaks in the next voice and
  the person's choice is kept for when access comes back. The list the
  Voice screen shows (`SpeechService.availableVoices`) leaves it out too.
  docs/DECISIONS.md, "A Personal Voice is used only while it is allowed".
- **A second Personal Voice no longer changes the voice.** Once Automatic
  speaks in a Personal Voice, its identifier is kept (settings key
  `automaticPersonalVoiceID`) and Automatic stays with it while the
  system lists it. docs/DECISIONS.md, "Automatic keeps the person's
  Personal Voice".
- **When to ask is one line.** `PersonalVoiceAskPolicy` (`.atLaunch`,
  today's behaviour and still the app's, or `.fromSettings`) is chosen in
  `AppAudio.makeForApp`. `SpeechService.requestPersonalVoiceAuthorization()`
  is the call for the Voice screen's explained button: it asks, waits,
  reads the voices again and returns the answer. docs/DECISIONS.md,
  "Personal Voice permission is asked at launch, for now".

For the Voice screen, `SpeechService` now offers `personalVoiceStatus`,
`availableVoices`, `personalVoices`, `hasPersonalVoice` (allowed and at
least one voice), `automaticVoice` (what Automatic speaks in now),
`currentVoice` (what the next phrase speaks in) and
`personalVoiceAskPolicy`.

The seam to the system is `PersonalVoiceAuthorizing` (status and request)
in `SpeechSynthesizing.swift`, with `SystemPersonalVoice` for the app and
`FakePersonalVoice` in the tests. The closure handed to AVFoundation is
built by a `nonisolated` function, `SystemPersonalVoice.forwardingAnswer`,
so a test can call it from a background thread.

APIs used, each read on developer.apple.com (the `.md` form) on
2026-10-21: `AVSpeechSynthesizer.requestPersonalVoiceAuthorization(completionHandler:)`
(its handler is `@Sendable`), `personalVoiceAuthorizationStatus`,
`PersonalVoiceAuthorizationStatus` (`notDetermined`, `denied`,
`unsupported`, `authorized`), `AVSpeechSynthesisVoice.Traits.isPersonalVoice`
("the system only makes personal voices available when ... authorized")
and `availableVoicesDidChangeNotification`. All are iOS 17, below the
iOS 26.0 deployment target, so nothing needs `#available`.

The work file is [`docs/work/personal-voice.md`](../work/personal-voice.md).

## Commits

- `2043faf` The work file: intent, spec and plan.
- `cc48e1c` The engine and its tests.
- The commit that adds this record: docs/DECISIONS.md, docs/HANDOFF.md,
  docs/PORTING.md.

## Verified

Not built for iOS: this was written in a cloud session without Xcode, so
GitHub CI on the pull request is the first build and the first run of
these tests on a simulator (AGENTS.md, *Build and test*). Until it is
green, treat the change as untested.

Before pushing, the app's speech code and all of `BricksonTests`' speech,
audio and selection suites were compiled with Swift 6.3.3 on Linux, in
Swift 6 mode with the project's default main-actor isolation, against
small stand-ins for AVFoundation's types (kept out of the repository),
and run: 210 tests in 12 suites passed. That shows the logic and the
strict-concurrency checking hold; it says nothing about AVFoundation's
real behaviour. Four tests cannot run there (two need the bundled tone,
two post notices from a background thread, which Linux's Foundation
deadlocks on with `queue: .main`) and were skipped on Linux only.

Each new test was made to fail by undoing its change, on those Linux
copies: dropping the permission filter fails
`aPersonalVoiceIsNeverAskedForWithoutPermission` and
`withoutPermissionNoPersonalVoiceIsUsable`; not keeping the voice fails
`aSecondPersonalVoiceDoesNotChangeTheVoiceAutomaticSpeaksIn` and
`theAutomaticPersonalVoiceIsKeptAcrossLaunches`; not reading the status
at launch fails `theStatusTheSystemAlreadyHasIsReadAtLaunch`; ignoring
the policy fails `fromSettingsDoesNotAskAtLaunch`; a refresh that skips
the status fails `comingBackToTheFrontReadsAccessAndVoicesAgain`; a
request that does not apply its answer, or never asks, fails
`theRequestReturnsTheAnswerAndTheNextPhraseUsesTheVoice` and
`aRefusedRequestIsKeptAndSpeaksNothing`. The request tests wait for the
answer to land before awaiting the request, so a broken path fails
instead of hanging the run. The two new off-main tests call the
request's answer and `forwardingAnswer`'s closure from a detached task.

## Not verified

- Anything on a device or a simulator yet. Device checks D1, D4 and D5
  (docs/recon/2026-10-15/directions/onboarding-and-settings.md, sections
  2.5 and 7) are now in docs/HANDOFF.md, *Checks that need a real
  device*: whether a voice allowed after the first phrase speaks without
  a relaunch; what a turned-off voice does; whether two voices keep their
  order and identifiers.
- Whether the system really posts `availableVoicesDidChangeNotification`
  when access changes. Reading again on every return to the front does
  not depend on it.
- The String Catalog: this change adds no words people see.

## Follow-ups

Start from docs/HANDOFF.md, then this file.

1. **The Voice screen's Ask button** *(Settings and first run, or the
   next speech thread)*. Pass `canAsk: speech.personalVoiceAskPolicy ==
   .fromSettings` to `PersonalVoiceGuidance`, add the Ask button for its
   ask-permission state calling `await speech.requestPersonalVoiceAuthorization()`,
   and hold the idle reset while iOS asks (that thread's
   `.personalVoiceRequest`). The screen refreshes itself: the service
   already reads the voices again after the answer.
2. **"Speaking with" on the Voice screen** should read `speech.currentVoice`
   (and Automatic's row `speech.automaticVoice`) instead of calling
   `VoiceSelection.select` itself, so it shows the kept Personal Voice.
   `hasPersonalVoice` there can read `speech.hasPersonalVoice`.
3. **Switch to `.fromSettings`** in `AppAudio.makeForApp` only when the
   button exists and D1 passes on a device. D1 needs a build that does
   not ask at launch: `.fromSettings` with the button is that build. If
   D1 passes only after a rebuilt synthesizer, rebuild it on a grant
   while idle, reusing the media-services-reset path; if only after a
   relaunch, keep `.atLaunch` and explain afterwards (docs/DECISIONS.md).
4. **A passive line on the Voice screen** when Automatic's kept voice is
   gone and it moved to another Personal Voice, and when the chosen
   Personal Voice cannot be used because access is off (onboarding and
   settings research, 3.2a and 3.2b). The engine keeps the choice;
   showing it is the screen's.
5. **Get Attention and Stop on Home** remains the speech work's next pull
   request ([`2026-10-21-speech-and-get-attention.md`](2026-10-21-speech-and-get-attention.md),
   *Follow-ups*, item 1).
