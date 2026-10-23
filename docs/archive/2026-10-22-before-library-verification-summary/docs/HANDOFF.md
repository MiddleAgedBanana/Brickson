# Archived PR #14 verification section

Technical excerpt from `docs/HANDOFF.md` at `4808701`, before its
verification chronology became a current-status summary. Read-only history,
not current instructions. Only the affected PR #14 section is copied;
unrelated handoff sections and attribution details are excluded.

## Verification

- **PR #14 reconciliation, 2026-10-22:** prepared a merge of `main` at
  `5abdd9f`, preserving its landed Voice Settings work, and adapted the
  starter-label tests to the library snapshot format. Category edits now
  reserve Again's `Repeat` alias. All 44 pure edit/import tests passed on
  macOS; the full iOS unit run on an iPad Pro 13-inch (M5), iOS 27.0,
  Xcode 27.1 passed 548 tests with only the pre-existing issue #19 crash
  probe skipped. The full UI suite passed on iPad Pro 13-inch (M5) and
  iPhone 17, iOS 27.0: 33 passed on each, no failures, with the four existing
  opt-in keyboard measurements skipped on each. The catalog is synchronized;
  a later review caught and fixed Emergency delete/move allowing only
  blank phrases to remain. It also restored the owner-only, unadopted
  safety-copy exception in the decision text. The follow-up full unit
  run passed 550 tests with only the same crash probe skipped; all 46
  pure edit/import tests also passed. CI on `596c59a` passed units (550
  passed, one existing skip, 551 total) and iPad UI (33 passed, four existing
  skips, 37 total), but iPhone UI had 32 passed, one failed test and the same
  four skips (37 total). The AX5 quick-control audit reported type 2 text
  findings with no element in both light and dark. Its cause remains
  unresolved; the pre-audit screenshot/tree pairs do not identify it.
  All 14 review conversations are resolved and Codex code review is clean
  for `596c59a`. This follow-up merges `main` at `d79d836` and strengthens
  the shared helper to preserve native audit issues and captures at
  reporting time. Five focused iPhone AX5 iterations passed in both
  appearances. Fresh full gates passed: units 550 passed, one existing
  skip (551 total); UI 33 passed, four existing skips (37 total) on each
  device, with no failures. These local runs did not reproduce or explain
  the earlier CI finding and do not establish a fix. Fresh CI and review
  remain pending; PR #14 is not yet green. Two later CodeRabbit findings
  have a focused local fix: distinct symbol category names no longer collide,
  Home-name reservation uses the existing spoken form, and a decision's
  rejection-enum reference is corrected. All 50 pure edit/import tests pass
  after reproducing 42 issues. The fresh full iOS unit gate also passed:
  554 passed, zero failures, the same existing crash probe skipped (555
  total); the catalog stayed synchronized. Full local UI evidence is for
  `182df4b`, before this pure comparison follow-up. Those two review
  conversations were answered and resolved on `d241dea`. A later Codex
  finding reproduced format/control-only text counting as Emergency words
  and editor input: 54 pure tests first reported 99 issues, then all passed
  with the shared blank predicate strengthened. Import bytes and meaningful
  composed text remain intact. Its full native unit gate passed 558 tests,
  zero failures, the same existing crash probe skipped (559 total); the
  catalog was unchanged. Commit `4fbd521` holds that correction.
  This publication also merges main `479175d`, retaining the native
  diagnostic handler alongside PR #31's settled-screen audits. The combined
  unit gate passed 558 tests with the same existing skip. Current merged
  UI is not yet locally validated: the same inherited wait failed in
  PR #32's local run while Speaking remained visible and CoreAudio reported
  backend startup errors. The cause is under investigation; no app fix or
  finding suppression is claimed. Fresh hosted CI and PR #14's full local
  iPad/iPhone run remain required. Audits now wait for Speaking to disappear,
  so they do not cover that status itself. The
  earlier PR #14 audit finding remains unexplained. The
  [`reconciliation record`](log/2026-10-22-library-reconciliation.md)
  preserves the earlier core/review fixes, failed CI evidence and next checks.
