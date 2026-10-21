# Accessibility API coverage checklist

*2026-10-21. Pull request from `claude/project-thread-tuixyp`. The
"Accessibility coverage checklist" thread, a cloud session that cannot
build or run the app.*

## What changed and why

The owner's goal is for Brickson to use every accessibility API in the
project's map of Apple features by ALS stage (2026-10-10). Until now no
document said which of them Brickson uses, which come in which release,
and which it will not use and why. This pull request adds that list and
changes no app code.

- **`docs/ACCESSIBILITY.md`** (new): every row of the map, then about 150
  features and APIs in ten groups, each with what it is for, the ALS
  stage, the iOS version from Apple's page, its status (in place, a
  roadmap item, later, not applicable or never) and how it is checked.
  It ends with the APIs newer than iOS 26.0 and their fallbacks.
- **`docs/DECISIONS.md`**: a new entry, "Accessibility API coverage"
  (default, reversible), and its row in *Decided by default*. *App
  identity* is corrected: Apple says Siri uses alternative app names only
  for apps with an Intents extension, so "Brick Son" has no effect yet.
  *Minimum iOS* now names the APIs above 26.0 found by this check.
- **`docs/ROADMAP.md`**: R1's layout engine gains the late-stage profile
  (the map's Yes/No mode and rest board); a new *Waiting, not yet in a
  release* section lists what the map wants after R2; the repo review's
  "not reviewed yet" line no longer lists accessibility coverage.
- **`docs/HANDOFF.md`**: a pointer for agents, the alternative-name gap,
  and five device checks.
- **`AGENTS.md`** (*Where things are*) and **`README.md`**
  (*Documentation*): a line each pointing to the new list.
- **`project.yml`**: the comment above `INAlternativeAppNames` now says
  Siri uses the names only once the app has Siri support. The key itself
  is unchanged.

## Commits

The commit that adds this file holds the whole change.

## Verified

Nothing was built or run: this is a cloud session, and the change is
documentation plus one `project.yml` comment. GitHub CI is the check that
nothing else moved.

How the list was made:

- **The map** was read in full from the owner's document (35 rows in four
  stages and an App Store section). Each row appears in
  `docs/ACCESSIBILITY.md`, *The map, row by row*.
- **An earlier research pass** (the same thread's predecessor, stopped
  before committing) had gathered 177 candidate items from Apple's pages,
  the 2026-10-15 recon and the reference app's accessibility notes.
  Duplicates were merged here and every row was rewritten.
- **Apple's pages, read 2026-10-21.** About 200 developer documentation
  pages were fetched in their Markdown form
  (`developer.apple.com/documentation/<path>.md`), which carries an
  availability block; every iOS version in the list's API rows comes from
  that block. Apple's update pages for Accessibility, SwiftUI, UIKit,
  AVFAudio, App Intents and XCUIAutomation were read for anything newer
  than the map.
- **Brickson's status** was checked against `main` at `6782db2` (the
  Swift sources, the unit and UI test names, `project.yml`).

What the check found that earlier documents had wrong or did not have:

- `INAlternativeAppNames` only works for apps with an Intents app
  extension (Apple, "Specifying Synonyms for Your App Name"). Brickson has
  none, so the alternative name does nothing yet.
- UIKit's `buttonShapesEnabled` is deprecated from iOS 26.1, and SwiftUI's
  `accessibilityShowButtonShapes` is marked deprecated; the current value
  is `accessibilityShowBorders`.
- `AVAudioSession.activate(options:completionHandler:)` is iOS 27.0 on
  iOS; `MCSession` (Multipeer Connectivity) is deprecated in iOS 27.0.
- `AccessibilitySettings.Feature.allowAppsToAddAudioToCalls` (iOS 18.2)
  opens the Add Audio in Calls switch, useful for R0 item 8.
- New since the map: the iPhone Duo reserved regions and hinge APIs
  (`ReservedRegion`, `onHingeChange`, iOS 27.1), and `XCUIVoiceOverService`
  for VoiceOver in UI tests (iOS 27.0).
- Confirmed above 26.0: `canOpenSettings(for:)`,
  `accessibilityPrefersCrossFadeTransitions` and
  `accessibilityReduceHighlightingEffects` (26.4); the audio-session
  life-cycle notices and `IntentExecutionTargets` (27.0). None needs a
  higher minimum.

## Not verified

- **First versions of system features** (Switch Control, AssistiveTouch,
  Touch Accommodations, Zoom, Read & Speak and others) were not re-checked
  where the list says "System" without a version. All are present on iOS
  26, which is all the minimum needs.
- **Behaviour Apple does not document**, each now a device check: whether
  SwiftUI containers become Switch Control scan groups, whether Switch
  Control and Full Keyboard Access follow `accessibilitySortPriority`,
  what VoiceOver does with `startsMediaSession` when the sound is
  synthesized speech, which status flags each input method turns on,
  whether Eye Tracking and Switch Control work inside Assistive Access,
  whether Guided Access's Display Auto-Lock overrides Brickson keeping the
  screen awake, and whether App Intents count as Siri support for
  alternative names.
- **Absences** cannot be proven from documentation: no API to write Live
  Speech phrases, to start Emergency SOS, or to read whether Voice
  Control, Eye Tracking, Head Tracking, Dwell or Full Keyboard Access is
  on was found.
- `NSMicrophoneInjectionUsageDescription` has no reference page; only
  Apple's sample documents it.
- Whether `XCUIVoiceOverService` works on a simulator.
- Apple's user guides (support.apple.com) were not re-read in this pass;
  the system-feature rows rest on the earlier research's reading of them.

## Follow-ups

What each roadmap item picks up from `docs/ACCESSIBILITY.md`, in the order
the work should land. Each item's owner is named in `docs/ROADMAP.md`.

**R0, in this order:**

1. **Item 3, an honest Home** (Phone layout and word fitting), with the
   slot model: the quick controls first in the accessibility order and
   the same order in every state, with a UI test that reads Home's
   elements in order; Home's regions as `.contain` containers;
   `accessibilityInputLabels` with the visible words first, and a
   whole-screen name-collision test; `@ScaledMetric` for non-text sizes
   and no Dynamic Type cap; the Large Content Viewer for any label the
   fitting type limits; fitting measured in bold; a motion policy that
   honours Reduce Motion and Prefer Cross-Fade (`#available(iOS 26.4)`,
   UIKit value before); borders drawn inside the frame when Show Borders
   is on. `accessibilitySortPriority` and
   `accessibilityRespondsToUserInteraction` only if view order or a
   device check shows they are needed.
2. **Item 4, Get Attention on Home** (a new speech thread, after item 3's
   slots): the `playsSound` trait on Get Attention; a steady alarm style
   whatever Reduce Bright Effects says; a unit test pinning
   `prefersAssistiveTechnologySettings` false; `startsMediaSession` on
   phrase tiles only after its device check.
3. **Item 5, typing** (Typing foundation): Apple's keyboard,
   `writingToolsBehavior(.disabled)`, third-party keyboards refused,
   Return speaks, `.keyboard` safe area ignored so nothing moves, the
   keyboard probe; an accessibility audit of the typing state.
4. **Item 6, editing** (Library editing and backup format): name
   collisions in a family-grown library; Writing Tools off in the phrase
   editor; an audit of each editing screen. Custom accessibility actions
   wait (*Later*).
5. **Item 7, Settings and first run**: the family setup text for every
   system feature marked R0-7 (Switch Control, Dwell, Eye and Head
   Tracking, Voice Control, Vocal Shortcuts, Listen for Atypical Speech,
   Live Speech, Touch Accommodations, Guided Access with its warnings,
   Assistive Access, the Accessibility Shortcut, Zoom, Share
   Accessibility Settings, Auto-Lock); `openSettings(for:)` links from
   setup only, with `canOpenSettings(for:)` behind `#available(iOS 26.4)`
   and a written path when opening fails or inside Assistive Access;
   Personal Voice guidance and its "Allow Apps to Request to Use" link;
   `UISupportsFullScreenInAssistiveAccess` with an `AppBundleTests` pin
   (and one that `UISupportsAssistiveAccess` stays absent); header traits
   and standard toggles in Settings; an audit of every Settings screen.
6. **Item 8, calls** (held): microphone injection, its usage text, and
   the `allowAppsToAddAudioToCalls` link.
7. **Item 9, screens**: a rendered check of Home's fills with Reduce
   Transparency and Increase Contrast; no glass on speaking or safety
   controls.
8. **Item 10, App Store**: the labels and evidence in
   `docs/APP-STORE.md`, section 4, and the accessibility page.
9. **Item 2 follow-up** (whoever next works on test seams): a VoiceOver
   walk of Home with `XCUIVoiceOverService` on the iOS 27 simulators,
   behind `#available(iOS 27.0)`, once item 3's slots land.

**R1:** the profile layout engine with switch, head, gaze, keyboard and
the late-stage profile (Yes/No and the rest board); dwell-safety scoring;
profile suggestions from the assistive-technology flags (never a switch);
Display Zoom window sizes; the Full Keyboard Access focus-order test;
recorded phrases with "recorded" as custom content; the printable board;
iPhone Duo reserved regions behind `#available(iOS 27.1)`.

**R2:** App Intents and App Shortcuts with fixed phrases
(`AudioPlaybackIntent` for Get Attention), then the Vocal Shortcuts and
Action button setup text that points at them, and a check of whether the
alternative name then works; the in-app recorder; the prediction strip
from `UITextChecker`.

**Device checks:** the five new rows in `docs/HANDOFF.md`, *Checks that
need a real device*, and the *Device* entries in each row of the list.
