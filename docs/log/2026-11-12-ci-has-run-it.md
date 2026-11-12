# Say what CI measured where the documents still waited for it

*2026-11-12. Pull request (`claude/project-thread-wl7fv0`). A cloud
thread, from docs/ROADMAP.md, *The quality bar*, Q26's thread check,
picked after the coordinator's brief found that the Snap to Item item
(pull request #81's last follow-up, device check B2 step 3) is the
owner's, on a device, and not a coding job.*

## What changed and why

Q26 asks that docs/HANDOFF.md say nothing stale, "such as 'untested
until CI runs it' about work CI has run", and its *Today* line pointed
to the list in
[`2026-10-30-sizes-switched-on.md`](2026-10-30-sizes-switched-on.md),
*Follow-ups*. Those lines came from two pull requests that merged on
green CI:

- **Pull request #56** (Settings' first row, placed from Home's frames,
  2026-10-25). Its record already says CI read the real frames: run
  40183035156 on `4e34c0a`, and the run on its final head, 40188414972
  on `f44f17f`, which passed the unit and UI tests
  ([`2026-10-25-settings-row-place.md`](2026-10-25-settings-row-place.md),
  *Verified*).
- **Pull request #66** (the first step's own rows, 2026-10-30). Its
  record was written before CI ran and still said "untested until
  GitHub CI's unit and UI runs pass"; records are not rewritten, so the
  result is here, below.

Each line now says what CI measured, and where the claim rests only on
the model (the 630 swept windows), it still says so:

- docs/DECISIONS.md: *One chain engine for dwell safety* (two places),
  *Typing on Home*, and the opening paragraphs of *Settings' first row,
  placed from Home's frames* and *The first step's own rows*.
- docs/ROADMAP.md: Wave 3 item 7's 2026-10-30 entry, and Q26's *Today*
  line.
- docs/HANDOFF.md, *Next steps, in order* (the paragraph for agents).

Two more lines of the same list, in docs/HANDOFF.md (*What the app does
today* and *Known gaps*, on the first step's rows), were left at first,
because the check-in card's pull request (#103) was rewriting both. It
merged on 2026-11-12, and its rewrite left neither waiting for CI, but
it added a line of the same kind to *Known gaps*: the card's rows,
scored by `SettingsChainsTests` and by `SettingsOnHomeTests` with
`--check-in-due`, "untested in the app until CI runs that change". CI
had run that change on #103's final head, so after `main` was merged in,
that line says what CI measured.

Seven work files in docs/work/ also still gave the status they had
before their pull requests merged: five waited for CI ("untested until
CI passes", or "in review; untested in the app until CI runs it") and
two said "building". They are Settings on Home (#33), Get Attention on
Home (#38), Typing on Home (#53), Settings' first row (#56), the
late-stage profile (#74), the Library screen (#80) and four phrases in
every category (#81). Each now says "done", the word
[`docs/work/README.md`](../work/README.md) gives a finished work file,
with its pull request, the day it merged and the CI run on its final
head. docs/ROADMAP.md, Q26's *Today* line, says so too.

The same kind of line waited for CI to move to Xcode 27.2: "CI moves by
itself once GitHub installs the release". It has moved, so
docs/HANDOFF.md, *Verification*, docs/DECISIONS.md, "Build with Apple's
current Xcode" (a dated note where it tells of the Mac moving first), and
docs/APP-STORE.md, section 2's table, now say so. That also meets the
first follow-up of
[`2026-10-30-xcode-27-2.md`](2026-10-30-xcode-27-2.md), which made the
first CI run on 27.2 the UI tests' check on it, with a pull request to
fix whatever 27.2 reported: runs on 27.2 have passed the UI tests,
pull request #81's among them. Two failures on 27.2 are known, neither
shown to come from 27.2 (the rest of this paragraph was corrected
after this pull request merged; it first said "so there was nothing to
fix":
[`2026-11-12-ci-claims-narrowed.md`](2026-11-12-ci-claims-narrowed.md)).
`HomeAccessibilityOrderTests` failed once on pull request #82's run
and passed on its last commit and on the Mac's iOS 27.2
(docs/HANDOFF.md, *Known gaps*, followed there as possibly
intermittent). This pull request's own first iPhone UI run failed once
in `SettingsTests.testAnIdleSettingsReturnsToItsFirstScreenAndStaysOpen`
and passed on its re-run (run 43277240579, on `be87979`); that test
had already failed once on a branch that did not touch it on
2026-10-22, before 27.2 (its tap found no hit point:
[`2026-10-22-audit-still-screen.md`](2026-10-22-audit-still-screen.md)),
and once on 2026-11-08 with the same words
([`2026-11-08-privacy-check-follow-ups.md`](2026-11-08-privacy-check-follow-ups.md)).
So no fix for 27.2 was found to be needed.

Nothing in the app changed.

## Commits

- The corrections and this record.
- The result of pull request #66's run narrowed to the chains the UI
  tests score, after review.
- A merge of `main`, after pull request #103 merged.
- The check-in card's line and the seven work files' status lines.

## Verified

Read from GitHub's records of each run, on 2026-11-12:

- **Pull request #66, run 41005078813, on `380ef7d`**, its final head
  and the commit that merged: "Unit tests" and "UI tests" both passed.
  The unit job's log: "804 tests ran on iPad Pro 13-inch (M5) (iOS
  Simulator 27.0): 795 passed, 0 failed, 1 skipped, 8 expected
  failures", the strict known issues the unit tests keep, so "no
  expected failure" is the UI tests' only (corrected after this pull
  request merged:
  [`2026-11-12-ci-claims-narrowed.md`](2026-11-12-ci-claims-narrowed.md)).
  The UI job's log: Xcode 27.1 (27A9275), chosen because GitHub's image
  then held only 27.2's release candidate; on the iPad Pro 13-inch (M5),
  iOS 27.0, "59 tests ran ... 57 passed, 0 failed, 2 skipped, 0 expected
  failures"; on the iPhone 17, iOS 27.0, "59 tests ran ... 53 passed, 0
  failed, 6 skipped, 0 expected failures". `SettingsOnHomeTests` passed
  at the default text size and the largest on both, and in landscape on
  the iPad (skipped on the iPhone, which is portrait only).
  `testTheFirstStepOpensWithLearnAboutEachWayOverSetUpStepByStep` passed
  on both. `SettingsOnHomeTests` fails on any held look that saves an
  answer or closes Settings in the chains it scores (from Home's
  Settings through Settings' first screen, Family Setup, and the first
  step with its guide, each as it first shows; the pull request's
  record, *Verified*), and no UI test was an expected failure, so the
  strict known issue for the phone at its largest size was gone too.
  What docs/DECISIONS.md, "The first step's own rows", lists as not
  scored was not scored by this run either: a review on this pull
  request found that the first wording claimed more, and it was
  narrowed.
- **Pull request #56, run 40188414972, on `f44f17f`**: concluded
  "success". The rest is that pull request's own record.
- **Pull request #103, run 43249231746, on `0c53792`**, its final head:
  "Unit tests" passed, and "UI tests" passed on the run's second
  attempt, after the first attempt's iPad job was cancelled at its
  90-minute limit (the iPhone job had passed). Both UI jobs ran on
  GitHub's `xcode-27-arm64` image, version 20261104.0337.1, with Xcode
  27.2 (27B52): "80 tests ran on iPad Pro 13-inch (M5) (iOS Simulator
  27.2): 77 passed, 0 failed, 3 skipped, 0 expected failures" and "80
  tests ran on iPhone 17 (iOS Simulator 27.2): 73 passed, 0 failed, 7
  skipped, 0 expected failures". On both,
  `testOpeningSettingsWithACheckInDueAtDefaultText`,
  `testOpeningSettingsWithACheckInDueAtTheLargestText` and
  `testAnsweringTheCheckInKeepsItsPlace` passed.
- **The seven work files' pull requests**, each on the run named in its
  status line: #33 (39899663714), #38 (39923081723), #53
  (40153289149), #56 (40188414972), #74 (41427429086), #80
  (42014189828) and #81 (42042331740). Each run concluded "success" on
  the head that merged (the pull request's head when it merged, read
  from GitHub, and the day it merged). Of their job logs, only #81's
  (below) was read here.
- **Pull request #81, run 42042331740, on `f8c6d7f`** (2026-11-05):
  both UI jobs ran on GitHub's `xcode-27-arm64` image, version
  20261104.0337.1, with Xcode 27.2 (build 27B52), and passed: "71 tests
  ran on iPad Pro 13-inch (M5) (iOS Simulator 27.2): 69 passed, 0
  failed, 2 skipped, 0 expected failures" and "71 tests ran on iPhone 17
  (iOS Simulator 27.2): 65 passed, 0 failed, 6 skipped, 0 expected
  failures". The unit job also passed; its Xcode is as that pull
  request's description gives it (27.2, 27B52), not read from its log
  here.
- `scripts/test-docs.py`, `scripts/test-hooks.py` and
  `scripts/test-privacy.py` pass, and
  `scripts/privacy-check.py --outgoing --no-list` finds nothing (results
  in the pull request).

## Not verified

- Whether 41005078813 or 42042331740 were the first runs of their kind:
  each is a run that shows the claim, not necessarily the earliest.
- The 630 swept windows, which stay modelled: no UI test draws them.
- Anything a device would show: where a pointer rests after an
  activation and how Snap to Item picks, which decide whether the
  modelled chains bind (docs/DEVICE-CHECKS.md, F1).
- The rest of Q26: the privacy policy, the website and its
  accessibility page, the README, the App Store text and the review
  notes, against a release build. No release build exists yet.
- docs/HANDOFF.md as a whole: only lines waiting for CI were looked
  for (by searching for "untested", "until CI" and their variants, and
  for CI's Xcode); a full read for other stale lines was not done.

## Follow-ups

- **Later pull requests** that write "untested until CI runs it", in
  docs/HANDOFF.md or a work file's status, leave this kind of line once
  their CI has run, and a work file that merges still says "building"
  unless its pull request changes it. *(The next thread that edits
  those lines, or the Q26 check before release.)*
- **Q26 in full**, against the release build. *(A thread, before App
  Review.)*
