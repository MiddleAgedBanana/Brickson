# AGENTS.md puts first what Codex reads

*2026-11-03. Pull request #77 (`claude/project-thread-8do6xw`). The
"Make AGENTS.md fit what Codex reads" thread, a cloud session that
cannot build: the owner's consultant notes of 2026-11-03 (from Claude
Duet, read-only, each claim with its source), as the coordinator
scoped them. Every claim used here was checked against its source
first; what checking found is below.*

## What changed and why

Nothing a person using Brickson sees or hears changes. This is about
the rules the agents building it read.

- **Codex never read half of `AGENTS.md`.** Codex reads only the first
  32 KiB of the AGENTS.md files on its path unless
  `project_doc_max_bytes` is raised, and cuts the rest with nothing but
  a log line. With #76 merged, `AGENTS.md` was 64,681 bytes and the cut
  fell inside *Code Review Rules* ("Tests, workflows and the rules
  themselves"), so a Codex at default settings never saw *Not findings*,
  *Workflow rules*, *Guardrails for agents*, *Working with the owner*,
  Apple's documentation, *Skills* or *Gotchas*.
- **`AGENTS.md` now opens with what every agent and reviewer must
  read** (docs/DECISIONS.md, "AGENTS.md puts first what Codex reads"):
  the stakes, the invariants, the privacy promise, layout, Apple's
  current frameworks, the design rules for dwell, switch and pointer
  input, *Code Review Rules*, *Workflow rules* and *Working with the
  owner*, ending at byte 30,645. *Build and test*, *Guardrails for
  agents*, *Where things are*, Apple's documentation, *Skills* and
  *Gotchas* follow, and Codex's cut now falls in *Build and test*,
  after its commands and the rules on green tests, warnings, pushing to
  an open pull request, cloud agents and the generated project, at the
  start of "Build with Apple's current Xcode". Inside *Build and test*
  those rules now come before how the script and CI work. Every section
  was moved whole, and one word changed with the move: *Build and test*
  said reviewers work against *Code Review Rules* "below", now "above".
- **What a default Codex no longer reads.** On `main`, *Where things
  are* and *Build and test* came second and third, so their rules were
  inside the cut. The rules in *Where things are* are now repeated in
  *Workflow rules*, "Rules that also live further down": the reference
  app is reference only, neither its own `AGENTS.md` nor `docs/recon/`
  overrides this file, the sections of `docs/LESSONS.md` that touch the
  work are read, a feature starts with a work file in `docs/work/`, and
  an accessibility change edits its row and, where its words become
  untrue, the website's accessibility page. The rest of "Build with Apple's current
  Xcode" (with the deployment-target rules), "Reviews and updates on
  GitHub", committing the synced String Catalog, and how the script and
  CI work are past the cut, and docs/DECISIONS.md says why each was not
  repeated.
- **Not every rule fits, and no reorder can make it.** Everything above
  *Gotchas* is 49,240 bytes; the sections that come first already take
  30,645 of the 32,768. Fitting every rule would mean rewriting the
  invariants and the review rules much shorter, which risks weakening
  them, so the introduction now says that the rest binds every agent
  and that an agent whose copy stops before *Gotchas* reads it from the
  repository before changing anything. A Codex on the owner's Mac reads
  the whole file once its limit is raised (docs/HANDOFF.md, *Next
  steps, in order*, owner step 8).
- **A check keeps it that way.** `scripts/test-docs.py` fails when
  those sections stop opening the file, in their order, when the
  introduction (before the first section) stops naming
  `project_doc_max_bytes`, or when they end past byte 32,768, counted in
  bytes (`CODEX_MUST_READ`, `codex_cut_problems`, `CodexCutTests`).
  Only `#` and `##` lines outside fenced code and HTML comment blocks
  end a section, read as CommonMark reads them (a comment hides lines
  only when its `<!--` starts a line), so a heading hidden in a comment
  or a `---` line cannot end the count early. The message says what to do: move how-it-works
  detail below *Working with the owner*, or shorten without dropping or
  weakening a rule, or ask the owner.
- **Sentences added to `AGENTS.md`**, besides the move: the
  introduction's *Read all of it*; the bullet "Rules that also live
  further down" in *Workflow rules*; in "Say what each result was
  measured on", that an activation, reachability or keyboard claim
  counts only from a UI test through `launchedApp`, from Device Hub's
  own input on a simulator or from a person's own input on a real
  device; in *Guardrails for agents*, "Cross-references", the new check;
  and three gotchas:
  - **An automation tool's tap, snapshot or keyboard report is not
    evidence** (new). On 2026-10-25 a RocketSim tap and a MobileBuildMCP
    tap reported success while nothing changed, and RocketSim's
    snapshot said `keyboard=hidden` over visible keys. Each record
    handled it, but the rule lived only in those records. Its headline
    names taps, snapshots and keyboard states because the iPhone Duo
    entry still reads hinge angles from RocketSim.
  - **iPhone Duo** (added to *The iPhone Duo simulator starts folded*):
    Xcode 27.2's three Device Hub known issues on iPhone Duo, with
    Apple's numbers 187146039, 187148389 and 189465196, and what they
    mean for a Duo run.
  - **`ViewThatFits`** (relabelled): it failed Apple's audit here, on
    CI with the Xcode of the time, which is this app's own finding, not
    a rule Apple documents. The entry cited only docs/DECISIONS.md,
    *Home's stand-in layout*, which gives Home's Dynamic Type report to
    drawing a label at a smaller text size; it now also cites the
    Settings record of the same day, where labels that used
    `ViewThatFits` to drop their icon failed the Dynamic Type check
    themselves. The rule (choose arrangements in a plain type, place
    each view once) is unchanged.
- **docs/PORTING.md** said Settings (step 7) was not started and typing
  on Home (step 5) not built. Steps 3, 4 and 8 of *Port order* were
  stale too: five measured fills, not three; the profiles came with
  Wave 3 items 8 and 9; and the chain engine took the snap-reach
  harness's place. Each row now says what is built, with its source,
  and *Still to port, by tier* marks what took the place of
  `SettingsIdlePolicy`, `BoardPlan`, `HomeView`, `SettingsView`,
  `SettingsOpening`, `TypeToSpeakView`, `VoicePickerView`,
  `SettingsSafetyBarLayout`, `CaregiverSetupView`, `VoiceControlLabels`
  and the snap-reach harness. `WindowSizePolicy`, `EditSheets` and the rest stay to come.
- **Copilot's step is unchanged.** On `main` it already says it ends on
  2026-11-09 and that a pull request removes it from 2026-11-10.
- **Two gaps recorded, no code** (docs/HANDOFF.md, *Known gaps*;
  docs/ROADMAP.md, *The quality bar*, Q10): no scene has a minimum
  window size, and nothing scores a look resting while an iPad window's
  resize switches Home between three and five columns. How iPadOS moves
  the pointer then is a new row of *Checks that need a real device*.
- **The next candidate job** is in docs/HANDOFF.md, *Next steps, in
  order*: step-by-step procedures, with what success looks like, for
  each gate the owner checks, before the first device session
  (docs/ROADMAP.md, *The quality bar*). docs/SDLC.md's line on the
  briefing now names the order.

## What checking the notes found

| The notes said | Source checked | Found |
|---|---|---|
| Codex reads AGENTS.md only up to 32 KiB by default | OpenAI, [Custom instructions with AGENTS.md](https://developers.openai.com/codex/agent-configuration/agents-md) and [advanced configuration](https://developers.openai.com/codex/config-advanced); `codex-rs/core/src/agents_md.rs`, `codex-rs/config/defaults.toml` and `codex-rs/codex-home/src/instructions/mod.rs` in `openai/codex` at `6b2a275`; issues [#13386](https://github.com/openai/codex/issues/13386) (open) and [#7138](https://github.com/openai/codex/issues/7138) | True: "stops adding files once the combined size reaches the limit defined by `project_doc_max_bytes` (32 KiB by default)"; the code truncates the file at the remaining budget and logs a warning only. The global `~/.codex/AGENTS.md` is read whole and does not count against `project_doc_max_bytes` (Codex's test `merges_existing_instructions_with_agents_md`). |
| The cut lands in *Workflow rules* on `17019ed`, in *Code Review Rules* on #76's branch | `AGENTS.md` at `1b4624d` (#76 merged), measured | True for `main` after #76: byte 32,768 fell at line 545, in "Tests, workflows and the rules themselves". |
| Codex review on GitHub and Codex cloud may use another limit | OpenAI, [Review GitHub pull requests with Codex](https://developers.openai.com/codex/integrations/github) | Not documented: it says Codex "searches your repository for `AGENTS.md` files and follows the applicable code review rules", with no size. |
| Xcode 27.2 lists 187146039 and 187148389 | Apple, [Xcode 27.2 Release Notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27_2-release-notes), Device Hub, *Known Issues* | True, word for word. The same list has a third iPhone Duo issue, 189465196 (modifier keys after switching displays), added too. |
| RocketSim and MobileBuildMCP reports were wrong on 2026-10-25 | `docs/log/2026-10-25-mac-keyboard-checks.md` lines 85 to 94; `docs/evidence/2026-10-25-duo-design/speech-diagnostic/README.md` lines 32 to 33, `results.json` line 8; `ax3-native-results.json` line 239 | True. AXe appears in no record: the rule names it as one more automation tool, not as one seen failing. |
| No Apple page says `ViewThatFits` fails the audit | Apple, [Performing accessibility audits](https://developer.apple.com/documentation/accessibility/performing-accessibility-audits-for-your-app) and [ViewThatFits](https://developer.apple.com/documentation/swiftui/viewthatfits); docs/DECISIONS.md, *Home's stand-in layout* and *Settings on Home*; `docs/log/2026-10-21-settings-and-first-run.md` | True: the audit page names the clipped-text and Dynamic Type checks, the `ViewThatFits` page says it picks "the first child whose ideal size on the constrained axes fits", and neither mentions the other. The app's records show both reports: clipped on Home, and Dynamic Type "partially unsupported" and clipped on Settings. |
| PORTING's steps 5 and 7 are stale | docs/HANDOFF.md, *What the app does today*; docs/DECISIONS.md; `Brickson/Home/Palette.swift`; `Brickson/Settings/` | True, and steps 3, 4 and 8 too, and the tier list below the table. |
| No minimum window size; `WindowSizePolicy` never ported | `Brickson/App/BricksonApp.swift`; a search of `Brickson/` for `windowResizability`, `minWidth`, `minHeight`, `defaultSize`; docs/PORTING.md | True: the scene is a plain `WindowGroup`; the only minimum heights are on Settings rows. |
| A resize can switch Home between three and five columns, and only iPhone Duo's window changes were scored | `Brickson/Layout/HomeLayout.swift` (`isRegular` from the width, `MinimumWidths.regularColumn`); `docs/evidence/2026-10-25-duo-design/transition-report.md`; `BricksonTests/Layout/HomeReservedRegionChainTests.swift` | True: five columns where each gets 122 points (132 with Bold Text). The changed-window diagnostic (report-only, run outside the app, no committed test) used only iPhone Duo's windows; the committed reserved-region chain tests also use only Duo's windows, each held fixed, and score no window change. |
| ROADMAP asks for owner procedures before the first device run | docs/ROADMAP.md, *The quality bar*; `docs/log/2026-10-26-settings-simulator-checks.md` | True; only Settings' procedure exists. |

## Commits

See the pull request; one commit per task.

## Verified

In this cloud session (no Xcode; no Swift changed, so GitHub CI is the
build only in that it runs the same Python checks first):

- An independent review of the whole diff, with a second agent trying
  to refute each finding, confirmed 18 problems, all fixed before the
  pull request opened. Among them: the evidence rule left out a
  person's own input on a real device, which docs/HANDOFF.md, *Checks
  that need a real device*, depends on; the rules a default Codex no
  longer read went unrecorded; the `ViewThatFits` entry dropped the
  Settings record; the check could be fooled by a heading in an HTML
  comment or a `---` line; and the PORTING tier list contradicted the
  rewritten rows. A second check of those fixes found 16 more, all
  fixed too, two contrived kinds of input by saying in the checker what
  it does not see: the repeated accessibility rule had lost "where its words
  become untrue" and "says only what is in place", the `docs/LESSONS.md`
  rules had been left out, the check took a `<!--` inside a sentence or
  a code span for a comment, and several records said slightly more or
  less than the code.
- `python3 scripts/test-docs.py`: the first seven `CodexCutTests` were
  written first and failed (seven errors: no checker yet), then passed.
  After the reviews, the introduction test was made to fail when the
  name sits only after the first section, and five were added: a
  subsection of the last section, a heading in an HTML comment (closed
  or not), a thematic break or Setext line, a `<!--` that does not start
  a line, and a comment opened inside fenced code. Each of fifteen
  deliberate breaks of the checker makes at least one of the twelve
  fail, among them counting characters instead of bytes, never
  comparing with the limit, ignoring the order, reading headings inside
  fenced code or HTML comments, treating any `<!--` as a comment,
  ending an unclosed comment early, counting `###` or Setext lines as
  section ends, searching the whole file for the introduction's word,
  and ending the block at the end of the file.
- `python3 scripts/test-docs.py`, `test-hooks.py`, `test-site.py`,
  `test-runner.py` and `test-select-xcode.py` all pass on the final
  branch (counts in the pull request).
- The move changed no line but those listed under *What changed and
  why*: `diff <(git show origin/main:AGENTS.md | sort) <(sort AGENTS.md)`
  shows only the added sentences, the rewritten `ViewThatFits` entry,
  the narrowed headline, two lines extended and "below" made "above".
- The byte offsets above were measured with Python on the committed
  file.

## Not verified

- Whether Codex's code review on GitHub, Codex cloud or Jules cut
  `AGENTS.md` at 32 KiB, or at all.
- That an agent whose copy stops partway reads the rest because the
  introduction asks it to.
- The owner's step 8 on a Mac: the command was not run there.
- Whether XCTest's own queries on an iPhone Duo are affected by Apple's
  187148389.
- The resize hazard itself: it is read from the layout code, not
  measured, and how iPadOS moves a pointer when a window is resized is
  not known.
- The port order rows and the tier list restate the records and code
  they cite; nothing was rerun for them.

## Follow-ups

- **Owner, optional:** docs/HANDOFF.md, *Next steps, in order*, step 8,
  gives the one line that lets Codex on the Mac read all of
  `AGENTS.md`, and what success looks like.
- **Windows** (docs/HANDOFF.md, *Known gaps*): a minimum window size
  from the layout engine, and a changed-window surface in the chain
  engine for iPad resizes, once the new device row says how the pointer
  moves. R0, Q10; no thread has them yet.
- **Owner procedures** before the first device session (docs/HANDOFF.md,
  *Next steps, in order*).
- **From 2026-11-10**, the pull request that removes Copilot's step
  (AGENTS.md, *Build and test*, "Reviews and updates on GitHub").
- When the new check fails, the pull request that made it fail moves or
  shortens something, never a rule, or asks the owner.
