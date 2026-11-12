# AGENTS.md trimmed, with every rule kept in it

*2026-11-12. Branch `codex/agents-md-trim`. Written by Codex through the
agent bridge (`scripts/agent-bridge.py`, three rounds), checked and
finished by a Claude thread on the owner's Mac.*

## What changed and why

AGENTS.md was 83,195 bytes. Codex reads only its first 32 KiB by default
and Antigravity only its first 24,000 bytes, so most agents never saw
most of it. It is now 35,475 bytes:

- **Kept in AGENTS.md, byte for byte:** all twelve invariants, every
  *Code Review Rules* bullet, the privacy, layout, framework and design
  rules, *Working with the owner*, and most *Workflow rules* bullets.
  The introduction, the opening paragraph of *Code Review Rules* (which
  reviewer reads what moved to the reference) and three workflow bullets
  (plain testable types, branches and pull requests, the tools you have)
  were reworded with the same meaning; the introduction now names
  Antigravity's 24,000-byte cut.
- **Moved whole to the new `docs/AGENT-REFERENCE.md`:** the long
  reference material after *Working with the owner* (the Mac build
  route, how the scripts and CI work, the reviewer roster, the guard's
  full list, the document list, Apple documentation sources, skills and
  the gotchas), plus six passages from the must-read part that are
  background or tied to one activity: the owner's vision, the conditions
  for shipping recorded phrases, caregiver alerts or Siri and Shortcuts,
  the Apple quote behind the layout rules, the reference app's gaze
  measurements, what to do when moving to a new major Xcode, and the
  list of today's plain testable types. Each leaves a pointer in
  AGENTS.md naming when to read it.
- **Short rules kept after *Working with the owner*:** every rule there
  that binds every change stays in AGENTS.md as a plain sentence (for
  example: no `@codex` comment; reviewers never write code; Copilot
  once, only through `request_copilot_review`; never edit the actions
  lockfile by hand), with the full text, which governs, in the
  reference. Every title other files cite stays a heading or bold
  lead-in, so no other file needed to change.

Where each part now ends, counting bytes from the start of AGENTS.md:

| | Before | After |
|---|---|---|
| Whole file | 83,195 | 35,475 |
| *Code Review Rules* end | 25,037 | 23,660 |
| Sections Codex must read end | 32,119 | 29,824 |

So everything up to and including *Code Review Rules* now falls inside
Antigravity's first 24,000 bytes. *Workflow rules*, *Working with the
owner* and the short sections after them do not; the introduction tells
an agent whose copy ends early to read the rest (`cat AGENTS.md`), and on
the owner's Mac Antigravity has an always-on rule to do so. Getting the
sections Codex must read inside 24,000 bytes would have meant moving
rules out of the file Claude Code and the reviewers load, so this change
does not (docs/DECISIONS.md, "AGENTS.md puts first what Codex reads").
The whole file is 2,707 bytes past Codex's default 32 KiB: a Codex at
default settings stops inside *Where things are* and must read the rest,
as the introduction says; on the owner's Mac Codex reads 131,072 bytes.

How it was done. Round 1 reached 23,906 bytes by emptying seven of the
nine must-read sections into one-line pointers and paraphrases, which
would have hidden their rules from Claude Code and the reviewers; it was
discarded. Round 2 kept every rule and moved only the reference
material. Round 3 moved four more background passages and tightened
prose. The Claude thread then restored the original wording of the
stakes, the introduction's facts and six *Workflow rules* bullets where
the rule-by-rule check found a lost word (below), and rewrote the short
sections after *Working with the owner* so that each rule there is a
plain, complete sentence.

Also in this pull request:

- **Codex's hook gap.** AGENTS.md, docs/AGENT-REFERENCE.md and
  docs/SDLC.md said git-ignored hooks hold Codex and Antigravity to what
  the guard refuses with no exception. They now say that Codex's hook
  does not see input typed into a command already running (its
  `write_stdin` does not run `PreToolUse` again; Antigravity's
  `send_command_input` is checked), as docs/HANDOFF.md already said, and
  that it acts only inside a Brickson checkout.
- **Two record corrections.** docs/log/2026-11-12-jules-wind-down.md
  claimed more than docs/HANDOFF.md said, and said #94 is reviewed like
  any other pull request; #94 was closed without merging at
  2026-11-12T05:03Z. docs/log/2026-11-12-no-farther-out.md said its
  session had no route to a Mac; the Mac was reachable, but CI built and
  tested the code.
- **Snapshot.** The old AGENTS.md, byte for byte, is
  `docs/archive/2026-11-12-before-agents-md-trim/AGENTS.md`.

## Commits

See the pull request's commit list. The bridge cannot yet let Codex
commit (its sandbox cannot write a worktree's git folder), so the Claude
thread committed after checking.

## Rules that now live only in docs/AGENT-REFERENCE.md

Each bullet is one rule, grouped by its reference section. Rules still
stated in AGENTS.md, including its short rules, are not listed here.
Measurements, file inventories and historical observations are not rules.

### Direction

- Follow the releases in order while using the long-term vision to guide
  direction.

### Planned privacy sections

- When shipping recorded phrases, caregiver alerts or Siri and
  Shortcuts, restore that feature’s privacy section and make the feature
  match it.
- Keep recordings on the device.
- Caregiver alerts must advertise a random service name and send the
  device name only inside the encrypted alert.
- App Shortcut phrases and parameters must never contain phrase words.
- Obtain the owner’s decision before building caregiver alerts, whose
  network code invariant 9 forbids.

### New major Xcode

- When moving to a new major Xcode, read what Apple has newly replaced
  and recheck every framework-exception row.

### Build and test

- For cloud work pushed before the Mac can test it, require a green Mac
  run or CI before calling the pull request ready.
- Allow no test exceptions or unexplained skips; a known limitation must
  use strict withKnownIssue naming its decision so an unexpected pass
  fails.
- Before an archive, run scripts/test.sh device -configuration Release
  on a Mac to catch Release-only warnings.
- Push to an open pull request only for failed CI, a real bug or rule
  violation found in review, or moved main that must be merged in.
- Batch cosmetic, wording and style findings into an otherwise needed
  push, or answer and resolve them without code; never push once per
  finding.
- Record declined findings in DECISIONS or HANDOFF with an otherwise
  needed push; after the final push, put them in the pull request
  description for the next pull request to record.
- After the final push, answer and resolve remaining threads in words,
  but leave real bugs, rule violations and failed CI open and tell the
  owner the problem and proposed fix; the owner decides on another push.
- After the final push, let owner-enabled auto-merge finish once its
  requirements pass.
- A cloud session that reaches the Mac builds and tests there in a
  separate worktree.
- Push the branch before creating its detached Mac worktree; after later
  pushes, fetch the branch, update that worktree and regenerate its
  project.
- Bring String Catalog changes from a detached Mac worktree back to the
  working branch and commit them there.
- Remove the detached Mac worktree after the pull request merges.
- For MobileBuildMCP, inspect defaults, set the worktree project,
  Brickson scheme, Debug, a listed simulator, worktree build/DerivedData
  and persist false; inspect defaults again before later builds.
- Build app and unit-test products with buildForTesting true, then pass
  testProductsPath to test_sim and report actual test counts; zero tests
  is not a pass.
- When a MobileBuildMCP test outlasts its wait, read the result bundle
  through Remote Control.
- Run test-docs.py, test-hooks.py and test-privacy.py yourself before
  pushing when using MobileBuildMCP.
- Record Xcode, simulator and iOS for either Mac testing route and keep
  guard rules yourself where Remote Control hook coverage is unverified.
- Regenerate the project after adding, removing or renaming files; never
  commit the generated project.
- Look up current Xcode on Apple’s releases and system-requirements
  pages, never from memory.
- Set the deployment target so every eye-tracking-capable device runs
  the app and every accessibility API in the ALS-stage map remains
  reachable, with availability guards for newer APIs.
- If Codex posts an environment-setup notice instead of a review, say so
  in the pull request and thread.
- A privacy or workflow pull request without the opening security review
  must wait for an owner-run Codex security review or another security
  review before merging.
- If privacy or workflow changes arrive after opening, the ready message
  must say the opening security review did not cover them and a security
  review is needed before merge.
- If cubic has not reviewed, request its review with @cubic-dev-ai
  review this PR.
- Request CodeRabbit review after the push intended for review; its
  rate-limit command can check availability without consuming a review.
- The agent opening a pull request answers and fixes every review round.
- Turn off reviewer features that commit or open pull requests wherever
  a setting exists.
- Ask Greptile with plain @greptileai, never a tier request.
- If Copilot review fails for lack of credits, say so in the pull
  request and thread and do not retry.
- Never request a Copilot task, or request its review through gh, the
  API, reviewer fields or mentions.
- Read Copilot Autofix suggestions as review comments; never commit them
  as supplied.
- Treat a Dependabot pull request as not security-reviewed until the
  owner reads it.
- Commit the String Catalog updated by the unit run; CI must fail when
  it differs from the code.
- UI tests run on both iPad and iPhone every time.
- Test runs with zero tests or unreadable counts fail.

### Guardrails for agents

- Guarded commands must not stage all files or commit with -a, approve a
  pull request, or write files directly onto main.
- Guarded commits and GitHub text must be readable before execution and
  checked for personal details; do not supply text hidden by shell
  construction, an editor, recovery file or commit autofill.
- The guard must reject alternate repositories, indexes or commit
  identities that prevent checking the actual commit and text before
  execution.
- The guard must reject release-asset uploads and gh paths that bypass
  checking: repository creation with implicit or explicit push, terminal
  prompts, pre-command options, extensions or newly defined aliases.
- The guard must reject pushes that skip the privacy hook or whose named
  branch lacks it, including commands that change the hook,
  configuration, check or branch before pushing.
- Do not name the private list or its containing configuration folder in
  command or file tools, by path or glob, or print the whole
  environment.
- Policy hooks must use onFailure block; confirm runtime support and
  hook reload before relying on startup, crash, output or timeout
  failures to block actions.
- Without the private list, the privacy check refuses to pass; describe
  --no-list only as pattern checking, never as a pass.
- In a cloud thread run the privacy check’s --status; if it reads a list
  but pushes lack the hook, enable the hook in your own clone.
- Quoted words after a file name and comma must name a section unless
  QUOTATIONS explicitly treats them as a quotation.
- A cited subheading must belong to or sit beside the preceding heading;
  bare italic titles in reviewer instructions must resolve.

### Where things are


### Skills

- Use the named per-machine specialist skills for their relevant domains
  when present.
- For Apple APIs, exported Apple skills lead over other skills; use the
  named specialist, modernization and resizability skills for their
  stated domains.
- Use device-interaction and audit-xcode-security-settings only on the
  Mac with Xcode tools; audit changes belong in project.yml, never the
  generated project.
- Do not apply adopt-c-bounds-safety or
  building-document-based-swiftui-applications here.
- AGENTS.md, DECISIONS and Apple documentation looked up at the time
  outrank every skill, including Apple’s.
- Export Apple’s skills again after each new Xcode release.

### Gotchas

- Outside scripts/test.sh ui, show the full software keyboard and mark
  the sliding-to-type introduction shown before typing tests.
- For Display Zoom measurements, boot the simulator yourself, prepare
  its configuration and verify the window size before trusting
  measurements.
- Rotate simulators with XCUIDevice.shared.orientation in a UI test and
  set Dynamic Type per launch.
- Use one simulator per agent, addressed by destination id; shutting
  down all simulators also stops other agents’ devices.
- Include function parentheses in Swift Testing only-testing filters;
  pass multiple flags as a zsh array, not one string.
- Time long new chain sweeps alone and report their added time in the
  pull request.
- Keep chain-engine inner loops plain and pin shortcuts with tests
  comparing them to the plain implementation.
- Rerun a timeout with no failures once only if unchanged preparation
  steps were clearly slower than main’s last run; a second timeout or
  normal-speed timeout requires reducing test cost without weakening
  tests.
- After UI taps, use existence or property expectations; assert
  unchanged state only after waiting for the change that did occur.
- Launch UI tests through launchedApp for fresh test storage, language,
  size, appearance and orientation; release builds ignore test launch
  arguments.
- Count captures only for what they visibly show.
- Keep an independent rendered-appearance screenshot gate using the
  empty gutter between Yes and No, not a median dominated by
  constant-color tiles.
- Rendered-label recognition must match whole words case-insensitively
  without language correction or recognition hints.
- Tall captures may be read in a band around drawn words and surrounding
  punctuation dropped, but neither may add a letter; exclude button
  borders from the word band.
- Keep rendered-word regression fixtures for whole, clipped and tall
  captures, with and without borders, and pin recognition settings.
- Run KeyboardProbeTests on every UI run; fail if the keyboard exceeds
  its allowance, critical controls enter its band, or only the
  hardware-keyboard bar is shown.
- Add new keyboard measurements to KeyboardAllowanceTests and raise that
  shape’s reference; report the simulator and iOS version.
- Never ship the Home large-content-viewer probe build.
- For iPhone Duo diagnostics, use one snapshot’s coordinate space and
  active-display captures; preserve existing failures and do not extend
  phone-idiom landscape skips to the inner display.
- After booting iPhone Duo, wait a few minutes before trusting black
  captures; never count Device Hub accessibility readings on Duo as
  evidence.
- Keep both the dedicated iPhone Duo runtime and the general iOS
  runtime.
- Every sound check needs a real device.
- Retry an accessibility-audit timeout once only for error -56; a second
  timeout fails and previously reported findings remain failures.
- Never retry or discard an accessibility finding to make CI green.
- A crash cannot be a known issue; commit its reproduction disabled and
  name its issue.
- Relaunch before inspecting the store to flush its write-ahead log.
- Do not restore simulator novelty voices to automatic voice selection.
- Use command cp and equivalent explicit commands in the Mac’s
  interactive shell to avoid its aliases.
- Before changing waits for slow CI UI tests, read simulator-load
  records to check wallpaper prewarm and paused extensions.
- Pause wallpaper extensions only on simulators the test script started,
  never ones it did not start.
- When cloud permissions block workflow changes, push the rest and give
  the owner the complete workflow text to commit; workflow action
  changes go through the Mac.
- On the Mac, run gh actions-lock from the worktree root for new
  workflows or changed uses lines, read the full diff, verify the lock,
  and commit the workflow and lock together.
- Never delete the action lockfile to clear an error.
- Only the owner may accept moved tags with --relock or --accept-moved
  after reading upstream changes; never run either in automation.
- Keep the local actions-lock extension at the release pinned in
  verify-lockfile.yml; update that pin when a newer extension release
  exists.
- Keep CodeQL default setup for workflow files and Python; do not add
  Swift or turn CodeQL off while required results would block merging.


## Verified

On the owner's Mac (macOS, Python 3), documents only:

- `python3 scripts/test-docs.py`: every cited section and link resolves
  in the repository's files; the only failures came from ignored bridge
  job files under `build/`, which CI does not have.
- The invariants, every *Code Review Rules* bullet, the privacy, layout
  and design sections and *Working with the owner* compared byte for byte
  with the snapshot, apart from the planned-features pointer and the
  four background passages listed above.
- A checklist of every rule in the old AGENTS.md: 1,579 single rules,
  each listed by one agent and then checked for gaps by a second. Each
  old paragraph or bullet was then matched, after normalising spaces,
  against the new AGENTS.md and docs/AGENT-REFERENCE.md: 96 carried
  over word for word in AGENTS.md, 76 moved word for word to the
  reference, none copied into both, and 20 reworded. The 376 rules in
  the reworded ones were checked by two independent reviewers each (one
  told to look for any loss). They found 29 rules weakened or dropped:
  lost words such as "anything" in "before changing anything", "for the
  change", "a work file", "which keyboard showed", and a moved sentence
  whose "this file" now meant the reference. Every one was fixed by
  restoring the original words or naming the file, except the fact that
  AGENTS.md is longer than 32 KiB, which is no longer true.
- A third pass asked, section by section, whether each moved paragraph
  could leave the file every agent loads. Its 20 objections were met by
  the short rules now in AGENTS.md (cloud agents without a Mac, the
  verifier, the guard in cloud threads, `~/code/brickson`, the privacy
  check's output, device checks, `docs/recon/`, developer.apple.com's
  `.md` pages, the `core-data` skills, required check names, the
  reviewers' instruction files, the launch rule, `ViewThatFits`, Remote
  Control's idle stop, committed project files and the JSON project
  format), or are listed above as background.

## Not verified

- The planned confirmation step (three more reviewers trying to refute
  each of the 29 findings) did not run: the session reached its usage
  limit. The findings were fixed as reported instead, which is the
  stricter choice.
- The short rules after *Working with the owner* were written after the
  rule-by-rule check; each repeats part of a rule whose full text is
  unchanged in docs/AGENT-REFERENCE.md.
- Whether Codex's review on GitHub or Codex cloud reads past 32 KiB is
  still not documented.
- Nothing was built or run: there is no Swift change. CI is the build.

## Follow-ups

- **The owner:** whether to go further for Antigravity's cut, by moving
  rules out of AGENTS.md; this change does not.
- **A later code change:** a check in `scripts/test-docs.py` that
  *Code Review Rules* ends within 24,000 bytes, and perhaps one for the
  whole file; it still checks only that the sections Codex must read
  end within 32 KiB. The same check reads ignored files under `build/`,
  so a bridge brief there can fail it on a Mac.
- **A later code change:** the same hook gap in the docstring of
  `.claude/hooks/guard.py`.
- **Open pull request #98** adds a paragraph to the iPhone Duo gotcha in
  AGENTS.md; whichever of the two merges second moves it into
  docs/AGENT-REFERENCE.md, *Gotchas*.
- **The bridge:** let a Codex write job commit (recorded as the bridge's
  next item).
