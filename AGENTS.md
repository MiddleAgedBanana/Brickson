# Brickson — Agent Briefing

The rules for every coding agent working here. Codex and Antigravity read
this file directly; Claude Code reads it through `CLAUDE.md` (which holds
only `@AGENTS.md`). Put agent instructions here, never in an
agent-specific file. Keep it short: Codex reads only the first 32 KiB
([`project_doc_max_bytes`](https://developers.openai.com/codex/agent-configuration/agents-md))
and Antigravity the first 24,000 bytes, so the rules that protect people
come first, and `scripts/test-docs.py` fails if the sections through
*Working with the owner* end past 32 KiB. If your copy of this file ends
before *Gotchas*, read the rest from the repository (`cat AGENTS.md`)
before changing anything. Why each rule exists is in docs/DECISIONS.md
and docs/LESSONS.md; current state is in docs/HANDOFF.md.

## What this is and what's at stake

Brickson is an iPhone and iPad app that speaks for people living with
ALS, at every stage of the disease: a person chooses a phrase or types,
and the app says it aloud, in their own Personal Voice if they banked
one. It works with touch, Voice Control, Switch Control, Full Keyboard
Access, AssistiveTouch with Dwell, head tracking and Eye Tracking. It has
no accounts, no servers, no ads and no analytics.

**The people using it may be unable to speak or move.** A bug can leave
someone with no way to ask for water, answer a question or call for help.
Correctness and accessibility outrank performance and elegance.

**One app follows a person as the disease progresses, so they never
relearn it.** Sizes, spacing and dwell protection change from touch to
switches to eyes; where each control sits never does. Build the boring,
reliable way (proven APIs, plain testable types), but judge every feature
by one question: does it make communication faster, clearer or more
reliable on the input method the person actually uses?

## Non-negotiable invariants

Tests and reviews enforce these; the numbers match the reference app's.

1. **Every interactive element is a standard SwiftUI `Button`** (or a
   standard system control) with an accessibility label and a target of
   at least 44×44pt, larger where the active profile sets a higher floor.
   Never gesture-only controls, never custom input, switch, head or gaze
   code.
2. **Every phrase speaks on the first activation**, by any input method,
   in every profile: no confirm step, no load-then-speak, not even as an
   option. Emergency is visible on Home in every state, never in a
   scrolling region and never covered, including by the software
   keyboard; it switches straight to the emergency phrases and leaves edit
   mode, and emergency phrases never open editors. One pure resolver owns
   that decision and every tap path goes through it.
3. **Speaking never changes data.** Every change to a person's phrases sits
   behind an explicit edit mode; every delete, replace or merge asks first,
   with Keep in the asking control's place and the confirmation where a
   repeated activation cannot reach it.
4. **Audio survives.** Speech and alarms use the `.playback` session (never
   `AudioServicesPlaySystemSound`) and recover from interruptions, route
   changes and media-services resets. A failure the person cannot hear
   shows as passive, layout-reserved text that never replaces the message,
   adds a dismiss control or moves a target. Observe but never set system
   volume. After a media-services reset, rebuild audio objects but wait for
   the next user action before activating. An interruption keeps the
   text and names a reachable control to retry; never auto-resume into a
   changed route.
5. **No silent failures.** Every `catch` recovers, shows the person
   something, or both. A failed save never crashes the app or leaves data
   half-changed, and every save path has a test that makes it fail
   (docs/LESSONS.md, "Never roll back a cascade delete").
6. **Contrast is measured, never eyeballed.** Text at least 4.5:1, control
   edges at least 3:1, in light, dark, Increase Contrast and Reduce
   Transparency, including system components the app shows. White on
   system red or system orange is forbidden. Pin every pair in
   `PaletteTests`.
7. **Never put words about a person's condition in their mouth.** The
   starter library holds only neutral, practical phrases; extra sets are
   opt-in, never seeded. Nothing (repair, migration, import) may delete a
   person's own words.
8. **Position is never a function of usage or time.** No frequency,
   recency or adaptive ordering; fixed column counts; a slot keeps its
   place across categories and every control keeps its relative position
   across stage profiles. A recents zone, if ever built, is fixed in
   place; only its contents change.
9. **Hard stops (never build):** accounts or login, servers or network
   code, cloud sync, analytics, ads or tracking, third-party packages or
   SDKs, AI-generated replies, custom gesture-only interactions, custom
   eye, head or switch tracking. The privacy manifest declares no data
   collected.
10. **Dwell safety.** Where dwell, pointer snapping or switch auto-select
    can repeat an activation, no control turns into its opposite in place
    (start and stop live apart), and a mode switch never leaves a
    speaking, alarming, position-changing or destructive control nearest
    the spot just activated; chains of activations are scored, not only
    the first. A repeat of the phrase being spoken is absorbed
    (`SpokenUtteranceTracker`). Get Attention, Emergency, Yes and No are
    one activation away from every Home state, including while typing.
    Every exception is named, measured and recorded in docs/DECISIONS.md.
11. **No scrolling on Home for the starter library** in any dwell, switch,
    head or gaze profile on any supported device and window, and never
    shrink targets below the profile's floor to avoid it: where a window
    cannot hold a profile's floors, Home takes the largest smaller profile
    it can (docs/DECISIONS.md, "Sizes that follow how the screen is
    reached"). Every size comes from the tested layout engine. A library
    a family has grown may scroll at the floor. Nothing reflows when the
    keyboard appears.
12. **The screen never locks while Brickson is open** (`ScreenWakePolicy`).

## The privacy policy is a promise

The policy (`site/privacy/index.html`) says what the app does with
people's data. A change that makes any sentence untrue updates the page,
its Effective date and the in-app copy in the same pull request.

- SwiftData opens with `cloudKitDatabase: .none`; the app has no iCloud
  capability.
- Never put a person's phrase, draft or category text, or an error that
  may contain it, in `fatalError`, `precondition`, `assert` or any crash
  message.
- Store nothing in the Keychain.
- Recorded phrases, caregiver alerts and Siri and Shortcuts are not in the
  policy because 1.0 does not ship them. The pull request that ships one
  adds its section back and matches it: recordings stay on the device,
  caregiver alerts advertise a random service name and send the device
  name only inside the encrypted alert,
  App Shortcut phrases and parameters never contain phrase words.
  Caregiver alerts need network code, so the owner decides first.
- Settings' Privacy row shows the policy in the app and opens the web page
  in an in-app sheet (`SFSafariViewController`), never Safari.

## Layout on every device and window

- **Lay out from the space available**, never from the device: window
  size, size classes, safe areas and Dynamic Type, through standard
  SwiftUI containers and navigation. Never choose an interface by device
  model, physical screen size, a device table, orientation or
  `userInterfaceIdiom`.
- One tested layout engine turns that space into frames; nothing in it
  names a device.
- iPhone Duo's fold and camera are reserved regions in the space
  available, never a device check (docs/DECISIONS.md, "iPhone Duo").

## Apple's current frameworks first

- Use the current framework for each job: SwiftUI not UIKit, SwiftData not
  Core Data, Swift Testing not XCTest, App Intents not SiriKit,
  Observation not Combine or `ObservableObject`, Swift concurrency not
  Dispatch; within a framework, its current Swift API, never an older or
  deprecated one. A legacy one only when no current one
  does the job with no loss (an ordering guarantee, a measurement's
  precision, a test's strength, a behaviour the person sees), with its row
  in docs/DECISIONS.md, "Apple's current frameworks first"; the pull
  request that moves to a new major Xcode rechecks every row of it.
- A file that uses UIKit's own types imports UIKit by name. A test that
  drives no app uses Swift Testing in the unit tests; XCTest is for UI
  automation only.
- Look Apple APIs up, never recall them: Context7, the Xcode MCP's
  `DocumentationSearch`, or developer.apple.com with `.md` appended to the
  page's path (the HTML page is an empty shell). Say when you could not.

## Design rules for dwell, switch and pointer input

For every profile where a resting pointer or a scan can activate
something:

- Wherever a pointer rests can activate: large targets, generous spacing,
  and no harmful control (speaks, alarms, deletes, reorders, changes a
  setting) nearest text the person reads or empty space they rest on.
- Scrolling costs dwell, head and switch users several activations.
- Target floors are physical sizes converted at the densest supported
  screen, so no code names a device (docs/DECISIONS.md, "Sizes that
  follow how the screen is reached").
- Keep corners clear of controls (dwell hot corners, window controls, the
  home indicator); never hide a standard Back button to do it.
- **Family controls stay out of the person's path.** Settings opens on a
  large way back and a start-only Get Attention; edit mode ends itself
  when idle; timeouts reset screens, never close them.
- **Words never break.** Labels shrink only as much as needed, drop a
  decorative icon before shrinking words, and never render below their
  default size.
- **Typing never hides the call for help.** Emergency, Get Attention, Yes,
  No, Speak and the way out sit above the worst-case software keyboard
  from the moment typing opens; Return speaks as an extra path.
- **Controls keep their frames across every state of a screen**,
  including keyboard show and hide.
- An alarm stops only from a separate, differently placed control. Fix
  hazards with placement, never with timers, decoy buttons or custom
  pointer code. Keep standard Back, Close and swipe navigation.
- **Score chains with the one chain engine.** `ChainEngine` follows held
  activations from every start; a new screen becomes a surface for it,
  never another nearest-control script.

## Code Review Rules

Every reviewer reads this section (Codex looks for this heading; the
steps in `.github/skills/code-review/SKILL.md` cite these titles). Flag a
change that does any of the following, name the invariant, and show the
path from a real input to the failure.

### Communication never fails

- A phrase that needs a second activation, a confirmation or a load
  before it speaks; Emergency, Get Attention, Yes or No more than one
  activation from any Home state, or covered (invariants 2 and 10).
- A failure the person cannot hear that shows nothing, a `catch` that only
  logs, a save path with no test that makes it fail, or
  `ModelContext.rollback()` after a cascading delete (invariants 4, 5).

### Dwell and gaze safety

- A control that turns into its opposite in place, or a mode switch that
  leaves a harmful control nearest the spot just activated (invariant 10;
  safe path: placement); an order that depends on usage or time
  (invariant 8); new scrolling on Home for the starter library, a target
  below its floor, or a layout that moves with the keyboard (invariant
  11).
- An interface or size chosen by device, physical size, orientation or
  `userInterfaceIdiom` instead of the space available.

### Data, privacy and platform

- Anything that deletes or rewrites a person's own words in a repair,
  migration or import (invariant 7).
- Network code, accounts, analytics, cloud sync, a third-party package or
  SDK, or a new data type in the privacy manifest (invariant 9).
- A closure a framework may call off the main thread that is main-actor
  isolated by default (it crashes under Swift 6); safe path:
  `@Sendable` or `nonisolated`, tested in `OffMainThreadCallbackTests`.
- A new legacy framework or API with no row in docs/DECISIONS.md, or
  where a current one does the job with no loss.
- Elapsed time measured with `Date` instead of `ContinuousClock`.
- A colour pair not pinned in `PaletteTests` (invariant 6).
- A sentence of the privacy policy made untrue without updating
  `site/privacy/index.html` and its Effective date, or a broken privacy
  code rule above.
- Personal names, email addresses, or health or family details in a
  committed file: the repository is public. The owner's exceptions, each
  only for what it names:
  - the developer's name and support email on the website's pages in
    `site/`, which Apple requires;
  - the short "Why Brickson?" founder note in `README.md` and
    `site/index.html`, attributed to Avery Dedmon, and its record in
    docs/DECISIONS.md and docs/HANDOFF.md (docs/DECISIONS.md, "Brand name
    and founder story");
  - Avery Dedmon's copyright attribution in `LICENSE.md` and the README's
    license notice (docs/DECISIONS.md, "Brickson's code is all rights
    reserved");
  - Avery's own name, their brother's first name, their own email
    addresses and the Claude session links, anywhere in the repository,
    its commits and its pull requests (docs/DECISIONS.md, "Personal
    details stay out of the repository", *Avery's decision of
    2026-11-08*).

  None permits other family identities, the brother's medical or hospice
  details, phrases, device or settings, family quotes, private documents
  or the Mac's account name.
- Text that says what Brickson costs before docs/DECISIONS.md records the
  owner's decision ("Price not decided").

### Tests, workflows and the rules themselves

- A test that cannot fail, a filter that runs no tests, a weakened
  assertion, an unexplained skip, or a `withKnownIssue` that is not strict
  or names no decision.
- A workflow change that lets pull request code reach secrets or a write
  token (`pull_request_target`, wider `permissions`), or puts pull request
  text into a shell command.
- A new action not published by GitHub, a `uses:` line changed without
  `.github/workflows/actions.lock`, or a lockfile edited by hand. In a
  lockfile diff, a changed `commit` is new code the workflows will run,
  and a changed `owner_id` or `repo_id` means another repository now holds
  that name: say so for the owner.
- A renamed required job or a path filter on its workflow (*Gotchas*).
- An Xcode, SDK, simulator or runner version written in when the owner
  did not ask, or a build with anything but Apple's newest released Xcode.
  The `runs-on` label naming GitHub's image for the current Xcode is not a
  pin, and a dated record of what something was measured on is history.
- A warning silenced instead of fixed, without its line in
  docs/DECISIONS.md, "Warnings are errors".
- A change that weakens an invariant or review rule, adds an exception or
  widens *Not findings*, in `AGENTS.md`, docs/DECISIONS.md,
  `.github/skills/` or any other file reviewers read; and any new file of
  that kind. Compare with the base branch; the owner decides.
- A change to `.claude/settings.json`, `.claude/hooks/`, `.githooks/` or
  `scripts/privacy-check.py` that unhooks the guard or the privacy check,
  drops a deny rule or lets through what its tests refuse, or a weakened
  `scripts/test-hooks.py`, `scripts/test-privacy.py` or
  `scripts/test-docs.py`.

### Not findings

- Formatting or naming on its own.
- A gap the base branch already records as accepted in docs/DECISIONS.md
  or docs/HANDOFF.md, *Known gaps*, unless the change makes it worse or
  newly reachable, or claims to close it and doesn't; a planned feature
  not built yet.
- The accessibility audit's "not human-readable" guess on phrase labels
  (Home's phrase tiles and the Library's phrase rows).
- That a cloud agent did not run the app: CI is its build.

## Workflow rules

- **Test first.** New behaviour gets a failing test, a bug fix a failing
  reproduction; name the change that would make each new test fail.
- Logic lives in plain, testable types; views only read them.
- Swift 6, strict concurrency, default main-actor isolation; notification
  observers use `queue: .main` plus `MainActor.assumeIsolated`.
- Elapsed time uses `ContinuousClock.Instant`; pure types take `now:`;
  `Date` only for times people read.
- Words people see go through the String Catalog; a person's own words
  use `Text(verbatim:)`.
- **Run it, don't just read it.** Check layout and flow changes on an iPad
  and an iPhone simulator, default and accessibility text sizes, light and
  dark, and say what each result was measured on. An activation,
  reachability or keyboard claim counts only from a UI test through
  `launchedApp`, Device Hub's own input or a person on a real device,
  never from an automation tool's report. Simulators prove nothing about
  sound, gaze comfort or Snap to Item.
- **Stage only your own changes** (`git add <paths>`, never `git add -A`);
  never touch someone else's uncommitted work or stashes. One task per
  commit, with a plain message.
- **Branches and pull requests.** Branch `<agent>/<topic>` from the latest
  fetched `main`; one pull request per piece of work, using
  `.github/pull_request_template.md`. Never push to `main`, force-push or
  rewrite pushed history; bring in a moved `main` with a merge commit. Keep
  a pull request body's first two attribution lines.
- Before every push, run the checks for the change (*Build and test*) and
  `python3 scripts/privacy-check.py --outgoing` (`--no-list` where there is
  no list, saying so in the pull request), and check any pull request text
  or comment with `--text -` before posting. Never repeat what it finds.
  Batch commits into one push: each push cancels running CI.
- **Document every change** in the same pull request: one new
  `docs/log/` file (template in `docs/log/README.md`); edit untrue lines
  of `docs/HANDOFF.md` in place, never append; record decisions in
  docs/DECISIONS.md and new rules here; edit `docs/ROADMAP.md` when an
  item starts, lands or moves, and `README.md` when setup or behaviour
  changes. Snapshot before removing information from HANDOFF or this file
  (`docs/archive/README.md`). Record reversals and their reasons. Where
  this file or a document is wrong,
  record it and propose the fix in the log; never silently work around
  it.
- Keep evidence later work needs in an ignored folder of the worktree or
  in `docs/log/`, never in `/tmp` or only in chat.
- FamilyVoice (`MiddleAgedBanana/ALS-app`, private) is reference only:
  never push to it or open a pull request on it. This file wins over its
  AGENTS.md and over `docs/recon/`. Read the sections of docs/LESSONS.md
  that touch your work. A feature that changes what a person sees or hears
  starts with a work file in `docs/work/`. A change to an accessibility
  feature edits its row in `docs/ACCESSIBILITY.md` and the website's
  accessibility page, which never says "works with" before a real-device
  check.
- Start each session with `git status`, `git log --oneline -15` and
  `git fetch origin`, then read this file, docs/HANDOFF.md,
  docs/DECISIONS.md and the newest
  `docs/log/` records from `origin/main` before changing anything. Check
  your own tools for build, simulator and Mac access.

## Working with the owner

The owner is new to programming. Explain in plain words: what a thing is
and why it matters, before how. Make routine decisions yourself and say
so; ask only about real trade-offs, together, with a recommendation. When
the owner must run a command, give it exactly with what success looks
like.

## Build and test

```sh
# Any machine, cloud threads too (CI runs them all):
python3 scripts/test-docs.py && python3 scripts/test-hooks.py && python3 scripts/test-privacy.py
python3 scripts/test-runner.py && python3 scripts/test-agent-bridge.py && python3 scripts/test-site.py && python3 scripts/test-select-xcode.py
# On a Mac:
scripts/test.sh          # generate the project, build, run the unit tests
scripts/test.sh ui       # the UI tests on an iPad and an iPhone simulator
scripts/test.sh device   # a build for a real device (needs DEVELOPMENT_TEAM)
scripts/test.sh unit '-only-testing:BricksonTests/PaletteTests/theContrastFormulaMatchesWCAG()'  # one test; keep the ()
SIMULATOR_FAMILY=iphone scripts/test.sh ui                         # one family
DESTINATION='platform=iOS Simulator,id=<udid>' scripts/test.sh ui  # one simulator
# Results: build/TestResults/<mode>-<family>.xcresult
```

- On a Mac the unit suite is 100% green before any commit; CI is green
  before any merge. **Warnings are errors**: fix the code, never silence
  it (docs/DECISIONS.md, "Warnings are errors").
- Build with Apple's newest released Xcode, never a pinned version; never
  write an Xcode, SDK or simulator version into the project, a script, a
  workflow or a document unless the owner asks. CI builds Debug only:
  before an archive, run `scripts/test.sh device -configuration Release`.
  The oldest supported iOS follows docs/DECISIONS.md, "Minimum iOS, iPhone
  and iPad".
- `Brickson.xcodeproj` is generated from `project.yml`: never edit,
  commit or open it from an agent, and never move the build to Xcode's
  JSON project format outside the pull request docs/DECISIONS.md plans;
  regenerate after adding or renaming a file. Commit the String Catalog a
  unit run updates.
- Cloud agents with no route to a Mac cannot build or run the app: say so,
  treat the change as untested until CI or a Mac run passes, and call the
  pull request ready only once the Mac's run or CI is green.
- A cloud session that reaches the owner's Mac (Remote Control,
  MobileBuildMCP) builds and tests there; never conclude from a handoff
  that you cannot. On the Mac, never check out, stash, reset or clean in
  `~/code/brickson`, and never pull `main` there. Build a pushed branch in
  its own worktree: `cd ~/code/brickson && git fetch origin <branch>`,
  `git worktree add --detach ~/code/brickson-<topic> origin/<branch>`,
  then `xcodegen generate` there; after a later push, fetch and
  `git checkout --detach origin/<branch>` again. A String Catalog change
  made there comes back as a diff to commit from your own session. Once
  the pull request merges,
  `git -C ~/code/brickson worktree remove ~/code/brickson-<topic>`.
- MobileBuildMCP builds and tests only: set the worktree's
  `Brickson.xcodeproj` (full path), scheme `Brickson`, a simulator id from
  `list_sims`, `derivedDataPath` under the worktree's `build/` and
  `persist: false`; `build_sim` with `buildForTesting: true`, then
  `test_sim` with its `testProductsPath`. A run with no tests is not a
  pass; for a run longer than its 60-second wait, read the result bundle
  with `xcrun xcresulttool get test-results summary`. Run the Python
  checks yourself.
- **Pushing to an open PR.** At most three review rounds from opening,
  one push each, never while CI is still running; then one final push for
  what is left. Push only for failing CI, a real bug or rule violation, or
  a moved `main`. Answer every review comment and resolve its thread;
  record declined findings in docs/DECISIONS.md or docs/HANDOFF.md with a
  push you make anyway, or after the final push in the pull request's
  description. A real bug, rule violation or failing CI found after the
  final push stays open: tell the owner the fix you propose, and the owner
  decides whether another push goes in. A run stopped at the time limit
  with no failure is re-run once only if its unchanged steps were clearly
  slower than on `main`; otherwise cut what the tests cost without
  weakening any. Agents never merge, approve or enable auto-merge.
- **Reviews and updates on GitHub.** Codex reviews every push by itself:
  never post an `@codex` comment. Ask CodeRabbit with `@coderabbitai
  review` after the push to review, and cubic with `@cubic-dev-ai review
  this PR` if it has not reviewed; ask Greptile with a plain
  `@greptileai`, never for a tier. Reviewers never write code: no autofix,
  "Fix with cubic" or fix request. Before opening a pull request that
  changes code, run `codex review --base origin/main` where the Codex CLI
  is installed (the owner's Mac) and answer its findings, or say in the
  pull request that it could not run; right after opening, ask for one Copilot review, only through
  `request_copilot_review` (a request that fails for lack of credits is
  said in the pull request and the thread, never retried).
  Documents-only pull requests get none. Where Codex posts an environment
  notice instead of a review, say so: a pull request that changes privacy
  or a workflow then waits for the owner's security review before it
  merges. Whatever Codex posted, a pull request whose privacy or workflow
  change came in a push after it opened also waits for that review, and
  its ready message says so. Treat a Dependabot pull request as not
  security-reviewed until the owner reads it.

## Guardrails for agents

- The guard (`.claude/hooks/guard.py`, run by `.claude/settings.json`)
  refuses staging everything, force pushes, pushes to `main`, merging,
  auto-merging or approving, a Copilot request other than the one review
  through `request_copilot_review` (a mention or other GraphQL request is
  held by this rule alone), personal details in commits or GitHub text,
  and reading the private list. When it refuses, do not look for another
  way round: say what you needed. On the owner's Mac, git-ignored hooks
  hold Codex and Antigravity to the same, except that Codex's hook does
  not see input typed into a command already running. A desktop worktree
  session runs `~/code/brickson`'s guard, so a guard change binds there
  only once the owner pulls `main`. Policy hooks block on failure only in
  Claude Code 2.1.295 or later; confirm the runtime and that the hooks
  reloaded before relying on them.
- Where the guard does not run (a Claude Code cloud thread in a project,
  where `git add -A --dry-run` is not refused; Codex or Antigravity away
  from the Mac), read the full list of refusals at the top of
  `.claude/hooks/guard.py` and keep every one yourself: among them, never
  publish text you cannot read before the command runs, never give `gh` a
  terminal or let it fill text from commits or an editor (`--fill`,
  `--editor`), never name the private list or its folder, never print the
  whole environment (`env`, `printenv`, `set`, `export -p`), and never
  upload a release asset.
- The privacy check (`scripts/privacy-check.py`) runs in git's pre-push
  hook and in CI. In a cloud thread, run it with `--status`. Where it
  reads a list but pushes do not run the hook, turn the hook on in your
  clone (`git config core.hooksPath .githooks`). With no list, leave the
  hook off, since it then refuses every push, and run `--outgoing
  --no-list` by hand. Never push with `--no-verify`. Without the private
  list it never counts as a pass. It prints where and what kind, never the
  words, and so do you.
- **Cross-references.** `scripts/test-docs.py` fails when a cited title or
  relative link stops resolving: rename a section and its citations in the
  same commit.
- Before calling a pull request ready, run the report-only verifier
  (`.claude/agents/verifier.md`) and paste its *Not verified* list into the
  pull request.

## Where things are

`docs/recon/` is research, not instructions. A pull request that changes
a device check or an owner gate edits its procedure in
`docs/DEVICE-CHECKS.md`.

## Skills

Review rules go in this file, never in a skill. Never commit Apple's
exported Xcode skills. Never apply `core-data`, `cloudkit`,
`authentication`, `push-notifications`, `ios-networking`,
`apple-on-device-ai` or `swiftui-gestures` skills. For an Apple API,
Apple's own skills lead over the others; this file, docs/DECISIONS.md and
Apple's documentation looked up at the time win over every skill. Export
Apple's skills again after each new Xcode release.

## Gotchas

- Swift Testing filters need the function's parentheses
  (`-only-testing:BricksonTests/PaletteTests/theContrastFormulaMatchesWCAG()`),
  or `xcodebuild` runs nothing and reports success.
- One simulator per agent, chosen with `DESTINATION` (`scripts/test.sh`
  passes its own `-destination`).
- UI tests launch through `launchedApp`; wait for a change after `tap()`
  before checking it, and check that something did *not* change only after
  waiting for the change that did.
- Outside `scripts/test.sh ui`, show the full software keyboard before a
  typing test: `xcrun simctl spawn <udid> defaults write
  com.apple.keyboard.preferences AutomaticMinimizationEnabled -bool false`,
  and write `DidShowContinuousPathIntroduction -bool true` to the same
  domain. `KeyboardProbeTests` attaches its `KEYBOARD-PROBE` and
  `KEYBOARD-BAND` lines to the result.
- Time a long new chain sweep on its own and say in the pull request what
  it adds; pin any `ChainEngine` shortcut against the plain way in
  `ChainEngineTests`.
- A crash cannot be a known issue: commit the reproduction disabled,
  naming its issue.
- **A just-started simulator is slow, and the first UI test pays for it.**
  Never put a call to a system service that can be slow on the main
  thread at launch (docs/DECISIONS.md, "The voice list never holds up
  launch").
- **Accessibility frames do not prove visible words fit.** Keep the
  rendered-label regression beside reachability and audits.
- **Audit only a still screen.** Speech and anything else that changes the
  screen must be over before an audit; a wait is not a retry. Never retry
  or discard an accessibility finding to make CI green.
- `ViewThatFits` failed Apple's audit around text here: choose
  arrangements in a plain type and place each view once.
- Check rendered appearance in a screenshot, not `XCUIDevice.appearance`.
  Lazy Forms unload far-off rows, so a missing element may only be
  scrolled away. Novelty voices are excluded from automatic voice choice
  on purpose.
- iPhone Duo has an iOS runtime of its own beside the plain one; keep
  both. Never count an accessibility reading taken inside Device Hub on
  iPhone Duo as evidence.
- **CI results can be read without a Mac.** A result bundle holds
  recordings, attachments and the app's own log; read them before blaming
  the machine (`docs/log/2026-11-01-voice-list-off-launch.md`). Before
  lengthening a wait for a slow CI UI test, read
  `simulator-load-<family>.txt`.
- Simulator audio is unreliable: sound checks need a real device.
- A Remote Control session stops after about 60 idle minutes: run long
  jobs detached, with a check that ends within 45 minutes.
- On the owner's Mac the shell aliases `cp`, `rm`, `grep` and `python3`;
  type `command cp` and so on.
- The `main` ruleset requires the jobs "Unit tests" and "UI tests": never
  rename them or add a path filter to their workflow.
- Cloud agents cannot push `.github/workflows/`; give the owner the file.
  A changed `uses:` line goes through the owner's Mac: run `gh
  actions-lock`, read the lockfile's whole diff, run `gh actions-lock
  --verify` and commit it with the workflow. Never delete the lockfile to
  clear an error; only the owner accepts a moved tag.
- Reviewers read `AGENTS.md`, `CLAUDE.md`, `.github/` and their own config
  (`.coderabbit.yaml`, `.greptile/`, `cubic.yaml`, which cubic takes from
  `main` only); a change to any of them is one *Code Review Rules* flags.
