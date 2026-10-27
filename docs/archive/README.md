# Archive

Older versions of documents whose content went out of date because the
code changed. Snapshots here are read-only history, never current
instructions.

Before rewriting `docs/HANDOFF.md` or `AGENTS.md` in a way that removes
information, save the old file here as
`YYYY-MM-DD-before-<change>/<its repository path>` and add a row below.
Small edits don't need a snapshot; git history keeps them.

| Snapshot | Taken from commit | What changed in the code |
|---|---|---|
| [`2026-10-21-before-handoff-restructure/docs/HANDOFF.md`](2026-10-21-before-handoff-restructure/docs/HANDOFF.md) | `9362eca` | None. The documents changed shape: the 474-line handoff became a front page (`docs/HANDOFF.md`), a history (`docs/HANDOFF-LOG.md`) and one record per pull request (`docs/log/`), so parallel pull requests stop conflicting in one file. The snapshot matches `9362eca` except two founder-note passages, which point to docs/DECISIONS.md, "Brand name and founder story", because AGENTS.md permits those facts only there, in `docs/HANDOFF.md`, `README.md` and `site/index.html`. |
| [`2026-10-22-before-library-verification-summary/docs/HANDOFF.md`](2026-10-22-before-library-verification-summary/docs/HANDOFF.md) | `4808701` | None. Only the affected PR #14 technical section is snapshotted, excluding unrelated sections and attribution details. Its chronology became a current-status summary; the full technical history stays in its reconciliation log. |
| [`2026-10-25-before-duo-layout/docs/HANDOFF.md`](2026-10-25-before-duo-layout/docs/HANDOFF.md) | `87ddb14` | Affected Duo technical section only. Item 6 now allocates Home around measured reserved regions; the earlier measurements and failures remain in the dated Mac log. |
| [`2026-10-25-before-speech-diagnostic/docs/HANDOFF.md`](2026-10-25-before-speech-diagnostic/docs/HANDOFF.md) | `1322630` | Affected speech-verification excerpt only. Later temporary simulator diagnostics observed real synthesizer flags and watchdog checks; physical-device behavior remains unverified. |
