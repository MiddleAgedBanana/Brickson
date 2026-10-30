# The first setup step's own rows

*2026-10-30. Pull request #66 (`claude/project-thread-0bj4p6`). The
Settings thread after PR #56 (ROADMAP Wave 3 item 7, PR #56's
leftovers), a cloud session: GitHub CI is its build.*

## What changed and why

PR #56 placed Settings' first row from Home's frames and left two
hazards for this change (docs/DECISIONS.md, "Settings' first row,
placed from Home's frames", *What remains, each a strict known issue
that fails when it clears* and *What it costs, for the owner to
weigh*): a look held on Home's Settings went through Family Setup and Set Up Step by
Step to one of the first step's answers and saved it, on every CI
window (accepted by the owner on 2026-10-25 only until this change);
and on the phone at its largest text size a look held on through the
first step met Back to Talking and closed Settings over No or Get
Attention. This change removes both, in the models (docs/DECISIONS.md,
"The first step's own rows"):

- **Learn About Each Way** opens the first step, in Set Up Step by
  Step's frame as Family Setup drew it, at least as tall, with the
  question beside it, above it or under it (`SettingsLanding.guidedRow`,
  `SettingsLeadIn`).
- **The answers start below every place a look can be resting on the
  way in** (`SetupAnswersPlace`, a new plain type with its own tests):
  every point of Home's Settings, the root's row and Set Up Step by Step
  lies nearer the link than the first answer.
- **The guide is a cover of its own** (`EachWayCover`), with one
  control, Done, in Back to Talking's frame (`SettingsSafetyBar` with
  `way: .done`). The link was built and held on 2026-10-24 (commit
  `1de50f5`) because the pushed guide had only Back and Back to Talking
  near the look; pushed, it still sounds the alarm on the phone
  (`aPushedGuideWouldSoundTheAlarm`).
- **Next only moves on.** With the answers placed, the sweep found Next,
  which saved the answers unchanged, nearest a look at the lower part of
  Home's Settings on 212 of the 630 swept windows (135 at AX5, 75 at
  AX3, two 568 points tall at the default size) and on CI's phone at
  AX5. The owner's acceptance ended with this change, so Next stopped
  saving, and the check-in card's Go Through Setup Again answers the
  check-in as it opens the first step, with the answers as they are
  (`CheckInPolicy.wentThroughAgain`, through
  `SetupStore.goThroughSetupAgain`). A failed save there keeps the card,
  shows the setup warning and opens nothing.

The chain map (`SettingsChains`) knows the link (opens the guide), the
guide's Done (back to the first step) and Next (on to step 2, not
followed); `showsAnAnswer`, which scoped the old strict expectations,
is gone. `SettingsOnHomeTests` opens the guide from the first step,
checks that Done is in Back to Talking's frame, scores the chains
through it, and fails on any hazard. The sweep
(`noSweptWindowClosesSettingsOrSavesAnAnswerUnderTheLook`) now draws
the first step and the guide (`SweptFamilySetup`), and the CI-window
model (`theFirstStepsOwnRowsCloseNothingAndSaveNothingUnderTheLook`)
adds the phone at AX5 from PR #56's CI frames.

Also in this pull request, PR #56's leftovers:

- PR #56's wording patch (from the project's files, as its own commit):
  docs/HANDOFF.md and that pull request's log no longer say the sweep
  covered the first step, and the log notes what the re-run gave.
  *Re-checked here:* the run on PR #56's final head, `f44f17f` (Actions
  run 40188414972), passed the unit and UI tests, so the log says so.
  That is a correction to a merged log entry, which `docs/log/README.md`
  allows.
- AGENTS.md, *Workflow rules*, gains the coordinator's evidence rule:
  evidence later work needs goes in a git-ignored folder in the
  worktree or under `docs/log/`, never `/tmp` and never only in a chat;
  and `SetupAnswersPlace` joins the list of plain logic types.
- The public accessibility page (`site/accessibility/index.html`) drops
  the two limits this removes, says where the first step's link and
  answers are, adds the guide to the audited screens, and is dated
  October 30, 2026. docs/ACCESSIBILITY.md has no row this changes.

## Commits

- `8376dc9` Say the sweep stops at Family Setup, and what the re-run
  gave (PR #56's patch, applied unchanged).
- `a0527e6` Place the first setup step's own rows (app, unit and UI
  tests).
- The documentation commit that adds this file, and the AGENTS.md rule.
- After Codex's review: the check-in card's action moves into
  `SetupStore.goThroughSetupAgain`, with tests that make its save fail.

## Verified

- **Nothing was built for iOS here.** This is a cloud session with no
  Xcode; the change is untested until GitHub CI's unit and UI runs pass.
- **On Linux, Swift 6.4.1 (release build), in a scratch package** that
  compiles the pure layout files and the chain engine with the unit
  tests that need no Apple framework: `SettingsChainsTests`,
  `ChainEngineTests`, `HomeChainsTests`, `SettingsRowPlaceTests`,
  `SettingsLeadInTests` and `SetupAnswersPlaceTests` pass (52 tests;
  `homesSettingsMeetsTheRow`'s 32 known issues are main's). The new
  check-in test was run from a copy, since its file also tests a
  SwiftUI type. The scratch package's full run also fails 30 cases of
  `HomeReservedRegionTests.everyMeasuredTextSizeAndBoldTextKeepsTargetsClear`,
  whose files this change does not touch. They pass on `main`'s CI, so
  the difference lies between the scratch package on Linux and the iOS
  build; its cause is unknown, since it was not investigated (CI is the
  check).
- What each new test fails on:
  - `SetupAnswersPlaceTests`: an answer top where a point of the
    arrivals is as near the first answer as the link, or one more than a
    point lower than it needs to be; Home's Settings dropped from the
    arrivals.
  - `theFirstStepsOwnRowsCloseNothingAndSaveNothingUnderTheLook`: on the
    phone at AX5, Next saving again (one save), or the answers back
    under the link; on every window, the guide pushed.
  - `noSweptWindowClosesSettingsOrSavesAnAnswerUnderTheLook`: Next
    saving (212 windows), the answers where main drew them, or the
    guide pushed.
  - `aPushedGuideWouldSoundTheAlarm`: a pushed guide that no longer
    closes Settings over Get Attention on the phone, or the cover
    closing anything.
  - `goingThroughSetupAgainAnswersTheCheckInWithTheAnswersAsTheyAre`:
    the card's answer changing the answers, or not restarting the
    check-in clock.
  - `SetupStoreTests.goingThroughSetupAgainAnswersTheCheckInThenOpensTheFirstStep`
    and `goingThroughSetupAgainOpensNothingWhenTheCheckInCannotBeSaved`
    (added for Codex's review): the card's action opening the first step
    after a failed save (checked: with the save's result ignored, the
    second fails), keeping an answer that was not saved, or opening
    anything but the first step. Run on Linux with a stand-in for
    Apple's `Logger`.
  - `testTheFirstStepOpensWithLearnAboutEachWayOverSetUpStepByStep` (UI,
    default and AX5): the link off Set Up Step by Step's frame by more
    than a point, shorter than it, another button in that frame, or the
    first answer within a row's gap of the link.
  - `SettingsOnHomeTests`: any held-look save or closing, Done off Back
    to Talking's frame, or a control the chains do not know on the
    guide.
- `scripts/test-docs.py`, `scripts/test-hooks.py` and
  `scripts/test-site.py` pass.

## Not verified

- The app itself: layout, the cover's presentation, Done's frame, the
  answers' place and the accessibility audit of the guide, until CI's UI
  run reads them on the iPhone 17 and the 13-inch iPad.
- The modelled numbers (answers at 572 on the iPhone 17, 553 and 552 on
  the iPad, 763 on the iPad at AX5, below the window on the phone at
  AX5) are the unit tests' model, not CI's frames.
- The sweep's first step: the question's height, Next's place and the
  sound line's height are modelled, checked only against CI's phone and
  iPad at the default size and AX5.
- The check-in card's new button: no UI test can make a check-in due,
  so its tap and its afterword were not run in the app; its action,
  failed save included, is unit-tested through `SetupStore`.
- Where a pointer rests after an activation, and how Snap to Item picks:
  device checks (docs/HANDOFF.md, "Checks that need a real device").
- VoiceOver, Voice Control and Switch Control on the guide's cover.

## Follow-ups

- If CI's UI run disagrees with the models (a hazard found, or Done off
  Back to Talking's frame), fix it on this pull request. *(this thread)*
- A launch option that makes a check-in due, so the card's buttons and
  the chain after Go Through Setup Again can be read by the UI tests.
  *(the next Settings thread)*
- Wave 3 item 8, which lets the setup answers change Home's sizes,
  starts after this, when the owner says. *(the coordinator)*
