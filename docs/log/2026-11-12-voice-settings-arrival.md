# Voice Settings, reached with a held look

*2026-11-12. Pull request #105 (`claude/project-thread-vl7g7k`). A cloud
thread, "Check held looks on Settings' unchecked screens"; GitHub CI is
its build.*

## What changed and why

docs/HANDOFF.md, *Known gaps*, listed three Settings places no chain had
followed: Voice Settings itself, iOS's Personal Voice question, and
Family Setup scrolled. This pull request takes each in turn.

- **Voice Settings had a hazard, now placed away.** On the frames CI
  drew on `main` (run 43180245909, at `3f92a8b`), a look held anywhere
  on Family Setup's Voice Settings row met "70% of normal speed" on the
  next screen: on the iPhone 17 at the default text size by nearest
  centre and by nearest edge, and on the 13-inch iPad in portrait by
  nearest edge (70% and 80%). A speed sets how Brickson speaks from
  then on and plays a sample, so a stray dwell in Settings changed the
  person's voice speed. Voice Settings now opens with **Back to Family
  Setup** where the row showed, however far Family Setup had scrolled,
  and everything it had below that, as one block that starts where a
  look on the way back cannot meet it. Going back returns to Family
  Setup as it was, so a repeated activation only goes back and forth.
  It follows the Library's question screens (docs/DECISIONS.md, "Voice
  Settings, reached with a held look").
- **A gap in the placement both share.** The sweep across every scroll
  of Family Setup found one more case: a row chosen where only its top
  showed, the rest past the foot of the screen. The way back stays
  within what shows, but the pointer can rest lower, at the row's hidden
  centre, and there the first speed was nearer than the way back (the
  iPhone at the largest text size). `LibraryQuestionPlace` now starts
  the choices clear of the whole row, which the Library's questions get
  too.
- **Family Setup scrolled** is covered for the Voice Settings row, in
  the model at every scroll that shows the row and in a new UI test.
- **iOS's Personal Voice question needs a device.** Its Ask button
  shows only under `PersonalVoiceAskPolicy.fromSettings`, which no build
  people use has yet, iOS shows the question only on a device that
  supports Personal Voice, and iOS places its buttons, so where a look
  rests after answering cannot be modelled from here. It is now step 4
  of device check P1 (D1) in docs/DEVICE-CHECKS.md, and Voice Settings
  from a stray dwell is step 3 of F4.

The chain engine learned Voice Settings as a screen of the Settings
surface (`SettingsChains`), with a hazard kind of its own
(`actsOnTheVoice`) and an effect for leaving Brickson (`leavesBrickson`,
which Open Personal Voice Settings has, and which counts as a hazard).

## Commits

- `e182152` Plan Voice Settings reached with a held look (the work file,
  `docs/work/voice-settings-arrival.md`, with Figma drawings of today's
  screen and the placed one on the iPhone 17 and the 13-inch iPad).
- `221c23b` Score Voice Settings reached from Family Setup's row (tests
  first: the surface, the engine's new effect, `VoiceSettingsChainsTests`
  and a failing `LibraryQuestionPlaceTests` case).
- `fe8e6ee` Keep question choices clear of a row past the foot.
- `50e1a43` Put Voice Settings' way back where its row showed.
- `269f5b9` Read Voice Settings where its row shows, scrolled or not.
- `9d00609` Record Voice Settings reached with a held look.
- A fix to the existing `SettingsChainsTests` for the new screen
  (below), and a merge of `main` once pull request #103 landed.

## Verified

Nothing here could build the app: this is a cloud session with no route
to a Mac, so the SwiftUI and UI-test code is untested until CI runs it.

What ran, on Linux with Swift 6.4.2 (the plain Swift types and the unit
tests that need no app, compiled with the project's default main-actor
isolation, in a debug build):

- `VoiceSettingsChainsTests` and `LibraryQuestionPlaceTests`, 15 tests,
  all passing, in about 2.4 seconds together; `LibraryChainsTests`, 6
  tests, still passing with the placement change; `SettingsChainsTests`
  (in `ChainEngineTests.swift`), 14 tests, passing in about 44 seconds,
  as on #103.
- The verifier found three expectations in the existing
  `SettingsChainsTests` that still had Family Setup's Voice Settings row
  leading to an unread guide and Settings' screens without Voice
  Settings; they failed on Linux until updated in this pull request.
  `ProfileChoiceTests` and `LateStageProfileTests`, which also build
  Settings' chains, need more of the app than Linux has and were not
  run; they build Settings without Voice Settings, where the row's chains
  end as they did before.
- What makes each new test fail, tried by undoing a change and running
  the tests again:
  - Family Setup's row leading nowhere the chains follow, as before this
    change: all four of `VoiceSettingsChainsTests` fail.
  - The way back at the top of the screen, or the speeds and voices not
    moved below it: `noHeldLookActsOnTheVoice` fails. It also failed on
    the iPhone at the largest text size before `fe8e6ee`.
  - `placedFromTheContentAScrolledRowMeetsBackToTalking` fails if a
    place taken from the content showed no hazard, which would mean the
    scroll sweep proves nothing; it does show one.
  - `aRowPastTheFootKeepsTheChoicesClearOfAllOfIt` failed before
    `fe8e6ee`.
- The modelled frames are CI's, read from run 43180245909's UI results
  to 0.1 point: the iPhone 17 in portrait at the default and largest
  text sizes and the 13-inch iPad in portrait at both and in landscape
  at the default size (CI drew no Voice Settings there; the model places
  it from the row). Every scroll of Family Setup that shows at least a
  point of the row, every 4 points, and the furthest; with and without
  the card's Ask button, and with a stand-in first control.
- `python3 scripts/test-docs.py`, `scripts/test-hooks.py`,
  `scripts/test-privacy.py`, and `scripts/privacy-check.py --outgoing
  --no-list` (the private list is not in this session, so that check
  covered the patterns only).

## Not verified

- The app: that Back to Family Setup lands in the row's frame on the
  iPhone and the iPad, that Family Setup keeps its scroll on the way
  back, and the new and changed UI tests themselves. CI's UI jobs are
  the first run.
- The String Catalog: "Back to Family Setup" was added by hand, as
  `scripts/test.sh unit` would add it; CI says if it differs.
- Gaze comfort, Snap to Item and where a real pointer rests: device
  checks (F4 step 3, P1 step 4).
- How long the new UI test adds to the iPad job, which was near its
  90-minute limit on one of #103's runs.

## Follow-ups

- Voice Settings' own words (Speed and its sentence, Voice) sit just
  above controls that change the speed or the voice: a look resting on
  them is a separate path, recorded in docs/HANDOFF.md, *Known gaps*.
  *(the next Settings thread)*
- Whether Set Up Step by Step's place should follow Family Setup's
  scroll as this one does is #103's question to the owner.
  *(the owner)*
- The chains still do not follow the steps after the second, where
  step 3 shows the same voice content. *(the next Settings thread)*
