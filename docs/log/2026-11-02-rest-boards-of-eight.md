# Rest boards of eight phrases, measured and checked

*2026-11-02. Pull request #75 (`claude/project-thread-iu6919`). The Wave 3
item 9 thread, a cloud session: GitHub CI is its first build.*

## What changed and why

The rest board (pull request #74, docs/DECISIONS.md, "The late-stage
profile"; [`2026-11-01-late-stage-profile.md`](2026-11-01-late-stage-profile.md))
was measured and tested only with a board of six phrases (Conversation),
while Basics and Needs, half the starter categories, make boards of
eight. This was found after #74's last push, while its auto-merge was
waiting for CI; #74 merged first, so the work is here.

- **Boards of eight, measured.** With the same engine, a board of eight
  takes the same sizes and frames as one of six on every iPad window in
  the windows table: four columns hold either in two rows. A resized
  iPad window narrow enough for three columns (600 to 672 points wide,
  to 720 with Bold Text) can differ, as a phone does. On a phone's
  columns a board of eight keeps every category's rows, so:
  - Yes and No grow out of the tiles' height: on the iPhone 17 both
    are 92 points tall, and so are the tiles, where with every category
    the tiles are 111.
  - The iPhone 17 Pro Max takes touch's sizes instead of head
    tracking's, which it takes with a board of six.
  - Where every category's phrases scroll, a board of eight scrolls the
    same and nothing grows. A board of six, a row shorter, stops the
    scrolling in some of those windows and not in others (the work
    file has which).
  - Tiles are whole points tall, so they can end up to a point shorter
    than Yes and No (108 against 108.8 on the Pro Max with eight).
- **Every layout test of the board runs on both boards.**
  `LateStageProfileTests.boardPhrases` is `[6, 8]`; each sweep, chain
  and share runs with both, with a windows table for eight
  (`boardTableForEight`: the same as six's but the Pro Max's row).
  `RestBoardTests` already checked the phrase count of a board of eight
  and of six; its two request tests use Conversation alone, as a
  request passes the board's count to the layout unchanged
  (`ProfileChoice.Request.phraseArea`).
  `StarterPhrasesTests.everyStarterRestBoardIsOneTheLayoutTestsMeasure`
  fails if the starter library makes a board of a size those tests do
  not measure, or if they measure one it does not make.
- **A board of eight in the app.** `HomeRestBoardTests` now also
  chooses Needs and, at the default and the largest text sizes, light
  and dark, runs Apple's audit and reads the drawn words of the quick
  controls and the everyday categories, as it does on Conversation
  (`testABoardOfEightPassesTheAuditAndDrawsItsWordsWhole`). It first
  checks that Needs is chosen, with the other three categories dimmed
  and eight phrases showing, so the test fails rather than goes on
  passing if Needs stops being a board of eight, and each launch checks
  the other three are still dimmed.
- **The second step's words.** They said the board shows its phrases
  "in fewer, larger buttons", and the summary "with larger buttons":
  untrue on every iPad and with a board of eight on a phone. The step
  now says "Home can show one category's phrases, and Emergency's,
  with Yes, No, Emergency, Again and Get Attention as large as this
  screen has room for. The other categories stay where they are,
  dimmed, so nothing moves. The change shows when Settings closes.",
  and the summary "Home shows one category's phrases:". The chain
  sweep's copy of the words (`ChainEngineTests`) and the String Catalog
  follow. With the shorter words, the step's model shows a choice on the
  first screenful on 99 of the 140 phone-height windows at the default
  size (97 before), 55 and 28 of 70 at AX3 and AX5 (53 and 26); the
  iPhone 17 still shows two.
- **The records.** The decision (*Where the board's sizes hold*, the
  dwell-safety bullet, the screenful count, and the coverage decision's
  note), the work file (its own table for boards of eight),
  docs/HANDOFF.md (the rest-board paragraph, *Known gaps*, the label
  checks and the pointer to this file), docs/ACCESSIBILITY.md,
  docs/ROADMAP.md (item 9 and the label-check gate's *Today*), two code
  comments (`HomeView`, `RestBoard`), the UI test's own comment and the
  website's accessibility page now describe both boards. #74's log said
  the board shows "fewer, larger tiles"; that sentence is corrected in
  place, as a mistake.
- **One independent review** of the records before this pull request
  found a missed *Known gaps* entry, two "fewer, larger tiles" left in
  records marked built, an incomplete account of where a board of six
  stops the scrolling, a claim about every iPad that holds only on four
  columns, and two overstatements on the website (rows on a two-column
  iPhone, "about as tall" where the tiles stay taller). Each was
  checked on the engine, then corrected.

## Commits

- `d626454`: every layout test of the board on boards of six and
  eight, with the starter library's check.
- `3ccb69d`: the second step's words and summary line.
- `7a38f33`: the records.
- `ae2a133`: the independent review's corrections.
- `c40c2f9`: the UI test on Needs, with its records.
- Then this file, with the pointers to it, and #74's log: the commits
  above had added this work to it, and it goes back to its merged text
  with the one correction.

## Verified

Nothing here was built with Xcode or run in a simulator by this thread:
it ran in a cloud session with no Xcode, so CI is the first build of
the change and the first run of its UI test.

- **The layout files on Linux**, in the Swift package #74's log
  describes (Swift 6.4.1 on Ubuntu 24.04, the project's language mode
  and default main-actor isolation, no SwiftUI, SwiftData or
  simulator): the whole suite, 217 tests in 19 suites, with the same
  three Linux-only failures as on `main` there (843 and 5 issues in
  `HomeReservedRegionTests` and
  `HomeReservedRegionChainTests.backToTalkingUsesTheFinalPhrasesFrame`)
  and nothing else. So `LateStageProfileTests` with both boards, the
  630-window sweep, and the Settings sweeps over the larger profiles
  with the new words all passed.
- **The eight-phrase table is read:** changing `boardTableForEight`'s
  Pro Max row to head tracking's failed the table test 10 times (five
  text sizes, Bold Text off and on).
- **The step's model:** with the old words it reproduces the old counts
  (97 of 140, and 53 and 26 of 70) before giving the new ones.
- **The starter library's boards:** the starter JSON's counts (Basics 8,
  Needs 8, Conversation 6, Feelings 6, Emergency 6) give the boards of
  six and eight the new `StarterPhrasesTests` test expects; the test
  itself needs the app's bundle, so it did not run here.
- **Time on Linux:** `LateStageProfileTests` took 210 s in one run,
  about 95 s more than with a board of six alone. One test at a time,
  the Settings chains over the boards took 79 s, the Yes and No shares
  55 s, Back to Talking onto the boards 34 s, the boards' chains 33 s,
  and the five sweeps over every window 14 to 20 s each, about 13 s of
  each being the shared windows they build once in a run.
- The Python checks (`scripts/test-docs.py`, `scripts/test-hooks.py`,
  `scripts/test-site.py`) passed.

## Not verified

- **All of it on CI's Mac** until CI passes: the build with warnings as
  errors, the String Catalog matching the code, and the unit tests in
  the app's build.
- **The new UI test** has never run. On the iPad, the owner's Mac ran
  Apple's audit at AX5 in dark on the Basics and Needs boards for #74,
  before the border, and it passed; on the iPhone, where a board of
  eight's frames differ from six's, nothing has drawn one. The
  six-phrase test it copies took 98 s on CI's iPad and 129 s on its
  iPhone on `2b1a9d5`, where the UI job took 96 minutes of its 120, so
  expect about 4 minutes more.
- **The step's new words in the app:** CI's run of this pull request
  is the first time `SettingsOnHomeTests` and `HomeRestBoardTests` read
  them.
- **The unit job's time on CI.** Only Linux timed the boards of eight;
  CI's result bundle has the Mac's figure (`TestCaseRuns.duration`;
  AGENTS.md, *Gotchas*, the unit job's time).
- **The flow test on a board of eight.**
  `testTheRestBoardShowsOneCategoryAndEveryCategoryPutsHomeBack` still
  chooses only Conversation. What it checks beyond the audit (the
  dimming, the phrase count, the frames kept between the board and
  Emergency, Every Category giving Home back) does not depend on which
  category is chosen, and the unit tests check a board of eight's
  frames.
- **Comfort, and every device check,** as in #74's log: the floors and
  the 4-degree growth have not been tried by a person, or with Apple's
  Eye Tracking.

## Follow-ups

- **The owner may overrule** the growth out of the tiles with a board
  of eight on a phone (92-point tiles on the iPhone 17 with Basics or
  Needs, where every category's are 111), and head tracking's sizes on
  the iPhone 17 Pro Max with a board of six only (docs/DECISIONS.md,
  "The late-stage profile", *Where the board's sizes hold*), along with
  #74's floors, 4-degree growth and growth on four columns.
- **Device checks** of the board, both sizes, with a person using Eye
  Tracking (docs/ROADMAP.md, *The quality bar*, Q11 and Q13): the owner
  and Codex.
