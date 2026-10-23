# Research

Dated research behind [`docs/ROADMAP.md`](../ROADMAP.md). Each folder is
one sweep, kept as it was written apart from removing local paths and
personal details before it was committed.

**Research, not instructions.** A report's recommendations are proposals
until [`docs/DECISIONS.md`](../DECISIONS.md) records the owner's choice.
Where a report disagrees with [`AGENTS.md`](../../AGENTS.md),
`docs/DECISIONS.md` or the roadmap, those win. Facts about versions, CI
and GitHub settings describe the day they were checked; the front page,
[`docs/HANDOFF.md`](../HANDOFF.md), says what is true now.

## 2026-10-15: where Brickson stands and where it could go

Written in one planning session on the owner's Mac against `main` at
`9362eca`, after a full read of the repository and a run of the app and
its tests on iPad and iPhone simulators. Read the synthesis first.

| File | What it is |
|---|---|
| [`2026-10-15/README.md`](2026-10-15/README.md) | **The synthesis**: what people with ALS need by stage, what the audits found, the proposed releases R0, R1 and R2, the decisions only the owner can make, and questions for people with ALS, caregivers and speech-language pathologists |
| [`code-audit.md`](2026-10-15/code-audit.md) | The app's code, ranked (M1 to M3, L1 to L8) |
| [`tests-ci-audit.md`](2026-10-15/tests-ci-audit.md) | The tests, scripts and CI, and the test infrastructure upcoming features need |
| [`docs-repo-audit.md`](2026-10-15/docs-repo-audit.md) | The documents, the repository's settings, the website and the privacy policy |
| [`als-aac-research.md`](2026-10-15/als-aac-research.md) | What people living with ALS need from a communication app, with sources |
| [`apple-platform.md`](2026-10-15/apple-platform.md) | Apple's frameworks and accessibility features that matter, checked against Apple's documentation |
| [`layout-blueprint.md`](2026-10-15/layout-blueprint.md) | A design for the profile layout engine (R1). Written before the owner's 2026-10-21 rule that layouts come from available space, never per-device checks: read it with docs/DECISIONS.md, *Layouts from the space available*, which replaces its device table |
| [`simulator-and-build-findings.md`](2026-10-15/simulator-and-build-findings.md) | What the simulators and builds showed |
| [`directions/typing.md`](2026-10-15/directions/typing.md) | Typing: where it lives, which keyboard, what stays above it |
| [`directions/alarm-and-audio.md`](2026-10-15/directions/alarm-and-audio.md) | Get Attention and the audio session |
| [`directions/editing-and-backup.md`](2026-10-15/directions/editing-and-backup.md) | Editing the library and backing it up without an account |
| [`directions/onboarding-and-settings.md`](2026-10-15/directions/onboarding-and-settings.md) | First launch, Settings, Personal Voice and the voice picker |
| [`directions/recorded-phrases.md`](2026-10-15/directions/recorded-phrases.md) | Phrases recorded in the person's own voice |
| [`directions/caregiver-alerts.md`](2026-10-15/directions/caregiver-alerts.md) | Reaching a caregiver who is not in the room |

## 2026-10-23: folding phones for an AAC app

A short, low-priority note the owner asked for when iPhone Duo went on
sale, written in a cloud session for the Wave 3 plan
(docs/ROADMAP.md). Nothing was run on a folding phone.

| File | What it is |
|---|---|
| [`2026-10-23/folding-phones-for-aac.md`](2026-10-23/folding-phones-for-aac.md) | How well a folding phone suits an AAC app across the disease, from Apple's pages and AAC practice, with what is not known |
