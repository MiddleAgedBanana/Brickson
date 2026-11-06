# Phrases named like Home's controls

*Roadmap: R0 item 6, the Library's second follow-up. Owner: the thread
"Flag phrases named like Home's controls". Status: building.*

## Intent

- **Problem:** since the Library (2026-11-05) a family can write a
  phrase another control on Home also answers to: "Help", which Get
  Attention answers to, "Stop.", "Again!", or two phrases said alike.
  With Voice Control, saying that name then matches two buttons, and
  nothing tells the family why.
- **Proposed outcome:** the family's words are kept as written, and the
  Library says so as they are saved, so they can change them if they
  want one command.
- **Who and what it affects:** Voice Control users and their families;
  the phrase editor, the category name editor and the Restore question.
  Nothing on Home changes.
- **Constraints:** invariant 7 (never rename a person's words; import
  keeps them), invariant 10 (Yes, No, Emergency and Get Attention one
  activation away), and the owner's answer for wide words ("Allow, with
  a note").
- **Open questions:** warn or refuse. "Home's scan order and names"
  leaves what the editor says to the editing thread, and it warns. For
  the names of the four controls invariant 10 keeps one activation away,
  that would be an exception, so the owner decides (docs/DECISIONS.md,
  "Phrases named like Home's controls").

## Spec

- **States:** no new state, control or screen. The line kept for what
  Save did adds one sentence: "Another button on Home answers to these
  words too, so Voice Control may ask which one is meant." It follows
  the wide-word note where both apply. A restore that brings a name two
  controls did not share adds: "Another button on Home answers to some
  of these words too, so Voice Control may ask which one is meant."
- **Input methods:** the words are the same for all; the note names
  Voice Control so a family that does not use it can pass over it.
  VoiceOver hears the line as it appears on the phrase editor, Rename
  and the Restore question. New Category opens a new screen with the
  line first in its content, read when VoiceOver reaches it, as before.
- **Nothing moves:** each line keeps the height of its longest version
  from the start, so Move Phrase and Delete Phrase stay in their frames
  as the note appears. The sentence quotes no words, so that height is
  known.
- **The keyboard:** Save puts it away when its line carries a note: on a
  phone at the largest text sizes it covers the line. A category's line
  clears with the next change that saves, so a note never outlives what
  it says.
- **Colours:** none new.
- **Privacy policy:** nothing it says changes.
- **Screens:** no Figma frames: every control keeps its frame, and the
  new words are passive lines in places the screens already keep for
  words.
- **Concerns:** the Edit Phrase line is two lines taller at the default
  text size than it was, always, to keep that place.

## Plan

- **Files that change:** `LibrarySnapshot`, `LibraryEdit` (`LibraryPlan`),
  `LibraryRules`, `LibraryEditors`, `LibraryQuestions`, the String
  Catalog, and the tests: `HomeNameCollisionTests`, `LibraryTests`.
- **Order of work:** one pull request, with the docs follow-ups of
  PR #81.
- **Risks:** a note on every phrase saved beside one that shares a name
  (checked: only the saved words are looked up); a rule that starts
  refusing words (pinned by `theWordsAreKeptAsWritten`).
