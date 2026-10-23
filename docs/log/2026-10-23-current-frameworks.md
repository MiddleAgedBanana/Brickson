# Apple's current frameworks first, and the owner's vision

*2026-10-23. Pull request #34 (`claude/project-thread-wmfo5z`). Claude
Code, cloud thread "Current frameworks rule and vision", from `main` at
`313de2c`.*

## What changed and why

The owner asked on 2026-10-22 for two things, recorded here together:

1. **Apple's current frameworks first.** Build on what Apple is investing
   in (SwiftUI, SwiftData, Swift Testing, App Intents), and move off
   legacy frameworks now, while it is cheap. AGENTS.md has the rule in a
   new section, *Apple's current frameworks first*, and a review rule
   under *Data, privacy and platform*; `.github/copilot-instructions.md`
   and the review skill point to it. docs/DECISIONS.md has a new entry of
   the same title that lists every legacy use kept, with its reason and
   when to look again, the moves made, and the moves still planned with
   an owner each. *Tests* now says a test that drives no app uses Swift
   Testing.
2. **The owner's vision.** Brickson becomes the one app a person with
   ALS keeps open all day, covering what they and their caregivers need
   and reaching the rest through Apple's doors. docs/ROADMAP.md has it as
   *Where this goes*, after *The goal*: direction, not a licence to skip
   steps, with the parts that meet a rule today (a web view is network
   code; on-device AI must never write a person's words, and Foundation
   Models is under *Never*) left for the owner, and five frameworks named
   for later, each quoted from Apple's page. AGENTS.md points to it from
   *What this is and what's at stake*. R2's Siri and Shortcuts now say
   App Intents and App Shortcuts, with a SiriKit Intents extension only
   if R2's device check shows the app's other names need one.

The audit read every Swift file in the three targets and `project.yml`
against Apple's documentation (two helper agents: one read Apple's pages,
one swept the code; their findings were checked here before use). There
was no Core Data, Combine, `ObservableObject` or deprecated API, and no
SiriKit code: the one SiriKit piece is the `INAlternativeAppNames`
Info.plist key, kept below, which Apple says works only with an Intents
app extension Brickson does not have yet. The unit tests used only Swift
Testing. A third agent reviewed the
commits before the push; its findings (settings the kept captures cannot
catch, an unpinned `Palette.screen`, an import rule that promised more
than it kept, a too-firm "never" about SiriKit, the README's wording)
were fixed. Code that changed:

- **The rendered-word check** in `LaunchTests` moved from
  `VNRecognizeTextRequest` to Vision's Swift API, `RecognizeTextRequest`,
  with the same settings (fast, English, no language correction,
  whole-word match), in a helper, `RenderedWords`, compiled into the UI
  and unit tests. The test is now `async`, and waits for Again with
  `XCTWaiter.fulfillment(of:timeout:enforceOrder:)`, since XCTest's
  blocking wait cannot be called from an async test.
- **`RenderedWordsTests`**, new: Apple does not say the Swift request
  reads exactly as the old one did, so the unit tests run `RenderedWords`
  on eight kept captures, cropped from the iPhone AX5 screenshots in
  `docs/log/ui-test-evidence/` (before and after PR #13's fix): each
  whole label must be read and each clipped one rejected. Until now
  nothing on CI showed the check could fail. Language correction or word
  hints could not rebuild these words from their pieces, so a further
  test pins the request's settings (fast, English only, no automatic
  language, no correction, no supplied words); automatic language
  detection is now off explicitly, as the old request had it by
  default.
- **`AccessibilityAuditRunnerTests`** moved from XCTest in the UI tests
  to Swift Testing in the unit tests; `project.yml` compiles
  `AccessibilityAuditRunner.swift` and `RenderedWords.swift` into the unit
  tests too. Same six tests and assertions; the loop over other errors
  now names the error in each failure.
- **`StandInPersonalVoice`** answers from `Task.detached` instead of
  `DispatchQueue.global()`.
- **Settings' inline titles** use `toolbarTitleDisplayMode(.inline)`
  instead of `navigationBarTitleDisplayMode(.inline)`; Apple documents
  the same inline title on iOS.
- **`Palette.screen`** replaces three copies of
  `Color(uiColor: .systemBackground)` in Settings and setup: the same
  colour, now in one place beside the measured fills, and a new
  `PaletteTests` case pins it to the system background the other cases
  measure: its UIKit colour in all four appearances, and the SwiftUI
  colour itself, resolved by SwiftUI, in light and dark. (CodeRabbit
  suggested turning `screen` back into a `UIColor` instead; reports say
  that conversion keeps one appearance only, so the dark checks would
  have compared the wrong colour.)
- **Imports say what a file uses:** `import UIKit` removed where unused
  (`SettingsTests`, `StarterLabelFitTests`), added where UIKit was used
  without it (`HomeLayoutTests`, `Palette`), and `LaunchTests` imports
  UIKit (a screenshot's `UIImage`) instead of Vision.

Kept, each with its row in DECISIONS: XCTest for UI automation, UIKit
types in UI tests, `isIdleTimerDisabled`, `LabelFont`'s UIKit measuring,
UIKit's system background, the Safari sheet, the ordered main-queue hop
for speech reports, block-based notification observers, KVO of the
volume, UIKit in `PaletteTests`, `UIImage(systemName:)` and
`UIHostingController` in tests, and `INAlternativeAppNames`.

## Commits

- `15e36be` Write the current-frameworks rule and the owner's vision into
  the docs
- `0bbca2a` Move test code to Vision's Swift API and Swift Testing
- `eaaa54f` Use current APIs for the stand-in's answer and Settings' titles
- `d72212b` Record the frameworks audit: exceptions, planned moves and the
  log
- `5c8b92b` Pin the word check's settings and the screen colour; tighten
  the docs
- Later commits on the pull request: this record's number and fixes from
  review.

## Verified

- Run in a cloud session, which cannot build or run the app: **the iOS
  code is untested until GitHub CI passes.**
- `AccessibilityAuditRunnerTests` and the runner compiled and passed (6
  of 6) on Linux with Swift 6.4.1, Swift 6 language mode, main-actor
  default isolation and approachable concurrency, as in `project.yml`.
  Each of three changes to a harness copy of the runner failed the tests
  that name it: no retry (three tests failed), retrying any error in the
  audit's domain (`otherErrorsFailWithoutRetry`), and no settle before the
  retry (`aRetrySettlesTheScreenAgain`).
- Apple's pages, read 2026-10-23 for the Xcode then current (27.1, iOS
  27.1 SDK, Swift 6.4): `RecognizeTextRequest` and its `perform(on:)`
  forms (iOS 18), `XCTWaiter.fulfillment`, `toolbarTitleDisplayMode`
  (iOS 17), `colorSchemeContrast` (get-only), `systemAction(_:prefersInApp:)`
  (iOS 26, undocumented presentation), the typed notification messages
  (iOS 26; AVFAudio's only for iOS 27's life-cycle notices), `Font.Resolved`
  (iOS 26), and the five frameworks in ROADMAP's list.
- The fixture crops were checked by eye: each whole crop shows its whole
  word, each clipped crop only pieces.

## Not verified

- Nothing here ran on iOS. Not yet seen on CI: that `RenderedWords`
  compiles in both targets, that Vision's Swift request reads the four
  whole crops and rejects the four clipped ones, that the async
  `testLargestTextKeepsQuickControlWordsVisible` still passes on iPad and
  iPhone, and that XcodeGen puts the two shared files and the PNGs where
  the tests expect them.
- The new pins (`theRequestReadsOnlyWhatIsDrawn`,
  `theFamilyScreensUseTheMeasuredScreen`) have not run; each fails if
  its setting or colour changes, by reading.
- That `toolbarTitleDisplayMode(.inline)` draws Settings' titles exactly
  as before, beyond Apple's description; Settings' UI tests find screens
  by their navigation bar titles.
- The crops are from full-screen captures, not the element screenshots
  the UI test takes; the clipped ones are from before PR #13's fix, on
  iOS 27.0.

## Follow-ups

- The planned moves in docs/DECISIONS.md, "Apple's current frameworks
  first", each with its owner: Personal Voice permission through the
  async API; `LabelFont` on `Font.Resolved`; XCUIAutomation's typed waits
  in UI tests; iOS 27's typed audio-session messages.
- `XCUIVoiceOverService` (XCTest, new in Xcode 27) can step real
  VoiceOver in UI tests on iOS 27 simulators. `HomeAccessibilityOrderTests`
  checks the accessibility tree's order, not VoiceOver's; a test behind
  `#available(iOS 27, *)` would add that. *(accessibility implementation,
  next pass)*
- `VoiceList` sorts names with `localizedStandardCompare` and breaks ties
  by identifier only when the names differ by bytes: two voices whose
  names compare equal but are spelled differently (case or width) fall to
  the system's order, which can change (invariant 8). A sort on
  `KeyPathComparator`s ending in the identifier fixes it. *(the next
  Settings thread)*
- `SpeechRateSteps` still builds English sentences that no screen shows
  and the String Catalog does not hold; delete them or localize them.
  *(the next Settings thread)*
- `project.yml`'s comment on the UI tests' `nonisolated` default says they
  "run off the main actor"; XCUIAutomation is main-actor, and the real
  reason is probably XCTestCase's overrides. Check on a Mac and reword.
  *(Test seams and CI evidence)*
- Before a vision item starts, its work file checks it against the
  invariants; the web, on-device AI, the camera, calls and messages each
  wait on the owner as ROADMAP's *Where this goes* says.
