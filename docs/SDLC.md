# How Brickson is made

The way of working for everyone who builds Brickson: the owner, and the
Claude Code, Codex and Jules agents. It follows the six stages of
Anthropic's playbook for an AI-native software development life cycle
(the owner's copy, 2026; not in this repository, and page numbers below
are the PDF's), adapted to a project with one owner who is new to
programming, many agents working in parallel, and an app that people who
cannot speak rely on.

The rules themselves live in [`AGENTS.md`](../AGENTS.md): its invariants
outrank anything here. This page says in what order work happens, who
decides at each step, and when a step is finished. Each stage has **one
gate**, the check a piece of work must pass to move on, and **one
definition of done**.

## At a glance

| Stage | What it produces here | Gate | Who passes the gate |
|---|---|---|---|
| 1. Plan | A row in [`ROADMAP.md`](ROADMAP.md) and the *Intent* of a work file; its decisions recorded in DECISIONS.md | The item serves the owner's goal, and nothing it needs is waiting on the owner | The agent planning it; the owner only for the few decisions that are theirs |
| 2. Design | The *Spec* of the work file; screens in the Figma file, from Apple's iOS and iPadOS 27 UI kit | The screens are linked in the pull request before it is ready to merge | The owner, by merging |
| 3. Build | The *Plan* of the work file; a branch and pull request; tests written first | A written plan before the first code commit | The agent, checked by reviewers |
| 4. Test | `scripts/test.sh`, GitHub CI, the device-check table | The required checks "Unit tests" and "UI tests" pass | GitHub's `main` ruleset |
| 5. Deploy | A merge into `main`; the website; TestFlight and App Store builds | The owner merges, and only the owner uploads or releases | The owner |
| 6. Maintain | A record per pull request, the handoff, lessons, issues | Every signal is triaged: fix now, schedule, or dismiss with a reason | The owner, or an agent for routine items |

**The rule behind the table:** agents may do everything up to a gate the
owner holds, and never pass it (playbook p46: "The agent may act up to the
production gate, and cannot pass it"). The owner's gates are deliberately
few, so the project never waits on them for routine work: the handful of
decisions only the owner can make, merging, and releasing. On 2026-10-21
the owner asked to focus on building and to leave the logistics to the
project, so everything else, agents decide, record, and keep going
(AGENTS.md, *Working with the owner*).

## The work file

The playbook keeps one chain of documents for each change: an intent
(what is wanted and why), a spec (what was decided), and a plan (how it
will be built), each committed before the next stage starts (pp. 11-20).
Here the three live in one file per feature, in
[`docs/work/`](work/README.md), so the owner reads one page, not three.
Each part is committed when it is written, so git history still shows
when the intent became a spec and the spec a plan.

A feature that changes what a person sees or hears, or that takes more
than one pull request, starts with a work file. A small fix does not: its
pull request description is enough. Work already under way on 2026-10-21
started from its roadmap row and the research in
[`docs/recon/`](recon/README.md), and does not need to go back and write
one.

The record of what *happened* is separate: one file per pull request in
[`docs/log/`](log/README.md), and the front page,
[`docs/HANDOFF.md`](HANDOFF.md), for what is true now.

## 1. Plan

**What it means here.** Deciding what to build next, for whom, and why.
The order follows the disease: what a person needs early, then as they
lose speech, then as they move to a switch, their head or their eyes
([`ROADMAP.md`](ROADMAP.md), *How the order was chosen*).

**Where work comes from.** The owner's requests; the research sweeps in
`docs/recon/`; a finding from Maintain (a failed device check, a bug, a
review, a person's feedback); a new Apple release. Each becomes a roadmap
row with an owner, and, when it needs one, a work file whose first part
is its *Intent* (p13's template: problem, proposed outcome, who and what
it affects, constraints, open questions).

**Decisions.** Agents decide, and record each decision in
[`DECISIONS.md`](DECISIONS.md) as decided: dated, with its reason, marked
*Default*, and reversible if the owner objects. Only a few questions are
the owner's: the app's name, its price, how the name is said, the
license, and anything personal. They are listed in DECISIONS.md, *Waiting
on the owner*, each with a recommendation and one plain sentence of why,
asked together rather than one at a time. Until one is answered, nothing
hard to undo is done under it.

**Gate:** the item serves the owner's goal, and nothing it needs is
waiting on the owner.

**Done when:**
- the item has a roadmap row naming who owns it;
- if it needs one, its work file's *Intent* is committed;
- its open questions are decided in DECISIONS.md, or listed under
  *Waiting on the owner*.

## 2. Design

**What it means here.** Turning the intent into a spec: what the feature
does in every state, which AGENTS.md invariants it touches and how it
keeps each one, and what the screens look like. The playbook has the spec
written against the organization's policies, with concerns flagged before
anyone builds (pp. 15-17). Brickson's policies are its invariants, its
design rules for dwell, switch and pointer input, and its privacy policy.

**The spec part of the work file names:**
- every state the feature adds or changes, and where each control sits in
  each one (invariant 8: positions never move);
- for each input method, how a person reaches it, and what a repeated
  activation meets (invariant 10);
- the colour pairs it adds, for `PaletteTests` (invariant 6);
- any sentence of the privacy policy it makes untrue;
- the concerns it raises, each resolved or listed as a proposed decision.

**Screens** are drawn in the project's Figma file from Apple's iOS and
iPadOS 27 UI kit, so they use the system's own components, with every
state on one page so the owner can see that nothing moves
(`docs/DESIGN.md`, kept by the screens work). Layouts are
designed from the space available, never for one device model (the
owner's goal, 2026-10-21).

**Gate:** the screens are drawn and linked from the pull request that
puts them on screen before it is ready to merge, so the owner sees them
when deciding to merge; the merge accepts them. Work that changes
nothing on screen needs no screens; its spec is reviewed with its pull
request.

**Done when:**
- the work file's *Spec* is committed;
- every invariant it touches is named with how it is kept;
- for screen changes, the Figma frames are linked from the spec and from
  the pull request.

## 3. Build

**What it means here.** Agents write the code, in parallel, without
stepping on each other.

- **Plan before code.** An agent starts in plan mode, reads the spec and
  the code, and writes the work file's *Plan*: the files that change, the
  order of work, the risks, and the proof (p20). When the build departs
  from the plan, the plan is corrected in the same commit.
- **One stream per piece of work.** Each thread or agent works on its own
  branch (`<agent>/<topic>`), owns a set of files, and opens one pull
  request at a time. Work in another's files goes to that owner as a
  message, not a commit (p28: parallel sessions in their own worktrees;
  `.claude/worktrees/` is ignored by git for that).
- **The briefing.** `AGENTS.md` is this project's `CLAUDE.md` (Claude
  Code loads it through `CLAUDE.md`). The playbook says to keep that file
  under a page (p23); this one is long on purpose, because its invariants
  are the safety rules every agent and reviewer must apply. Reference
  material that no rule depends on belongs in `docs/`, not there.
- **Test first** (AGENTS.md, *Workflow rules*): a failing test before new
  behaviour, a failing reproduction before a fix.
- **Cloud agents cannot build Swift.** Claude Code on the web, Codex cloud
  and Jules have no Xcode, so for them GitHub CI is the compiler. They say
  so, and never call unbuilt code working.

**Gate:** a written plan before the first code commit, which the
pull request's reviewers check the diff against.

**Done when:**
- the diff matches the plan, or the plan was updated with it;
- every new behaviour has a test, named with the change that would make it
  fail;
- the pull request adds one `docs/log/` file, edits the handoff's front
  page where it made a line untrue, and moves its roadmap row.

## 4. Test

**What it means here.** Every session can check its own work before a
person sees it (p31), with one command:

| Command | Healthy output |
|---|---|
| `scripts/test.sh` | `All unit tests passed.` |
| `scripts/test.sh ui` | `All UI tests passed.` |
| `scripts/test.sh device` | `The device build succeeded.` |
| `python3 scripts/test-site.py` | `OK` |

On a Mac the unit suite is green before any commit; for work made where
nothing can be built, CI is green before the pull request merges
(AGENTS.md, *Build and test*). Results name what they were measured on
(AGENTS.md, *Workflow rules*).

**Three levels, because a simulator cannot show everything:**
1. **Unit and UI tests** on simulators, locally and in GitHub CI, on the
   iPad and, as the test-seams work lands, the iPhone. UI tests keep
   screenshots, which are compared with the accepted Figma frames
   (p32: close the loop with a visual check).
2. **Device checks** on the owner's own iPhone and iPad: sound, the real
   keyboard, every input method, Snap to Item. The list and its results
   are on the handoff's front page, *Checks that need a real device*.
3. **People.** Before a release, people who will use Brickson try it
   through TestFlight, including a person living with ALS and a
   speech-language pathologist (ROADMAP R0, item 11). The playbook has no
   such step; for this app it is the test that matters most.

**Gate:** the required checks "Unit tests" and "UI tests" pass on the pull
request. The `main` ruleset enforces this; nothing merges without it.

**Done when:**
- the required checks are green on the pull request's last commit;
- the pull request says what ran where, and what was not checked;
- any device check the change affects is listed in the table, with a
  result once a device run has happened.

## 5. Deploy

**What it means here.** Three kinds of release, each behind the owner.

- **Into `main`.** Codex reviews every push to a pull request, GitHub
  Copilot reviews each pull request once when it opens, and GitHub's AI
  Scan posts security findings; all three review against AGENTS.md,
  *Code Review Rules*, which is this project's `REVIEW.md` (p39). Their
  findings inform the owner; they never approve or block on their own
  (p38). The agent that opened the pull request answers every finding,
  fixing it or saying why not, and says in its ready message whether the
  findings are handled. **The owner merges.** Agents never merge, never
  push to `main`, and never add Copilot as a reviewer.
- **The website** publishes itself from `site/` after each merge to
  `main` ("Publish website", `.github/workflows/pages.yml`).
- **The app.** The owner archives a build on the Mac with the current
  Xcode, uploads it to App Store Connect, tests it through TestFlight,
  submits it to App Review and releases it. Agents prepare everything
  around that (release notes, review notes, store text with no price
  words, screenshots, the checklist in `docs/APP-STORE.md`,
  kept by the App Store work), and never create, sign in to or change
  anything in App Store Connect.

**Workflow files are an owner step.** Cloud agents' GitHub access cannot
change files under `.github/workflows`. The agent finishes the file and
gives the owner its full text (in the pull request, or in the project's
shared files), and the owner commits it on the pull request's branch:
open the file on that branch in GitHub, choose the pencil (Edit), paste,
then **Commit changes** to the same branch. From the Mac, `git` works as
usual. The owner did this for PR #12 on 2026-10-21.

**There is no rollback on the App Store.** A version that is out cannot be
taken back; the fix is a new build. For updates, App Store Connect's
phased release spreads automatic updates over seven days and can be
paused for up to 30 days in total, though anyone can still download the
new version by hand (Apple, "Release a version update in phases", checked
2026-10-21). TestFlight is where problems should be found.

**Gate:** the owner's hand. The owner merges, and only the owner uploads,
submits or releases. GitHub's `main` ruleset enforces the merge gate for
every agent, which is why it, not a per-agent setting, is the backstop.

**Done when:**
- for a pull request: merged by the owner, with the website republished if
  `site/` changed;
- for an app release: the build is live, its version and build number are
  recorded in a `docs/log/` file, and the handoff's front page says what
  shipped.

## 6. Maintain

**What it means here.** Noticing what went wrong or changed, and feeding
it back into Plan (p47: "what it finds re-enters the pipeline as
intent.md").

**Signals, and where they arrive:**
- a failed CI run on `main` or a flaky test (GitHub Actions);
- Dependabot's monthly pull request for the workflow actions, and any
  security update (not reviewed by Copilot unless the owner requests it;
  AGENTS.md, *Build and test*);
- CodeQL alerts on the workflow files and Python scripts;
- a new Xcode or iOS release from Apple (moved to through a pull request);
- device-check results, TestFlight feedback, and after release, crash
  reports people choose to share, App Store reviews and support email.

**Triage.** Each signal gets one of three answers: fix now (a pull
request), schedule (a roadmap row, and a work file if it needs one), or
dismiss with a reason written down. An agent may decide routine ones and
says what it chose; anything that changes the goal goes to the owner.
When something went wrong, its lesson goes into
[`docs/LESSONS.md`](LESSONS.md) with the rule it gives, and, where a test
can hold that rule, a test (p50: add an eval for the incident).

**Gate:** every signal is triaged.

**Done when:**
- no signal is left without an issue, a roadmap row, a pull request or a
  recorded dismissal;
- the handoff's front page is true;
- each lesson learned has a rule, and a test where one can hold it.

## What does not transfer, and why

- **Separate roles.** The playbook has a product owner, a tech lead, a
  release manager and policy owners. Here the owner holds all of them, so
  the owner's gates are the few that matter, and agents carry the rest.
- **Hooks, managed settings and telemetry** (pp. 27, 40-43). They suit a
  company that manages its engineers' machines. Claude Code hooks bind
  only Claude Code, not Codex or Jules, so GitHub's ruleset stays the
  backstop for every agent. A small `.claude/settings.json` hook that
  blocks `git add -A`, a push to `main` and edits to the generated Xcode
  project would add a second line of defence for Claude Code; proposed,
  not built.
- **Continuous evals in CI** (p34) need an API key and a budget in CI.
  Codex and Copilot already review every pull request against the same
  rules. Revisit if agent mistakes start to repeat; the evidence would be
  the same lesson appearing twice in `docs/LESSONS.md`.
- **Control bands** (p49) need a steady stream of runs to set a baseline;
  this project has a few CI runs a day. Every failure on `main` is looked
  at instead.
- **Claude in Slack** (p52). The project's chat with Claude plays that
  part.

**What this project adds that the playbook lacks:** device checks,
testing with people living with ALS, App Review, measured contrast, and
invariants that a reviewer applies to every change.

## What is measured

From records GitHub and git already keep, read when planning each release:

- the share of agents' pull requests whose CI is green on the first push
  (playbook p33);
- how long a ready pull request waits for the owner;
- device-check rows with no result yet;
- a lesson that has to be learned twice.
