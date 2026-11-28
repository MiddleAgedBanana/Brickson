# The word being spoken is marked in Home's message

*2026-11-28. Pull request #PR (`claude/spoken-word-marking`). A Claude
thread on the owner's Mac.*

## What changed and why

While a phrase or a typed message is spoken, Home's message now shows
where the voice is: the words already said in full ink, the word being
said in full ink with a bar under it, and the words still to come dimmed.
It follows only the synthesizer's own word reports, so nothing guesses
timing, and it clears whenever speech ends, stops or fails. It is drawn
in today's message area with today's colours (docs/DECISIONS.md, "The
word being spoken is marked").

- The synthesizer's word report now carries the whole place of the word,
  where it starts as well as where it ends, worked out without overflow
  on the background thread it arrives on; a report naming no place still
  counts as progress (`SpeechSynthesizing.swift`). Before, a report whose
  location was NSNotFound would have trapped there when its end was added
  up.
- `SpokenUtteranceTracker` keeps the latest reported word with the
  utterance, moving only forward and only inside the phrase's words, and
  `SpeechService.phraseInProgress` shares it. Every way an utterance ends
  clears it. A Settings voice sample is never a phrase in progress.
- `Brickson/Home/SpokenMessage.swift` holds the plain types (which words
  are said, being said and to come; each word's look; where the bar goes)
  and the `TextRenderer` that draws them. The message is one `Text` of
  tagged words built from the message alone; the renderer only changes
  brightness and draws the bar, so nothing moves. Only a small view reads
  the speech's progress, so a word report lays nothing out again.
- The bar reaches a few points below the last line shown, so while a
  phrase is spoken Home's message is clipped that much lower, into the gap
  above the status line; at other times it is clipped at its lines, as
  before. No frame changes.
- SwiftUI drew nothing at all of a `Text` that interpolated more than 128
  pieces (measured on iOS 27.2: a message of 65 words, with the spaces
  between them, came out blank). The message is therefore joined in
  groups of 64, and the groups joined again; a test draws a message of
  400 words, under the 2,000-character limit, and finds every word.
- The debug review sheet shows the marking on a sample sentence at fixed
  places, with a button that steps it one word at a time.

## Commits

- `87969b4` Mark the word being spoken in Home's message.
- `1ff5f69` Record the word marking: decision, work file, checks and the
  website.
- `3c06006` Clip lower only while speaking, and mark no word for an empty
  place (after the Codex review run before opening).
- This record's own commit.

## Verified

On the owner's Mac with Xcode 27.2, on iOS 27.2 simulators of an iPhone 17
and a 13-inch iPad Pro (M5), in portrait:

- `scripts/test.sh` (the documents, hooks, privacy, agent-bridge and
  forbidden-code checks, then every unit test) on the iPhone: 1,150 tests,
  none failed (1 skipped and 12 expected failures, as on `main`); the
  String Catalog up to date.
- `scripts/test.sh ui` with `LaunchTests`, `TypingOnHomeTests` and
  `HomeLayoutTests`, on the iPhone and on the iPad: 14 of 16 passed on
  each, with the full software keyboard. Apple's accessibility audit
  passed on Home in light and dark. The two that failed wait for speech to
  finish, which this Mac's simulators never do (their audio does not
  start, so "Speaking" never leaves): `testLargestTextKeepsQuickControlWordsVisible`,
  which is not changed here, and the new
  `testSpeakingTypedWordsLeavesTheFieldAsItIs`. Each failed only at that
  wait. GitHub's simulators speak and finish.
- Home on the iPad, from the UI test's own screen recording: after Again
  with a typed message, the simulator's voice reported its first word, and
  Home showed "Green" in full ink with the bar under it, the rest of the
  message dimmed, and "Speaking" on the status line, with every control in
  its place. (The voice then stalled, as this Mac's simulators do.)
- The debug review sheet on the iPad in light, dark, light and dark with
  Increase Contrast, and at the largest text size: every word in its
  place, the bar under the word being spoken (thicker with Increase
  Contrast), the words to come dimmed and readable, and at the largest
  size a bar under a first-line word clear of the line below.
- `SpokenWordFramesTests` fails when the marked word is drawn 3 points
  higher (tried once, then put back). `everyWordOfTheLongestTypedMessageIsTagged`
  failed before the message was joined in groups, which is how the
  128-piece limit was found; a 400-word message is now built and drawn in
  about 40 ms on the simulator.
- `codex review --base origin/main` before opening: three findings fixed
  (an empty place inside a word, the lower clip when nothing is marked,
  and the debug button's edge), two answered in the pull request (an
  accent on the line below, and the UI test's wait for real speech).

## Not verified

- GitHub CI, at the time of writing.
- Landscape, iPhone Duo and Split View; the UI tests other than the
  three classes above; the mark moving on from word to word on Home (this
  Mac's simulator voice reported the first word and then stalled).
- Differentiate Without Colour, Reduce Motion, Reduce Transparency and
  Smart Invert were not captured: by the code nothing changes under the
  first three, and Smart Invert was not looked at.
- Sound, and whether any real voice, a Personal Voice included, reports
  its words in time: simulators prove nothing about either (device check
  S7, added).
- How VoiceOver behaves on a device while the words are marked (S7).
- The review sheet's capture script (`scripts/design-review/review.py`)
  does not measure the new samples; their contrast is pinned by
  `PaletteTests` arithmetic instead.

## Follow-ups

- Follow a message longer than the two lines Home shows, by whole lines,
  as it is spoken (*Known gaps*). No thread yet.
- Mark typed words inside the open typing field, if a way is found that
  provably neither jumps nor hides the cursor (docs/DECISIONS.md, "The
  word being spoken is marked").
- A soft glow behind the word and a short slide between words, once the
  message has a measured dark plate and the app has one place for every
  animation's timing.
