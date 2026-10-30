# An "in active development" note at the top of the README

*2026-10-30. Pull request #67 (`claude/project-thread-sxky71`). A cloud
thread, which cannot build or run the app.*

## What changed and why

The owner asked for a work-in-progress note at the very top of the
README, like the ones other new repositories show. GitHub has no official
template for one; the common way is GitHub's own alert syntax
(`> [!WARNING]`), which GitHub renders as a coloured box with an icon.

The README already had a plain quoted note, "Early development — not ready
for dependable daily communication", below the website links. It is now a
`[!WARNING]` alert directly under the title, so it is the first thing a
visitor reads, and it says three more things: the app is a work in
progress, it is not yet on the App Store, and its features and name may
change before release. The name is kept (docs/DECISIONS.md, "Brand name
and founder story"), but it is not cleared or reserved yet
(docs/NAME_AVAILABILITY.md). The old note's warning that the app is not
ready for dependable daily communication, and why, is kept in the alert,
so the README has one notice rather than two.

The note states no price and names no family details. The README uses no
badges, so none was added.

## Commits

- `f6b59ee`: the alert and this record.
- The next commit: this record's header, *Verified* and *Not verified*
  corrected after review.

## Verified

- In the cloud session: `python3 scripts/test-docs.py` passed (45 tests)
  and `python3 scripts/test-hooks.py` passed (124 tests).
- After the first push, GitHub's own page for this branch's README drew
  the note as a warning alert (its HTML has `markdown-alert-warning`).

## Not verified

- GitHub CI's unit and UI tests were still running when this record was
  written; the pull request's checks hold their result. Nothing about the
  app changed.
- The alert was not looked at by eye in a browser, in light or dark
  appearance; only the rendered HTML was checked.

## Follow-ups

- When the app reaches the App Store, the alert's words change with the
  release (docs/ROADMAP.md, R0's release gate: the README says only what
  the build does). Owner: whichever thread prepares the first App Review
  build.
