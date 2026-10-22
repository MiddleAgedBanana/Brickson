# CI keeps each job's test results

*2026-10-22. Pull request #28 (`MiddleAgedBanana-patch-1`), merged as
`c23a4b4`; this record and its docs changes follow in their own pull
request (`claude/project-thread-5s82a6`). The owner committed the
workflow; the "Keep CI test results" thread wrote the record.*

## What changed and why

Nothing a person using Brickson sees. Each job in
`.github/workflows/tests.yml` now ends with a "Keep the test results"
step that uploads `build/TestResults` (the result bundles
`scripts/test.sh` writes: every test's outcome, screenshots of UI-test
failures, the captures UI tests attach) as a download on the run's page:
`unit-test-results` and `ui-test-results`, kept for 14 days.

Before this, the bundles vanished with GitHub's machine, so when CI
failed nobody could see what the app showed, and cloud agents, which
cannot build, had only the log. This was the last open piece of ROADMAP
item 2 and half of the repo review's finding that cloud threads cannot
see test results or screenshots (`docs/recon/2026-10-21/repo-review.md`,
sdlc-13); the other half is under *Follow-ups*.

The file was prepared during PR #13's work and committed by the owner
through GitHub's web editor, because cloud agents cannot change files
under `.github/workflows` (AGENTS.md, *Gotchas*; docs/SDLC.md,
*Deploy*).

Choices in the steps:

- `actions/upload-artifact@v7`, published by GitHub (AGENTS.md, *Code
  Review Rules*: no actions from other publishers). Dependabot's monthly
  pull request keeps it current.
- `if: always()`, so a failed run keeps its bundle; that is when it
  matters most.
- `if-no-files-found: warn`, so a run that fails before any test (Xcode
  choice, XcodeGen) reports its real failure, not a missing upload.
- `retention-days: 14`: long enough to look at a failure while its pull
  request is open, short enough that old bundles do not pile up.
- Unchanged: `permissions: contents: read`, the triggers, the job names
  "Unit tests" and "UI tests" that the `main` ruleset requires, and no
  path filter.

The repository is public, so anyone signed in to GitHub can download
the bundles. They hold only test data: the neutral starter library on
test-only storage (`--test-storage`), nothing personal.

## Commits

- `baf3567`: the two upload steps and the header comment (the owner).
- The docs pull request after it: this record, and the lines #28 made
  untrue in `docs/ROADMAP.md` (item 2, and the repo review's list),
  `docs/HANDOFF.md` (*Verification*) and `AGENTS.md` (*Build and test*).

## Verified

- The committed workflow is byte for byte the prepared copy (same
  SHA-256), and its only change from `main` is the two steps and the
  header comment.
- CodeQL's analysis of the workflow files passed on `baf3567`, and
  Codex's security review found nothing.
- GitHub CI on `baf3567` (run 39811895414): Unit tests and UI tests
  passed, and the run's page lists both artifacts, `unit-test-results`
  (0.9 MB) and `ui-test-results` (13.2 MB), each set to expire 14 days
  after upload.
- The docs pull request's first CI run (`1df97d5`, run 39823137500)
  failed once on the iPad: `HomeLayoutTests.testTheStarterLibraryFitsWithoutScrolling`
  timed out evaluating its `phraseTile` query after 395 s, on code
  identical to `main`. The one re-run passed. The failed run's
  `ui-test-results` holds that failure's bundle until it expires.
- Its second run (`5beb447`, run 39835147321) failed on the iPhone: the
  accessibility audit in `LaunchTests.testLargestTextKeepsQuickControlWordsVisible`
  ("AX5, light") reported text with no accessibility element, on code
  identical to `main`, where the same test had passed. It was not
  re-run (AGENTS.md: never retry an accessibility finding to make CI
  green); it is issue #30. That failed job still uploaded
  `ui-test-results` (26.3 MB, expiring
  2026-11-05), so `if: always()` keeps a failed run's bundle.

## Not verified

- Nothing ran outside GitHub CI; a cloud session wrote these docs.
- The record came in a second pull request, not in #28 as AGENTS.md
  asks (Codex's finding on #28): #28 was the owner's web-editor branch,
  and it merged by auto-merge before the docs could be added to it.
- That a failed run's artifact holds the failure screenshots: run
  39835147321 shows the upload happens on failure, but nobody has opened
  the bundle to see the screenshots inside (that needs a Mac).
- A `.xcresult` bundle opens only in Xcode or with `xcrun xcresulttool`
  on a Mac, so a cloud agent that downloads one still cannot read it.

## Follow-ups

- Export the UI tests' screenshots and a short failure summary from the
  bundle as plain files (`xcrun xcresulttool export`), so a failure can
  be read without a Mac (`docs/recon/2026-10-21/repo-review.md`,
  sdlc-13). Needs a
  `tests.yml` change, so the owner commits it. *(Test seams and CI
  evidence; not scheduled)*
