# Accessibility reference audit and framework updates

*2026-10-27. Pull request #63 (`codex/accessibility-reference-audit`). Agent.*

## What changed and why

Audited every API and feature row across sections 1 to 10 in
`docs/ACCESSIBILITY.md` against current Apple developer documentation
(`developer.apple.com`, `.md` plain-text symbol and update pages) and
independent accessibility references (docs/DECISIONS.md, "Accessibility API
coverage" and "Apple's current frameworks first"):

- **`docs/ACCESSIBILITY.md`**:
  - Corrected API names, availability and `main` implementation statuses:
    - **Section 2 (`hoverEffect(_:)`, `contentShape(_:_:eoFill:)`):** recorded
      that `HomeButtonStyle` applies `.contentShape(shape)`,
      `.contentShape(.hoverEffect, shape)` and `.hoverEffect(.highlight)`.
    - **Section 3 (`accessibilityInputLabels(_:)`):** recorded that input
      labels are in place on `Get Attention` (`"Help"`), `Stop`
      (`"Stop Alert"`), `Settings` (including when narrow width shows the gear
      alone), and each voice's `Hear` and `Use` buttons in `VoiceSettingsView`.
    - **Section 4 (`AVSpeechUtterance`, Personal Voice and `.spokenAudio`
      mode):** updated `AVSpeechUtterance` rate and voice picker and Personal
      Voice setup guidance (`PersonalVoiceGuidance`, `VoiceSettingsView`) to
      **in place**; noted `AVSpeechUtterance(ssmlRepresentation:)`'s failable
      initializer (`init?(ssmlRepresentation:)`); and corrected `.spokenAudio`
      mode to state that Brickson uses `.default` mode (`AudioSessionCoordinator`)
      rather than `.spokenAudio`, marking the device check as unverified.
    - **Section 5 (`accessibilityLabel`, `accessibilityValue`,
      `accessibilityHint`, traits and `AccessibilityNotification.Announcement`):**
      updated to reflect `"In Use"` values in `VoiceSettingsView`, the hint on
      Home's dimmed `Type` button, `.isSelected` on the active mode and speaking
      speed, `.isHeader` on Settings and privacy policy headings (noting that the
      safety row uses `.homeRegion(.safety)` container grouping), and
      `DraftIssue` announcements.
    - **Section 6 (`accessibilityReduceTransparency` and
      `accessibilityShowBorders`):** recorded `HomeButtonStyle`'s opaque
      `Color` fills on Home, `@backDeployed(before: iOS 26.1)` on
      `accessibilityShowBorders`, `AccessibilitySettings.showBordersEnabled`
      (iOS 26.1), and the deprecation of `UIAccessibility.buttonShapesEnabled`
      in iOS 26.1.
    - **Section 7 (`AccessibilitySettings.openSettings(for:)`):** listed the
      exact per-case minimum iOS versions (`.personalVoiceAllowAppsToRequestToUse`
      and `.captionStyles` in 18.0; `.allowAppsToAddAudioToCalls` in 18.2;
      `.dwellControl`, `.assistiveTouch` and `.assistiveTouchDevices` in 26.0).
    - **Section 8 (`UIConversationContext` and Dictation):** listed both
      `UIConversationContext` and
      `UITextInputDelegate.conversationContext(_:didChange:)` (18.4), and
      marked Dictation's whole-field replacement support in `MessageField` /
      `MessageComposer` as **in place**.
    - **Section 9 (`performAccessibilityAudit` and
      `XCUIDevice.voiceOverService`):** clarified in-place audit screens and
      updated toolchain availability for `XCUIDevice.voiceOverService` to
      `Xcode 27+` alongside iOS 27.0.
  - Added **`## New since this list was written`** covering 18 verified Apple
    additions across `Accessibility`, `SwiftUI`, `UIKit`, `AVFAudio`,
    `AppIntents` and `XCUIAutomation`, and updated `## Newer than iOS 26.0`.
- **`docs/HANDOFF.md`**: recorded the audit under *Verification*, adding the two
  follow-ups.

## Commits

- Commit on `codex/accessibility-reference-audit`: API table corrections,
  framework updates section, and documentation updates.

## Verified

- Fetched `.md` documentation pages on `developer.apple.com` for every symbol
  in `docs/ACCESSIBILITY.md` and read the framework update pages
  (`https://developer.apple.com/documentation/updates/{accessibility,swiftui,uikit,avfaudio,appintents,xcuiautomation}.md`),
  cross-checking with independent references (Appt, Deque, UseYourLoaf, Create
  with Swift and Swift with Majid).
- Ran `python3 scripts/test-docs.py` (45 tests) and `python3 scripts/test-site.py`
  (7 tests): all passed.

## Not verified

- Real-device audio session behavior with another app's spoken prompt while
  Brickson uses `.default` mode (requires a physical device check).

## Follow-ups

- Real-device check of `.default` audio session behavior when another app speaks.
- Evaluate `AccessibilitySettings.Feature.assistiveTouchDevices` as an extra
  Settings link in `Reaching the Screen` when device-checking external pointer
  and switch hardware.
- Evaluate `AVAudioSession.setPrefersNoInterruptionsFromSystemAlerts(true)` and
  `AVAudioSession.isOutputMuted` during real-device audio checks (D3).
