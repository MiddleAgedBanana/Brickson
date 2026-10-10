## What changes for the person using Brickson

Before:

After:

## How

<!-- A short paragraph: what changed in the code, and why this way. -->

## Verified

<!-- Say what ran and where. Name the simulator or device, orientation,
text size, appearance, and which keyboard showed if typing was involved.
Cloud agents cannot build: say so if nothing ran outside GitHub CI. -->

- [ ] GitHub CI is green (unit and UI tests)
- [ ] Ran on a Mac or device (say which), or: not run outside CI

## Checklist (AGENTS.md invariants)

- [ ] Every new control is a standard `Button` with a label and a target of at least 44pt (1)
- [ ] Phrases still speak on the first activation; Emergency stays visible and uncovered (2)
- [ ] Speaking changes no data; deletes, merges and replaces ask first (3)
- [ ] Audio failures still show as passive text that moves nothing (4)
- [ ] Every new save path has a test that makes it fail (5)
- [ ] New colour pairs are measured and pinned in a test (6)
- [ ] No new seeded words about anyone's condition (7)
- [ ] No position depends on usage or time (8)
- [ ] No network, accounts, analytics, packages or custom input code (9)
- [ ] No control turns into its opposite in place, and nothing harmful is left nearest the spot just activated (10)
- [ ] No new scrolling on Home for the starter library in dwell, switch or gaze profiles (11)
- [ ] The screen still never locks while the app is open (12)
- [ ] Elapsed time uses `ContinuousClock`; framework callbacks are `@Sendable` or `nonisolated`
- [ ] `docs/HANDOFF.md` updated (and `README.md`, `AGENTS.md`, `docs/DECISIONS.md` where they changed)
