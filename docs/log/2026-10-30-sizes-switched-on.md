# Home's sizes switched on, and #69's loose ends

*2026-10-30. Pull request on `claude/project-thread-ffwagr`, after #69
merged. The thread that built Wave 3 item 8.*

## What changed and why

**For the person using Brickson,** Home's sizes now follow Family
Setup's answer to how the screen is reached, as #69 built them:

- Before anyone answers, Home has the largest sizes the window holds.
  Every iPad in portrait gets Eye Tracking's: quick controls at least
  109 points, phrase tiles at least 136, 15 points apart. The one
  exception is the iPad mini in portrait with Bold Text, which gets
  head tracking's.
- An answer of Switch Control, Head Tracking or Eye Tracking gets those
  sizes wherever the window holds them. Touch, Voice Control and
  Someone Else Helps get touch's.
- Every phone keeps touch's sizes, because no phone holds the larger
  ones without scrolling.
- Nothing changes place as the sizes change, and new sizes show when
  Settings closes.
- Family Setup's first step now says what its answers do.

The owner chose this on 2026-10-30 by tapping "Use the largest sizes
that fit", answering what Home does where a window cannot hold the
sizes asked for (docs/DECISIONS.md, "Sizes that follow how the screen
is reached", *Switched on by the owner*). #69 had built the sizes held
because only the owner could accept that reading of invariant 11.

Two things the owner's card did not settle:

- **Scrolling at touch's sizes.** The card said the phrases never
  scroll. At touch's sizes they still do on phones smaller than the Pro
  Max at AX5, on a 375×667 phone and 320-point windows at every size,
  and on other windows (docs/HANDOFF.md, *Known gaps*). That stays an
  invariant 11 gap for R0's item 3, not part of what the owner
  accepted, and the owner was told when this pull request opened.
- **Back to Talking's frame.** #69's record said switching on would
  also accept Settings' way back at touch's size under the larger
  sizes. The card did not ask that, so a second card does. The switch
  went ahead of that answer because it is one line to undo; the answer
  holds a build with the larger sizes back from App Review and external
  TestFlight groups, as the three dwell hazards do.

**In the code and the rules:**

- `ProfileChoice.followsTheAnswer` is on. It stays as the line a build
  changes to go out without the larger sizes. Turning it off holds Home
  at touch's sizes for every answer again, with only
  `--home-profile=from-answer` on test storage following the answer;
  the pin in `ProfileChoiceTests` is then reversed and `HomeSizesTests`
  asks for `from-answer` again.
- The first step's sentence on sizes follows the owner's switch, not
  whether a UI test fixed Home's sizes (`BricksonApp`), so every
  Settings UI test draws the first step as people see it: its audit,
  and `SettingsOnHomeTests`' measured chains. Before, only a launch
  that followed the answer drew it, so the shipped step went unaudited.
- AGENTS.md, invariant 11, now says that the floor a window must not go
  below is the floor of the profile it takes, and that a window which
  cannot hold the floors asked for takes the largest smaller profile it
  holds, touch's last. Where even touch's sizes scroll, a dwell, switch,
  head or gaze answer still breaks the invariant there. That is a
  narrower reading of an invariant, made by the owner's choice, and no
  wider than it.
- docs/DECISIONS.md records the answer:
  - *Waiting on the owner* swaps the answered question for the one
    still open: whether Settings' Back to Talking keeps touch's frame
    under the larger sizes. The owner's card did not ask that, so a
    second card does, and touch's frame stays as recommended until the
    answer comes. With each profile's own frame, a look resting on
    Back to Talking as Settings closes meets Type, Get Attention or
    Again. With touch's frame it meets only Phrases.
  - *Layouts from the space available* now states the new rule, with
    a *Before* line, and *Fewer tiles to a screen, for R1* says where
    fewer tiles would still help.
  - The UIKit exceptions row names `HomeSizesTests`, whose screenshots
    are `UIImage`s.
  - *Held until the owner answers* stays, dated, as the history beside
    *Switched on by the owner*, because #69's log cites it.
- docs/ROADMAP.md (item 8 and R0's *Release gate*), docs/HANDOFF.md,
  docs/ACCESSIBILITY.md, the work file, the website's accessibility page
  and the README now say the sizes are in place. The website also says
  which windows take smaller sizes, that a recipe or saved gesture
  tapping a fixed spot needs recording again after the answer changes,
  which checks run at which sizes, and that Yes and No border most of
  the message.
- The three open dwell hazards still hold any build with the larger
  sizes back from App Review and external TestFlight groups until each
  is gone or accepted (R0's *Release gate*). Switching on in `main` does
  not send a build anywhere.

**Tests:**

- `ProfileChoiceTests.homeFollowsTheAnswerSinceTheOwnerSwitchedItOn`
  fails if the switch is off.
- The Settings chain sweep now scores the first step with its sentence
  on sizes (`ChainEngineTests`, `sizesHeight`), as everyone gets it.
- `HomeSizesTests` launches as a person does. Its flow test checks Eye
  Tracking's sizes on an iPad in portrait, touch's on a phone, the
  first step's sentence, and touch's again once Touch is chosen. It
  also runs Apple's audit on Settings' first screen, Family Setup and
  the first step over that Home, each once the screen before it has
  gone.
- `testTheLargerSizesPassTheAuditAndDrawTheirWordsWhole` is new. At the
  default and the largest text size, light and dark, it runs Apple's
  audit on a person's first launch. It also reads the drawn words of
  Yes, No, Emergency, Get Attention and Again, and, where the larger
  sizes hold, of Phrases, Type and the four everyday categories
  (`RenderedWords`).
- On an iPad in portrait, the new test first fails if Home is not at
  Eye Tracking's sizes, so it cannot pass by checking touch's.

**#69's loose ends, in the same pull request:**

- **docs/HANDOFF.md** now names an external TestFlight group beside App
  Review in the three places that name the open dwell hazards, as the
  roadmap and DECISIONS already did. CodeRabbit found the mismatch
  outside #69's last diff. It waited for this pull request rather than
  restart #69's CI for wording.
- **AGENTS.md**, *Gotchas*, gains "The unit job uses most of its 40
  minutes" (below).

## What happened to #69's unit tests

#69's last push (4d81491) ran its UI tests green on the iPad and the
iPhone. Its unit job (run 41042583501) was cancelled by GitHub at the
job's 40-minute limit ("The job has exceeded the maximum execution time
of 40m0s") while the tests were still running. No test had failed. The
machine was slow, measured on steps the change did not touch:

| Step | main at 5c07480 | #69's first run | the cancelled run | its re-run |
|---|---|---|---|---|
| `test-hooks.py`, 124 tests | 71.5 s | 57.2 s | 132.6 s | 83.4 s |
| `test-runner.py`, 56 tests (54 on #69's first run) | 33.7 s | 23.5 s | 46.2 s | 24.5 s |
| Starting the simulator and building | 10.3 min | 10.3 min | 16.3 min | 14.5 min |
| The tests | about 14 min | about 15 min | stopped after 20 min | about 16 min |
| The whole job | 26.8 min | 27.7 min | stopped at 40 min | 33.3 min |

The job was re-run once on the same commit and passed. It ran 823
tests: 814 passed, 0 failed, 1 skipped and 8 expected failures. Main had
804, with the same skip and expected failures. The owner merged #69 after
the re-run.

Why the tests take about the sum of their times: the unit tests are
main-actor isolated by default (`project.yml`), so they share the main
thread. On Linux with four cores, `ProfileChoiceTests` took 165 seconds
of wall time and 164 seconds of processor time, and every test in it
reported finishing after 165 seconds. Run alone, its word sweep took 30
seconds, its place sweep 35 and its chain sweep 73. #69 added about two
minutes to a normal run.

## Commits

- 1e537fe: Name external TestFlight beside App Review in the handoff's
  hazard lines. Written before #69 merged, and carried onto the merged
  `main`.
- The commits after it: the gotcha and this record, the switch and its
  tests, and the documents for the owner's answer.

## Verified

- Made in a cloud session, so nothing was built with Xcode. GitHub CI
  is the build, and the new UI test first runs there.
- **Linux, Swift 6.4.1.** The layout and chain unit tests, built from
  this branch's files, were run with the switch on, in 12 minutes. They
  include `ProfileChoiceTests` and the Settings chain sweep that now
  scores the first step with its sentence on sizes. All passed except
  the one check that fails only on Linux, as it did for #69:
  `HomeReservedRegionChainTests.backToTalkingUsesTheFinalPhrasesFrame`,
  where Linux's Foundation says a rect does not contain another that
  prints identically. That test runs at touch's sizes, which this
  change does not alter.
- `python3 -I scripts/test-docs.py`, `scripts/test-hooks.py` and
  `scripts/test-site.py` pass.
- The timings above come from the GitHub Actions logs of runs
  41040560867 (main), 41031065358 and 41042583501 (both attempts).

## Not verified

- No person has used the larger sizes on a device. The switch and head
  floors are proposals from studies, none with Apple's Head Tracking or
  Eye Tracking, or with people with ALS.
- Apple's audit and the drawn words at the larger sizes, until this pull
  request's CI runs `HomeSizesTests`. The audit cannot judge comfort,
  and the words are read only on the iPad in portrait at the larger
  sizes. No CI window holds head tracking's or Switch Control's sizes,
  so those are checked only by the layout engine's unit tests.
- Settings' first screen, Family Setup and the first step over the
  larger Home, and the first step with its sentence in every Settings
  UI test, until this pull request's CI runs them. The heights pinned
  in `ChainEngineTests`' `ModelledWindow` were measured without the
  sentence; the unit sweep models it.
- Whether Vision reads every label whole beside its icon. At the larger
  sizes the controls have room for their icons, and a symbol read as a
  letter joined to a word would fail the whole-word match. The kept
  captures show which, if it happens.
- Why the slow machine was slow. GitHub does not say which machine a
  job ran on.
- How CI's speed compares with the Linux timings. They show what each
  sweep costs relative to the others, not CI's minutes.

## Follow-ups

- *(owner, before App Review or an external TestFlight group)* Answer
  whether Back to Talking keeps touch's frame under the larger sizes
  (the card in the item 8 thread). The switch went ahead of this
  answer, which #69's record had made a condition of switching on. If the owner chooses
  the larger frame, it is built with a placement that keeps Type, Get
  Attention and Again from under a resting look, or the hazard goes to
  the owner measured.
- *(owner, before App Review or an external TestFlight group)* The three
  open dwell hazards, unchanged (docs/HANDOFF.md, *Known gaps*).
- *(device checks)* The floors' comfort with Eye Tracking, Head Tracking
  and Switch Control's point scanning on an iPad (docs/HANDOFF.md,
  *Checks that need a real device*).
- Compare the first step's measured heights in this pull request's
  captures with `ModelledWindow`'s model of the sentence, and pin them.
- If unit jobs keep ending near 40 minutes on normal machines, raising
  the limit is a change to `.github/workflows/tests.yml`, which the owner
  pastes (AGENTS.md, *Gotchas*). The other way is to cut what a sweep
  costs without weakening it. Neither is needed yet.
