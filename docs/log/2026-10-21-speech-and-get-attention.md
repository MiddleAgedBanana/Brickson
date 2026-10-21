# Speech engine seams and the Get Attention alarm

*2026-10-21. Pull request #16 (`claude/project-thread-ykcc9b`). The
"Speech engine and Get Attention" thread.*

## What changed and why

Nothing new is on screen yet. Underneath, the speech engine can now be
tested without sound, four bugs carried over from the reference app are
fixed, and the Get Attention alarm is built and ready for Home to show.

- **Seams.** `SpeechService` takes its synthesizer
  (`SpeechSynthesizing`), audio session, voice list, settings
  (`UserDefaults`), Personal Voice request and sleep from outside.
  `AppAudio.makeForApp(settings:)` builds the real ones, and the app
  passes `launch.settings`, so UI tests on test-only storage never read or
  change the person's voice and rate (PR #13's `SpeechService(settings:)`
  became this `settings:` parameter in the merge). The synthesizer's
  delegate is internal and forwards plain events.
- **One audio session.** `AudioSessionEvents` turns the session's
  notices into plain events, on iOS 26 and iOS 27 (which reports who
  deactivated the session). `AudioSessionCoordinator` configures
  `.playback` in the `.default` mode (pinned by a test) and hands out
  holds to speech and the alarm. In 1.0 it never deactivates
  (docs/DECISIONS.md, "Background audio").
- **Fixes.** The voices-changed observer is removed when the service
  goes away. Utterances are matched by a token the service hands out,
  never by an object identifier the system can reuse. A phrase the
  system cuts off is no longer reported as finished
  (docs/DECISIONS.md, "A phrase the system cuts off"). The missed-finish
  check no longer hides "Audio failed".
- **Get Attention.** `AttentionAlertStatus` and `AttentionAlertPlayer`,
  with the tone `AttentionTone.wav`, ported from the reference app. It is
  start-only, dips while a phrase speaks, and never restarts by itself
  (docs/DECISIONS.md, "Get Attention", "Audio session notices"). It is in
  the environment but no control starts it yet.
- **Settings support.** `preview(from: .voice(id:))` speaks in that
  voice (`nil` means the voice Automatic would choose), and
  `VoicePreviewControl.normalRate` exists for a Normal Speed button.

## Commits

- `179b4e7` Report a phrase the system cuts off instead of calling it
  finished
- `f829dc4` Put the speech engine behind testable seams and share the
  audio session
- `5c731cb` Port the start-only Get Attention alarm
- `f9fb5b0` Build the app's audio objects in one place and check
  framework callbacks off the main thread
- `6aeda4b` Document the speech seams and the Get Attention alarm
- `5683e7e` Let the off-main-thread tests read their boxed framework
  objects off the main actor (the first CI run's only compile errors)
- The merge of `main` (PRs #12, #13 and #15), which adopts
  `launch.settings`, keeps PR #13's three settings tests on the new
  harness, and records "Personal Voice is never written to a file".

## Verified

Written by a cloud agent with no Swift compiler for iOS: nothing was
built or run here. The first CI run (Xcode 26.6, `6aeda4b`) compiled the
app and every test file but one, whose errors `5683e7e` fixes; no test
had run yet. Code under `#if compiler(>=6.4)` (iOS 27's session notices)
is first compiled by CI on Xcode 27 after the merge.

Every new rule has a unit test with fakes; each test's doc comment names
the change that makes it fail. New off-main-thread tests call the
synthesizer delegate, the tone player's delegate, the Personal Voice
answer and a session notice from a background thread.

## Not verified

- Any sound: the tone's loudness, the dip while speaking, and playing
  with the silent switch on or the screen locked. Device checks are
  listed in docs/HANDOFF.md, "Checks that need a real device".
- That iOS really reports an early finish before an interruption, which
  the cut-off rule relies on.
- The iOS 27 deactivation notice on a device.

## Follow-ups

Each of the next two pull requests gets a fresh thread. Start from
docs/HANDOFF.md, then this file.

1. **Get Attention and Stop on Home**, after the layout's slot model lands
   (Phone layout and word fitting; docs/DECISIONS.md, "Home's slot
   plan"). Get Attention goes in safety row C and Stop in the pinned cell
   above Emergency, never in the same place (invariant 10; "Get
   Attention"). Read `AttentionAlertPlayer` from the environment
   (`start()`, `stop()`, `isSounding`, `state`, `failureSequence`), feed
   its real `state` to `AudioSafetyPolicy` on Home instead of idle, and
   announce each new `failureSequence`. UI tests: both controls reachable
   in every Home state, including while typing, and Stop's frame never
   under Get Attention's.
2. **Personal Voice foundation.** In `SpeechService`:
   `requestPersonalVoiceAuthorization() async` (wrapping the injected
   request, which already hops to the main actor),
   `refreshPersonalVoiceAvailability()` (status and installed voices again
   on returning to the foreground), and `hasPersonalVoice`. Add a plain
   `PersonalVoiceAskPolicy` with `.atLaunch` (today's behaviour) and
   `.fromSettings`; switch to `.fromSettings` only when Settings has the
   explained button (Settings and first run owns `PersonalVoiceGuidance`
   in `Brickson/Settings`). Keep "Personal Voice is never written to a
   file" (docs/DECISIONS.md). Off-main tests for any new callback.
3. Later, not now: Add Audio in Calls (waits for a device build) and the
   recorder for recorded phrases.
4. A device check of background audio before the App Review notes promise
   it, and the replacement tone (docs/HANDOFF.md, *Checks that need a real
   device*). *(owner)*
