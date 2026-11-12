# The check-in card, drawn and scored

*2026-11-12. Pull request #103 (`claude/project-thread-dffzed`). A cloud
thread of the coordinator's, the follow-up named in
[`2026-10-30-first-step-rows.md`](2026-10-30-first-step-rows.md),
*Follow-ups*, and found again on PR #66's captures.*

## What changed and why

Every three months Family Setup shows a passive card asking whether
anything has changed (docs/DECISIONS.md, "Check-ins come every three
months"). Until now no test could make one due, so the card was never
drawn on CI and the chains through its buttons were never scored
(docs/HANDOFF.md, *Known gaps*, the list that starts "Not scored
yet").

- **A launch option makes a check-in due.** `--check-in-due` moves the
  saved setup's dates back past three months and clears Not Now and
  Stop Asking (`CheckInPolicy.makeDue`), only in a debug build on test
  storage (`LaunchOptions.activeCheckInDue`), like every other test
  option. It goes back one day more than three months, because three
  calendar months after the day the clocks skip an hour can land an hour
  short at 02:00.
- **The card's buttons never break a word.** Not Now and Stop Asking
  sat side by side under Go Through Setup Again. At the largest text
  size on CI's iPhone 17 each had about 111 points for its words, where
  "Asking" is about 170 points wide and "Stop" and "Now" about 115 (SF
  Pro Semibold at 55 points), so each broke mid-word (AGENTS.md, "Words
  never break"; PR #66's captures). Now all three are full-width rows,
  one under another, like every other Settings row, under the card's
  panel, which keeps its heading and sentence (inside the panel, a row
  would be narrower than the content by the panel's padding). The card
  is taller by one row, and Family Setup's rows below it start lower
  while it shows; once it is answered its place is kept by passive words, as
  before, so nothing moves up under the button just chosen.
- **Go Through Setup Again opens the first step as Set Up Step by Step
  does.** A held look rests where the button was. Learn About Each Way,
  which only opens a guide, now takes the button's place
  (`SettingsLanding.goThroughRow`), and the answers start below it
  (`SetupAnswersPlace.arrivals(from:…)`, `GuidedSetupEntry.checkIn`).
  Before, the first step kept Learn About Each Way in Set Up Step by
  Step's place, so the look rested over an answer, which saves.
- **A second path the scoring found.** After Not Now or Stop Asking,
  a look held over the words that keep the card's place can meet Set
  Up Step by Step, the nearest row, and then an answer of the first
  step it opens. So on that visit Set Up Step by Step opens a first
  step whose answers also start below where the card's rows were
  (`GuidedSetupEntry.setUpStepByStepAfterTheCheckIn`). Modelled, laid
  out as before, a held look saved an answer both ways on the phone at
  the default size, and the second way on the iPad at the largest size
  too.
- **Answering the check-in unasked is a hazard.** In the chain map each
  of the card's rows changes data (`SettingsChains`), so a chain that
  reaches one fails the tests, like a saved answer.

The decisions are in docs/DECISIONS.md, "The first step's own rows",
*From the check-in card*, and "Check-ins come every three months"; the
work file is [`work/settings-chains.md`](../work/settings-chains.md),
*The check-in card*.

## Commits

- `a2b1d20` Plan the check-in card's rows and scoring in the Settings
  work file.
- `c684deb` Add a test-only launch option that makes a check-in due.
- `c59115c` Lay out the check-in card's buttons as rows and score their
  chains.
- `3673949` Record the check-in card's rows and scoring.
- `f4a0dc3` Place Go Through Setup Again's step where the button
  showed (*After review*, below).
- The commit that records it here and in docs/DECISIONS.md,
  docs/HANDOFF.md and docs/ROADMAP.md.

## Verified

This is a cloud session with no route to a Mac in this thread, so
nothing was built for iOS or run in the app here. GitHub CI is the
build: until its unit and UI runs pass on this pull request, treat the
change as untested.

The plain Swift types and the unit tests that use only them were built
and run on Linux with the Swift 6.4.2 release toolchain (Swift 6
language mode, default main-actor isolation), in a scratch package that
links the repository's files and stands in for `os.Logger` and two
SwiftUI-only names: `SettingsChainsTests`, `ChainEngineTests`,
`HomeChainsTests`, `HomeChainsTypingTests`, `SetupRecordTests`,
`SetupStoreTests`, `SetupAnswersPlaceTests`, `SettingsRowPlaceTests` and
`HomeLayoutEngineTests`, 138 tests in all, every one passing with its
known issues as before, except that with every suite at once
`SetupAnswersPlaceTests.aFrameFarTallerThanAScreenIsPlacedAtOnce` hit
its one-minute limit while it waited for the main thread behind the
chain sweeps; alone it passed in about 3 seconds. The new chain tests
take 0.06 and 0.02 seconds there; `SettingsChainsTests` as a whole took
19.6 seconds, nearly all of it the sweep, which does not draw the card.
`LaunchOptionsTests` was not run on Linux.

New tests, each with the change that would make it fail:

- `SetupRecordTests`: a check-in made due is due, and clears Not Now
  and Stop Asking, at hours 0, 2, 7, 12 and 23 of every day for two
  years. Fails if `makeDue` goes back exactly three months (it failed
  on two dates that way before the extra day), or keeps a snooze or a
  stop.
- `LaunchOptionsTests.aCheckInIsMadeDueOnlyWithDebugAndTestStorage`:
  fails if the option works on the person's own storage or in a
  release build.
- `SetupAnswersPlaceTests.theAnswersStartClearOfTheCheckInCard`: fails
  if the after-the-check-in arrivals leave out the card's rows.
- `SettingsChainsTests.theCheckInCardsRowsCloseNothingAndSaveNothingUnderTheLook`:
  on CI's windows with a check-in due, fails on any chain that closes
  Settings under the look, saves an answer (the check-in included) or
  meets an unknown control, or if Learn About Each Way is not in Go
  Through's place. Fails if Go Through's first step keeps Learn About
  Each Way in Set Up Step by Step's place, or if the after-the-check-in
  step leaves out the card's rows.
- `SettingsChainsTests.theStepsLaidOutAsBeforeWouldSaveAnAnswer`: fails
  once the old layout no longer saves an answer either way, so the
  first test cannot pass for the wrong reason. With the fix taken out
  (the after-the-check-in entry treated as the plain one), the first
  test failed on the phone, as it should.
- `SetupStoreTests`: Go Through Setup Again now opens the first step
  from the check-in.
- UI tests, run by CI only: `SettingsTests.testTheCheckInCardDrawsItsWordsWholeAndPassesTheAudit`
  (each row at least 44 points tall, across the content, its words
  each read whole from its capture by `RenderedWords`, and Apple's
  audit with the rows in view, light and dark at the default size and
  light at AX5); `SettingsTests.testAnsweringTheCheckInKeepsItsPlace`
  (after Stop Asking and after Not Now: the rows go, the words saying
  what happens next show, no row moves, and after Not Now the next
  launch shows no card); and `SettingsOnHomeTests` at the default size
  and AX5 with a check-in due, which reads the first step from the
  card and the one after it, checks Learn About Each Way against Go
  Through's frame and the first answer against the card's rows, and
  follows every chain through the card.

The Python checks (`scripts/test-docs.py`, `scripts/test-hooks.py`,
`scripts/test-privacy.py`) and `scripts/privacy-check.py --outgoing
--no-list` ran before the push; the private list was not available
here, so it was not checked.

## After review

CodeRabbit's review of the first push (one finding, marked minor)
pointed out that Go Through Setup Again's place was taken in Family
Setup's content, so with Family Setup scrolled, Learn About Each Way lay
lower than the button had shown. A probe of the chain model, Family
Setup scrolled 0 to 2,400 points, 40 at a time, wherever some of the
button shows, scored three placements of the step it opens, chains
from Go Through Setup Again only:

- in the content (the first push): hazards at 6 of 14 scrolls on the
  iPhone 17, 7 of 17 at AX5, 5 of 13 on the iPad in portrait and in
  landscape and 13 of 25 at AX5, from 320 points of scroll at the
  default size: Back to Talking, then Get Attention (alarms), No
  (speaks) or, on the iPad at AX5, a phrase (speaks);
- in Set Up Step by Step's place, as `main` had it: hazards at 9, 3, 13,
  13 and 18 of them, an answer saved at small scrolls;
- where the button showed: none, once the button's frame is cut to
  what shows between the bar and the foot of the stack and its place
  kept below the content's top, as the Library's questions keep theirs
  (`LibraryQuestionPlace`).

So the step now takes the place the button showed in
(`SetupAnswersPlace.shown`, read when the button is chosen, as
`LibraryAskingRow` does). New tests, each with the change that would
make it fail:

- `SetupAnswersPlaceTests.goThroughSetupAgainIsPlacedWhereItShowed`:
  fails if the scroll is left out or added, or if a button half under
  the bar is placed above the content.
- `SettingsChainsTests.goThroughSetupAgainOpensItsStepUnderTheLookHoweverFamilySetupScrolled`:
  the sweep above; with `shown` made to ignore the scroll, it failed at
  36 scrolls, as it should.
- `SettingsChainsTests.goThroughSetupAgainPlacedFromTheContentWouldSoundTheAlarm`:
  pins why, and fails once the content placement no longer sounds Get
  Attention on the iPhone 17 and the iPad scrolled 400 points.
- `SettingsTests.testGoThroughSetupAgainOpensItsStepWhereItShowed`
  (CI only): scrolls Family Setup, chooses the button, and fails if
  Learn About Each Way is not where the button showed.

CodeRabbit's other note (trivial): `SettingsOnHomeTests` read the two
check-in steps only where Go Through Setup Again showed, so a layout
that pushed it off the first screenful would have dropped them without
failing. It now fails if either is missing, except on the phone at
the largest size, where the card lies below the first screenful.

Set Up Step by Step still takes its row's place in Family Setup's
content (docs/DECISIONS.md, "Settings' first row, placed from Home's
frames", whose bullet on a scrolled first screen gives the reason), so
the two rows now follow different rules; whether it should follow Go Through Setup Again is a
follow-up, below.

Codex's code review of the first push found nothing, and its security
review finished. Copilot's review, asked for once on opening, was
refused for lack of the month's remaining Copilot allowance, and was
not asked for again. CI's runs on the first push were still queued,
none started, when the fixes were pushed, so the push cancelled no
running job; the second push's runs are the first to test this pull
request's code.

## Not verified

- Everything in the app until CI's runs pass: the card's drawing, the
  rows' heights and words, the audit, and every frame above. The
  numbers in docs/DECISIONS.md are the unit tests' model of CI's
  windows, not CI's frames.
- `LaunchOptionsTests` and the UI tests, which need Xcode.
- Whether the new UI tests lengthen the iPad UI job, whose runs took
  about 50 to 69 minutes before this change.
- Where a pointer rests after an activation, and how Snap to Item picks:
  device checks (docs/HANDOFF.md, "Checks that need a real device").
- VoiceOver, Voice Control and Switch Control on the card.
- The String Catalog: no words changed, but only a Mac run of
  `scripts/test.sh` brings the catalog up to date, and CI fails if it
  does not match.

## Follow-ups

- If CI's runs disagree with the model (a hazard, Learn About Each Way
  off Go Through's frame, or a word not read whole), fix it on this
  pull request. *(this thread)*
- Family Setup scrolled before Not Now, Stop Asking or Set Up Step by
  Step is chosen is not scored, and on the phone at the largest text
  size the card is always reached by scrolling. Set Up Step by Step
  could take the place it showed in, as Go Through Setup Again now does,
  reversing the reasoning in docs/DECISIONS.md, "Settings' first row,
  placed from Home's frames", on a scrolled first screen; the model's
  `scroll` can score it. *(the next Settings
  thread)*
- After the card is answered, the first step Set Up Step by Step opens
  on that visit shows no answer on its first screenful on CI's windows
  (modelled), and a family scrolls to answer. A placement that keeps an
  answer in view without meeting a look over the card's old place would
  remove that cost. *(the next Settings thread)*
- Resting over the card's own heading and sentence (reading is
  pointing) is not modelled, and the 630-window sweep does not draw the
  card. *(the next Settings thread)*
- Other Settings rows hold a single word wider than a row's room for
  words at the largest text size. On CI's iPhone 17 that room is about
  255 points (from main's Family Setup capture at AX5: the words start
  about 103 points in and the capsule's inner edge is about 28 points
  from each side), and by the same font measurement "Accessibility" is
  about 313 points (More Accessibility Settings) and "Categories" about
  270 (Phrases and Categories); on a 375-point phone the room is about
  228, and "Shortcuts" (about 243) and "Reaching" (about 231) are wider
  too. Not yet read from captures of those rows: the rendered-words
  check reads only the card's rows so far. *(the next Settings thread)*
- `main`'s iPad UI job failed on run 43180245909, before this change;
  not looked into here. *(whoever next reads that run)*
