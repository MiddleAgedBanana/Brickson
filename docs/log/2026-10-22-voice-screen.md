# The Voice screen: asking for Personal Voice, and places that hold

*2026-10-22. Pull request #27 (`claude/project-thread-stqn5g`).
The "Voice screen in Settings" thread, which follows PR #23 (Settings
and first run) and PR #25 (the Personal Voice engine).*

## What changed and why

Nobody using Brickson sees a difference yet: Settings has no way in from
Home until Home's Settings button lands, and the Ask button shows only
under a policy the app does not use yet. What changed for the family's
Voice Settings screen, once they can reach it:

- **Codex's three held fixes for PR #23** (its fourth review), applied
  first from the patch the Settings thread left in the project files:
  - Set Up Step by Step no longer says the access answers set how large
    the buttons are, since no layout reads them yet.
  - Family Setup's opening text is at least as tall as the root's Family
    Setup row as drawn, button insets included (`SettingsLanding`), so a
    repeated activation where that row was lands on words.
  - Voice Settings keeps its places while voices come and go
    (docs/DECISIONS.md, "Voice Settings keeps its places while it is
    open"): rows keep the place they had when the screen opened, a voice
    that goes keeps its place as words, one that arrives goes last, and
    the Personal Voice card keeps its tallest height. Codex's review of
    this pull request found two gaps, fixed here: voices arriving one at
    a time were sorted among themselves, so a later arrival could move
    an earlier one (now each keeps the place it first had,
    `VoiceList.addingArrivals`); and a gone voice's words could be taller
    than its row on a narrow screen at the largest text sizes, pushing
    every row below down (now the words take the line under the voice's
    name, and every row lays out each version of that line,
    `VoiceList.secondLines`). Its second review found that a grant from
    the Ask button can reveal a Personal Voice whose name was hidden
    until then, and "Speaking with …" would grow to name it; the line now
    names only voices on the device when the screen opened, and says "a
    newly available voice" otherwise (`VoiceList.speakingName`).
- **Ask to Use Personal Voice** (docs/DECISIONS.md, "Asking for Personal
  Voice from Voice Settings"): the card's explained button, calling
  `SpeechService.requestPersonalVoiceAuthorization()`. A second press
  while iOS asks asks nothing more (`isAskingForPersonalVoice`), and
  Settings holds its idle reset meanwhile (`.personalVoiceRequest`). The
  answer moves nothing: the words keep room for every answer
  (`PersonalVoiceGuidance.outcomesOfAsking()`), the button's place keeps
  its size with "Answered. …" in it, and no new button appears in the
  card on the visit that asked (`askedOnThisVisit`), so Open Personal
  Voice Settings, which leaves Brickson, never appears beside the spot
  just activated. It shows only under `PersonalVoiceAskPolicy.fromSettings`;
  the app's policy is still `.atLaunch` until device check D1.
- **A way to run D1 without changing code:** a debug build launched with
  `--personal-voice=ask-from-settings` asks only from the button, with
  the device's own permission. `--personal-voice=stand-in-refuses` uses a
  stand-in that refuses (`StandInPersonalVoice`), so a UI test reaches
  the button. The app's policy is now the first line of
  `AppAudio.personalVoiceAskPolicy(for:)`. Release builds read no launch
  arguments.
- **No false "gone" when only access is off** (Personal Voice foundation,
  follow-up 4, the access half): without Personal Voice permission a
  chosen Personal Voice is left out of the list but is still on the
  device. The note above the list now says the chosen voice "can't be
  used now" and comes back when Personal Voice is turned on, and a
  Personal Voice that leaves while the screen is open says it "can't be
  used while Personal Voice is turned off" (`VoiceList.missingVoiceNote`,
  `goneVoiceNote`). Every version of each note is laid out, so access
  changing moves nothing.

Besides the patch's own changes, the String Catalog gains seven strings
and loses one, written by hand in code-point order (nothing here could
build).

## Commits

- `20966a3`, `a2228c2`, `a98f455` Codex's three held fixes, applied
  with `git am` from the Settings thread's patch.
- `259b690` The Personal Voice launch trial and its stand-in.
- `3d88c1a` The Ask button and the truthful notes.
- `58cd607`, `d133c93` This record and the documents.
- `54d36f4` The review fixes: arrivals keep their first places, and
  every row reserves its gone-voice line.
- `38139ba` The two UI tests measure what they meant to measure.
- `0dd6ab7` Main (with PR #22) merged in.
- The commit that keeps "Speaking with …" from growing after a grant.

## Verified

Written in a cloud session without Xcode, so GitHub CI on the pull
request was the first build (AGENTS.md, *Build and test*), on the current
Xcode with iOS Simulator 27.0:

- `d133c93` and `54d36f4`: the app built, the String Catalog matched the
  code, and every unit test passed on the iPad Pro 13-inch simulator
  (414, then 416 with the review fixes' two tests).
- `54d36f4` UI tests: 29 of 30 run passed on the iPad Pro 13-inch and 28
  of 30 on the iPhone 17 (the 4 opt-in keyboard probes skipped on
  each). Both failures were the tests' measurements, not the app, and
  are fixed in `38139ba` (below). Until the UI tests are green on a
  later head, treat the two screens' UI checks as unproven.

Before pushing, with Swift 6.3.3 on Linux in Swift 6 mode with
main-actor default isolation (a throwaway package outside the repository,
`String(localized:)` stubbed):

- `PersonalVoiceGuidanceTests` and `VoiceListTests`, including the
  patch's four `keepingPlaces` tests: 23 tests passed, and 26 after the
  review fixes.
- Each new test was made to fail by undoing its rule on those copies:
  offering Open Personal Voice Settings after asking fails
  `afterAskingHereNoNewButtonAppearsOnThisVisit` and
  `everyAnswerToAskingOffersNoButton`; dropping an answer from
  `outcomesOfAsking` fails `everyAnswerToAskingOffersNoButton`; words
  that do not name the button or Allow fail
  `theAskButtonIsExplainedBeforeIOSAsks`; one note for both access
  states, or a gone row that ignores access, fails
  `aVoiceWhoseAccessIsOffIsNeverCalledGone`. Leaving the snapshot
  without its arrivals fails `arrivalsKeepTheOrderTheyFirstAppearedIn`;
  reserving only the quality and language line fails
  `everyRowReservesTheNotesItCouldShow`; naming whichever voice speaks
  now fails `aVoiceThatAppearsAfterOpeningIsNotNamed`.
- `StandInPersonalVoice` and `theStandInPersonalVoiceAnswersFromAnotherThread`
  compiled against a small stand-in for AVFoundation's status type and
  passed; the `switch` that picks the permission in `AppAudio` compiled
  in the same package.

Written to fail, and first run by CI:

- `SpeechServiceTests.aSecondRequestWhileTheFirstWaitsAsksNothingMore`
  fails if a second press asks again, or if `isAskingForPersonalVoice`
  is not set while waiting or not cleared after.
- `LaunchOptionsTests.thePersonalVoiceTrialIsReadOnlyWhenSpelledRight`
  fails if a typo is taken for a trial.
- `PersonalVoiceAskPolicyTests.theAppAsksAtLaunchUnlessALaunchAsksForATrial`
  fails if the app's own policy changes.
- `SettingsTests.testAnsweringTheAskButtonMovesNothing` (UI, default and
  AX5 text) fails if the button is missing under the trial, if its place
  does not hold its words after the answer, if the answer moves the
  Speed heading against that place, if any button covers the spot where
  the Ask button was, or if Open Personal Voice Settings appears on the
  visit that asked. It also runs Apple's audit on the asking state.
- The patch's `SettingsTests.testFamilySetupOpensOnTextOverTheWholeRootRow`
  read the opening's lower edge from its accessibility frame, which CI
  showed is the words' own bounds, not the block they are laid out in:
  42.5pt tall and 995pt wide on the iPad (two lines of text) against a
  110pt by 1000pt root row, and 86.3pt against 110pt on the iPhone. The
  test now reads the block's lower edge from the first row below it,
  less the spacing between rows (measured on the same screen), and also
  fails if any button that can be activated lies within the root row's
  frame. No captures were kept (CI uploads no result bundle); the frames
  in the failure messages were enough.
- `testAnsweringTheAskButtonMovesNothing` failed only on the iPhone,
  naming Home's "I don't know." tile at the spot: Home stays in the
  accessibility tree under the Settings cover. It now counts only a
  button that can be activated (`isHittable`), as
  `testAnIdleSettingsReturnsToItsFirstScreenAndStaysOpen` already does
  for Home's Yes. Every other check in it passed on both devices.

## Not verified

- Anything on a device, and iOS's real question: the UI test uses the
  stand-in, which never shows one. Whether Settings is still on Voice
  Settings after the question has been open for over 90 seconds, and
  where a dwell user's look rests after answering, are device checks
  (docs/HANDOFF.md, *Checks that need a real device*, the row after D1).
- How much empty space the card shows while the button is offered: it
  keeps room for the longest answer ("No Personal Voice yet", with its
  path and the note on making one). Judged acceptable on a family
  screen; look at the CI captures.
- Whether the system posts `availableVoicesDidChangeNotification` after
  the answer; the service reads the voices again either way.

## Follow-ups

For the next Settings thread, in order, after docs/HANDOFF.md and
[`2026-10-21-settings-and-first-run.md`](2026-10-21-settings-and-first-run.md),
*Follow-ups* (its follow-up 3 is now done; 1, 2 and 4 to 10 remain):

1. **Device check D1, then the switch** *(owner with a device build,
   then an agent)*: run D1 with `--personal-voice=ask-from-settings`
   (docs/HANDOFF.md). If a voice allowed after the first phrase speaks
   after a refresh, change the first line of
   `AppAudio.personalVoiceAskPolicy(for:)` to `.fromSettings` and update
   "Personal Voice permission is asked at launch, for now" (the privacy
   policy does not say when Brickson asks). If only a rebuilt synthesizer
   works, rebuild it
   on a grant while idle first ([`2026-10-21-personal-voice-foundation.md`](2026-10-21-personal-voice-foundation.md),
   *Follow-ups*, item 3).
2. **A passive line when Automatic moves to another Personal Voice**
   (Personal Voice foundation, follow-up 4, the other half): the engine
   replaces the kept voice silently when it is gone
   (`SpeechService.keepAutomaticPersonalVoice`). It needs the engine to
   record the change, for the screen to say so once.
3. **Words that grow while Voice Settings is open** still push what is
   below down (the card going from ready to turned off). Reserve every
   version where they are known, as the Ask button's words now are.
4. **Score the chain through iOS's question** with the other Settings
   chains (Settings' follow-up 10) before `.fromSettings` ships: after
   answering, a dwell user's look rests where the question's button was.
