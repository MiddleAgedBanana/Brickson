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
- The bar reaches a few points below the last line shown, so Home's
  message is clipped that much lower, into the gap above the status line.
  No frame changes.
- SwiftUI drew nothing at all of a `Text` that interpolated more than 128
  pieces (measured on iOS 27.2: a message of 65 words, with the spaces
  between them, came out blank). The message is therefore joined in
  groups of 64, and the groups joined again; a test draws a message of
  400 words, under the 2,000-character limit, and finds every word.
- The debug review sheet shows the marking on a sample sentence at fixed
  places, with a button that steps it one word at a time.

## Commits

COMMITS

## Verified

VERIFIED

## Not verified

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
