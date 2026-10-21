# Typing foundation — 2026-10-21

The pieces every way of typing needs, built before Home gets its typing
state, so they can be tested on their own. Nothing on Home changed: the
app looks and behaves as before. Its decisions are adopted defaults in
docs/DECISIONS.md (the owner left these choices to the project on
2026-10-21; reversible if the owner objects) ("Typing is a state of Home", "Typing uses Apple's
keyboard", "Writing Tools off while typing", "Third-party keyboards
refused in 1.0", "Return speaks", "The typed message").

## What changed

| Piece | What it does |
|---|---|
| `Brickson/Typing/MessageComposer.swift` | The rules for the message being typed, whichever keyboard feeds it. Return speaks and is never stored; line breaks in pasted text become spaces; speaking keeps the message; Clear can be undone once, from memory; an edit past 2,000 characters is refused whole; a word suggestion replaces the word being typed. It returns the words to speak instead of calling `SpeechService`, which has no test seam. |
| `Brickson/Typing/DraftStore.swift` | Keeps the message across launches in Application Support/Typing/draft.txt, written atomically after every change through an injectable `save`. A failed save keeps the words and reports `DraftIssue.notSaved`; an unreadable file gives an empty message and `notRestored`. Only an error's domain and code are logged. |
| `Brickson/Typing/TypingFieldTraits.swift` | `typingFieldTraits()`: Writing Tools off, sentence capitals, the standard keyboard. Every typing field uses it. |
| `Brickson/Typing/KeyboardProbeLaunch.swift`, `KeyboardProbeScreen.swift` | A debug-only screen with one typing field and a readout of where SwiftUI sees the keyboard's top, opened by the launch argument `--screen=keyboard-probe` in place of Home. A release build ignores the argument and has no probe screen. |
| `Brickson/App/BricksonApp.swift` | One line: `.replacedByKeyboardProbeIfRequested()` after `HomeView()`. |
| `BricksonUITests/KeyboardProbeTests.swift` | The opt-in probe, ported from the reference app's `TypingKeyboardProbe`: portrait and landscape at the default and largest text size, one `KEYBOARD-PROBE {json}` line each, plus the JSON, a screenshot and the accessibility tree attached to the result. Skipped unless `TEST_RUNNER_BRICKSON_KEYBOARD_PROBE=1`. iPhone landscape is skipped because the iPhone is portrait only. Fails, after printing, when the simulator shows the keyboard bar instead of the full keyboard. |
| `BricksonTests/MessageComposerTests.swift`, `DraftStoreTests.swift`, `KeyboardProbeLaunchTests.swift` | 44, 24 and 3 tests. Each names the change that would make it fail. Every save path has a test that makes it fail (invariant 5), including a real write into a blocked folder. |

## How Home will use it

Home's typing state is built with the layout engine (docs/PORTING.md,
step 5), by the layout work, not here. The seams it calls:

- `DraftStore(directory:)` once per app, kept in the environment. The app
  uses Application Support/Typing (`DraftFile.applicationSupport`); with
  the test seams' launch options, the test-only files folder plus
  `Typing`.
- The field shows `draftStore.text`. Each change goes through
  `perform(.propose(newText))`; when the outcome's `fieldNeedsUpdate` is
  true, the field is given `draftStore.text` again.
- Speak calls `perform(.speak)`, Clear `perform(.clear)`, and the restore
  control `perform(.restoreCleared)`. Whenever an outcome has
  `textToSpeak`, Home passes it to `SpeechService.speak(_:)`, exactly as a
  phrase tile does. `canSpeak`, `canClear` and `canRestore` (on
  `composer`) say when those controls are on.
- `draftStore.issue` goes in the warning space as passive text
  (`compactMessage`, with `message` for VoiceOver). Its height must be
  reserved like the audio warnings', so it moves nothing.
- `retrySave()` when the app goes to the background.

## Keyboard measurements

Simulator numbers. A real device can differ, and the keyboard changes
with the languages and keyboards a person has added.

GitHub CI, 2026-10-21: iPad Pro 13-inch (M5) simulator, iOS 26.5, Full
Screen, default Display Zoom, the full software keyboard (53 keys, not
the bar), US English. The keyboard's top is where SwiftUI's layout stops
(the readout), so it includes the prediction bar above the keys.

| Orientation | Window (points) | Text size | Keyboard top | Keyboard height |
|---|---|---|---|---|
| Portrait | 1032 × 1376 | Default (L) | 973 | 403 |
| Portrait | 1032 × 1376 | Largest (AX5) | 973 | 403 |
| Landscape | 1376 × 1032 | Default (L) | 534 | 498 |
| Landscape | 1376 × 1032 | Largest (AX5) | 534 | 498 |

Text size does not change the keyboard. These match the reference app's
iOS 27.0 numbers for the same iPad exactly. In landscape the keyboard
takes nearly half the window: everything the band holds must fit in the
top 534 points.

Still to measure: every iPhone (the reference's iPhone 17 Pro, iOS 27.0:
top 546 of 874, height 328), the 11-inch iPad and iPad mini, Display Zoom
(the reference's zoomed 13-inch landscape: top 276 of 774), windowed apps,
and iOS 27. The probe runs on any of them once the simulator shows the
full keyboard.

## Verified, and how

- **On Linux** (Swift 6.3.3, Swift 6 language mode, main-actor default
  isolation as in project.yml): `MessageComposer`, `DraftStore` and their
  68 tests compile and pass. The file tests ran against a real file
  system. Not checked there: anything that needs SwiftUI, UIKit or
  XCTest.
- **On GitHub CI**: see the pull request's checks. CI is the first build
  of the SwiftUI and UI-test code.
- Not run on a Mac or a device. Nothing here has been seen by a person.

## Not done, and why

- **The typing state on Home**: the layout work builds it on the layout
  engine (docs/DECISIONS.md, "Typing is a state of Home").
- **Refusing third-party keyboards**: decided, built with the typing state
  (an app delegate returning false for `.keyboard`).
- **A UI test that Return speaks**, which docs/LESSONS.md asks for: it
  needs the typing state. The rule itself is unit-tested.
- **The keyboard table** that the layout engine reads, and an always-on
  test comparing it with the live keyboard: they arrive with the layout
  engine. This probe produces the numbers.
- **Inline predictions** cannot be turned off from SwiftUI (docs/DECISIONS.md,
  "Typing uses Apple's keyboard").
- **iPhone numbers from CI**: CI's UI tests run on the 13-inch iPad only.
- `KeyboardProbeLaunch` is a stopgap: when the app's launch options can
  name a start screen, the probe screen moves there and it goes.

## Checks that need a real device

From the typing options study (2026-10-16). HANDOFF's device table points
here.

| # | Check | What it decides |
|---|---|---|
| 1 | Eye Tracking typing on Apple's keyboard, on a 13-inch and an 11-inch iPad, portrait and landscape, with the keyboard dwell timer and Snap to Item, and Zoom on Keyboard Keys on and off. Words a minute on a fixed set of sentences; wrong keys, accidental shift, 123, emoji, dictation, hide and paste; misses on the prediction bar. | Whether Apple's keyboard is enough for gaze, or a Brickson keyboard is worth building |
| 2 | A throwaway build with ten Brickson keys marked `.isKeyboardKey`: do Eye Tracking's keyboard dwell timer and Zoom on Keyboard Keys apply to them? Do Switch Control's Always Tap Keyboard Keys and Scan Same Key After Tap? | How fast a Brickson keyboard would really be for gaze and switch users |
| 3 | A Bluetooth switch interface that pairs as a keyboard, and its keyboard-toggle mode if it has one: does Apple's software keyboard still appear, and what does Switch Control offer? | Whether Apple's keyboard works at all for those switch users |
| 4 | Switch presses per character for a fixed sentence, on Apple's keyboard (Group Items on) and on a grouped prototype layout | A Brickson keyboard for switch users |
| 5 | At the keyboard's edge: where Snap to Item lands for a look just above the prediction bar; whether the pointer stays or follows the look after a key; whether a lingering look re-fires a key, a prediction or Return | The order of the band, the word row's empty-after-insert rule, and Return under dwell |
| 6 | Keyboard tops on every device and orientation, plus the floating or undocked iPad keyboard over the band, the hardware-keyboard bar, windowed apps, and FaceTime beside Brickson | The keyboard table and the smallest window |
| 7 | A typed message spoken into a phone call and a FaceTime call through Add Audio in Calls, in Personal Voice and a system voice: what the caller hears, whether the call notification arrives, and what happens when a call starts mid-sentence | The call status line and the speech session |
| 8 | VoiceOver and Voice Control with the field: dictating into it, "Tap Speak", and with a Brickson keyboard, Voice Control's numbers over 30 or more keys | Whether a Brickson keyboard must hide itself for voice users |

Checks 3, the Apple-keyboard halves of 1 and 4, and the floating-keyboard
part of 6 need no Brickson build: they can be done now in Notes or Live
Speech.
