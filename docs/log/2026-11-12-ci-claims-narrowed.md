# Two CI claims narrowed to what the runs showed

*2026-11-12. Pull request (`claude/project-thread-wl7fv0`). The cloud
thread that made pull request #104, correcting two of its claims that a
check before it was called ready found too broad. #104 merged on green
CI before the correction was pushed.*

## What changed and why

Pull request #104
([`2026-11-12-ci-has-run-it.md`](2026-11-12-ci-has-run-it.md)) wrote
what CI had measured where the documents still waited for it. The
verifier (`.claude/agents/verifier.md`), run on its head `be87979`,
read the job logs again and found two claims broader than the runs:

- **docs/DECISIONS.md, "The first step's own rows"**, said pull request
  #66's run 41005078813 "passed the unit and UI tests with no expected
  failure". Its UI tests had none, but its unit job's log reads "804
  tests ran on iPad Pro 13-inch (M5) (iOS Simulator 27.0): 795 passed,
  0 failed, 1 skipped, 8 expected failures": the strict known issues
  the unit tests keep. It now says no UI test was an expected failure,
  which is all the sentence's conclusion (no chain the UI tests score
  saves an answer or closes Settings) rests on. #104's record already
  said it that way; its own description did not.
- **#104's record** said that, because runs on Xcode 27.2 had passed
  the UI tests, "there was nothing to fix" for 27.2. Two failures on
  27.2 are known: `HomeAccessibilityOrderTests` once on pull request
  #82's run (docs/HANDOFF.md, *Known gaps*), and
  `SettingsTests.testAnIdleSettingsReturnsToItsFirstScreenAndStaysOpen`
  once on #104's own first iPhone run. Neither is shown to come from
  27.2: the first passed on #82's last commit and on the Mac's iOS
  27.2, and the second had failed the same test before 27.2, on
  2026-10-22. The record now names both and says no fix for 27.2 was
  found to be needed, with a note that the paragraph was corrected
  after merging. Its #66 entry also gains the unit job's line.

docs/log/README.md lets a merged record be corrected ("correct a
mistake in it"), so #104's record is corrected in place, and this file
records the correction. docs/HANDOFF.md, *Known gaps*, also gains the
idle-Settings UI failure (below), seen three times now on branches that
did not touch it. Nothing in the app changed.

## Commits

- The two corrections (made before #104 merged, pushed after).
- A merge of `main`, after #104 merged.
- The correction notes in #104's record, the idle-Settings gap in
  docs/HANDOFF.md, and this record.

## Verified

Read from GitHub on 2026-11-12, from the job logs the verifier saved:

- **Pull request #66, run 41005078813, on `380ef7d`**, unit job: "804
  tests ran on iPad Pro 13-inch (M5) (iOS Simulator 27.0): 795 passed,
  0 failed, 1 skipped, 8 expected failures". UI jobs: "59 tests ran
  ... 0 expected failures" on both the iPad Pro 13-inch (M5) and the
  iPhone 17, iOS 27.0.
- **Pull request #104, run 43277240579, on `be87979`**: the iPhone UI
  job's first attempt, "75 tests ran on iPhone 17 (iOS Simulator 27.2):
  67 passed, 1 failed, 7 skipped", the failure being
  `SettingsTests.testAnIdleSettingsReturnsToItsFirstScreenAndStaysOpen`
  ("Family Setup did not open after familySetup was chosen"); its
  second attempt, "75 tests ran ... 68 passed, 0 failed, 7 skipped, 0
  expected failures".
- **#104's final head, `0b29a66`** (run 43302240769): every check
  passed on its first attempt, and it merged on it.
- `scripts/test-docs.py` passes, and
  `scripts/privacy-check.py --outgoing --no-list` finds nothing (the
  private list was not checked: this cloud session has none).

## Not verified

- Whether the idle-Settings failure and the `HomeAccessibilityOrderTests`
  failure have a cause tied to 27.2: neither has been reproduced on
  purpose.
- Everything #104's record lists under *Not verified* still stands.

## Follow-ups

- **The idle-Settings UI failure** (docs/HANDOFF.md, *Known gaps*),
  now seen three times on branches that did not touch it. A likely
  cause, not proven: under `--short-timeouts` Settings' idle limit is 3
  seconds, and each reset changes the navigation stack's identity even
  on its first screen, so a tap can land on a rebuild. On a real device
  the same happens every 90 seconds on Settings' first screen, where it
  costs at most a lost activation. The fix touches Settings or its
  test. *(A Settings thread, in its own pull request.)*
