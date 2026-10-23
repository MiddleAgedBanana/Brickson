# Porting from the reference app

Brickson is built partly by porting code from **FamilyVoice**
(`MiddleAgedBanana/ALS-app`, commit `6a22c1a`). That repository is
**private** and **reference only**: read it, never push to it or open pull
requests on it. Without access, `docs/LESSONS.md` carries its rules.
Port one piece at a time, with its tests, into a pull request here.

Before porting any piece, read in the reference repository:
`docs/HANDOFF.md` → *Decided but NOT built* and *Known limits and issues*,
and `docs/SUCCESSOR-HANDOFF.md`. Here, read `docs/LESSONS.md`.

## How to port a file

1. Copy the type and its tests. Rename `FamilyVoice` to `Brickson`
   (`@testable import Brickson`).
2. Take out anything written for one person: their window, their phrases,
   their device, words about their care. Brickson serves many people at
   every stage of ALS and with every input method.
3. Take out every check of the device: `userInterfaceIdiom`, `UIDevice`,
   `UIScreen`, the interface orientation and fixed screen sizes. Replace
   each with the size of the window or container (AGENTS.md, *Layout on
   every device and window*).
4. Apply the lessons that touch it, especially *Timers use ContinuousClock*
   and *Closures a framework may call off the main thread*.
5. Put user-facing words through the String Catalog (`String(localized:)`,
   or `LocalizedStringKey` in views).
6. Run the tests, then record the port in the pull request's `docs/log/`
   file: what came over, from which reference file, and what changed.

## Port order

| Step | What | State |
|---|---|---|
| 1 | Speech, the Get Attention alarm and audio safety | **Ported**, behind test seams (2026-10-21). Get Attention is not on Home yet, and the status strip is still Home's stand-in. |
| 2 | Storage, editing logic and backup. Fix D28 here. | **Core written new** (editing rules, applier, backup format; D28 avoided by design: `rollback()` is never called, issue #19). Safety copies, export and import not yet. |
| 3 | Text fitting and colour tokens | **Text fitting ported** (`WordFit`, `FittedLabel`, `FittedLine`). Three measured fills only (`Palette`). |
| 4 | The layout engine, generalized to profiles | Not started. |
| 5 | Home and typing. Fix D27 here. | A stand-in Home only (docs/DECISIONS.md, "Home version 0 is a stand-in"). **Typing foundation built** (`Brickson/Typing`: `MessageComposer`, `DraftStore`, the keyboard probe); the typing state on Home not yet. |
| 6 | Editing screens. Build D24 and D25 here. | Not started. |
| 7 | Settings and family setup for every input method | Not started. |
| 8 | The snap-reach harness, as a test matrix per input method | Not started. |

## Ported so far

All from `FamilyVoice/Speech/` unless noted. "Same" means the logic is
unchanged apart from names.

| Brickson | From | Changes |
|---|---|---|
| `Speech/SpeechService.swift` | `SpeechService.swift` | Progress is stamped with `ContinuousClock`; the voice is chosen for the app's language; one-person comments removed. 2026-10-21: every dependency injected (`SpeechSynthesizing`, `SpeechVoiceCatalog`, settings, sleep, Personal Voice access through `PersonalVoiceAuthorizing`); utterances keyed by `UtteranceToken`, not `ObjectIdentifier` (L1); the voices observer removed on deinit (L4); "Audio failed" never replaced by "Stopped — Again" (L3); the watchdog also catches a synthesizer left paused; a voice row's sample plays in that voice; Normal Speed. Personal Voice: when to ask is `PersonalVoiceAskPolicy`; the status is read at launch, after an answer and on every return to the front; `requestPersonalVoiceAuthorization()` returns the answer; no Personal Voice without permission; Automatic keeps the Personal Voice it used (docs/DECISIONS.md). |
| `Speech/SpokenUtteranceTracker.swift` | `SpokenUtteranceTracker.swift` | `ContinuousClock.Instant` and `Duration` instead of `Date` and seconds. 2026-10-21: reads a finish that never reached the final word as an early ending, confirmed by an interruption within 3 seconds (M1; docs/DECISIONS.md, "A phrase the system cuts off"). |
| `Speech/VoiceSelection.swift` | `VoiceSelection.swift` | Takes a language code instead of assuming English. 2026-10-21: Automatic keeps a remembered Personal Voice while it is listed; `usableVoices` leaves out a Personal Voice without permission. |
| `Speech/SpeechRateSteps.swift` | `SpeechRateSteps.swift` | Same. |
| `Speech/AudioSafetyMonitor.swift` | `AudioSafetyMonitor.swift` | Reads the session's events from `AudioSessionEvents` instead of observing notifications itself. |
| `Speech/AudioSessionCoordinator.swift`, `Speech/AudioSessionEvents.swift` | `SpeechService.swift`, `AttentionAlertPlayer.swift` | New: one owner of the session (holds, `.default` mode, mixing fallback) and one observer of its notices, including iOS 27's (docs/DECISIONS.md, "Background audio", "Audio session notices"). |
| `Attention/AttentionAlertPlayer.swift`, `Attention/AttentionTonePlayback.swift`, `Resources/AttentionTone.wav` | `AttentionAlertPlayer.swift`, `Resources/AttentionTone.wav` | Rules moved into the pure `AttentionAlertStatus`; a repeat is absorbed only while the tone really plays; a once-a-second and on-return health check; the tone dips while speech plays; lost output, interruptions and resets come through `AudioSessionEvents` (docs/DECISIONS.md, "Get Attention"). |
| `Speech/AudioSafetyPolicy.swift` | `FamilyVoice/Models/AudioSafetyPolicy.swift` | Messages localized. |
| `App/ScreenWakePolicy.swift` | `FamilyVoice/Models/ScreenWakePolicy.swift` | Same. |
| `Library/PhraseLibrarySchema.swift` | `FamilyVoice/Models/Models.swift` | Versioned schema; `.nullify` instead of `.cascade`; stable `uuid`; no `recordingFileName`. |
| `Library/StarterLibrary.swift` | `FamilyVoice/Models/PhraseSeeder.swift` | Seeding only, in its own context with no rollback; the retired-seed repair is left behind. The launch repair beside it (`PhraseLibraryRepairer`, 2026-10-23) is Brickson's own: it only adds the starter emergency phrases. |
| `Layout/WordFit.swift`, `Layout/FittedLabel.swift`, `Layout/FittedLine.swift`, `Layout/LabelFont.swift` | `FamilyVoice/Views/WordFit.swift` (`WordFit`, `FittedText`) and `BoardLabel` | Rewritten. A label steps through Apple's text sizes (the person's, then smaller ones down to the default) instead of searching for a point size, and UIKit measures each size's width and the height of its whole-word lines, with room for the line spacing SwiftUI adds (measured on CI, checked against SwiftUI in `StarterLabelFitTests`). The words are drawn at the person's size in those lines and shrunk by `minimumScaleFactor`, so they keep following Dynamic Type, as Apple's accessibility audit requires. Same order: icon first, then the words, never below the default size. |
| `Layout/HomeShape.swift`, `Home/HomeButtonStyle.swift` | — | New: the stand-in Home's sizes from the space it is given, and Home's button style (docs/DECISIONS.md, "Home's stand-in layout"). |
| `Resources/StarterPhrases.json` | — | New, neutral starter set (docs/DECISIONS.md, "Starter phrases"), in the backup format with fixed identities. |
| `Library/LibrarySnapshot.swift`, `LibraryEdit.swift`, `LibraryRules.swift`, `LibraryImport.swift` | — (replace `PhraseEditor`'s logic) | Written new from the editing and backup memo: every edit planned as plain values, the Emergency category undeletable, import that only adds. |
| `Library/LibraryEditor.swift` | — (replaces `EditPersistence`) | Writes a plan from a context of its own in one save; never calls `rollback()`. |
| `Library/BackupCodec.swift` | — (replaces `BackupService`'s file format) | `brickson.library` version 1, with a version check the reference lacked. |
| Tests for each of the above | `FamilyVoiceTests/` | Timer tests built from one `now` plus offsets. |
| `BricksonUITests/KeyboardProbeTests.swift` | `FamilyVoiceUITests/TypingKeyboardProbe.swift` | Opens a debug-only probe screen instead of Home's typing state; reads SwiftUI's own keyboard edge as well as the keys; fails on the keyboard bar; no Display Zoom or Settings-app preparation; no Return-key check yet. |
| `Typing/MessageComposer.swift`, `Typing/DraftStore.swift` | `AppSettings.typedDraft` and the typing panel in `HomeView` | New types: the reference kept its draft in UserDefaults, which cannot report a failed save, and let Return add a line break (docs/LESSONS.md). |

## Still to port, by tier

From the reference's own successor handoff, checked against its code.

**Almost as-is (general and tested):**
- `Views/AudioSafetyStatusStrip` (step 1; Home's status area stands in for it).
- `PhraseTileAction`, `HomeChromePolicy`, `QuickControl` (step 5).
- `EditModeTimeout`/`EditModeSession` (on `ContinuousClock`),
  `EditSubmission`, `EditToolbar`, `PendingDeletion` (step 6, on the
  library core; `PhraseEditor`'s logic is replaced by `LibraryEdit`).
- `BackupImportQuestion` (step 6; the file format and the import rules
  are replaced by `BackupCodec` and `LibraryImport`).
- `SettingsIdlePolicy` (on `ContinuousClock`) (step 7).
- The `Views/FamilyVoiceTheme.swift` tokens (step 3; add Bold Text and
  Increase Contrast).
- `VoiceControlLabels` and its collision tests (step 5; compare every
  alias, not only the first, and match visible text).

**Port and generalize:**
- `BoardPlan`: the most valuable and the most tuned to one person.
  Generalize it to profiles (touch, voice, switch, head, gaze) and any
  library size. Define a position as a slot (region, row, column), so sizes
  can change by profile while every control keeps its place.
- `HomeView`, `SettingsView`, `SettingsOpening`, `TypeToSpeakView`,
  `EditSheets`, `VoicePickerView`: keep the structure; the geometry was
  tuned to one window.
- `SettingsSafetyBarLayout`, `WindowSizePolicy` (steps 4 and 7): they
  check for an iPad; take their sizes from the window instead, and give
  every scene the minimum window.
- `CaregiverSetupView`: rewrite as setup for families on their own,
  covering every input method.

**Knowledge, not code:** the invariants and design rules (now in
`AGENTS.md`), the accessibility verdicts in the reference's
`docs/ACCESSIBILITY.md`, the snap-reach harness
(`FamilyVoiceTests/SnapReach/`, `docs/snap-return/`), and the gotchas.

**Leave behind:** one person's phrases and the retired-seed repair,
`docs/fixes/` as process, the reference's `docs/archive/`, the Voice
Control-era documents, and the care-specific install guide.
