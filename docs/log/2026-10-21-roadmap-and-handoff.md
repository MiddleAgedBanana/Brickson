# A roadmap, a way of working and a handoff that does not conflict

*2026-10-21. Pull request #15 (`claude/project-thread-9b2zvk`). The
"Roadmap, decisions and repo review" thread (Claude Code on the web).*

## What changed and why

Nothing in the app changed. The documents changed shape so that many
agents can work at once without editing the same lines, and so that the
owner's goal of 2026-10-21 has a plan behind it.

- **The handoff was split.** The 474-line `docs/HANDOFF.md` became a
  front page of 150 lines that says what is true now and is edited in
  place, a history of everything before 2026-10-21
  (`docs/HANDOFF-LOG.md`), and one file per pull request in `docs/log/`
  (this is the first). The old file is kept, unchanged, in
  `docs/archive/2026-10-21-before-handoff-restructure/`. AGENTS.md's
  "Document every change" rule and the pull request template now ask for
  one log file plus in-place edits.
- **A roadmap** (`docs/ROADMAP.md`): three releases in the order a person
  meets the disease (R0 "A voice you can rely on", R1 "Follows you", R2
  "Your own words, your own voice"), with each R0 item mapped to the
  thread that owns it. They are working defaults until the owner confirms
  them.
- **A way of working** (`docs/SDLC.md`): Anthropic's six-stage playbook
  for AI-native development mapped onto this project, with one gate and
  one definition of done per stage, what does not transfer and why, and
  the owner's step for workflow files. `docs/work/` holds the template for
  a feature's intent, spec and plan.
- **The 2026-10-15 research** (`docs/recon/`), committed with local paths,
  the owner's name and email, private file names and details about the
  reference app's user removed, and a banner on every file saying it is
  research, not instructions.
- **Corrections from the research's docs audit:** CodeQL scans the Python
  scripts as well as the workflow files; DECISIONS.md's *Code review*,
  *Dependencies*, *Code scanning* and *`main` ruleset* are headings, so
  their citations resolve; the Python website test class is
  `WebsitePaletteTests`, so it is not confused with the Swift
  `PaletteTests`; `.github/copilot-instructions.md` carries the founder-note
  exception AGENTS.md already had; `.gitignore` covers worktrees, archives,
  app builds, debug symbols and a `private/` folder for the owner's own
  documents.
- **Decisions.** On 2026-10-21 the owner asked to focus on building and
  leave the logistics to the project. DECISIONS.md now lists the five
  questions left for the owner (*Waiting on the owner*), registers every
  choice decided by default that day (*Decided by default on
  2026-10-21*), and records *Layouts from the space available*.
- **Layout from the space available.** AGENTS.md carries the owner's
  adaptive-layout sentence word for word in a new section, a review rule
  against interfaces chosen by device, and target floors converted to
  points at the densest supported screen instead of a device table.
- **A repository review** against the owner's goal
  (`docs/recon/2026-10-21/repo-review.md`, 71 findings, each with an
  owner, not yet checked by a second reviewer), summarised in the roadmap
  with an R0 release gate. Its documentation findings are applied here.
- **Apple's documentation** is read in Markdown by adding `.md` to a
  developer.apple.com address (checked 2026-10-21); AGENTS.md says so.

## Commits

- `131ccdc` Split the handoff into a front page, a history and one record
  per pull request
- `f88766e` Correct stale documentation found by the 2026-10-15 docs audit
- `47563d3` Add the roadmap, the way of working and the 2026-10-15 research
- `cceaffc` Record this pull request in the change log
- `07163fb` Lay out from the space available, and decide routine choices
  by default
- `c343ae7` Record the decisions made by default and the repository review
- Later commits: the Settings, speech, toolchain, App Store and design
  decisions added to the register; answers to two rounds of Codex review
  (`1be6f74`, `c40be15`); and the merge of `main` after PR #12
  (`a5280a7`), which moved PR #12's handoff section, unchanged in
  substance, to [`2026-10-21-toolchain.md`](2026-10-21-toolchain.md) and
  kept both sides' AGENTS.md gotchas.

## Verified

- `python3 scripts/test-site.py` on the cloud machine: 4 tests, OK, after
  the class rename.
- The archived handoff is byte-identical to `main`'s (`cmp`).
- Every relative link inside `docs/recon/` resolves; an adversarial scan
  of the research files for personal details, paths, emails, price words
  and secrets found the items listed above, which were fixed.
- No Swift, project or workflow file changed, so the app's build and tests
  are unaffected; GitHub CI on this pull request is the check.

## Not verified

- Mentions of files other open pull requests add (`docs/DESIGN.md`,
  `docs/APP-STORE.md`, `docs/ASO.md`) are plain text, not links, until
  those merge; decisions they hold are named in DECISIONS.md's register
  with the pull request that holds them.
- The research's facts about CI, Xcode and simulators describe
  2026-10-15, not today.

## Follow-ups

- The five questions in DECISIONS.md, *Waiting on the owner*. *(Owner)*
- The repo review's findings, each with an owner, in `docs/ROADMAP.md`.
  *(This thread)*
