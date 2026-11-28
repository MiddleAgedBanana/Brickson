# The word being spoken is marked in Home's message

*2026-11-28. Pull request #137 (`claude/spoken-word-marking`). A Claude
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
  phrase is spoken, and the whole message fits the lines shown, Home's
  message is clipped that much lower, into the gap above the status line;
  at other times, and for a longer message, it is clipped at its lines, as
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
- `5e8752d` Say what ran, what it showed and what did not run.
- `a816220` Merge `main` after #136.
- `1171ead` Move the mark only for a word, and reach below only when the
  message fits (the first review round).
- `649fd27` Answer the first review round in the records, device check and
  website.
- `14d3006` Correct the word marking's record, and name it in the README
  (after the report-only verifier's check).
- `6dc45e4` Show a person can keep typing while typed words are spoken
  (the second review round).
- The commit that adds this line, the third round: typing now starts while
  "Speaking" shows, and the bar touching an accent below is put to the
  owner, since the review rules leave a new exception to the owner.

## Review, first round

CodeRabbit, cubic, Gitar and Greptile reviewed the first push; Copilot could
not (the requester's quota was used up; not retried). Fixed: a report over
only a space moved the mark off its word (the tracker now moves it only for
a report naming a word's character, with a test); the lower clip showed the
top of a hidden third line in a longer message (it now reaches lower only
when the message fits the lines shown); the pixel tests now check that the
words to come are drawn at their share of the ink and that the bar lies
under the reported word, each tried once against a broken renderer; the
device check now leaves typing before watching a typed message, cuts a
phrase off with another phrase (Home's Stop ends the alarm, not speech),
and checks VoiceOver while the words are marked; the website's date; and
this record's number and commit line. Declined: measuring the review
sheet's samples in the capture script (their contrast is pinned in
`PaletteTests`; *Known gaps*). `main` was merged in, after #136.

## Verified

On the owner's Mac with Xcode 27.2, on iOS 27.2 simulators of an iPhone 17
and a 13-inch iPad Pro (M5), in portrait:

- `scripts/test.sh` (the documents, hooks, privacy, agent-bridge and
  forbidden-code checks, then every unit test) on the iPhone: 1,150 tests,
  none failed (1 skipped and 12 expected failures, as on `main`); the
  String Catalog up to date.
- `scripts/test.sh ui` with `LaunchTests`, `TypingOnHomeTests` and
  `HomeLayoutTests`, on the iPhone and on the iPad, before `3c06006`: 14 of
  16 passed on each, with the full software keyboard. Apple's
  accessibility audit passed on Home in light and dark. The two that
  failed wait for speech to finish, which this Mac's simulators never do
  (their audio does not start, so "Speaking" never leaves):
  `testLargestTextKeepsQuickControlWordsVisible`, which is not changed
  here, and the new `testSpeakingTypedWordsLeavesTheFieldAsItIs`. On the
  iPad the new test also once found no keyboard element right after Speak.
  Its screen recording shows the keyboard on screen in every frame from
  Type until Phrases (the bottom of the screen holds the keyboard's
  brightness throughout, before, during and after Speak), so the element
  was missed by one immediate query, not gone; and this change adds no
  view and moves no focus while typing (the marked message is not on
  screen then). The check was taken out in `3c06006`; after review the
  test instead types more while the words are spoken and checks they
  arrive, which shows the keyboard is still the person's (device check
  S7, step 4, does the same on a device). On
  GitHub's simulators both tests passed: the new one on the iPad in the
  first CI run and on the iPhone and iPad in the second (the iPhone part
  that holds it ran no tests in the first run, and another iPhone part ran
  none in the second: each time the runner's simulator never settled).
- At `649fd27` the report-only verifier ran `CI=true scripts/test.sh unit`
  here: 1,152 unit tests, none failed (1 skipped and 12 expected failures,
  as on `main`), and the privacy check found nothing.
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
- `SpokenWordFramesTests` failed when the marked word was drawn 3 points
  higher, and, after `1171ead`, when the words to come were drawn at full
  ink and when the bar was shifted 20 points (each tried once, then put
  back). `everyWordOfTheLongestTypedMessageIsTagged`
  failed before the message was joined in groups, which is how the
  128-piece limit was found; a 400-word message is now built and drawn in
  about 40 ms on the simulator.
- `codex review --base origin/main` before opening: three findings fixed
  (an empty place inside a word, the lower clip when nothing is marked,
  and the debug button's edge), two answered in the pull request (an
  accent on the line below, and the UI test's wait for real speech).

## Not verified

- Home's marked message on an iPhone, in dark, at accessibility text
  sizes, in landscape, in Split View or Slide Over, and on iPhone Duo. The
  only capture of the mark on Home is one iPad, light, default size,
  portrait, from before `3c06006`; the debug sheet was seen on the iPad
  only, also before it. The pixel tests draw the words alone (light,
  default size, 320 points wide), not in Home's lines or clip.
- The lower clip while speaking (`MessageViewport`, `RoomBelow`): no test
  fails if it stops reaching below the lines, or reaches below while a
  hidden line waits.
- Home's wiring: no test fails if Home stops passing the marking to its
  message (`MarkedMessage`); the UI test checks frames and one element.
- The mark moving from word to word on Home: this Mac's simulator voice
  reports its first word, then stalls (S7).
- Typing on while the words are spoken, on a real device and with each
  input method (S7, step 4); on simulators it is the UI test's.
- Differentiate Without Colour, Reduce Motion, Reduce Transparency, Bold
  Text and Smart Invert with a word marked: from the code only.
- VoiceOver while words are marked, sound, and whether real voices, a
  Personal Voice included, report their words in time (S7).
- The bar touching a tall accented capital on the line below: described,
  not captured.
- The review sheet's capture script does not measure the new samples;
  their contrast is pinned by `PaletteTests` (*Known gaps*).

## Follow-ups

- Follow a message longer than the two lines Home shows, by whole lines,
  as it is spoken (*Known gaps*). No thread yet.
- Mark typed words inside the open typing field, if a way is found that
  provably neither jumps nor hides the cursor (docs/DECISIONS.md, "The
  word being spoken is marked").
- A soft glow behind the word and a short slide between words, once the
  message has a measured dark plate and the app has one place for every
  animation's timing.
