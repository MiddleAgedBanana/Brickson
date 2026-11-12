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
today* and *Known gaps*, on the first step's rows), are left as they
are: the check-in card's pull request (#103) rewrites both, and editing
them here too would only make the two pull requests conflict.

The same kind of line waited for CI to move to Xcode 27.2: "CI moves by
itself once GitHub installs the release". It has moved, so
docs/HANDOFF.md, *Verification*, docs/DECISIONS.md, "Build with Apple's
current Xcode" (a dated note where it tells of the Mac moving first), and
docs/APP-STORE.md, section 2's table, now say so. That also meets the
first follow-up of
[`2026-10-30-xcode-27-2.md`](2026-10-30-xcode-27-2.md), which made the
first CI run on 27.2 the UI tests' check on it, with a pull request to
fix whatever 27.2 reported: runs on 27.2 have passed the UI tests,
pull request #81's among them, so there was nothing to fix.

Nothing in the app changed.

## Commits

- One commit: the corrections and this record.

## Verified

Read from GitHub's records of each run, on 2026-11-12:

- **Pull request #66, run 41005078813, on `380ef7d`**, its final head
  and the commit that merged: "Unit tests" and "UI tests" both passed.
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

- **When the check-in card's pull request (#103) merges**, its own new
  "untested in the app until CI runs that change" line, and any others
  like it from later pull requests, become this kind of line once
  their CI has run. *(The next thread that edits that part of
  docs/HANDOFF.md, or the Q26 check before release.)*
- **Q26 in full**, against the release build. *(A thread, before App
  Review.)*
