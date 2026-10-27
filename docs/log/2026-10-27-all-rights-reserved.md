# Explicit all-rights-reserved notice

*2026-10-27. Branch `codex/all-rights-reserved`. Codex; owner-requested.*

## What changed and why

Added the root `LICENSE` with Avery Dedmon's copyright notice and an
explicit reservation of rights for Brickson's original source code and
accompanying documentation. Reuse requires prior written permission,
subject to applicable law and GitHub's terms. Third-party material keeps
its applicable terms.

The README links the notice, explains the permission requirement and
points to the website's contact details. The owner's choice is recorded in
docs/DECISIONS.md, "Brickson's code is all rights reserved". Handoff and
roadmap wording no longer list licensing as an outstanding owner decision.
No open-source license is granted.

The shared briefing records the owner's authorization for the copyright
attribution in these notices and the licensing decision record. This
exception covers the developer's name, not other personal information.

## Commits

The licensing notice and related documentation are delivered together on
`codex/all-rights-reserved`.

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
- `git diff --check`: passed.
- Reviewed the notice and README together for matching permission wording,
  applicable-law and GitHub-term exceptions, and third-party terms.

## Not verified

The UI suite was not run locally because no app code, controls, layout or
resources changed. GitHub CI results are recorded on the pull request;
local results alone do not establish that its unit and UI jobs passed.

## Follow-ups

Any future grant of broader reuse rights remains an owner decision.
