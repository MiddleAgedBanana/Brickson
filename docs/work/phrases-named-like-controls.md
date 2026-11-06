# Phrases named like Home's controls

*Roadmap: R0 item 6, the Library's second follow-up. Owner: the thread
"Flag phrases named like Home's controls". Status: done.*

## Intent

- **Problem:** since the Library (2026-11-05) a family can write a
  phrase another control on Home also answers to: "Help", which Get
  Attention answers to, "Stop.", "Again!", or two phrases said alike.
  With Voice Control, saying that name then matches two buttons, and
  nothing tells the family why.
- **Proposed outcome:** the names of the controls one activation away
  stay theirs. Other words are kept as written, and the Library says so
  as they are saved, so a family can change them if they want one
  command.
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
  warning would be an exception, so the owner decided: refuse them
  (2026-11-06; docs/DECISIONS.md, "Phrases named like Home's controls").

## Spec

- **States:** no new state, control or screen. For a phrase with the name
  of Yes, No, Emergency or Get Attention, "Help" included, Save saves
  nothing and the line says: "A button on Home that must always be one
  step away already answers to this. Add another word, such as “Help
  me.” or “Yes, please.”" For any other shared name, the line kept for
  what Save did adds one sentence: "Another button on Home answers to these
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
- **The keyboard:** Save puts it away when its line carries a note or a
  refusal: on a phone at the largest text sizes it covers the line. A category's line
  and a restore's clear with the next change that saves, so a note never
  outlives what it says.
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
  (checked: only the saved words are looked up); a rule that refuses
  more than the five names (pinned by `theWordsAreKeptAsWritten`), or
  that stops a family changing a phrase a backup brought
  (`aPhraseThatAlreadyHasSuchANameCanStillBeChanged`).
