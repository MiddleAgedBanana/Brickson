# Speech engine seams and the Get Attention alarm

*2026-10-21. Branch `claude/project-thread-ykcc9b`. The "Speech engine
and Get Attention" thread.*

## What changed and why

Nothing new is on screen yet. Underneath, the speech engine can now be
tested without sound, four bugs carried over from the reference app are
fixed, and the Get Attention alarm is built and ready for Home to show.

- **Seams.** `SpeechService` takes its synthesizer
  (`SpeechSynthesizing`), audio session, voice list, settings
  (`UserDefaults`), Personal Voice request and sleep from outside.
  `AppAudio.makeForApp(settings:)` builds the real ones. The synthesizer's
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
- The commit that adds this file: the documentation.

## Verified

Written by a cloud agent with no Swift compiler for iOS: nothing was
built or run here. GitHub CI on this pull request is the first build.
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

- Show Get Attention and Stop on Home once the layout's slot model lands
  (this thread).
- Personal Voice: ask from an explained Settings button, and record that
  a Personal Voice is never rendered to a file (this thread).
- `BricksonApp` passes `.standard` to `AppAudio.makeForApp(settings:)`
  until the test-seams pull request lands `LaunchOptions`; whichever
  merges second passes `launch.settings`.
- Replace the placeholder tone if a better one is chosen.
