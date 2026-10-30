# An "in active development" note at the top of the README

*2026-10-30. This pull request (`claude/project-thread-sxky71`). A cloud
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

- The commit on `claude/project-thread-sxky71`: the alert and this record.

## Verified

- `python3 scripts/test-docs.py` passed (45 tests) in the cloud session.
- GitHub CI on this pull request (unit and UI tests): see the pull
  request's checks. Nothing about the app changed.

## Not verified

- How GitHub draws the alert was not looked at in a browser from this
  session; the syntax is GitHub's documented alert form.

## Follow-ups

- When the app reaches the App Store, the alert's words change with the
  release (docs/ROADMAP.md, R0's release gate: the README says only what
  the build does). Owner: whichever thread prepares the first App Review
  build.
