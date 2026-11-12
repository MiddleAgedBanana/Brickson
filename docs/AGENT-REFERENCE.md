# Agent reference

This holds rules and detail moved out of AGENTS.md, which bind every
agent the same. Read it in the cases AGENTS.md names.

## Direction

**Where it is going** (the owner's vision, docs/ROADMAP.md, *Where this
goes*): over time, the one app a person with ALS keeps open all day,
covering inside Brickson what they and their caregivers need and reaching
the rest through Apple's own doors. It sets the direction, not the order:
work follows the releases, and every invariant in AGENTS.md still holds.

## Planned privacy sections

- Three planned features have no section in the policy, because 1.0
  does not ship them: recorded phrases, caregiver alerts and Siri and
  Shortcuts. Their sections were deleted on 2026-10-23, and their words
  are kept in `docs/log/2026-10-23-accessibility-page-and-privacy-trim.md`.
  The pull request that ships one adds its section back, and the feature
  matches it: recordings stay on the device; caregiver alerts advertise a
  random service name and send the device name only inside the encrypted
  alert; App Shortcut phrases and parameters never contain phrase words.
  Caregiver alerts need network code, which invariant 9 forbids; the owner
  decides before they are built.

## Layout background

The owner's goal (2026-10-21), in Apple's words: "For SwiftUI development,
standard layout and navigation primitives remain the appropriate default,
using adaptive layouts and standard SwiftUI containers, instead of
building device-specific interfaces."

## Reference gaze measurements

For gaze at about 45 cm the reference used phrase tiles of at least
110pt, quick controls of at least 88pt and categories of at least 72pt,
sized on a 13-inch iPad (about 132 points per inch); held at the densest
screen they are about 136, 109 and 89pt.

## New major Xcode

The pull request that moves Brickson to a new major Xcode also reads
what Apple has newly replaced, and rechecks every row of the exceptions
list in docs/DECISIONS.md, "Apple's current frameworks first".

## Plain testable types

`SpokenUtteranceTracker`, `VoiceSelection`, `SpeechRateSteps`,
  `AudioSafetyPolicy`, `AttentionAlertStatus`, `AudioSessionEventMapping`,
  `AudioSessionLeasePolicy`, `ScreenWakePolicy`, `CategorySelection`,
  `StarterLibrary`, `PhraseLibrarySeeder`, `MessageComposer`,
  `DraftStore`, `SettingsIdleClock`, `SetupRecord`, `CheckInPolicy`,
  `VoiceList`, `PersonalVoiceGuidance`, `PrivacyPolicyDocument`,
  `SpeedChoice`, `WordFit`, `HomeRegion`, `HomeControlNames`,
  `HomeStatusLine`, `HomeButtonLook`, `LibrarySnapshot`, `LibraryEdit`,
  `LibraryRules`, `LibraryImport`, `LibraryEditor`, `BackupCodec`,
  `EmergencyRepair`, `SettingsLeadIn`, `SettingsRowPlace`,
  `SettingsScreenFrames`, `SetupAnswersPlace`, `SetupChoicesPlace`,
  `KeyboardAllowance`, `SettingsAppLink`, `HomeLayout`, `ProfileChoice`,
  `RestBoard`, `HomeWordRoom`, `LibraryQuestionPlace`, `RestoreChoices`,
  `LibraryEditorWords`.

## Build and test

```sh
scripts/test.sh          # generate the project, build, run the unit tests
scripts/test.sh ui       # the UI tests: launch the real app and drive it
scripts/test.sh device   # a build for a real device (needs DEVELOPMENT_TEAM)
```

On a Mac, the unit suite must be **100% green before any commit**; for
work made where nothing can be built, CI must be green before the pull
request merges. Work made in a cloud session is committed and pushed
before the owner's Mac can test it (*Build and test*): there the Mac's run or CI
must be green before the pull request is called ready, and CI before
it merges. No exceptions and no unexplained skips. A known limitation is a strict `withKnownIssue`
naming its decision, so it fails when it starts passing.

**Warnings are errors** in every target and build configuration
(`project.yml`; docs/DECISIONS.md, "Warnings are errors"): a compiler
warning fails the build, on CI and on a Mac. Fix the code it names;
never silence it. CI builds Debug only: before an archive,
`scripts/test.sh device -configuration Release` on a Mac shows any
warning only the Release build sees (code under `#if DEBUG` differs).

**Pushing to an open PR.** Review rounds count from the moment the pull
request opens, not from its first green run: at most three rounds, one
push each, and never a push while CI is still running on the last one;
then one final push that batches what is left. A round is the reviews and
CI results that one push brings. Push only when CI fails, a reviewer finds
a real bug or a rule violation, or `main` moved and must be merged in.
Batch cosmetic, wording and style findings into one otherwise needed
push, or answer them in words and resolve the thread; never one push per
finding. Record declined findings in docs/DECISIONS.md or
docs/HANDOFF.md with a push you make anyway; after the final push, list
them in the pull request's description instead, for the next pull
request to record. After the final push, answer the rest in words and
resolve their threads, but a real bug or rule violation found then, or
CI still failing, stays open: tell the owner what it is and the fix you
propose, and the owner decides whether another push goes in. This
replaces counting the
[stop after two rounds rule](log/2026-10-22-agent-guardrail-reconciliation.md#main-refresh-and-declined-findings-2026-10-23)
from the first green run, which never applied to #86: it was first green
at its fourteenth push (`docs/log/2026-11-08-privacy-check-follow-ups.md`).
A PR with owner-enabled auto-merge merges itself on green once its other
merge requirements are met: after the final push, stop and let it.
Agents never enable auto-merge or merge a PR.

**Cloud agents** with no route to a Mac (Codex cloud, a Claude Code
session without the tools below) cannot build or run the app or
its Xcode tests; the Python checks run anywhere, and plain Swift types
can be tested on Linux (`docs/log/2026-11-05-four-phrases.md`). Say so
plainly, treat the change as untested until CI or a Mac run passes,
and never describe unbuilt code as working.

**A cloud session that reaches the owner's Mac builds and tests there**
(first done on 2026-11-05: `docs/log/2026-11-05-four-phrases.md`). Two
tools reach it, and a Claude Code session in this project may have both:
Remote Control, which runs a Claude Code session on the Mac, in `~/code`
or `~/code/brickson`, with the Mac's own Xcode, XcodeGen and
simulators; and MobileBuildMCP, a build tool on the Mac whose tools are
named `MobileBuildMCP__…`. Use neither in the owner's own checkout,
`~/code/brickson`, which may hold their uncommitted work: never check
out, stash, reset or clean there. The route:

1. Push your branch. Then, through Remote Control, make a separate
   worktree of it and generate its project (MobileBuildMCP cannot run
   XcodeGen):
   ```sh
   cd ~/code/brickson && git fetch origin <branch>
   git worktree add --detach ~/code/brickson-<topic> origin/<branch>
   cd ~/code/brickson-<topic> && xcodegen generate
   ```
   After a later push, `git fetch origin <branch>`, then
   `git checkout --detach origin/<branch>` and `xcodegen generate` in
   the worktree. Remote Control can run `scripts/test.sh` there too,
   the only route that also brings the String Catalog up to date. The
   worktree is detached, so nothing made in it reaches your branch by
   itself: if the script changes `Brickson/Resources/Localizable.xcstrings`,
   have Remote Control give you the diff, and commit it on your branch
   from your own session.
   Once the pull request is merged,
   `git -C ~/code/brickson worktree remove ~/code/brickson-<topic>`.
2. MobileBuildMCP: `session_show_defaults`, then `session_set_defaults`
   with the worktree's `Brickson.xcodeproj` by its full path, scheme
   `Brickson` (the unit tests), configuration Debug, a simulator's id
   from `list_sims`, `derivedDataPath` set to the worktree's
   `build/DerivedData` (ignored by git) and `persist: false`. Show them
   again before a later build: they were lost once when the tool
   restarted.
3. `build_sim` with `buildForTesting: true` builds the app and its unit
   tests, with warnings as errors, and gives the path of a
   `.xctestproducts` bundle.
4. `test_sim` with that `testProductsPath` and `extraArgs` such as
   `["-only-testing:BricksonTests/LibraryEditTests",
   "-collect-test-diagnostics", "never"]` runs them and reports the
   counts; a run with no tests is not a pass. The tool waits only 60
   seconds for the Mac's answer: a longer run, such as the whole unit
   suite, keeps going there, and Remote Control reads its result with
   `xcrun xcresulttool get test-results summary --path <bundle>` (the
   newest bundle in
   `~/Library/Developer/MobileBuildMCP/workspaces/*/result-bundles/`).

MobileBuildMCP builds and tests only: run `scripts/test-docs.py`,
`scripts/test-hooks.py` and `scripts/test-privacy.py` yourself before
pushing, as `scripts/test.sh unit` does before it builds. Results from either tool are test results
like a Mac's, recorded with the Xcode, simulator and iOS they ran on; MobileBuildMCP's taps and
snapshots are not evidence (*Gotchas*). Whether the guard (*Guardrails
for agents*) runs in a Remote Control session started in `~/code` is
not checked: keep its rules yourself there.

`Brickson.xcodeproj` is generated from `project.yml` and is not committed.
Regenerate after adding, removing or renaming any file. Never edit the
generated project, and never open it in Xcode from an agent.

**Build with Apple's current Xcode, never a pinned one** (owner,
2026-10-21; docs/DECISIONS.md, "Build with Apple's current Xcode"). The
toolchain is Apple's newest Xcode release (not a beta) with its SDKs and
Swift compiler, on the owner's Mac and on CI. Never write an Xcode, SDK,
simulator or runner version into the project, a script, a workflow or a
document unless the owner asks for it: documents say "the current Xcode
release". Look up what is current on Apple's releases page
(https://developer.apple.com/news/releases/) and Xcode's system
requirements (https://developer.apple.com/xcode/system-requirements/),
never from memory. CI picks the newest released Xcode on GitHub's machine
(`scripts/select-xcode.py`) and warns on the run when Apple has a newer
one. The deployment target, the oldest iOS the app runs on, is a separate
product decision, set by two rules: every device that can use eye
tracking runs the app, and every accessibility API in the ALS-stage map
stays reachable, behind `#available` when newer (docs/DECISIONS.md,
"Minimum iOS, iPhone and iPad").

**Reviews and updates on GitHub.** The owner keeps several AI
reviewers on purpose (2026-11-07): each sees things the others miss,
and one stands in when another is out of credits. Codex reviews every
push to a pull request that a person or agent opens, and runs a
security review by itself when one opens (as on pull request #90); the
owner set it up in the Codex app, and no agent writes an `@codex`
comment of any kind, as some have Codex push code (owner, 2026-11-08).
Where Codex posts a notice to set up an environment instead of its
reviews (as on #89 and #92), the agent says so in the pull request and
the thread, and a pull request that changes privacy or a workflow
waits for the owner to run Codex's security review from the Codex app,
or another security review, before it merges. So does a pull request
whose privacy or workflow change came in a push after it opened, which
Codex's security review on opening did not see: its ready message says
so. Greptile, which
the owner also installed, reviews a pull request by itself when it
opens, as far as its free plan's credits allow (out of them when
checked on 2026-11-06). cubic, added by the owner on 2026-11-07,
reviews by itself when a pull request opens and after each push, once
the owner has installed its GitHub app; when it has not reviewed, ask
with a comment reading `@cubic-dev-ai review this PR`. CodeRabbit,
also installed, gives a repository with fewer than 10 stars no
automatic reviews, so the agent that opens a pull request asks for its
review with a comment reading `@coderabbitai review`, after the push it
wants reviewed (`@coderabbitai rate limit` says whether one is left
this hour, without using one). The agent that opened the pull request
answers and fixes every round. **Reviewers review; they never write
the code.** `.coderabbit.yaml`, `cubic.yaml` and `.greptile/` turn
off every feature that commits or opens a pull request and has a
setting, and no agent asks a reviewer for code: no `@coderabbitai
autofix` or other command that commits, no finishing touch or
"Autofix" box in CodeRabbit's comment, no "Fix with cubic", no fix
request to `@cubic-dev-ai`. Code written that way skips the failing test
first, the `docs/log/` record and the rest of *Workflow rules*. Ask
Greptile with a plain `@greptileai`, never for a tier ("at apex"),
which costs more of its credits. GitHub Copilot reviews again since
2026-11-08 (the owner kept its plan): the agent that opens a pull
request that changes code asks for Copilot's review **once**, right
after opening it. Before opening, it runs Codex's local review
(`codex review --base origin/main`, read-only, where the Codex CLI is
installed, as on the owner's Mac) and answers its findings, so Copilot
sees the fixed code; Codex's review on GitHub, which the owner runs
from the Codex app, is not part of this step. A pull request that
changes only documents gets none. Each review spends some
of the owner's monthly AI credits (about 31 to 46 of 1,500); a request
that fails for lack of them is said in the pull request and the thread,
with no retry. Ask only through the GitHub tool `request_copilot_review`:
never `gh`, the API, a reviewer field or an `@copilot` mention, and
never a Copilot task. The guard lets that one tool through, refuses a
second request on the same pull request from any worktree of the clone,
and refuses the other Copilot tools, `gh`'s reviewer, assignee and
agent-task commands, `gh copilot`, the REST reviewer, assignee and task
endpoints, a GitHub tool's reviewer or assignee field and a GraphQL
agent assignment; "changes code", the local review first, other GraphQL
requests and a mention are held by this rule alone (*Guardrails for
agents*; docs/DECISIONS.md, *Code review*). None of these reviewers
reviews Dependabot's pull requests by itself. All of them review
against *Code Review Rules* in AGENTS.md. GitHub's AI Scan is off since
2026-11-08 (it spent most of the month's AI credits and found nothing);
Copilot Autofix, which suggests fixes for CodeQL alerts at no cost,
stays on, and its suggestions are read like a review comment, never
committed as they are. CodeQL did not analyse Dependabot's first pull
request before it merged, so treat a Dependabot pull request as not
security-reviewed until the owner reads it (docs/DECISIONS.md, *Code
scanning*). Dependabot opens one pull
request a month for new versions of the actions in
`.github/workflows`, and one at once for a security fix.
The intended repository settings, and why, are in docs/DECISIONS.md,
"Reviews, updates and GitHub settings".

`scripts/test.sh` runs `xcodegen generate` first and prints the Xcode
and XcodeGen versions. It chooses simulators by device type, never by
name: the newest iPad Pro 13-inch (any iPad if there is none) and, for UI
tests, the newest standard iPhone too, each with an iOS between the
deployment target and the SDK of the Xcode in use. It starts each one,
waits for it, builds for testing, then runs the tests. Before UI tests it
shows the full software keyboard and launches the app once, so the first
test does not meet a cold simulator. A simulator the script boots is shut
down after its run, including failures, before the next family starts;
a simulator already running is left running. `SIMULATOR_FAMILY=iphone` runs one
family; `DESTINATION='platform=iOS Simulator,name=iPhone 17' scripts/test.sh`
names one simulator, which is started and waited for too. Anything after
the mode goes to `xcodebuild`
(`scripts/test.sh unit '-only-testing:BricksonTests/PaletteTests/theContrastFormulaMatchesWCAG()'`).
Each run keeps its result bundle, with screenshots of UI-test failures and
the captures UI tests attach, in `build/TestResults/<mode>-<family>.xcresult`,
and prints how many tests ran; a run in which no test ran, or whose count
cannot be read, fails. A unit run also prints the app's code coverage and
brings `Brickson/Resources/Localizable.xcstrings` up to date with the code
(`xcstringstool sync` over the strings the build found); commit the
updated catalog with your change. On CI a catalog that does not match the
code fails the run and prints the difference. Beside each bundle,
`build/TestResults/simulator-load-<family>.txt` records which of the
simulator's processes used the Mac's processors, every five seconds; on
a simulator the script started, `scripts/simulator-load.py` also pauses
its lock-screen wallpaper extensions for the run (*Gotchas*). The iPad
and the iPhone are both first-class: UI tests run on both every time.

**GitHub CI** (`.github/workflows/tests.yml`) runs the unit and UI tests on
GitHub's Mac machines for every pull request and every push to `main`.
Since 2026-11-03 the UI tests run as one job per family, "UI tests on
iPad" and "UI tests on iPhone", at the same time, and the job named "UI
tests" passes only when both passed (docs/DECISIONS.md, "Tests"). Each job keeps `build/TestResults` (the
result bundles and load records above) as a download on the run's page
for 14 days, passed or failed: the artifacts `unit-test-results`,
`ui-test-results-ipad` and `ui-test-results-iphone` (one
`ui-test-results` before the split). A job that stops before its
tests start (choosing Xcode, XcodeGen, a build failure) writes no
bundle, so that job has no artifact, only a warning. A
pull request merges only when CI is green.

## Guardrails for agents

Agents push and open pull requests as the owner's GitHub account, so
GitHub itself cannot tell an agent's merge from the owner's. The rules in AGENTS.md and in this document are backed by checks wherever a check can run:

- **The guard.** `.claude/settings.json` runs `.claude/hooks/guard.py`
  before every Bash command, before the GitHub tools that can merge or
  write, and before the file tools (Read, Edit, Write, Grep, Glob and the
  like). It refuses, with the rule it breaks: `git add -A`, `--all`, `-u`
  or `.` and `git commit -a`; force pushes and any push that updates
  `main`; merging, auto-merging or approving a pull request (`gh`, the
  GitHub API or a GitHub tool); a Copilot review or Copilot task asked
  for by a Copilot tool, `gh`, the REST API, a GitHub tool's reviewer
  or assignee field or a GraphQL agent assignment, except one review
  per pull request through `request_copilot_review`, which the guard
  records after it runs (*Reviews and updates on GitHub* says what only
  the rule holds); a GitHub tool writing
  a file onto `main`; a commit, or text sent to GitHub by `gh`, the API
  or a GitHub tool, that holds a personal detail, text it cannot read
  before the command runs (built by the shell, a file the same command
  writes, an index change or commit identity it sets, a commit it reuses
  that an earlier command in the same call may move, or another
  repository or index a commit names with `--git-dir`, `--work-tree` or
  a `GIT_*` variable); a release asset upload; the ways gh can push past
  these rules (`gh repo create --push`, or with no words, and any gh
  command given a terminal, which can ask for text or where to push) or
  run what it cannot read (an option before a command's name, an
  extension, an alias set in the same call), a gh recovery file, text
  gh takes from an editor or fills in from commits (`gh pr create
  --fill`) and a shell alias the command defines; a push
  from a checkout whose pushes skip the privacy hook or whose branch has
  none, whichever branch the push names, or after a command in the same
  call that changes the hook, its setting or the check it runs, or checks
  out another branch (*The privacy check*); and
  any command or file tool that names the private list or the config
  folder that holds it, by path or glob, wherever the check reads the
  list from (not a recursive read of a folder above it, such as
  `grep -r . ~`: docs/DECISIONS.md, "Personal details stay out of the
  repository"), and any command that prints the whole environment. The same
  settings deny the merge tools and the Copilot task tools outright, and the
  Read and Edit tools the list's default folder. When the guard refuses, do not look for
  another way round: say in the thread what you needed and why. It is
  a guard against mistakes, not a sandbox, and it covers
  Claude Code only. On the owner's Mac, git-ignored hooks hold Codex and
  Antigravity to what it refuses
  (`docs/log/2026-11-08-codex-antigravity-setup.md`); elsewhere, Codex
  and the owner are held to the same rules by review. The one exception
  on the Mac is input sent to a command already running: Codex's
  `write_stdin` does not run `PreToolUse` again, while Antigravity's
  `send_command_input` is checked. Codex's hook lives in
  `~/.codex/hooks.json` and acts only inside a Brickson checkout. Every policy hook
  uses `onFailure: "block"`, so a startup error, crash, invalid output or
  timeout blocks the original action in Claude Code 2.1.295 or later.
  Older or unknown runtimes do not establish that protection; confirm the
  runtime and hook reload before relying on it.
- **Where the guard runs.** Claude Code reads a repository's hooks and
  permission rules in a session with one repository. A cloud session that
  clones several repositories reads only plugin settings from them, so
  there the guard does not run and these rules are yours alone to keep.
  On 2026-11-03 it did not run in a Brickson cloud thread either, though
  that thread had cloned only this repository (Claude Code 2.1.317): a
  `git add -A --dry-run`, which the guard refuses, ran. The
  environment's documentation says a cloud thread applies a
  repository's settings only in a project with one repository. So in a
  cloud thread, check before relying on it: where the guard runs,
  `git add -A --dry-run` is refused. On the owner's Mac, a session in
  one of the desktop app's worktrees runs the guard and settings of the
  checkout it was started from, `~/code/brickson`, not the worktree's
  copy (2026-11-08: a worktree with #90's guard was refused Copilot by
  the older one there). So a change to the guard binds Mac sessions
  only once that checkout has it, and an agent never updates that
  checkout itself: the owner pulls `main` there.
- **The privacy check.** `scripts/privacy-check.py` looks for personal
  details (a private list the owner keeps outside the repository, email
  addresses, phone numbers, home folders, where a photo was taken) in
  files, file names, pictures' hidden text, commits and pull requests.
  It runs in git's pre-push hook (`.githooks/pre-push`, on once per
  checkout with `git config core.hooksPath .githooks`), in the guard,
  by hand (`--outgoing`, `--text -`), and in CI's "Privacy check" job,
  the only one given the list, which by then can only warn. Without the list it refuses to pass
  (`--no-list` checks the patterns alone, and is never described as a
  pass). It prints places and kinds, never the words, and neither does
  anyone after it. In a cloud thread, run `--status`: where it reads a
  list but says pushes do not run the hook, turn it on in your own
  clone. How it works, what it cannot catch and what to do when it
  finds something: docs/DECISIONS.md, "Personal details stay out of the
  repository".
- **Its tests.** `scripts/test-hooks.py` feeds the guard the calls it must
  refuse and the ones it must let through, and `scripts/test-privacy.py`
  feeds the privacy check what it must find and what it must let pass;
  `scripts/test.sh` runs both before the unit tests, so CI runs them.
  A new rule gets a test first.
- **Cross-references.** `scripts/test-docs.py`, run the same way, fails
  when a section cited by title (a file name, then the title in quotes or
  italics) or a relative link no longer resolves. A title after a comma
  must be part of a title before it, or a section beside one
  (docs/DECISIONS.md, "iPhone Duo", *The fold*), and words in quote marks
  after a file name and a comma are a title unless the script's
  `QUOTATIONS` lists them as a quotation of that file. In AGENTS.md, the
  review skill and `.github/copilot-instructions.md`, an italic title on
  its own must name a real section. Rename a section and update what cites it in the same commit.
  It also fails when the sections Codex must read stop opening
  AGENTS.md, in their order, when its introduction stops naming
  `project_doc_max_bytes`, or when they end past the 32 KiB Codex reads
  by default (`CODEX_MUST_READ`; docs/DECISIONS.md, "AGENTS.md puts
  first what Codex reads").
- **The verifier.** `.claude/agents/verifier.md` is a report-only
  subagent: it runs the Python checks, reads the branch's CI run and says
  what was and was not verified. Run it before calling a pull request
  ready, and paste its *Not verified* list into the pull request.
- **Issues.** `.github/ISSUE_TEMPLATE/something-went-wrong.yml` is the
  bug form, with a warning that issues are public. Blank issues are off.

## Where things are

- **`docs/HANDOFF.md`**: start here. Current state, what is verified and
  how, what to do next. Each pull request's record is its own file in
  `docs/log/`; the history before 2026-10-21 is `docs/HANDOFF-LOG.md`.
- **`docs/ROADMAP.md`**: the releases, in the order a person meets the
  disease, and which thread or person owns each item; and
  *The quality bar*, the gates every release passes before App Review,
  the owner's "would I recommend this to someone?" last.
- **`docs/SDLC.md`**: how this project runs as a software factory, stage
  by stage (plan, design, build, test, deploy, maintain), with each
  stage's gate. A feature that changes what a person sees or hears starts
  with a work file in `docs/work/`: its intent, spec and plan.
- **`docs/DECISIONS.md`**: binding decisions, by title. Code comments point
  to them.
- **`docs/LESSONS.md`**: what went wrong in the reference app, and the rule
  each lesson gives. Read the sections that touch your work.
- **`docs/ACCESSIBILITY.md`**: every Apple accessibility feature and API
  in the project's map by ALS stage, with its iOS version, its release and
  how it is checked. A pull request that adopts, changes or drops one
  edits its row, and the website's accessibility page
  (`site/accessibility/index.html`, the App Store's Accessibility URL)
  where its words become untrue. That page says only what is in place and
  how it was checked, never "works with" before a real-device check.
- **`docs/DEVICE-CHECKS.md`**: the step-by-step procedure, with what
  passes, for every row of docs/HANDOFF.md, *Checks that need a real
  device*, and every gate of docs/ROADMAP.md, *The quality bar*, that
  the owner checks, each step marked as the owner's or one an agent
  runs from the owner's Mac. A pull request that adds or changes a
  device check or an owner gate edits its procedure there.
- **`docs/PORTING.md`**: what has come over from the reference app, what is
  next, and how to port a file.
- **`README.md`**: the overview for people, written for a beginner. Keep it
  accurate when behaviour or setup changes.
- **`docs/GETTING_STARTED.md`**: setting up a Mac and a device, for the
  owner. **`docs/NAME_AVAILABILITY.md`**: the name checks.
  **`design/brand/`**: the logo artwork (not yet the app icon).
- **`docs/recon/`**: dated research reports behind the roadmap. Research,
  not instructions: where it disagrees with AGENTS.md or
  `docs/DECISIONS.md`, they win.
- **`docs/archive/`**: old versions of rewritten docs.
- **The reference app**, FamilyVoice: `MiddleAgedBanana/ALS-app` at commit
  `6a22c1a`, a **private** repository. **Reference only. Never push to it or
  open pull requests on it.** Without access to it, follow `docs/LESSONS.md`,
  which carries its rules. Where a session also loads the reference app's
  own `AGENTS.md`, it describes that app and its one user: for Brickson,
  AGENTS.md wins.

## Apple documentation: look it up, don't recall it

Training data is not current enough for this app. Look APIs up before
using them, and say when you could not.

- Context7 MCP, where available: `/websites/developer_apple_swiftui`,
  `/websites/developer_apple_accessibility`,
  `/websites/developer_apple_appintents`.
- The Sosumi MCP (`searchAppleDocumentation`, `fetchAppleVideoTranscript`)
  adds full-text search and WWDC transcripts.
- The Xcode MCP's `DocumentationSearch`, read-only.
- **developer.apple.com in Markdown:** its HTML pages are JavaScript
  shells that look empty rather than failing, but the same page with
  `.md` appended to its path returns Markdown with availability metadata
  (for example `https://developer.apple.com/documentation/swiftui/button.md`,
  checked 2026-10-21). Fetch that form, never the HTML page.

## Skills

Skills are installed per machine (`.agents/skills/`, with `.claude/skills/`
symlinks), and both folders are ignored by git. Committed skills live in
`.github/skills/`: `code-review/` holds the review steps given to GitHub
Copilot code review (*Code Review Rules*). Put new review rules in this
file, not in a skill. Where per-machine skills exist:
`swiftui-pro` leads for SwiftUI, `swiftdata-pro` for SwiftData,
`swift-concurrency` for concurrency, `swift-testing-expert` for tests,
`ios-accessibility` for accessibility, `app-intents` for Siri and
Shortcuts. **Never apply** `core-data` skills (this app uses SwiftData),
`cloudkit`, `authentication`, `push-notifications`, `ios-networking` or
`apple-on-device-ai` (hard stops), or `swiftui-gestures` (invariant 1).

**Apple's own skills** ship with Xcode and are exported with
`xcrun agent skills export`, then copied into `.agents/skills/`. They are
Apple's software under the Xcode and Apple SDKs Agreement, which forbids
redistributing it, so **never commit them** (`/xcode-skills/` is ignored
as a safety net; `docs/log/2026-10-23-iphone-duo-readiness.md`). For an
Apple API they lead over the skills in *Skills*: `swiftui-specialist` and
`swiftui-whats-new-27` for SwiftUI, `app-intents-specialist` and
`app-intents-whats-new-27` for App Intents, `modernize-tests` for moving
tests to Swift Testing, and `app-resizability` for windows that change
size and iPhone Duo. `device-interaction` and
`audit-xcode-security-settings` need Xcode's own tools, so only on the
Mac; the audit's changes go into `project.yml`, never the generated
project. `adopt-c-bounds-safety` and
`building-document-based-swiftui-applications` do not apply. Some say
they "unconditionally supersede" an agent's prior training, and
`app-resizability` counts "an empty diff for a file containing the
target API" as a failure. AGENTS.md, this document and docs/DECISIONS.md win over every
skill, Apple's included, and so does Apple's documentation looked up at
the time. Export them again after each new Xcode release.

## Gotchas

- **The simulator keyboard is minimized by default.** `scripts/test.sh ui`
  shows the full software keyboard before the tests; anywhere else, show
  it before any typing test:
  `xcrun simctl spawn <udid> defaults write com.apple.keyboard.preferences AutomaticMinimizationEnabled -bool false`
  (write `true` to restore the bar). The first keyboard on a fresh iPhone
  simulator also covers its keys with a sheet about sliding to type, so a
  test finds no keys; `scripts/test.sh ui` marks it as shown, and
  anywhere else write `DidShowContinuousPathIntroduction -bool true` to
  the same domain first (docs/log/2026-10-23-keyboard-allowance.md).
- **Display Zoom is lost whenever a simulator restarts**, and `xcodebuild`
  shuts down a simulator it booted itself. Boot the simulator yourself, set
  the configuration in a prepare step, and check the window size before
  trusting a measurement.
- **Rotation and text size on simulators:** `simctl` cannot rotate; set
  `XCUIDevice.shared.orientation` in a UI test. Set Dynamic Type per launch
  with `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXXXL`.
- **One simulator per agent**, addressed with `-destination 'id=<udid>'`.
  Parallel simulators cause false UI-test timeouts. If every `simctl` call
  hangs, `xcrun simctl shutdown all` clears it, but stops every agent's
  simulators.
- **Swift Testing and `-only-testing:`**: include the function's
  parentheses (`-only-testing:BricksonTests/PaletteTests/theContrastFormulaMatchesWCAG()`);
  without them `xcodebuild` runs 0 tests and reports success
  (`scripts/test.sh` fails such a run: "No tests ran"). In zsh, pass
  several flags as an array, not one string.
- **A failing `xcodebuild test` can sit for minutes collecting
  diagnostics**; `scripts/test.sh` passes `-collect-test-diagnostics never`.
- **The unit job's time is mostly the dwell chain sweeps.** Its limit
  is 60 minutes (docs/DECISIONS.md, "Tests"). On 2026-10-30, under the
  old limit of 40, it took 36 to 39 minutes, about 16 of them starting
  the simulator and building, and one run each of pull requests #69 and
  #70 was stopped at 40 with every test it had reported passing. The
  same day the chain engine was made about half as costly, with the
  same results, and the job's next two runs took 24.4 and 28.2 minutes
  (docs/DECISIONS.md, "One chain engine for dwell safety").
  The unit tests are main-actor isolated by default, so they share the
  main thread and the job takes about the sum of every test's time; run
  together, a suite's reported time includes waiting for the others.
  Each test's own time is in its result bundle: the `.xcresult`'s
  `database.sqlite3`, table `TestCaseRuns`, column `duration`; the query
  is in the record below. Time a long new sweep on its own and say in
  the pull request what it adds. The engine runs millions of times in a
  build that is not optimised, so keep its inner loops plain, and pin
  any shortcut with a test that compares it with the plain way
  (`ChainEngineTests`). A run stopped at the limit with no failure
  is re-run once only if the steps it did not change (the Python
  checks, starting the simulator and building) took clearly longer than
  on `main`'s last run; a second stop, or a stop on a machine as fast as
  usual, is real, so cut what the tests cost without weakening any. The limit is in `.github/workflows/tests.yml`,
  which a cloud agent cannot push. The measurements are in
  [`docs/log/2026-10-30-sizes-switched-on.md`](log/2026-10-30-sizes-switched-on.md)
  and [`docs/log/2026-10-30-unit-test-time.md`](log/2026-10-30-unit-test-time.md).
- **A just-started simulator is slow, and the first UI test pays for it.**
  Its voice service took more than 60 s to answer its first request on
  CI. Until 2026-11-01 the app waited for it on its main thread before
  its first frame, so XCTest's automation session gave up and the first
  test failed with "kAXErrorServerNotFound" while re-runs passed
  (docs/log/2026-11-01-voice-list-off-launch.md). Never put a call to a
  system service that can be slow on the main thread at launch
  (docs/DECISIONS.md, "The voice list never holds up launch"). One run
  also found Again still off when the test read it straight after a tap,
  on code that was green on `main`. `scripts/test.sh`
  starts each simulator, one a `DESTINATION` names included, and waits for
  it to finish starting (`xcrun simctl bootstatus <udid> -b`); it shuts down
  devices it booted after their run. Before UI tests it also launches the app once (a warm-up,
  on test-only storage). A `DESTINATION` that is not one simulator is left
  to xcodebuild, which doesn't wait. In UI
  tests, wait for a change after `tap()`: `waitForExistence(timeout:)` for
  something appearing, an `XCTWaiter` expectation for a property such as
  `isEnabled`. Check that something did *not* change only after waiting
  for the change that did happen.
- **UI tests launch through `launchedApp`** (BricksonUITests/LaunchHelpers.swift):
  fresh test-only storage, short idle limits, English, and the text size,
  appearance and orientation a test asks for. A bare
  `XCUIApplication().launch()` runs on whatever the simulator kept from
  earlier runs. The app reads these launch arguments (`LaunchOptions`)
  only in debug builds; a release build ignores them. `assertReachable`,
  `attachCapture` and `assertPassesAccessibilityAudit` sit beside it.
- **An automation tool's tap, snapshot or keyboard report is not
  evidence.** On 2026-10-25 a
  RocketSim tap reported success without changing the app, where Device
  Hub's own input did change it; RocketSim's compact snapshot reported
  `keyboard=hidden` in captures that showed the keys; and a MobileBuildMCP
  tap returned success with no change on screen
  ([`docs/log/2026-10-25-mac-keyboard-checks.md`](log/2026-10-25-mac-keyboard-checks.md);
  [the speech diagnostic](evidence/2026-10-25-duo-design/speech-diagnostic/README.md)).
  Taps, snapshots and keyboard states that RocketSim, MobileBuildMCP,
  AXe or any other automation tool reports are for looking around, never
  evidence: an activation, reachability or keyboard claim counts only
  from a UI test through `launchedApp`, from Device Hub's own input on a
  simulator or from a person's own input on a real device, and a capture
  counts only for what it visibly shows.
- **Verify rendered appearance, not the setter's readback.** Command-line
  simulator runs on Xcode 27.1 reported `XCUIDevice.appearance == .dark`
  while the app stayed light. `launchedApp` uses debug-only
  `--appearance=light|dark`, applied by `preferredColorScheme`; ordinary
  and release launches follow the system. Keep the independent screenshot
  gate. Its sample is the empty gutter between Yes and No, not a median
  dominated by constant-colour tiles. Evidence and reproductions:
  `docs/log/2026-10-21-ui-test-diagnosis.md`.
- **Accessibility frames do not prove visible words fit.** On PR #13,
  both complete UI suites passed while AX5 phone screenshots showed
  clipped Yes, No, Emergency and Again labels. Keep the rendered-label
  regression alongside reachability and audits: it recognizes each
  button screenshot without language correction or supplied expected
  words. Inspect its kept captures when it fails; a complete accessibility
  label is not evidence that the text was drawn completely.
  Vision's accurate mode also misread a clear `No` as `ON`; the fast mode
  read it and rejected the old clipped captures. Keep whole-word matching
  (case-insensitive), with no language correction or recognition hints.
  The fast mode also read nothing in a whole `No` small on a tall
  button, and `Attention,` for a whole `Attention` (PR #74), so a tall
  capture is also read in a band around its drawn words, and
  punctuation read around a word is dropped; neither can add a letter
  that was not drawn. A row drawn all the way across a capture is a
  button's border, not words: Home draws one round every control in
  dark mode, and counted as words it made the band the whole capture,
  which read a whole `No` as `I`. The recognizer lives in
  `RenderedWords` (Vision's `RecognizeTextRequest`). The unit tests run
  it on kept whole, clipped and tall captures, with a border and
  without (`RenderedWordsTests`, `BricksonTests/RenderedLabels`), and
  pin its settings, so a change that stops it reading whole words,
  accepts part of one, or turns on correction or hints fails there
  first.
- **Measuring the keyboard:** `KeyboardProbeTests` runs on every UI run.
  For each orientation and text size it opens a debug-only probe screen
  (`--screen=keyboard-probe`) instead of Home, prints one
  `KEYBOARD-PROBE {json}` line, and fails if the keyboard reaches above
  the room `KeyboardAllowance` keeps for the window (add the measurement
  to `KeyboardAllowanceTests` and raise that shape's reference). It then
  opens Home in the same window, prints `KEYBOARD-BAND {json}` and fails
  if Yes, No, Emergency, Again or Get Attention ends below the
  allowance's limit. It also fails, after printing, if the simulator
  shows the keyboard bar instead of the full keyboard. xcbeautify hides
  printed lines from passing tests, so read the JSON attached to each
  test in the result (Xcode's Report navigator, or the `.xcresult`
  database on Linux), or run `xcodebuild` without xcbeautify. Say which
  simulator and iOS version the numbers came from.
- **Measuring a slow press and a slide:** `HeldSlideProbeTests` is
  opt-in (`TEST_RUNNER_BRICKSON_SLIDE_PROBE=1 scripts/test.sh ui
  '-only-testing:BricksonUITests/HeldSlideProbeTests'`) and reports in its
  attachments, like the keyboard probe. The large content viewer follows
  the app's own text size, so `launchedApp(textSize: .ax5)` turns it on
  whatever the simulator is set to. The test build that gives Home's
  controls the viewer is in
  `docs/log/2026-10-23-large-content-and-iphone-duo.md`; never ship it.
- **The iPhone Duo simulator starts folded**, on its outer display. No
  command-line way to open or fold it was found (2026-10-23): `xcrun
  simctl` has no pose command, `XCUIDevice` has none, and turning a
  display off does not unfold it. On 2026-10-25 the authorized Mac run
  used Device Hub's Closed, Partially Open, Open and rotation controls;
  RocketSim's `duo hinge` confirmed 0°, 130° and 180°. Later that day,
  the installed CLI also provided `rocketsim duo pose closed|book|open`;
  the selected native pose probes confirmed its book pose at about 90°.
  This supersedes the earlier lack of CLI pose control, not the native
  rotation/window-coordinate limits. On the inner display,
  the tested XCTest orientation request did not make the same turn, its screenshots
  captured the inactive outer display as black, and separate window/frame
  queries disagreed with the window and controls in one accessibility
  snapshot. Diagnostic measurements use one snapshot's coordinate space
  and RocketSim captures of the active display. Preserve the existing
  test failures: phone-idiom landscape skips do not cover the inner
  display. The record is
  [`docs/log/2026-10-25-mac-keyboard-checks.md`](log/2026-10-25-mac-keyboard-checks.md).
  XCTest's touches reach the inner display where they are aimed in one
  orientation only: opened flat, it starts in a wide 951×669 window, and
  after three quarter turns to the right (Device Hub, or the Claude
  desktop app's simulator control) it is the tall 669×951 window in
  which `PhraseDragTests`' coordinate check passes; in the other two,
  that check fails before input, as it should. Even in that window, a
  point offset from the app element's own origin reported the aimed
  screen point but never reached Home; offset from the element touched
  instead (2026-11-11,
  [`docs/log/2026-11-12-duo-drag-speech.md`](log/2026-11-12-duo-drag-speech.md)).
  `DESTINATION='platform=iOS Simulator,id=<udid>' scripts/test.sh ui`
  runs the UI tests on whichever display is showing. Xcode 27.2's
  [release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27_2-release-notes)
  (read 2026-11-03) list three Device Hub known issues on iPhone Duo:
  its screenshots and recordings may be black for up to a few minutes
  after it boots (187146039); VoiceOver, the Accessibility Inspector and
  other accessibility tools cannot convey its screen within Device Hub
  (187148389); and after switching between its inner and outer display,
  modifier keys such as Shift and Command may stop working until you
  click the visible screen (189465196). So wait a few minutes after a
  boot before trusting a black capture, and never count an
  accessibility reading of an iPhone Duo taken inside Device Hub as
  evidence. The black XCTest captures of 2026-10-25, of the inactive
  outer display on Xcode 27.1, are not among these. Whether XCTest's own
  queries on an iPhone Duo are affected is not known.
- **iPhone Duo has an iOS runtime of its own.** From Xcode 27.2, a Mac
  lists two runtimes with the same iOS version: one holds only iPhone
  Duo, and its identifier names the device after the version
  (`com.apple.CoreSimulator.SimRuntime.iOS-27-2-iPhone19-4`); the other,
  with the plain identifier, holds every other iPhone and iPad. Keep
  both. `scripts/choose-simulator.py` reads both kinds of identifier
  (before 2026-10-30 it ignored the Duo's, so a Duo `DESTINATION` was
  refused); `xcrun simctl list runtimes` shows which build is which
  ([`docs/log/2026-10-30-xcode-27-2.md`](log/2026-10-30-xcode-27-2.md)).
- **Simulator audio is unreliable.** Every sound check needs a real device.
- **The desktop app stops a Remote Control session after about 60 idle
  minutes**, and a background task of the session stops with it; a
  running job does not count as activity. On 2026-11-05 that ended a
  UI run with no connection lost (`~/Library/Logs/Claude/remote-control.log`:
  `idle sweep`, `stopping session (idle)`), and the session came back
  only when a message arrived. Run anything longer detached (`nohup`,
  writing a file when done), and keep a background check that ends
  within 45 minutes, so the session wakes and sets the next one.
- **Apple's accessibility audit can time out on CI** with domain
  `com.apple.xcode.xctest.accessibilityAudit`, code `-56`. The UI suite
  retries the full audit once for that error only; a second timeout still
  fails. Findings already reported with `XCTFail` remain failures. Never
  retry or discard an accessibility finding to make CI green.
- **Audit only a still screen.** Apple's audit reads a screenshot and the
  accessibility tree a moment apart, so text that leaves the screen in
  between is reported as "Potentially inaccessible text" on no element.
  Home's "Speaking" line did that on CI, leaving as the simulator's voice
  finished just after an audit began (issue #30). The audit helper first
  waits for speech to finish (`waitForSpeechToFinish`); anything else
  that changes the screen by itself (Settings' idle reset under
  `--short-timeouts`, an alarm that ends) must be over, or unable to
  happen, before an audit. A wait is not a retry: the finding came from
  auditing a moving screen, not from the app.
- **`ViewThatFits` failed Apple's audit around text, here.** This is
  the app's own finding on CI, on the Xcode of the time, not a rule
  Apple documents: Apple's audit checks text for clipping and for
  following Dynamic Type as it grows the text
  ([Performing accessibility audits](https://developer.apple.com/documentation/accessibility/performing-accessibility-audits-for-your-app)),
  and `ViewThatFits` swaps one view for another as the text grows. On
  2026-10-21 Settings labels that used one to drop their icon where the
  words did not fit failed the audit's Dynamic Type check ("partially
  unsupported") on both devices and were reported as clipped on the
  iPhone, on rows that had passed as plain labels
  ([`docs/log/2026-10-21-settings-and-first-run.md`](log/2026-10-21-settings-and-first-run.md));
  on Home, a label whose size one picked was reported as clipped
  (docs/DECISIONS.md, *Home's stand-in layout*, where drawing a label at
  a smaller text size was a separate way reported as not following
  Dynamic Type); and on PR #33 Settings' root, built with one, was
  reported as clipped text belonging to no element on the phone
  (docs/DECISIONS.md, *Settings on Home*). Choose arrangements in a
  plain type and place each view once (`WordFit`, `SettingsLeadIn`).
- **CI results can be read without a Mac.** A failed UI test's result
  keeps a screen recording of the whole test, and each `.xcresult` has a
  `database.sqlite3` listing every activity and attachment with its time
  and its file in `Data/` (`data.<id>`). Images and recordings are stored
  as they are; text and JSON are zstd-compressed. `sqlite3` (or Python),
  `zstd` and `ffmpeg` read them on Linux; how it was done for issue #30 is
  in `docs/log/2026-10-22-audit-still-screen.md`. The app's own output,
  per launch, and the test runner's log are in the bundle's diagnostics
  folder (`Actions.diagnosticsRef`): read them before blaming the machine
  for a UI failure. How to unpack it is in
  `docs/log/2026-11-01-voice-list-off-launch.md`.
- **A crash cannot be a known issue.** `withKnownIssue` does not survive a
  crash; commit the reproduction disabled, naming its issue.
- **Lazy Forms unload rows far off screen**, so a missing element in a UI
  test can mean "scrolled", not "gone".
- **Inspecting the store:** `sqlite3 <app container>/Library/Application Support/default.store`,
  after relaunching the app to flush its write-ahead log.
- **Simulator novelty voices** (Bells, Boing and others) are deliberately
  excluded from automatic voice choice. Don't "fix" it.
- **On the owner's Mac**, the interactive shell aliases `rm`, `cp`,
  `grep` and `python3` (`cp` asks before overwriting and can hang a
  script). Scripts are not affected; in a typed command, use
  `command cp` and so on.
- **Job names in `tests.yml` are required check names.** The `main`
  ruleset requires "Unit tests" and "UI tests" by name (docs/DECISIONS.md,
  "Reviews, updates and GitHub settings"). Renaming a job, or adding a path
  filter to the workflow, leaves every pull request waiting for a check
  that never arrives until the owner updates the ruleset. Since the
  split of 2026-11-03, "UI tests" is the small job that waits for both
  families; it keeps `if: always()`, because GitHub reads a skipped
  required check as passed, so without it a failed family would let a
  pull request merge. The families are two jobs, not a matrix, so it
  reads each one's own result (docs/DECISIONS.md, "Tests").
  `scripts/test-runner.py` checks all of this.
- **iOS's lock-screen wallpaper prewarm starves a CI simulator.** About
  five minutes after a simulator starts, iOS runs SpringBoard's
  `posterboardupdate.prewarm` task, and some 14 wallpaper extensions
  render the gallery's pictures for about three minutes. On GitHub's
  three-processor machines that stalled iPad UI tests, four runs in a
  row, until XCTest's queries and the tests' waits timed out
  (docs/log/2026-11-03-ui-test-stall.md). `scripts/test.sh` pauses
  those extensions on a simulator it started; it never touches one it
  did not start, so on a Mac a simulator left running is unprotected.
  When a UI test is slow or times out on CI, read
  `simulator-load-<family>.txt` in the artifact before changing a wait:
  it shows whether the extensions were paused and which process was
  busy. A longer wait would only hide a starved app.
- **Cloud agents cannot change `.github/workflows/`.** On 2026-10-21 a
  cloud session's `git push` of `tests.yml` was refused ("refusing to
  allow an OAuth App to create or update workflow ... without `workflow`
  scope"), and so was the GitHub MCP's file update ("Insufficient scope").
  Push the rest, and give the owner the workflow file's full new text to
  commit with their own account (GitHub's web editor on the branch, or an
  agent on their Mac). A change to a `uses:` line goes through the Mac
  (next).
- **A workflow's actions and the lockfile change together.**
  `.github/workflows/actions.lock` records the commit of every action
  each workflow runs, and a run refuses an action it does not record
  (docs/DECISIONS.md, "Reviews, updates and GitHub settings",
  *Dependencies*). A pull request that adds a workflow or changes a
  `uses:` line runs `gh actions-lock` on the owner's Mac, from the root
  of its worktree (it also narrows a short tag such as `@v7` to the full
  version), reads the whole diff, runs `gh actions-lock --verify`, and
  commits the lockfile with the workflow. A cloud agent can push neither
  file, so such a change goes through the Mac. Dependabot's pull requests
  update both by themselves. Never edit the lockfile by hand, and never
  delete it to clear an error: a fresh run accepts a tag that moved.
  `--relock` and `--accept-moved` both take a moved tag's new commit, so
  each is the owner's decision, after reading what moved upstream, and
  neither runs in automation. `gh actions-lock` is an extension of `gh`;
  keep the Mac's at the release `verify-lockfile.yml` pins
  (`gh extension install github/gh-actions-lock --pin <release>`, after
  `gh extension remove actions-lock` if an older one is there), and move
  that pin when the extension has a newer release: nothing else raises
  one. `python3 scripts/test-runner.py` checks, with no network, the
  `uses:` lines of steps written in plain block form; only `--verify`
  checks every form, and the commits.
- **CodeQL scans the workflow files and the Python scripts in `scripts/`,
  not the Swift code, on purpose.**
  Default setup cannot build Swift without a committed Xcode project, so
  adding Swift to it fails again; turning CodeQL off blocks every
  merge while the ruleset requires CodeQL results. docs/DECISIONS.md,
  "Reviews, updates and GitHub settings", *Code scanning*, says why and
  when to revisit.
Codex code review looks for the Code Review Rules heading. GitHub
Copilot code review reads AGENTS.md and
`.github/copilot-instructions.md` from the pull request's own branch,
and Claude Code reads AGENTS.md through `CLAUDE.md`. Copilot is also
given review steps in `.github/skills/code-review/SKILL.md`, which
GitHub says it uses when they are relevant.

- **Copilot code review reads its instructions from the pull request's
  own branch** (GitHub's documentation, checked 2026-10-12): `AGENTS.md`,
  `CLAUDE.md`, `.github/copilot-instructions.md` and the skills in
  `.github/skills/`, and also `REVIEW.md`, `GEMINI.md` and
  `.github/instructions/**/*.instructions.md` if one is added. A change to
  any of them applies to the review of the pull request that makes it.
- **The other reviewers read instructions too, and not all from the
  same branch** (their documentation, read 2026-11-07). CodeRabbit
  takes `.coderabbit.yaml`, and as its guidelines `AGENTS.md`,
  `CLAUDE.md`, `.github/copilot-instructions.md`, `REVIEW.md`,
  `GEMINI.md` and any `SKILL.md` under `.github/skills/`, all from the
  pull request's own branch. Greptile takes `.greptile/` from the pull
  request's own branch. cubic reads `AGENTS.md`, `CLAUDE.md`, the README
  files and everything under `.github/` as background, but takes
  `cubic.yaml` from `main` only, so a pull request that changes
  `cubic.yaml` is reviewed under the old one. A change to any of these
  files is one *Code Review Rules* flags for the owner.
- **Xcode 27.2's JSON project format is not adopted yet.** From Xcode
  27.2, Xcode can keep a project in JSON (`project.xcproj`) instead of
  `project.pbxproj`, and new projects use it by default. Brickson's
  project stays generated by XcodeGen and uncommitted until the switch
  planned in docs/DECISIONS.md, "Xcode's JSON project format". Never
  commit a project file (`.gitignore` ignores it; `git add -f` gets past
  that), and never move the build to JSON outside that plan's pull
  request.
