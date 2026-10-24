# Settings' chains: Get Attention scored, the guide link held

*2026-10-24. Pull request #50 (`claude/project-thread-xn2qoy`). The
Settings' chains thread (a cloud session), ROADMAP Wave 3 item 7.*

## What changed and why

Under Dwell, head tracking, Eye Tracking or Switch Control's auto-select,
a look held after choosing Set Up Step by Step in Family Setup stays
where the row was, and the first step, "How is the screen reached?",
puts an answer there. An answer saves the moment it is chosen, so a held
look can add Touch and restart the check-in clock, some chains starting
at Home's Settings button. The chain engine finds it on every window CI
reads (docs/DECISIONS.md, "One chain engine for dwell safety"). The work
file is [`work/settings-chains.md`](../work/settings-chains.md), and the
screens are in the Figma file's
[Settings' chains section](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f/?node-id=48-207).

Nothing a person sees changes in this pull request. What it leaves:

- **Get Attention is not added to Settings' bar, and the owner decides
  what happens to its place** (docs/DECISIONS.md, "Get Attention in
  Settings' bar: the owner decides"). Scored on CI's frames, filling the
  bar's empty place adds 2 to 5 chains on every window that sound the
  alarm unasked, mostly through the standard Back button just under it.
  So the place stays empty, as it has always been, and the sound line
  stays where it is. The section was first written as a reversible
  default; Codex's review found that it made a gap into an exception to
  an AGENTS.md design rule without the owner, and it was rewritten as
  open, with the owner's three choices, before merging.
- **The fix for the saving chain is built and held.** The first step
  opened on its words, filled down to where Family Setup's Set Up Step
  by Step row was, and then **Learn About Each Way**, at least as tall
  as that row, which only opened the Reaching the Screen guide, with the
  answers one row lower. It was built in `1de50f5` (`SettingsScreen`
  naming its content's coordinate space, Family Setup measuring the row
  into `SettingsLanding`, the chain model and the UI tests knowing the
  link and the guide) and passed CI's unit and UI tests. Codex's review
  then found that the guide opens with only Back and Back to Talking near
  the look, so a held look goes on to Back to Talking, and Settings
  closes over a phrase, No or Get Attention. Modelled on CI's frames,
  "Settings closes under the look" went from 3, 3, 4, 5 and 4 chains to
  6, 3, 10, 7 and 9. That is worse than saving a setup answer, which
  nothing reads yet, and no placement of the link avoids it while Back to
  Talking closes onto Home under the look. The owner chose to take the
  link out: `1de50f5` is reverted here, the code and tests are main's
  again, and the saving chain stays an open hazard, strictly expected,
  until the link comes back after ROADMAP Wave 3 item 4 puts Back to
  Talking over harmless controls.

## Commits

- `c663791`, `31cc050`, `144248b`: the work file's intent, spec and plan.
- `1de50f5`: the link, its measuring, and the tests.
- `603ad93`: this record and the documents, first version.
- `cb6925d`: Get Attention's section rewritten as open for the owner,
  after Codex's review.
- `ae2f573`: main merged in (the layout engine, #48, and the Figma
  notes, #51), resolving two documents' conflicts.
- `47f6c1f`: `1de50f5` reverted, as the owner chose.
- The next commit: this record and the documents, for the link held.

## Verified

- **No Xcode here.** This is a cloud session: nothing was built for iOS.
  GitHub CI on this pull request is the build and the run.
- **The findings were modelled on CI's real frames.** PR #49's last UI
  run (40036138085, `23fcc0e`) keeps each Settings screen's button frames
  for the iPhone 17 and the 13-inch iPad at the default and largest text
  sizes and the iPad in landscape. Fed to the chain engine on Linux, they
  reproduce that run's findings exactly (saves an answer: 7, 0, 6, 4 and
  6; Settings closes under the look: 3, 3, 4, 5 and 4). In that order:
  - With the link on Set Up Step by Step's frame and the answers a row
    lower, no chain saves an answer on any window, and the link still
    clears them 40 or 100pt lower or 60pt taller, but not shorter than
    the row. "Settings closes under the look" goes to 6, 3, 10, 7 and 9,
    through the guide's Back to Talking, ending on a phrase tile, No or
    Get Attention.
  - Get Attention in the bar's empty place, without the link, adds 3, 5,
    2, 2 and 2 chains that sound the alarm; with the link, 7, 5, 7, 5
    and 7.
- **The link's code passed CI** on `cb6925d`: unit tests, including
  `SettingsLandingTests`, and UI tests on the iPad and the iPhone,
  including `SettingsOnHomeTests` with "a held look saves an answer" as a
  plain assertion and a UI test that opened the guide and came back with
  the answer kept. On Linux, Swift 6.4.1, the chain files and
  `ChainEngineTests.swift` built with no warning and their 27 tests
  passed. That code is reverted now; what merges is main's code.
- `scripts/test-docs.py` and `scripts/test-hooks.py` pass on this
  branch.

## Not verified

- Every finding is the model's, on the simulator's frames, not evidence
  of what a gaze, Snap to Item or Dwell does on a device
  (docs/HANDOFF.md, *Checks that need a real device*).
- Still not scored: Voice Settings and Settings' other screens; the
  check-in card's rows (no test can make a check-in due yet); Family
  Setup scrolled before a row is chosen; and opening the Settings app
  from a guide, which the engine would count as navigating, not as a
  hazard.

## Follow-ups

- **AGENTS.md is ahead of the app.** Its *Design rules for dwell, switch
  and pointer input* say "Settings opens on a large way back and a
  start-only Get Attention". Brickson has never shown Get Attention in
  Settings, and now has a measured reason not to yet. If the owner
  chooses to keep it out, proposed wording: "Settings opens on a large
  way back, with a place kept for a start-only Get Attention until one
  clears its chains (docs/DECISIONS.md, "Get Attention in Settings' bar:
  the owner decides")", with that section retitled for the choice. Not
  changed here, because review rules change only with the owner's yes.
- **Get Attention in Settings:** the owner's choice of the three in
  docs/DECISIONS.md, "Get Attention in Settings' bar: the owner decides":
  keep it out for now, add it anyway at the measured cost, or find a
  place that clears its chains first.
- **After ROADMAP Wave 3 item 4:** bring back `1de50f5` (cherry-pick it
  or revert the revert, `47f6c1f`), rescore it on that pull request's
  frames, and make "a held look saves an answer" a plain assertion again
  only if no chain ends on Home over a control that speaks or alarms.
- **Voice Settings as a chain surface**, with the Personal Voice question,
  before ROADMAP Wave 3 item 8 lets setup answers change sizes.
