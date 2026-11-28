# Marking the word being spoken

*Roadmap: Home's message. Owner: a Claude thread on the owner's Mac.
Status: building.*

## Intent

- **Problem:** when Brickson speaks, the message on Home shows the words
  but not where the voice is in them. A listener who misses a word, or a
  person checking that their sentence is going out as they meant it, has
  nothing to follow, and a long typed message gives no sign of how far it
  has got.
- **Proposed outcome:** while a phrase or a typed message is spoken, the
  word the voice is saying is marked in the message: the words already
  said in full ink, the word being said with a bar under it, the words
  still to come dimmed. When speech ends, stops or fails, the message is
  drawn as before.
- **Who and what it affects:** everyone who hears Brickson speak and the
  people beside them, at every stage and with every input method, since
  the message is not a control. Home's message, and the speech service's
  record of the utterance being spoken.
- **Constraints:** invariant 2 (every phrase speaks on the first
  activation; nothing waits for the mark), invariant 4 (a failure the
  person cannot hear still shows in the status line, and the mark clears
  with it), invariant 6 (every new colour pair measured and pinned),
  invariant 8 and *Controls keep their frames* (nothing moves), the dwell
  rules (motion pulls a pointer that follows the eyes, so the mark steps,
  never slides), and *Apple's current frameworks first* (SwiftUI's
  `TextRenderer`, Swift Testing).
- **Open questions:** each decided in docs/DECISIONS.md, "The word being
  spoken is marked".

## Spec

- **States:** not speaking (every word in full ink, as today); speaking
  with no word reported yet (every word dimmed); speaking a word (said
  words in full ink, the word being said in full ink with the bar, words
  to come dimmed); speech ended, stopped, interrupted or failed (as not
  speaking). Every control keeps its place in every state; the message
  keeps its frame.
- **What moves the mark:** only the synthesizer's own word reports. A
  voice that reports no words leaves the message dimmed until it ends. A
  report earlier than the one marked, past the end of the words, or naming
  no place moves nothing.
- **Typed words:** while the typing field is open, the field is left
  exactly as it is (Apple's own text field, editable and showing the
  cursor); a typed message is marked wherever the message shows it once
  typing is put away.
- **Input methods:** the message is not a control and is not in any scan;
  nothing new can be activated, so no chain changes.
- **VoiceOver:** the message keeps one label, the whole message. The mark
  is never announced, so VoiceOver never talks over the voice.
- **Colours:** words to come are primary ink at 60% over the screen (75%
  with Increase Contrast), pinned at 4.5:1 or better in every appearance
  and on the lifted dark screen (`PaletteTests`); the bar is primary ink,
  already pinned.
- **Settings:** Increase Contrast darkens the dimmed words and thickens the
  bar from 3 to 4 points; Differentiate Without Colour changes nothing,
  because the bar is a shape; Reduce Motion changes nothing, because the
  mark never animates; at the largest text sizes the bar follows the words
  and keeps its room below the last line shown.
- **Privacy policy:** no sentence changes. Nothing is stored or sent.
- **Concerns:** a message longer than the two lines Home shows scrolls,
  so the word being spoken can be out of sight; following it comes with
  the work that gives the message more lines.

## Plan

- **Files that change:** `Brickson/Speech/SpeechSynthesizing.swift` (the
  word report carries its whole place), `SpokenUtteranceTracker.swift` and
  `SpeechService.swift` (the phrase in progress and its latest word),
  `Brickson/Home/SpokenMessage.swift` (the plain marking types and the
  renderer), `HomeView.swift` (the message draws through it), and the
  debug review sheet.
- **Order of work:** one pull request.
- **Risks:** a renderer that changed the layout (checked by drawing the
  message with and without the mark and comparing its pixels); a mark
  left on after speech ends (every ending tested through the speech
  service); work on the main thread for each word (the words are measured
  once per message; each report only records a place); Apple's
  accessibility audit on text drawn by a renderer (the UI suite's audits
  on both simulator families).
- **Proof:** `SpokenWordMarkingTests`, `SpokenWordFramesTests`, the new
  cases in `SpokenUtteranceTrackerTests`, `SpeechServiceTests`,
  `OffMainThreadCallbackTests` and `PaletteTests`, and
  `TypingOnHomeTests.testSpeakingTypedWordsLeavesTheFieldAsItIs`. Device
  checks: whether each voice, a Personal Voice included, reports its words
  and how late; how VoiceOver reads the message while it is marked
  (docs/DEVICE-CHECKS.md).
