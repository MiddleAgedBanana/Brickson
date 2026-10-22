# Personal Voice

*Roadmap: R0, items 4 (the speech engine) and 7 (the voice picker).
Owner: the Personal Voice foundation thread (engine); Settings and first
run (the Voice screen and `PersonalVoiceGuidance`). Status: the engine
landed with PR #25 and the Voice screen's Ask button on 2026-10-22
(docs/log/2026-10-22-voice-screen.md); asking from Settings switches on
after device check D1.*

## Intent

- **Problem:** Brickson can speak in a person's own Personal Voice, but
  the engine around it is thin. It asks for permission once, at launch,
  with no explanation, and never looks again: a voice made or allowed
  while Brickson waits in the background is missed until the next
  launch, and a voice whose access was turned off may still be asked for
  (one report says that gives silence). With two Personal Voices on a
  device, Automatic takes whichever the system lists first, so a
  person's voice can change between two launches without anyone choosing
  it. A voice is part of who someone is.
- **Proposed outcome:** the engine knows, at every moment the app is in
  front, whether the person's Personal Voice can be used, and speaks in
  it whenever it can; it never asks for a voice it may not use; once
  Automatic has spoken in someone's Personal Voice it keeps that voice
  while it exists; and the Voice screen can ask for permission from an
  explained button, changing one line when that moment comes.
- **Who and what it affects:** everyone who has made a Personal Voice,
  at every stage, on every input method (nothing here is on screen);
  families setting it up. `SpeechService`, `VoiceSelection`, the app's
  foreground handling.
- **Constraints:** invariant 2 (nothing waits before speaking: the voice
  is resolved from what is already known), 3 (no phrase data changes),
  4 and 5 (never silence because of a voice: fall back to the next voice),
  9 (no network: everything is the system's own API),
  docs/DECISIONS.md "Personal Voice is never written to a file", and
  *Closures a framework may call off the main thread* (docs/LESSONS.md).
- **Open questions:** each decided by default in docs/DECISIONS.md:
  when the question is asked ("Personal Voice permission is asked at
  launch, for now"), what Automatic keeps ("Automatic keeps the
  person's Personal Voice"), and what happens when access is turned off
  ("A Personal Voice is used only while it is allowed").

## Spec

- **States:** none on screen. The engine's Personal Voice state is the
  system's answer (`personalVoiceStatus`: not asked, allowed, not
  allowed, not supported) and the voices the system lists. It is read at
  launch, after every answer, whenever the system says its voices
  changed, and each time the app comes back to the front.
- **Asking:** `PersonalVoiceAskPolicy`. `.atLaunch` (today, and still the
  app's policy) asks every time the app starts. `.fromSettings` asks only
  from Settings' explained button; at launch it asks again only when
  the person has already allowed it, which shows no question.
  `requestPersonalVoiceAuthorization()` is that button's call: it asks,
  waits for the answer, reads the voices again and returns the answer.
- **Choosing a voice:** in order: the voice the person chose; for
  Automatic, the Personal Voice Automatic used before (remembered under
  `automaticPersonalVoiceID`) while it is listed; any Personal Voice; the
  best voice in the app's language; any voice. A Personal Voice is a
  candidate only while the answer is "allowed". Every step still checks
  that the voice loads and falls to the next one. Speaking never waits
  for any of this. The remembered voice is written only when the voice
  list is read, and is kept, not cleared, while access is off, so the
  same voice comes back with it.
- **Input methods:** nothing to reach; no repeated activation meets
  anything new.
- **Colours:** none.
- **Privacy policy:** nothing becomes untrue. The remembered voice is a
  setting kept on the device ("Your settings, such as the voice and
  speaking speed you chose"), and the voice itself stays with iOS.
- **Screens:** none in this part. The Voice screen (Settings and first
  run) reads `personalVoiceStatus`, `availableVoices` (which leaves out a
  Personal Voice without permission), `hasPersonalVoice`,
  `personalVoices`, `automaticVoice`, `currentVoice` and
  `personalVoiceAskPolicy` (whether it offers its own Ask button).
- **Concerns:** whether a voice allowed after the first phrase in a
  session works without a relaunch (device check D1 in
  docs/recon/2026-10-15/directions/onboarding-and-settings.md, 2.5)
  decides when the app may switch to `.fromSettings`; what a turned-off
  voice does when asked for (D4) and whether two voices keep their order
  and identifiers (D5) are device checks too.

## Plan

- **Files that change:** `Brickson/Speech/PersonalVoiceAskPolicy.swift`
  (new), `VoiceSelection.swift`, `SpeechSynthesizing.swift` (the
  `PersonalVoiceAuthorizing` seam), `SpeechService.swift`,
  `Brickson/App/AppAudio.swift`, `BricksonApp.swift` (one line on
  returning to the front); tests in `PersonalVoiceAskPolicyTests`,
  `VoiceSelectionTests`, `SpeechServiceTests`,
  `OffMainThreadCallbackTests` and the doubles in `AudioTestDoubles`.
  The Voice screen and `PersonalVoiceGuidance` stay with Settings and
  first run.
- **Order of work:** one pull request: failing tests, then the pure
  types, then the service, then the documents.
- **Risks:** the Settings pull request touches `BricksonApp.swift` too;
  whichever lands second merges `main` once more. The policy switch could
  hide personal voices if D1 fails, so the app keeps `.atLaunch` until
  D1 passes and the button exists.
- **Proof:** unit tests with fakes, each naming the change that makes it
  fail: the policy table; the ask, its answer from a background thread,
  and the refresh; a second Personal Voice that does not change
  Automatic; a turned-off Personal Voice never asked for; the remembered
  voice kept through a time without access. Device checks D1, D4 and D5
  join docs/HANDOFF.md, *Checks that need a real device*.
