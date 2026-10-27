# Explicit all-rights-reserved notice

*2026-10-27. Pull request #65 (`codex/all-rights-reserved`). Codex; owner-requested.*

## What changed and why

Added the root `LICENSE.md` with Avery Dedmon's copyright notice and an
explicit reservation of rights for Brickson's original source code and
accompanying documentation. Reuse requires prior written permission,
subject to applicable law and GitHub's terms. Third-party material keeps
its applicable terms.

The README links the notice, explains the permission requirement and
points to the website's contact details. The owner's choice is recorded in
docs/DECISIONS.md, "Brickson's code is all rights reserved". Handoff and
roadmap wording no longer list licensing as an outstanding owner decision.
No open-source license is granted.

The owner requested the `.md` extension to match the repository's other
documents. The follow-up renames the notice without changing its text
and updates every active filename reference.

The shared briefing records the owner's authorization for the copyright
attribution in these notices and the licensing decision record. This
exception covers the developer's name, not other personal information.

The refresh after PR #63 merged incorporates main `a3456c6` without
conflicts. That main already raises the UI job's limit from 75 to 120
minutes and removes redundant termination calls in the fold-offset UI
test. The old-head UI job timed out; the refreshed head needs its own
green CI run. The same update completes the change-log metadata requested
in review.

## Commits

- `79e6571`: add the all-rights-reserved notice and project records.
- `1ebcbd9`: rename the notice to `LICENSE.md` and update references.
- This merge incorporates main `a3456c6` and completes the PR/commit
  metadata in this record.

## Verified

- `python3 scripts/test-docs.py`: all 45 tests passed on the local Mac,
  including documentation links and section references.
- The verifier also passed the existing Python suites for hooks (124),
  website (7), test runner (54) and Xcode selection (21): 251 Python tests
  in total, including the documentation suite.
- `CI=true scripts/test.sh unit`: passed on the local Mac with Xcode 27.1
  (27A9275), XcodeGen 2.46.0, and the iPad Pro 13-inch (M5, 16GB) simulator
  running iOS 27.0. The result bundle is
  `build/TestResults/unit-ipad.xcresult`. Of 781 cases, 772 passed, none
  failed, eight had expected failures and one was skipped. The skip is
  the existing disabled SwiftData rollback crash reproduction for issue
  #19 (`SwiftDataBehaviourTests`); no test was newly disabled or changed.
  Reported app line coverage was 71.2%; the String Catalog stayed current.
- Repeated the full unit gate after the owner's `LICENSE.md` rename:
  the same 781-case result passed, with zero unexpected failures and no
  catalog change. The renamed notice is byte-for-byte identical to
  `79e6571:LICENSE`; README links resolve to the new filename.
- Rechecked commit `79e6571` after the owner registered the existing SSH
  key for signing: GitHub reported `verified: true`, reason `valid`.
- Repeated `CI=true scripts/test.sh unit` after the clean merge of main
  `a3456c6`: the same 781-case result passed, with zero unexpected failures,
  71.2% line coverage and no catalog change. The refreshed head's GitHub
  unit/UI results remain a separate gate.
- `git diff --check`: passed.
- Reviewed the notice and README together for matching permission wording,
  applicable-law and GitHub-term exceptions, and third-party terms.

## Not verified

The UI suite was not run locally because no app code, controls, layout or
resources changed. GitHub CI results are recorded on the pull request;
local results alone do not establish that its unit and UI jobs passed.

## Follow-ups

Any future grant of broader reuse rights remains an owner decision.

## Latest main refresh

Merged main `bae6887` after PRs #61 and #62 landed; Git merged the
shared decision and handoff records cleanly. Narrowed the owner-status
sentence to the remaining questions, as requested in review, so it no
longer dates the October 27 licensing choice to October 21. The copyright
publication exception remains the scope explicitly authorized by the owner.

The refresh passed `CI=true scripts/test.sh unit`: 781 cases, 772 passed,
zero failures, one existing skip and eight expected failures; 71.2% app
line coverage. Documentation checks passed all 45 tests. Fresh-head GitHub
CI remains required before merging.
