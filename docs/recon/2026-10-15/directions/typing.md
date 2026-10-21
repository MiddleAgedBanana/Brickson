# Typing a new message: options memo

> **Research snapshot, 2026-10-15/16, committed 2026-10-21.** Written on the owner's Mac against `main` at `9362eca`; local paths and personal details were removed before it was committed. It is research, not instructions: its recommendations are proposals until `docs/DECISIONS.md` records the owner's choice, and where it disagrees with `AGENTS.md`, `docs/DECISIONS.md` or `docs/ROADMAP.md`, those win. Facts about CI, Xcode and simulator versions describe that date.

**What this is based on**
- Planning only: nothing was built, run or changed in the repository.
- Sources:
  - Brickson at `9362eca`.
  - The reference app (FamilyVoice, which is private), read at `6a22c1a` in `the owner's local clone of the reference app`.
  - Apple's documentation, read through Context7.
  - The web sources listed at the end.
- "Measured" means the reference app's simulator probes: iPad Pro 13-inch and iPhone 17 Pro simulators, iOS 27.0, full software keyboard, 2026-10-08.
- Nothing here was measured on a real device.
- Brickson's CI runs iOS 26.5, and the keyboard can change between iOS versions.

**For the coordinator:** the band rule in section 1 rules out the reference's right-hand column of quick controls, because the keyboard covers its lower half. This has to reach the layout-blueprint work before the layout engine is designed.

## The short answer

- **Typing lives on Home, not on its own screen.**
  - When typing opens, a keyboard takes the place of the categories and phrase tiles.
  - A band at the top that the keyboard never reaches holds the message, Again, Emergency, Get Attention, Yes, No, Speak, the way back and the audio-warning space.
  - Type can stay in the phrase area. It does nothing while typing, so the keyboard covering it is harmless.
- **Apple's keyboard decides how tall that band can be, in every profile.**
  - Touch users need Apple's keyboard.
  - Invariant 8 keeps every control's relative place the same across profiles.
  - So the room Apple's keyboard leaves on the worst screen is the room every profile gets. This belongs in the layout engine's design (port step 4), before anything is built.
  - One consequence already: Home's audio warnings sit at the bottom today, where the keyboard would hide them (invariant 4).
- **Two sums separate the options (section 2):**
  - **Room above Apple's keyboard.**
    - The case is a 13-inch iPad with Display Zoom set to Larger Text, held in landscape.
    - Apple's keyboard leaves room for only one row of 88pt controls under the message, and only at the default text size.
    - That row touches the keyboard's edge, so its speaking and alarming controls need a named exception at every text size.
    - At the largest text size only 53.5pt is left, and even that one row doesn't fit.
    - Option C's extra word row doesn't fit on that screen at any text size.
  - **Key width.**
    - An in-app keyboard can't fit ten 44pt keys across any iPhone. A phone 375–402pt wide gives keys of 37.5–40pt even with no gaps.
    - So Option B is an iPad option. On a phone it would need a different layout, and the person would have to learn it again.
- **Recommendation: Option C, in stages, with B decided after device tests.**
  - Apple's keyboard everywhere: cheap, standard, and Apple keeps improving it. iOS 26 added a keyboard dwell timer for Eye Tracking and fewer steps for switch typing.
  - A fixed row of Brickson word buttons wherever the band has room.
  - A large-key Brickson keyboard for pointer and gaze users on big iPads, only if device tests show Apple's keyboard is too slow or unsafe there.
- **First step:** three pieces that every option needs.
  - A message composer that doesn't care which keyboard feeds it.
  - A draft store whose save can be made to fail in a test.
  - A UI test that measures the keyboard.

## 1. What every option has to do anyway

**Typing is a state of Home.**
- A sheet would cover Emergency (invariant 2).
- A separate screen would have to repeat Emergency, Get Attention, Yes and No at exactly the same places, because invariant 10 keeps them one activation away from every Home state, typing included. That would be Home again, with extra risk.
- So Type swaps the phrase area (categories and tiles) for the keyboard area, and everything above it stays put.
- Type stays where it is and does nothing while typing. The way back to phrases is a different control in a different place, as in the reference.
- Emergency while typing leaves typing, keeps the draft and shows the emergency phrases. Nothing that speaks may then be nearest the spot where Emergency was activated.
- Home v0 already has this shape (message, quick controls, categories, tiles). The exception is its warning area, which is at the bottom.

**The band rule.**
- *What goes in it.*
  - From the moment typing opens, these sit above the tallest keyboard the device can show in that orientation: everything invariants 2 and 10 name, plus Speak, the way out, the message and the warning space.
  - Type doesn't have to. It does nothing while typing, so it can stay in the phrase area where the keyboard covers it, as in the reference.
- *Nothing moves.* Nothing moves when the keyboard appears or hides (invariant 11). The keyboard overlays the phrase area using `.ignoresSafeArea(.keyboard)`, as in the reference.
- *A measured table.*
  - An app can't read the keyboard's height before the keyboard appears.
  - The reference checked Apple's docs: `UIKeyboardLayoutGuide` and the keyboard notifications describe only a keyboard that is already on screen.
  - So the layout engine needs a measured table of keyboard tops for each device, orientation and Display Zoom setting, kept as test data.
- *A check that can fail.*
  - A UI test fails when the live keyboard is taller than the table, so a new iOS can't silently cover Emergency.
  - CI runs only the 13-inch iPad, so the iPhone table is checked locally before each release.
- *Under the keyboard.* While typing, the area under the keyboard stays empty, never phrase tiles. Hiding the keyboard (the iPad's hide-keyboard key) then reveals nothing that speaks.

**Which controls touch the keyboard's edge.**
- Reading the predictions is pointing. So the band row nearest the keyboard holds only controls that are harmless if a look slips upward:
  - Type, if it sits there (it does nothing while typing);
  - or a row of word buttons.
- Where the band holds only one row, this can't be met (section 2).
- Speak, Yes, No, Get Attention, Emergency and Clear sit away from the keys and from the message the person is reading.
- The snap-reach harness (port step 8) scores this.
  - It can't see Apple's keys, because they live in another window; the reference found this.
  - So it treats the whole keyboard area as keys that could be activated anywhere.

**The message area is the draft.**
- While typing, the typed text is the message the listener reads, shown in the message row's reserved space.
- It stays at full size and scrolls inside that space when it is long (the existing "Messages never shrink").
- Again replays what was last spoken.

**Speak never changes the draft** (invariant 3: speaking never changes data).
- The draft stays after speaking, so it can be repeated or extended, as in the reference.
- If the same text is activated again while it is still playing, `SpokenUtteranceTracker` already absorbs the repeat.

**Return speaks, as an extra path.**
- *Which kind of field:*
  - In the reference, a multi-line `TextField(axis: .vertical)` turned Return into a newline. Nothing was spoken, and the newline was later spoken as a pause. That was observed in the simulator; Apple's docs say only that `onSubmit` fires on Return.
  - A single-line field does fire `onSubmit`, but it scrolls long messages sideways, out of the listener's view.
  - The safer choice is a multi-line field whose composer turns a typed newline into "speak" and never stores the newline. Pin this with a UI test on the full software keyboard (LESSONS, "The return key must speak").
- *Under dwell:*
  - AGENTS asks for Return-speaks under dwell. It also asks that no speaking control sit next to what the person points at.
  - With Apple's keyboard the two rules collide, because its Return key sits among the letter keys.
  - A slip then speaks half a sentence; on a call, it speaks it to the caller.
  - For dwell profiles this needs either a named, measured exception to invariant 10 or a change to the rule. The owner decides, after device check 5.

**Clearing.**
- Throwing away a draft typed by eye over ten minutes is destructive. The reference's harness counted it as a hazard of its own, `discardsDraft`.
- Two safe patterns, both handled by where things are placed, never by timers:
  - *Ask first.* Keep takes Clear's place and the confirmation appears elsewhere. This is the existing delete pattern (invariant 3), and it costs two activations every time.
  - *Recoverable.* Clear moves the draft into "Typed recently" (section 4), so one activation loses nothing.
- Never put an Undo button in Clear's place: a control turning into its opposite.
- Never put Clear beside the message text or beside Speak.
- Clear is disabled when the draft is empty, so a repeated look does nothing.

**Keeping the draft.** The privacy policy already promises that the typed message survives the app closing and stays until it is cleared.
- Save on every change; the draft is tiny.
- Restore it at launch without speaking and without opening typing, as in the reference.
- Invariant 5 needs a test that makes the save fail:
  - UserDefaults, which the reference used (`AppSettings.typedDraft`), can't report a failed write.
  - A small file in Application Support can. It is written atomically through an injectable `save`, like `PhraseLibrarySeeder.seedIfEmpty(save:)`.
  - When the save fails, passive text appears in the warning space ("This message isn't being saved") and the text stays in memory.
  - The warning space reserves height for this line, as it does for the audio warnings, so its appearance moves nothing.
- Never log the draft or put it in a crash message (AGENTS, *The privacy policy is a promise*).
- Clear empties the stored copy too.

**Words in the person's mouth.**
- *Writing Tools:* turn it off on the field with `writingToolsBehavior(.disabled)` (SwiftUI, iOS 18 and later). Otherwise a stray look could let Apple Intelligence rewrite the message. That would break invariant 7 and the hard stop on AI-generated replies.
- *Language models:* no on-device language model (Foundation Models) for predicting words or finishing sentences, for the same reason.
- *Inline predictions:* this is the grey text that Space accepts (iOS 17 and later). It can add a word the person never chose.
  - An app can turn it off only through UIKit (`inlinePredictionType = .no`). I found no SwiftUI modifier, so controlling it means wrapping a UIKit text view.
  - Otherwise it is a setup tip: Settings › General › Keyboard › Show Predictions Inline.
- *Autocorrect:* it helps imprecise gaze typing, but it can change a word, such as a name, as Space is typed. This is a real trade-off (question 3).

**Calls.** The speech-engine side belongs to the Apple platform audit.
- How it works:
  - The person turns on iOS's Add Audio in Calls.
  - Brickson asks permission with `AVAudioApplication.requestMicrophoneInjectionPermission()` and sets `setPreferredMicrophoneInjectionMode(.spokenAudio)`.
  - Its speech then goes into phone and FaceTime calls along with the microphone.
- Typed messages are most of what someone says on a call, so the message area needs the following.
- **Call status as passive text, in reserved space:** either "the caller hears Brickson" or "the caller can't hear Brickson".
  - `microphoneInjectionCapabilitiesChangeNotification`, read with `AVAudioSessionMicrophoneInjectionIsAvailableKey`, tells Brickson when a call starts or ends.
  - Its observer uses `queue: .main` with `MainActor.assumeIsolated`, and gets a test in `OffMainThreadCallbackTests`.
  - The fix for "can't hear" belongs in Settings, through `AccessibilitySettings.openSettings(for: .allowAppsToAddAudioToCalls)`, not on the person's path.
- **A holding phrase one activation away while typing,** such as "One moment, I'm typing."
  - At 5–8 words a minute, a caller waits one to two minutes for a ten-word reply.
  - It is a phrase, so it speaks at once.
- **Again matters more than the listener display.** Showing the listener means nothing on a call.
- **The narrower window.** On an iPad, typing has to work in the narrower window left when FaceTime sits beside Brickson.
- **The usage string.** Info.plist needs `NSMicrophoneInjectionUsageDescription`. Apple's docs say the system quits an app that asks for this permission without it.
- **The privacy policy.** Its speech section, and its sentence about when the microphone is used, need updating.
- **The speech engine's call fallback.** This interacts with `SpeechService.ensurePlaybackAudioSession`, which falls back to `.mixWithOthers` during a call.
- **An idea to test with users.** An opt-in "speak each sentence when its full stop is typed" would keep a call moving.

## 2. The two sums

### Room above Apple's keyboard (decides A and C)

Measured keyboard tops. "Top" means the top of the prediction and shortcut bar, which is part of the keyboard. The keyboard's height does not change with text size.

| Window | Landscape | Portrait |
|---|---|---|
| 13-inch, Display Zoom Larger Text (1032×774pt) | top at y 276 of 774 (keyboard 498pt) | y 629 of 1032 (403pt) |
| 13-inch, default zoom (1376×1032pt) | y 534 of 1032 | y 973 of 1376 |
| iPhone 17 Pro (402×874pt) | the phone is portrait-only | y 546 of 874 |
| 11-inch, iPad mini, other iPhones | not measured | not measured |

On the zoomed 13-inch in landscape, the reference's own layout left 92pt between its message row and the keyboard at the default text size, and 53.5pt at AX5, the largest text size.
- **Width is fine.** One row of Emergency, Get Attention, Yes, No and Speak fits, with the way out and Again in the message row: (1032 − 40 margins − 4 × 12 gaps) ÷ 5 ≈ 189pt each.
- **Height decides it.**
  - The reference's gaze floor for quick controls is 88pt. That fits in 92pt at the default text size, with 4pt to spare and no gap at the keyboard's edge.
  - So that one row sits on the keyboard's edge, a few points above the prediction bar.
  - Section 1's edge rule allows only harmless controls there, and this row holds Speak, Yes, No, Get Attention and Emergency.
  - So on this window A needs a named exception at every text size, not only at large ones.
  - At AX5, the 53.5pt left doesn't hold an 88pt row.
- **What doesn't fit on this window:**
  - Clear has no legal place: not beside the message, not beside Speak, not on the edge. It needs an exception (for example beside the message, using the recoverable pattern), or it is left out there.
  - The holding phrase and the listener display are left out there.
- **Option C's word row** needs another 72–88pt plus a gap out of that same 92pt. On that screen it fits at no text size unless the message row shrinks.
- **What A would need there at large text sizes.** These are my estimates; the layout engine must measure them.
  - A one-line message row in that configuration (positions may depend on text size).
  - Labels shrunk toward their default size, never below it.
  - Controls of about 70pt, below the 88pt goal. That is a named exception with numbers. The alternative is a keyboard Brickson controls (B).
- **On the phone at AX5,** the keyboard covered the reference's Speak and Clear completely, and 9.5pt of Emergency and Get Attention. So the phone at large text sizes has the same problem.
- **Portrait iPads and default-zoom landscape** leave 534–973pt above the keyboard. A and C fit easily there.

### Key width for a Brickson keyboard (decides B)

- The formula, for ten keys across (QWERTY's top row): key width = (window width − 2 margins − 9 gaps) ÷ 10.
- Physical sizes use 264 ppi for the 11- and 13-inch iPads, 326 ppi for the mini and 460 ppi for the phone.
- One zoomed-window point is 1.33 default points.

| Screen (points wide) | Key width | Physical |
|---|---|---|
| iPhone SE or mini (375), touch spacing (8pt margins, 6pt gaps) | 30.5pt (37.5pt with no gaps at all) | 5.1mm |
| iPhone 17 Pro (402), touch spacing | 33.2pt (40.2pt with no gaps) | 5.5mm |
| iPhone Pro Max (440), touch spacing | 37pt (44pt only with no gaps) | 6.1mm |
| iPad mini portrait (744), gaze spacing (16pt margins, 12pt gaps) | 60.4pt | 9.4mm |
| 11-inch iPad portrait (820), gaze spacing | 68pt | 13.1mm |
| 13-inch, zoomed portrait (774), gaze spacing | 63.4pt (84.5 default pt) | 16.3mm |
| 13-inch portrait (1032), gaze spacing | 89.2pt | 17.2mm |
| 13-inch, zoomed landscape (1032), gaze spacing | 89.2pt (118.9 default pt) | 22.9mm |
| 13-inch landscape (1376), gaze spacing | 123.6pt | 23.8mm |

**For comparison, Apple's keyboard.** Same probe. These are accessibility frames, which tile edge to edge, so the visible keys are smaller.
- 13-inch letter keys: 94.5×88pt in landscape, 71×68pt in portrait.
- Zoomed 13-inch: 71×88pt in landscape, 53×68pt in portrait.
- The prediction bar is 49pt tall. The undo, redo and paste buttons on it are 22×49pt.
- On the iPhone 17 Pro the visible keys are about 33×42pt, estimated from a screenshot.

**The reference's gaze floors** on the 13-inch were 110pt for phrase tiles, 88pt for quick controls and 72pt for categories. 72pt there is about 13.9mm. A mini's point is about 19% smaller, so the mini needs more points for the same physical size.

What the sums mean:
- **Phone.**
  - No Brickson QWERTY with any space between its keys reaches 44pt. Even the 440pt Pro Max gets there only with no gaps.
  - A phone keyboard big enough for gaze would need about five columns, and that doesn't fit vertically under the band.
  - So B is not a phone option. Gaze typing on a phone is poor with any keyboard.
  - The phone serves touch, hardware keyboards, Voice Control and switches. Switch scanning doesn't need big keys.
- **Small iPads in portrait.** B's QWERTY keys (60–68pt) are barely larger than Apple's. Fewer columns would mean a different layout.
- **13-inch iPad.**
  - B gives keys about 20–30% wider than Apple's.
  - More important, Brickson can trade keyboard height for band height, for example with shorter rows at AX5.
  - Its prediction row can be 88pt tall instead of 49pt.
  - It can drop the keys that cause trouble under a resting look.
- **The tension for the owner.**
  - "One app the person never relearns" favours the same QWERTY everywhere.
  - Research favours other layouts for scanning (Option B, section 3).
  - Different layouts on phone and iPad are acceptable, because they are different devices.
  - A layout change when the person moves to a new stage is a moment of relearning (question 2).

### Speed, for scale

- **Dwell-time gaze typing.**
  - It usually runs 5–10 words a minute [R1, R2].
  - The dwell time caps it: a 1-second dwell allows at most about 12 words a minute [R2].
  - Novices given an adjustable dwell went from about 7 to 20 words a minute over ten sessions as their dwell shortened [R1]. That is why iOS 26's keyboard-only dwell timer matters.
- **Experienced gaze typists with ALS.**
  - Two such typists averaged about 4–8 words a minute on Tobii's keyboard with its prediction [R3].
  - Prediction saved them far fewer keystrokes than simulation predicts: 0.23, and below zero for one of them, against 0.48 in simulation [R3].
  - Reading the suggestion list costs time of its own [R4].
- **Switch scanning.**
  - About 5 words a minute for able-bodied learners [R5].
  - Frequency-ordered layouts are reported to be about 30–40% more efficient for scanning than QWERTY [R7, a vendor blog].
- **Speech, for comparison.** Speech runs up to about 190 words a minute [R3]. That is why phrases, quick words and the holding phrase matter more than any keyboard.

## 3. The options

Cost estimates are rough agent time. They leave out the owner's device sessions and review rounds, so they are not calendar time.

### What each person gets

| Stage | A: Apple's keyboard only | B: Brickson keyboard for pointer, gaze and switch; Apple's for touch | C: A plus a Brickson word row |
|---|---|---|---|
| Touch, full hands | The keyboard they know: QuickType prediction, autocorrect, swipe typing (QuickPath), Text Replacement shortcuts and dictation. The best of all three. | Same as A | Same as A, plus a word row they can ignore |
| Touch, weak hands | Touch Accommodations (Hold Duration, Ignore Repeat) help. iPhone keys of about 33×42pt are hard; iPad keys are bigger. | Same as A, or the big keyboard on a large iPad if offered | A, plus bigger word buttons |
| Head tracking or AssistiveTouch dwell | Keys of 68–95pt on a 13-inch iPad, a 49pt prediction bar and 22pt undo, redo and paste. Shift, 123, emoji, dictate and hide-keyboard change what's under the pointer. iOS 26's keyboard dwell timer may allow faster keys than Brickson's own buttons (exact behaviour unverified). | On large iPads: keys of 89–124pt, an 88pt prediction row, no keys that switch modes. On a phone, Apple's keyboard. May lose the keyboard dwell timer (check 2). | A, plus 88pt word buttons where the band has room |
| Eye Tracking with dwell and Snap to Item | As above, plus Zoom on Keyboard Keys: one look zooms in, a second types. Keys are below Brickson's gaze floors in portrait, and far below on an iPhone. | As above. Snap to Item lands only on Brickson's large keys. | A, plus word buttons, absent on the tightest screens |
| Switch Control scanning | Apple's keyboard scanning: Always Tap Keyboard Keys, Scan Same Key After Tap, Extended Predictions, and iOS 26's fewer steps. About 53 keys to scan on a 13-inch. A switch interface that pairs as a Bluetooth keyboard may stop the software keyboard appearing (check 3). | Brickson's row-then-key grouping, fewer keys and predictions first. But each key may cost an extra press if iOS doesn't treat Brickson's keys as keys (check 2). | A, plus quick words, each one more thing to scan |
| Hardware keyboard | Excellent. Return speaks. iPad shows a small shortcuts bar instead of the keyboard. | Same as A, with the real UIKit field | Same as A |
| Brain-computer interface through Switch Control | As switch scanning, at a few selections a minute. Phrases and quick words matter most. | As switch scanning | As switch scanning |
| Voice Control | Dictation into the field, and "Tap Speak" | Same as A; Brickson's keys hidden in voice profiles | Same as A |

### Option A: Apple's keyboard only

A text field, Speak and Return. Everything else comes from Apple: QuickType, autocorrect, Text Replacement, dictation, Switch Control's keyboard scanning and Eye Tracking's keyboard features.

**Invariants:**
- **1:** met. Everything is a standard control.
- **2 and 10:**
  - Met only through the band rule, and only where the band fits.
  - On the zoomed 13-inch in landscape, the one row that fits touches the keyboard's edge. That needs an exception at every text size, and at large text the row doesn't fit at all.
  - On the phone it doesn't fit at AX5.
  - The iPad's floating or undocked keyboard can be dragged over the band, and Brickson can't prevent it. That is a named risk.
- **10:**
  - Return-speaks sits next to keys: an exception or a rule change.
  - Keys that switch modes sit inside a keyboard Brickson doesn't control.
  - The harness can't see the keys.
- **11:** met by overlaying the keyboard, against the measured table.
- **6:**
  - Apple's keyboard is a system component Brickson shows, so it gets measured too.
  - One light-mode sample from the reference's iPhone screenshot: prediction text 6.85:1, key labels 21:1.
  - Dark, Increase Contrast and Reduce Transparency are not measured.
  - If one of them fails, LESSONS says to replace it with an in-app control (which would be B) or record an exception.
- **7 and 9:** Writing Tools is turned off. Third-party keyboards are covered just below.
- **8:** QuickType's learning is the system's own, shown in the system's bar.

**Third-party keyboards.**
- Brickson can refuse them: `application(_:shouldAllowExtensionPointIdentifier:)` returns false for `.keyboard`.
- Refusing keeps the measured table true, because other keyboards have other heights.
- It also keeps the privacy promise simple, because a keyboard with Full Access can send what is typed to its maker.
- Allowing them keeps choices such as Keeble, the accessible keyboard that AssistiveWare's Proloquo4Text page points to.
- Recommendation: refuse them in 1.0, record that in DECISIONS.md, and revisit if people ask.

**Cost.** About a week, on top of the shared foundation and the layout engine.
- That covers the field, the typing state, the keyboard table and its tests, the Return test, a test that frames don't move, and the decision records.
- Add 3–4 days if Brickson must control inline predictions or empty the iPad shortcuts bar. Both need a wrapped UIKit text view (`inlinePredictionType`, `inputAssistantItem`).

**Risks:**
- D27 again (the keyboard covering the call for help) if the band rule slips.
- Keeping the table up to date with each iOS release.
- The floating keyboard.
- Switch interfaces hiding the keyboard.
- Gaze typing turning out too slow or error-prone on Apple's keyboard.
- With a hardware keyboard attached, and in the simulator by default, iPadOS shows only a small bar instead of the keyboard.
  - Every typing test must force the full keyboard (AGENTS, *Gotchas*).
  - The bar's own size and position must be measured.

**Evidence:** L1, L2, L5, A5, A7–A11, S1–S5, P2.

### Option B: a Brickson keyboard for pointer, gaze and switch; Apple's for touch

The keys are standard SwiftUI Buttons carrying the keyboard-key trait (`.isKeyboardKey`). The layout engine places them in the area Apple's keyboard would cover.

**Design rules:**
- **Layout.**
  - QWERTY, in the same letter order as Apple's, so moving from touch to gaze means the same keyboard with bigger keys.
  - For pointing, QWERTY is much faster for people who already know it: novices typed 20.2 words a minute on QWERTY against 10.7 on ABC [R6].
  - For scanning, ABC or frequency-ordered layouts are faster [R7]. Smartbox offers both, though I saw that only in a search summary.
  - Any other layout is an explicit one-time choice by the person or their SLP, never tied to a change of profile (invariant 8).
- **No shift and no layers.**
  - Speech doesn't need capitals, so there is no shift.
  - Digits and . , ? ' get fixed keys. That replaces a 123 key, which swaps every key under the pointer.
- **Delete:** one character per activation, nothing repeating while held, and never nearest Speak.
- **Speak:** a Brickson control placed where no key, word button or the message is nearest to it (the harness checks).
- **Switch scanning.**
  - Each row is an accessibility container, so Switch Control's group scanning becomes row-then-key scanning.
  - Predictions and Speak can come first in the scan.
- **Two ways to build it.**
  1. A wrapped UIKit text view whose `inputView` is replaced. A real field stays focused, so hardware keyboards, VoiceOver's text editing, the cursor and Voice Control dictation keep working.
  2. Plain text built from key presses. Simpler, but it loses all of those.

  Build the first. SwiftUI has no `inputView`.
- **Invariant 1.**
  - It forbids custom input code. A keyboard made of standard Buttons is not custom pointer or gesture code.
  - A reviewer may still read the rule literally, and UIKit itself calls `inputView` a custom input view.
  - So it needs a DECISIONS.md entry, in the owner's words, before any code is written.

**What B gives up.** This is the big unknown.
- **Apple's iOS 26 typing improvements** apply to its own keyboard: the keyboard dwell timer, fewer switch steps, and QuickPath on the phone [A10].
- **Probably keyboard-only too:** Zoom on Keyboard Keys, Always Tap Keyboard Keys and Scan Same Key After Tap.
- **Whether the keyboard-key trait makes iOS treat Brickson's keys the same way** is a hypothesis for device check 2, not a fact.
- **If it doesn't:**
  - Every Brickson key may cost a switch user an extra press for the scanner menu, unless Auto Tap is on.
  - A gaze user can't have a faster dwell on keys than on Emergency.
- **Also lost:**
  - autocorrect;
  - QuickType's learned predictions;
  - Text Replacement (an app can't read the person's shortcuts unless it is a keyboard extension);
  - other languages' keyboards. Each language needs its own layout; Vocable ships separate English, German and Italian layouts [P1].

**Prediction on the device**, with no network and no third-party code:
- **`UITextChecker.completions(forPartialWordRange:in:language:)`.** Apple documents the results as most likely first [A2]. Vocable builds its suggestions from this plus spelling guesses [P1].
  - It completes only the word being typed.
  - There is no public next-word API. QuickType's model isn't exposed, and NaturalLanguage offers embeddings and tagging, not prediction.
- **A fixed list of neutral quick words,** such as "I", "you", "please", "want", "need" and "not" (invariant 7).
- **Completions from the person's own phrase library.** These are their own words, and they need no new storage.
- **Next-word prediction** would need a bundled word-pair table built from a licensed text corpus. That is a licensing and size question, not a package.
- **Learning from what the person types** is how Proloquo4Text, Predictable and Spoken describe their prediction. For Brickson it needs an invariant 8 decision and a privacy-policy change, because it stores vocabulary.

**Invariants:**
- **1:** needs a DECISIONS.md entry.
- **2 and 10:** solved by design in pointer and gaze profiles. Touch profiles still use Apple's keyboard, so the band rule still shapes Home.
- **6:** key colours are pinned in `PaletteTests`.
- **8:** the layout and the number of prediction slots are fixed.
- **10:** the keys are Brickson's own, so the harness can score every chain, including key → Speak.
- **11:** met.

**Cost.** About 5–8 weeks on top of the foundation and C's word row, then upkeep for each iOS release and each language. That covers:
- the UIKit field wrapper;
- layout data for each language;
- the keys and their grouping;
- rules for delete and punctuation;
- sizes per profile from the layout engine;
- `PaletteTests` pins;
- Voice Control label collisions, such as a key "I" against the phrase "I.";
- UI tests for every key, and harness surfaces;
- device sessions for five input methods.

**Risks:**
- The biggest: weeks of work on a keyboard that turns out slower than Apple's for switch users and no better for gaze.
- A second keyboard to keep accessible for VoiceOver, Voice Control and Full Keyboard Access.
- With `inputView` replaced, the iPad may still draw its 55pt shortcuts bar over the bottom row of Brickson's keyboard. That is a simulator check, and emptying the bar costs `inputAssistantItem` work.
- Localization.

**Evidence:** L1–L3, A2, A3, A6, A10, P1–P5, R1–R7.

### Option C: Apple's keyboard plus a Brickson word row, and a gaze keyboard later only if needed

**What it adds to A:**
- A row of word buttons at the profile's size, just above Apple's keyboard and part of Home's own layout. On a large iPad that could be 88pt tall, against QuickType's 49pt.
- It is not a keyboard toolbar. `ToolbarItemPlacement.keyboard` comes and goes with the keyboard and is sized by the system; the reference rejected it for that reason.
- The window and profile set the number of slots, never the content.
- The slots hold completions of the current word (`UITextChecker`), plus fixed quick words or completions from the person's own phrases.

**Rules:**
- **Refills under dwell.**
  - A lingering look on slot 1 inserts "water". If the slot then refills with a new word, the next re-fire inserts that word too.
  - Fix it by state, never by a timer: after an insert, the completion slots stay empty and disabled until the next key.
  - Quick words sit in fixed places and never change.
  - QuickType has the same refill problem, and Brickson can't change it (check 5).
- **A buffer at the keyboard's edge.** The word row sits between the keys and the band's speaking controls. At worst, a look slipping up from the keys inserts a word.
- **Room.**
  - Where the band has no room (zoomed 13-inch landscape, the phone at large text sizes), the row is left out.
  - That is allowed, because positions may depend on window and text size.
  - The person loses the row on those screens.

**Invariants:**
- As A.
- **8:** comfortable, because the contents depend only on the current text and fixed lists.
- **7:** the quick words are neutral.

**Cost.** A plus 1.5–2 weeks. That covers a `WordSuggester`, the row, the insertion rules, the empty-after-insert state, `PaletteTests`, harness scoring and quick words for each language.

**Risks:**
- Two prediction areas, QuickType's and Brickson's, may confuse people.
- It doesn't fix A's tight configurations.
- The later gaze keyboard needs somewhere to go. The band rule already gives it one: B fills the same area.

**Evidence:** as A, plus A2, P1, R3, R4.

### Also considered

- **D: a Brickson keyboard for everyone, touch included.**
  - It would give one keyboard at every stage, and full control of the layout.
  - But early typists would lose QuickType, autocorrect, QuickPath, dictation and Text Replacement.
  - People whose ALS starts with speech (bulbar onset) often lose speech while their hands still work, and they type the most.
  - Not recommended.
- **A language model that predicts words or finishes sentences**, whether Foundation Models or SpeakFaster-style expansion of abbreviations [R3]. Ruled out by the hard stop on AI-generated replies and by invariant 7.

## 4. Around the keyboard

**Show the listener.** A control that shows the message in very large type.
- It never covers Emergency, Get Attention, Yes or No (invariants 2 and 10).
  - So it enlarges within the message area, or fills the phrase and keyboard area below the band.
  - The keyboard drops while it shows.
- Two controls in different places open and close it. Never one toggle in place.
- It is passive text with no controls inside, because the person's look may rest on it.
- On an iPhone it could offer upside-down text for someone across a table.
- It takes a few days once the layout engine exists. It means nothing on a call.

**Typed recently.**
- Invariant 8 allows a recents zone if it is fixed in place and only its contents change.
- The natural fit is a "Typed recently" category whose tiles speak on the first activation, like any phrase.
- **Speaking a recent message never reorders the list.** Otherwise the tile under the look changes, and a re-fire speaks a different message.
- **Only a new typed message joins the list,** when Speak or Return speaks it.
- **Kept in memory only,** it needs no policy change.
- **Kept after the app closes,** it is new stored data, and several things need deciding:
  - the privacy policy's *What stays on your device* section and its Effective date;
  - whether backups include it;
  - delete controls that ask first.

  Adding to a stored history every time something is spoken also strains invariant 3.
- **Recommendation: keep it in memory at first.** That also makes Clear recoverable.
- "Save as phrase" belongs in edit mode (invariant 3).

**Abbreviations.**
- With Apple's keyboard (A and C), the system's Text Replacement already works, set up in iOS Settings. For example, "brb" becomes "Be right back."
- A Brickson keyboard (B) would need its own abbreviations: new stored data, an editor behind edit mode, and changes to backups and the policy. Not for 1.0.

**Privacy policy changes, by option:**
- **A and C:** none for typing itself. If third-party keyboards are allowed, add a sentence about them.
- **B:** none, unless it learns words or stores abbreviations.
- **Calls:** need policy sentences whichever option is chosen.
- **Keeping recents, or learning from typing:** whichever option does it updates *What stays on your device* and the Effective date in the same pull request.

## 5. What to measure before choosing

New rows for HANDOFF's *Checks that need a real device*:

| # | Check | Decides |
|---|---|---|
| 1 | Eye Tracking typing in Brickson on Apple's keyboard. Use a 13-inch and an 11-inch iPad, in portrait and landscape, with iOS 26's keyboard dwell timer and Snap to Item, and Zoom on Keyboard Keys on and off. Record words a minute on a fixed set of sentences, wrong keys, accidental shift, 123, emoji, dictate, hide and paste, and misses on the prediction bar. | Whether A is enough for gaze, or B is worth building |
| 2 | A throwaway build with ten Brickson keys marked `.isKeyboardKey`. Do Eye Tracking's keyboard dwell timer and Zoom on Keyboard Keys apply to them? Do Switch Control's Always Tap Keyboard Keys and Scan Same Key After Tap? | B's real speed for gaze and switch users |
| 3 | A Bluetooth switch interface that pairs as a keyboard, and its keyboard-toggle mode if it has one. Does Apple's software keyboard still appear, and what does Switch Control offer? | Whether A works at all for those switch users |
| 4 | Switch presses per character for a fixed sentence, on Apple's keyboard (iOS 26, Group Items on) and on a grouped prototype layout | B for switch and brain-computer-interface users |
| 5 | Across the keyboard's edge: where Snap to Item lands for a look just above the prediction bar; whether the pointer stays or follows the look after a key; whether a lingering look re-fires a key, a prediction or Return | The order of the band, the empty-after-insert rule, the Return exception |
| 6 | Keyboard tops on every device and orientation (the existing row), plus: the floating or undocked keyboard over the band, the hardware-keyboard bar, iPadOS 26's windowed apps, and FaceTime beside Brickson | The keyboard table and the minimum window size |
| 7 | A typed message spoken into a phone call and a FaceTime call through Add Audio in Calls, in Personal Voice and in a system voice. What does the caller hear (level, echo)? Does the call notification arrive? What happens when a call starts mid-sentence? | The call status line, and changes to the speech session (with the platform audit) |
| 8 | VoiceOver and Voice Control with the field: dictating into it, "Tap Speak", and with B, Voice Control's numbers over 30-plus keys | Whether B must hide itself for voice users |

**What each check needs:**
- *No Brickson build; can start now in Notes or Live Speech:*
  - the Apple-keyboard half of 1;
  - all of 3;
  - the Apple-keyboard half of 4;
  - the floating-keyboard part of 6.
- *Brickson on a device:* the Brickson half of 1, and checks 2, 5, 7 and 8. These wait until Brickson can be installed (`DEVELOPMENT_TEAM`, HANDOFF next step 4).

**On the simulator,** before the layout engine is designed:
- keyboard tops for each simulator, with keyboard minimization off;
- Return on the software keyboard;
- the contrast of Apple's keyboard in all four appearances, from screenshots;
- frames unchanged as the keyboard shows and hides.

**What would justify B.** This is my suggestion; set the numbers with an SLP. Build B if any of these holds:
- On a 13-inch iPad, the ten-key prototype is clearly faster for gaze users, say by 25% or more.
- It halves their errors.
- Check 3 shows switch users can't get Apple's keyboard.

## 6. Recommendation

1. **Build the shared foundation now, and measure** (section 7). It doesn't depend on which keyboard wins.
2. **Put the band rule into the layout engine's design** (port step 4).
   - Everything invariants 2 and 10 name, plus the message and the warning space, goes above the worst measured keyboard top, in every Home state and every profile.
   - The warning area moves up from the bottom.
   - This is the lesson of D27, applied before anything is built.
3. **Plan C as the path.**
   - Ship Apple's keyboard first, with Writing Tools off and third-party keyboards refused.
   - It ships with these named exceptions, each with its numbers, for the owner to accept or refuse:
     - speaking and alarming controls on the keyboard's edge, on the zoomed 13-inch in landscape and anywhere else the band holds only one row;
     - controls below 88pt, or covered, at AX4–AX5 in landscape on that window, and at AX5 on the iPhone;
     - Clear on that window: either beside the message and recoverable, or no Clear there;
     - Return speaking under dwell;
     - the iPad's floating or undocked keyboard, which can be dragged over the band.
   - Add the Brickson word row after device check 5, and only where the band holds it.
4. **Decide B after device checks 1–4.**
   - If it is built: large iPads only, pointer and gaze profiles only, QWERTY, in the same area as Apple's keyboard, on a real UIKit field, with the invariant 1 decision written first.
   - Never build it for the phone.
5. **Owner decisions to record in docs/DECISIONS.md:**
   - the band rule;
   - Return under dwell;
   - third-party keyboards;
   - whether predictions may learn;
   - whether Typed recently is stored;
   - if B is built, invariant 1.

## 7. The smallest first step that keeps every option open

One pull request, about 3–5 days of agent time, with no Home redesign:
- **`MessageComposer`**, a pure type that doesn't depend on any keyboard.
  - It inserts text, puts a completion in place of the partial word, and deletes one character.
  - A newline becomes a request to speak.
  - Clear returns the cleared text, so it can be recovered.
  - It never calls `SpeechService` itself, because `SpeechService` has no test hook for the synthesizer (HANDOFF). It returns a request to speak, and the view passes that on to `SpeechService`.
  - Unit tests, each naming the change that would make it fail.
- **`DraftStore`**: a small file in Application Support, written atomically on every change through an injectable `save`.
  - A test makes the save fail and checks that the passive warning shows and the text stays in memory.
  - Restoring the draft never speaks.
  - A test checks that Clear empties the stored copy.
- **The reference's keyboard probe** (`FamilyVoiceUITests/TypingKeyboardProbe.swift`), ported as an opt-in UI test.
  - It writes the table of keyboard tops for each simulator in the matrix.
  - Later the layout engine reads the table, and an always-on test compares it with the live keyboard.
- **Rows 1–8 above, added to HANDOFF's device-check table.**

**After that:**
- A small stand-in typing state on Home v0 lets the owner run the Brickson half of check 1, and checks 5, 7 and 8, once Brickson can be installed.
  - It needs only the field in the message row, Speak, the way out, and nothing under the keyboard.
- Check 2 needs a throwaway branch with ten test keys.

## 8. Three questions for a speech-language pathologist or a person with ALS

1. **How much would you type rather than choose a saved phrase, at each stage and on calls?**
   - Once your eyes or a switch do the work, is typing still worth its screen space?
   - Published research measured gaze typing in daily use at about 8 words a minute, against about 190 for speech ([als-aac-research.md](../als-aac-research.md), section 2).
   - The answer decides whether B is worth weeks of work.
2. **When you can no longer type by hand, would you rather keep the keyboard you know, or learn one made for your eyes or a switch? And when?**
   - The keyboard you know is QWERTY: familiar, but slower to scan.
   - The alternative is larger and simpler, in ABC or frequency order.
   - The answer decides B's layout, and what "never relearn" means for the keyboard.
3. **Exact letters, or help you have to check?**
   - Should Brickson autocorrect, predict and learn from what you type, given that each suggestion is one more thing to read before it is spoken?
   - The answer decides autocorrect, inline predictions and the word row, and whether anything typed is ever stored.

## Sources

**Local** (no URL):
- **L1:** reference `docs/fixes/typing-keyboard.md`, plus its probe data in `docs/fixes/typing-keyboard/`: keyboard tops, key frames, and Return inserting a newline.
- **L2:** reference `docs/fixes/measurer.md` section 12 and `docs/fixes/measurer-typing/`: what the keyboard covered, the phone's keyboard top, keys the harness can't see, and `discardsDraft`.
- **L3:** reference `FamilyVoice/Views/TypeToSpeakView.swift`, `Models/HomeChromePolicy.swift` and `Models/AppSettings.swift`.
  - What they show: typing replaced the grid, Phrases was the exit, Clear sat beside Speak, and the draft lived in UserDefaults.
- **L5:** Brickson's own files:
  - `AGENTS.md`;
  - `docs/LESSONS.md` ("Typing and the keyboard");
  - `docs/DECISIONS.md`;
  - `docs/HANDOFF.md`;
  - `Brickson/Home/HomeView.swift` (`StatusArea` at the bottom);
  - `Brickson/Speech/SpeechService.swift` (the `.mixWithOthers` fallback);
  - `site/privacy/index.html` (the draft promise).

**Apple's documentation, read through Context7 (not fetched):**
- **A1:** Adding synthesized speech to calls: https://developer.apple.com/documentation/avfaudio/adding-synthesized-speech-to-calls
- **A2:** `UITextChecker` completions: https://developer.apple.com/documentation/uikit/uitextchecker/completions(forpartialwordrange:in:language:)
- **A3:** `isKeyboardKey`: https://developer.apple.com/documentation/swiftui/accessibilitytraits/iskeyboardkey
- **A4:** `writingToolsBehavior`: https://developer.apple.com/documentation/swiftui/view/writingtoolsbehavior(_:)
- **A5:** refusing custom keyboards: https://developer.apple.com/documentation/uikit/uiapplication/extensionpointidentifier/keyboard
- **A6:** `inputView`: https://developer.apple.com/documentation/uikit/uitextview/inputview
- **A7:** `inlinePredictionType`: https://developer.apple.com/documentation/uikit/uitextinputtraits/inlinepredictiontype
- **A8:** `UITextInputAssistantItem`: https://developer.apple.com/documentation/uikit/uitextinputassistantitem
- **A9:** `onSubmit`: https://developer.apple.com/documentation/swiftui/view/onsubmit(of:_:)

**Apple, on the web:**
- **A10:** Apple Newsroom, May 2025: https://www.apple.com/newsroom/2025/05/apple-unveils-powerful-accessibility-features-coming-later-this-year/
  - iOS 26 makes keyboard typing easier with Eye Tracking and Switch Control: a keyboard dwell timer, fewer switch steps, QuickPath.
  - It also brings Switch Control support for brain-computer interfaces.
- **A11:** Live Speech, Apple's own typed speech: https://support.apple.com/105018
  - You type, then tap Send.
  - It has saved phrases, works in calls, and can use Personal Voice.

**Secondary sources on Apple features:**
- **S1:** AbilityNet on Switch Control's keyboard options: https://mcmw.abilitynet.org.uk/how-to-use-switches-to-control-your-device-in-ios-16-on-your-iphone-or-ipad
- **S2:** AbilityNet on Eye Tracking and Zoom on Keyboard Keys: https://mcmw.abilitynet.org.uk/how-to-control-your-device-using-eye-tracking-in-ios-18-on-your-iphone-or-ipad
- **S3:** inline predictions; Space accepts them, and the switch to turn them off arrived in iOS 17.2: https://www.idropnews.com/how-to/how-to-turn-off-inline-predictive-text-on-your-iphone/206700
- **S4:** a hardware keyboard hides the software keyboard: https://www.switchingtomac.com/ipad-keyboard-not-showing-fixes/
- **S5:** switch interfaces acting as keyboards (forum-grade evidence):
  - AbleNet says its Blue2 is seen by devices as a Bluetooth keyboard: https://support.ablenetinc.com/?p=1823
  - A product listing says the Blue2 can toggle the on-screen keyboard: https://portale.siva.it/en-GB/databases/products/detail/id-19623
- **S6:** brain-computer interfaces through Switch Control:
  - https://techcrunch.com/2025/05/13/apple-announces-new-accessibility-features-including-support-for-brain-implants
  - https://9to5mac.com/2025/08/04/apples-new-brain-controlled-iphone-ipad-tech-revealed-in-video/

**Other apps:**
- **P1:** Vocable, open source under MIT: https://github.com/willowtreeapps/vocable-ios
  - `Vocable/Extensions/TextSuggestionController.swift` uses `UITextChecker`.
  - It has keyboard layouts for English, German and Italian.
  - Its QWERTY and ABC keyboards under head tracking: https://www.boia.org/blog/new-app-can-help-people-communicate-with-head-tracking-technology
- **P2:** Proloquo4Text: https://www.assistiveware.com/products/proloquo4text
  - Prediction that learns, Switch Control, and Keeble suggested as an accessible keyboard.
  - Its page names no keyboard layouts.
- **P3:** Predictable: https://apps.apple.com/us/app/predictable/id404445007
  - QWERTY, ten-key and Apple keyboards; prediction that learns; switch scanning; head tracking.
- **P4:** TD Talk, which advertises word prediction for eye gaze (layout unverified): https://investors.tobiidynavox.com/blogs/press-releases/tobii-dynavox-launches-td-i-series-to-empower-people-with-disabilities-with-independence
- **P5:** Spoken, whose next-word prediction adapts to the user: https://spokenaac.com
- **Smartbox Text Talker:** its QWERTY, ABC and frequency keyboards were seen only in a search summary: https://hub.thinksmartbox.com/?p=5716

**Research:**
- **R1:** Majaranta, Ahola and Špakov, CHI 2009: https://homepages.tuni.fi/oleg.spakov/publications/Majaranta_CHI_09.pdf
- **R2:** Majaranta, MacKenzie, Aula and Räihä, UAIS 2006: https://www.yorku.ca/mack/UAIS2006.pdf
- **R3:** Cai et al., SpeakFaster: https://arxiv.org/abs/2312.01532. This is a study of a large language model; only its baseline numbers are used here.
- **R4:** Koester and Levine 1994: https://ieeexplore.ieee.org/document/331567. Trnka et al. 2008: https://www.eecis.udel.edu/~mccoy/publications/2008/trnka08at.pdf
- **R5:** MacKenzie, ICCHP 2012 (scanning): https://www.yorku.ca/mack/icchp2012.html
- **R6:** MacKenzie et al., BIT 1999 (soft keyboards): https://www.yorku.ca/mack/BIT-1999.pdf
- **R7:** Tecla's blog, citing the Ace Centre (a vendor source): https://gettecla.com/blogs/news/switch-scanning-for-typing-qwerty-vs-frequency-layouts

**Not verified:**
- the exact name and behaviour of iOS 26's keyboard dwell timer;
- whether Zoom on Keyboard Keys stays zoomed between letters;
- whether `.isKeyboardKey` changes how Eye Tracking or Switch Control treat Brickson's keys;
- the claim that switch interfaces stop the software keyboard appearing;
- the keyboard layouts of Proloquo4Text and TD Talk;
- any keyboard measurement on the 11-inch iPad, the iPad mini, other iPhones, or iOS 26.