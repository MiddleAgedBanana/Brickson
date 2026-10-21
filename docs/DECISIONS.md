# Decisions

Binding choices for Brickson, with the reason for each. Code comments point
here by section title, so keep titles stable. A settled decision is not
reopened without new evidence; to change one, edit its entry, say what
changed and why, and keep the old reasoning in a "Before" line.

"Owner" means the repository owner decided; "default" means an agent chose
a reasonable default that the owner can overrule.

## Waiting on the owner

*2026-10-21.* On 2026-10-21 the owner asked to focus on building the app
and to leave the logistics to the project. These are the only questions
left for the owner, because each is personal, sets a price, or cannot be
taken back. Until one is answered, nothing hard to undo is done under it.

| Question | Recommended | Why |
|---|---|---|
| Is "Brickson" the final name, and so what is the bundle identifier? | Keep Brickson (retained publicly on 2026-10-12), with a bundle identifier that contains no personal name | The bundle identifier is public and can never change after the first upload; today's `family.avery.brickson` contains the owner's first name (*App identity*) |
| What does Brickson cost? | No recommendation: the owner's call, before the first submission | Until then nothing anywhere states a price (*Price not decided*), and no purchase code is built |
| How is "Brickson" said? | Tell an agent how it sounds; it sets a sound-alike spelling in `APP_SPOKEN_NAME` | VoiceOver and Siri say the name; only the owner knows how it should sound |
| Should the code have a license? | Not yet: keep all rights reserved | A license can be added later, but one that has been granted cannot be withdrawn from copies already taken |
| Is the owner a "trader" under the EU's Digital Services Act? | Decide when the App Store Connect record is made; if yes, publish a dedicated contact rather than a home address | App Store Connect asks before the app can be offered in the EU, and a trader's contact details are shown publicly |

Owner steps that are actions, not decisions: the Team ID in
`project.yml`, device runs, committing workflow files (docs/SDLC.md,
*Deploy*), and every step in App Store Connect.

## Decided by default on 2026-10-21

*Default, adopted 2026-10-21: the owner left these choices to the
project. Reversible if the owner objects.* Each was the recommended option
of the research of 2026-10-15 (`docs/recon/`) or of the work that owns it.
Decisions with their own entry are listed by title; the rest are recorded
here. Entries kept by other work arrive with its pull request.

| Decision | Where it is recorded |
|---|---|
| The releases and their order: R0, R1, R2 | `docs/ROADMAP.md` |
| Layouts from the space available, with floors set without a device table | "Layouts from the space available", below |
| Minimum iOS 26.0, iPhone and iPad | "Minimum iOS 26, iPhone and iPad" (Toolchain and iOS version targets) |
| The App Store category is Utilities | "App Store category" (App Store readiness and ASO) |
| Home's fixed slots, labels and button style | Entries next to "Home version 0 is a stand-in" (Phone layout and word fitting) |
| Typing as a state of Home under a band Apple's keyboard never covers, Apple's keyboard in 1.0, Writing Tools off, third-party keyboards refused, Return speaks, the typed message | "Typing is a state of Home", "Typing uses Apple's keyboard", "Writing Tools off while typing", "Third-party keyboards refused in 1.0", "Return speaks", "The typed message" (Typing foundation) |
| Explicit saves, an Emergency category that is always there, fixed starter identities, editing, import, replace, the backup format, an unreadable library reported and never replaced | "Every save is explicit", "Starter phrases", "The emergency category is always there", "Editing the library", "Importing a backup", "Replacing the library", "Backup file format", "An unreadable library is reported, never replaced" (Library editing and backup format) |
| When the audio session is released, the alarm's sound, start-only Get Attention, no automatic resume, Personal Voice never written to a file | Entries next to "Background audio" (Speech engine and Get Attention) |
| Home first with setup as a place in Settings, the Settings root, the voice picker, the Privacy row, the largest sizes when nobody answers setup, an "Anything changed?" check-in every three months that waits 30 days after Not Now | "First launch opens Home; setup lives in Settings", "Settings is a cover with a fixed safety bar", "Settings resets when idle and never closes", "Setup answers are kept as offered, never as completed", "Check-ins come every three months", "The privacy policy ships inside the app" (Settings and first run) |

Recorded here:

- **iPhone orientations.** Portrait and both landscape orientations, not
  upside down, from the pull request whose layout tests show a landscape
  phone with no scrolling for the starter library; until then portrait
  only. A phone on a wheelchair or bed mount is often sideways, and the
  person may not be able to turn their head. That pull request updates
  *Orientations*.
- **No iCloud sync in 1.0** stands as recorded below.
- **Caregiver alerts:** 1.0 alerts only with sound in the room (Get
  Attention), and the privacy policy's caregiver-alerts section is deleted
  before release. Anything that reaches another device needs network code,
  which invariant 9 forbids, so it stays the owner's decision.
- **Recorded phrases, in stages:** guidance for recording elsewhere first,
  then importing and playing recordings (R1), then an in-app recorder
  after device checks (R2).
- **No purchase code** (StoreKit) until the owner decides a price.
- **Who chooses the input profile:** the family, in Settings. Accessibility
  features the system reports may suggest a profile, never switch it.
- **No rating prompt on Home.** Brickson never asks for a review on its
  own; a "Rate Brickson" row, if added, lives on a family Settings screen.
- **Copilot's "Review new pushes" stays off.** Each review spends the
  owner's AI credits, and Codex already reviews every push.
- **No `REVIEW.md`.** AGENTS.md, *Code Review Rules*, is the review policy
  every reviewer reads.
- **The research is public** in `docs/recon/`, with personal details and
  local paths removed.
- **If storage cannot start at all,** the app still stops
  (`PhraseLibraryStore.openForApp`), as the reference app did: no real way
  for it to happen was found. Revisit if one is.
- **At release, Mac and Apple Vision Pro availability are switched off**
  in App Store Connect, matching *Minimum iOS 26, iPhone and iPad*.
- **At most three pull requests wait for the owner's review at once**
  (docs/SDLC.md, *Build*); other work continues on its branch.

## Layouts from the space available

*Default, adopted 2026-10-21: the owner left these choices to the
project. Reversible if the owner objects.* The owner's goal of 2026-10-21
asks for interfaces built from the space available with standard SwiftUI
containers, "instead of building device-specific interfaces" (AGENTS.md,
*Layout on every device and window*).

- Layout code and the layout engine take the window's size, its safe
  areas, Dynamic Type, the input profile and the library's shape, and
  nothing that names a device: no device model, no table of screens, no
  check of the screen's physical size. Size classes are hints, never the
  reason a control moves. Test matrices and dated measurements may name
  devices.
- **Floors without a device table.** iOS does not report a screen's
  physical density, so each profile's floors are physical sizes converted
  to points once, at the densest supported screens (about 163 points per
  inch, the 326 ppi screens at 2x), and used everywhere. A target is then
  at least its physical size on every screen, and larger on most. The
  reference app's gaze floors of 110, 88 and 72pt were sized on a 13-inch
  iPad (about 132 points per inch); held at the densest screen they are
  about 136, 109 and 89pt. The layout engine's fit tables decide whether
  those hold on phones, and any shortfall is a named, measured exception.
- The 2026-10-15 layout blueprint
  (`docs/recon/2026-10-15/layout-blueprint.md`) keyed density, profiles and
  the keyboard band to device tables; those parts are replaced by this
  entry. Before: AGENTS.md said floors were "computed in physical size per
  device".

## App identity

*2026-10-10. Name: owner. Other values: default.*

Everything that identifies the app sits in one block at the top of
`project.yml`, so changing it means changing one line:

| Setting | Value | Notes |
|---|---|---|
| `APP_DISPLAY_NAME` | `Brickson` | The name under the icon. The name retained by the owner on 2026-10-12. |
| `APP_SPOKEN_NAME` | `Brickson` | How VoiceOver and other text-to-speech say the app's name (`CFBundleSpokenName`). If they say it wrong, use a sound-alike spelling here; the name under the icon stays as it is. |
| `APP_BUNDLE_ID` | `family.avery.brickson` | The identifier the owner was advised to register for the App Store. It **cannot change after the first App Store upload**, and it is public, so any change happens before that upload. Someone building for their own device changes it locally (it belongs to one team) and does not commit that. |
| `DEVELOPMENT_TEAM` | empty | Needed only to run on a real device or upload. Left empty until the developer account is chosen (personal or organization). A team ID is not secret; it is in every signed app. |
| `MARKETING_VERSION` | `0.1.0` | The version people see. |
| `CURRENT_PROJECT_VERSION` | `1` | Must go up with every upload to App Store Connect. |

Siri also accepts the alternative name "Brick Son" (`INAlternativeAppNames`
under the app's `info` in `project.yml`; at most three, never another app's
name), because "Brickson" is in no pronunciation dictionary. Whether Siri,
Voice Control and VoiceOver handle the name well is a device check.

The Xcode project, targets and folders are also called Brickson. Renaming
those is a larger change (folders, target names, `@testable import`), and is
not needed to change the name people see.

## Brand name and founder story

*2026-10-12. Owner.*

Keep **Brickson**, styled **brickson** in the website wordmark. Before:
Brickson was a working name and alternatives were being explored. The owner
chose to retain it because his brother invented the name as a teenager;
it became a family joke more than twenty years ago. His brother later died
of ALS. The owner authorized a short public founder note on the website and
README and specifically requested that it avoid a detailed backstory.

Use the concise first-person note attributed to Avery Dedmon. Do not invent
biographical details, testimonials, treatment benefits or reliability claims.
The name decision is not legal clearance or an App Store reservation; see
[the availability screen](NAME_AVAILABILITY.md).

## Generated Xcode project

*2026-10-10. Default, from the reference app.*

`Brickson.xcodeproj` is generated from `project.yml` by XcodeGen and is not
committed (it is in `.gitignore`). Every machine, and CI, generates it.
This keeps project settings reviewable as plain text and avoids merge
conflicts in the project file. Agents never open the project in Xcode
(docs/LESSONS.md, "Never open the project in Xcode from an agent").

## Minimum iOS 26, iPhone and iPad

*2026-10-10. Default, from the reference app.*

iOS and iPadOS 26.0 or later, on iPhone and iPad. Mac ("Designed for
iPad"), Mac Catalyst and Vision Pro are switched off until someone decides
to support them. iOS 26 brings the current SwiftUI, SwiftData and
accessibility APIs, and Eye Tracking needs a recent iPad anyway.

## No outside packages

*2026-10-10. Default, from the reference app and invariant 9.*

Only Apple's frameworks. No Swift packages, no SDKs. Every dependency is
code that can break, track or change under the person relying on it.

## No servers, accounts, ads or analytics

*Invariant 9.* Everything stays on the device. The privacy manifest
(`Brickson/Resources/PrivacyInfo.xcprivacy`) declares no tracking and no
collected data; `AppBundleTests` pins it.

## Price not decided

*2026-10-12. Owner.*

The owner has not decided Brickson's price. Until they do, nothing in the
repository, the website (`site/`), the app or the project's documents
states one: not "free", not "paid", no amount. Describe Brickson by what it
does ("an iPhone and iPad app that speaks for people living with ALS").
"Free" about other things, such as Xcode, a free Apple Account or GitHub
Pages, is fine. The reference app's handoff called its successor free, and
earlier documents here copied that; the owner never decided it.

## Versioned storage

*2026-10-10. Default.*

The phrase library is stored with SwiftData in a versioned schema
(`PhraseLibrarySchemaV1`) with a migration plan
(`PhraseLibraryMigrationPlan`), from the very first release. Every later
version must migrate from whatever 1.0 ships. To change a stored model:
add `PhraseLibrarySchemaV2` with copies of the models, add a migration
stage, move the `PhraseCategory` and `Phrase` type aliases, and never edit
V1. Models carry a stable `uuid` for backups, restores and (later) Siri and
Shortcuts.

Deleting a category does not cascade to its phrases (`.nullify`); the code
that deletes a category deletes its phrases in the same save
(docs/LESSONS.md, "Never roll back a cascade delete").

## No iCloud sync in 1.0

*2026-10-10. Default; recommended to the owner.*

The library stays on the device (`cloudKitDatabase: .none`). Sync brings
conflicts, account states and failure modes that a person who cannot speak
must never meet mid-sentence. The models already follow SwiftData's iCloud
rules (defaults on every property, optional relationships, nothing unique),
so sync could be added later without a migration. Backup by file comes
first (docs/PORTING.md, step 2).

## The screen stays awake

*Invariant 12.* While Brickson is open, the screen never dims or locks
(`ScreenWakePolicy`): many people using it cannot unlock their device. It
is not a setting on the person's path. Whether touch users, who can unlock
their own device, should be able to turn this off is an open question for
the stage profiles.

## Background audio

*2026-10-10.* `UIBackgroundModes` includes `audio`, and speech uses the
`.playback` audio session, so a sentence keeps playing when the device
locks or another app opens, and the Get Attention alarm (once ported)
keeps sounding until it is stopped. App Review allows background audio
only for its intended purpose (guideline 2.5.4), so:

- never play silent audio to keep the app alive;
- in the App Review notes, give steps that show it, for example: "Choose a
  long phrase, then lock the device: speech continues."

**Open, decide with the Get Attention port (step 1):** when to release the
audio session. Today `SpeechService` activates it before speaking and never
deactivates it, as the reference app did, so music or a podcast that speech
interrupted does not resume on its own. Releasing it after speech ends
(with `.notifyOthersOnDeactivation`) is kinder to other apps, but it must
never happen while the alarm sounds, must not delay the next phrase
(invariant 2), and needs a device check. The alarm shares the session, so
both are designed together.

## Orientations

*2026-10-10. Default, from the reference app (its D2).*

iPhone: portrait only, for now. iPad: all four orientations (iPadOS
multitasking requires them). The reference app locked the phone to portrait
because its phone layout lost Emergency off screen in landscape at large
text sizes. Brickson revisits this when the layout engine is ported
(docs/PORTING.md, step 4); until then, `AppBundleTests` pins it.

## Starter phrases

*2026-10-10. Default; for the owner to review.*

New libraries start with five categories and 34 neutral, practical phrases
(`Brickson/Resources/StarterPhrases.json`): Basics, Emergency, Needs,
Conversation and Feelings. Yes and No are quick controls, so they are not
tiles too. Nothing about anyone's condition and nothing self-deprecating
(invariant 7). The wording is a draft to review with people living with
ALS and their families; the category count matters for scanning by eye.

At launch, `PhraseLibraryLaunch` fills an empty store with them. If the
store opens but cannot be filled (a full disk, say), the app speaks from a
filled in-memory library and shows that changes will not be kept, rather
than open on a Home where Emergency has nothing to show. Only an unreadable
starter file, which the tests rule out for a passing build, leaves Home
with Yes and No alone and a warning.

## Home version 0 is a stand-in

*2026-10-10. Default.*

The first Home screen (`HomeView`) proves the foundations end to end:
quick controls (Yes, No, Emergency), categories, phrase tiles that speak on
the first activation, Again, and passive warnings. Its sizes are plain
defaults, not the measured gaze, switch and touch sizes. It is replaced
when the layout engine and Home are ported (docs/PORTING.md, steps 4 and
5).

How it behaves, and where it knowingly falls short:

- **One Emergency button.** The emergency category has no button in the
  category row; the Emergency quick control opens it and shows a check
  mark while it is open. Two buttons with the same name confused Voice
  Control and the UI tests, and the reference app did the same.
- **Messages never shrink.** The message row always reserves two lines of
  its font; a longer message scrolls inside them at full size (the reference
  app's phone layout did the same). Every phrase start, including Again and
  the same phrase chosen again, shows the message from the top.
- **Audio warnings keep their space.** The warning area always holds the
  height of the tallest short audio warning ("Volume low", "Audio failed"),
  so a warning appearing hides no phrase tile (invariant 4). The short text
  is what people see; VoiceOver reads the full sentence. The two library
  warnings are decided at launch and never appear later.
- **VoiceOver is told about audio problems.** Text appearing on screen is
  not announced, so Home posts an announcement when an audio problem
  appears (including one present at launch) and on every cut-off phrase.
  It says the full sentence, which names the control to use; the reference
  app announced the short text instead. Cut-off phrases and audio failures
  interrupt what VoiceOver is saying and cannot be cut off (high priority);
  low volume waits until VoiceOver has finished (low priority, where the
  reference app used the default). Focus does not move.
- **Accepted for the stand-in only:**
  - No Get Attention yet, so invariant 10's "reachable in one dwell" holds
    only for Emergency, Yes and No. Get Attention comes in port step 1.
  - Again sits beside the message text the person reads, and the phrase
    grid ends just above the warning text: under a gaze profile a look
    that rests on the text could snap to them.
  - The selected category swaps its symbol for a check mark; symbols
    differ in width, so the buttons after it can shift slightly.
  - CI tests the iPad only. On a narrow iPhone the three quick-control
    labels may not fit at larger text sizes.

## Personal Voice permission is asked at launch, for now

*2026-10-10. Default, from the reference app.*

`SpeechService` asks for Personal Voice permission when the app starts.
The reference app did the same, with a comment saying that asking after
the first sentence can hide personal voices for the rest of the session;
Apple's documentation does not say so, so treat that as unverified. As a
result the system question appears on first launch with no explanation.
Onboarding should explain Personal Voice first and then ask; that comes
with Settings and setup (docs/PORTING.md, step 7).

No Info.plist key is needed for the request. If **Allow Apps to Request to
Use** is off (Settings → Accessibility → Personal Voice), the system denies
the request without asking. `AccessibilitySettings.openSettings(for:
.personalVoiceAllowAppsToRequestToUse)` opens that switch directly; the
voice picker should offer it when permission is denied.

## Tests

*2026-10-10. Default.*

Unit tests use Swift Testing and run inside the app on a simulator
(`BricksonTests`, scheme `Brickson`). UI tests use XCTest and launch the
real app (`BricksonUITests`, scheme `Brickson-UI`). GitHub runs both on
every pull request (`.github/workflows/tests.yml`); a pull request merges
only when they pass.

## Reviews, updates and GitHub settings

*2026-10-10. Default; the owner applies the settings in GitHub, so check
them there before relying on them.*

The repository's settings live on GitHub, not in these files. This is
what they are meant to be, and why, so a change to the workflows or the
review setup does not quietly break them.

### Code review

- Codex reviews every push to a pull request. GitHub Copilot (the owner's
  Copilot Pro plan) reviews each pull request **once, when it opens**,
  through the `main` ruleset's "Automatically request Copilot code review"
  rule, at Balanced effort. It does not review every push: each Copilot
  review is paid from a monthly allowance of AI credits (GitHub estimates
  $0.25 to $5 a review at Balanced; Pro includes $15 a month), and Codex
  already reviews every push. When a pull request changes a lot after
  review, the owner can choose **Re-request review**.
- *Added 2026-10-12.* Dependabot's pull requests get no automatic review
  from Copilot or Codex: PR #7, Dependabot's first, got neither, while
  PR #8, opened by an agent, got both. The owner requests a Copilot review
  of one by hand when wanted. Only the owner requests Copilot reviews;
  agents never add Copilot as a reviewer unless the owner asks, because
  each review spends the owner's credits.
- Review guidance lives in AGENTS.md, *Code Review Rules*, which Codex,
  Copilot and Claude Code all read. `.github/copilot-instructions.md` only
  adds what is specific to Copilot and points back to AGENTS.md, so the
  rules exist in one place.
- *Added 2026-10-12.* `.github/skills/code-review/SKILL.md` gives Copilot
  the steps of a review: learn what is built, find the rules the change
  touches, trace a path from a real input, and write the finding. It holds
  the method only. What counts as a finding is decided in AGENTS.md, which
  the skill cites by invariant number and section title, and the skill
  says nothing about which features are built, how many there are or how
  they are set, so it stays true as the app grows. A new review rule goes
  in AGENTS.md, not the skill, and renaming a section the skill cites
  means updating the skill. GitHub's documentation says Copilot code
  review uses a skill in `.github/skills` when it is relevant to the
  review, and that a review-focused folder name such as `code-review`
  makes that likely; `.github/copilot-instructions.md` also points to it.
  The owner asked for this skill, so it is an accepted reviewer
  instruction file outside AGENTS.md. *Tests, workflows and the rules
  themselves* still flags every change to it and every new file of its
  kind for the owner to decide.
- Copilot's review runs on a Linux machine and cannot build an iOS app, so
  there is no `copilot-code-review.yml`; the Tests workflow is the build.
- Copilot never approves a pull request (its "Auto-approval" settings stay
  off). An AI approval does not stand in for the owner's merge.
- No `CODEOWNERS` file: the owner is the only maintainer and appears as
  the author of every pull request agents open, and GitHub never asks an
  author to review their own pull request.

### Dependencies

Brickson has no packages (invariant 9), so the actions
in `.github/workflows` are its only dependencies. Dependabot proposes new
versions once a month in one grouped pull request, waiting seven days
after each release (`.github/dependabot.yml`); security fixes come at
once through Dependabot security updates. Those need three switches in
Settings → Advanced Security that the file cannot turn on: the dependency
graph, Dependabot alerts and Dependabot security updates. Security
updates were on when checked on 2026-10-10, and GitHub allows that only
with the other two on; keep all three on. Actions are referenced by
version tag, not pinned to commit hashes: GitHub only raises security
alerts for tag references, and all of them are GitHub's own actions.

### Code scanning

*Revised 2026-10-12; languages corrected 2026-10-21.* CodeQL's default
setup scans the workflow files in `.github/workflows` and, since
2026-10-13, the Python scripts in `scripts/` (GitHub added Python by
itself once `scripts/test-site.py` landed; checks "Analyze (actions)" and
"Analyze (python)"). CodeQL does not scan the Swift code, on purpose:

- Default setup can only build Swift that has a committed Xcode project
  or Swift package. Brickson's project is generated by XcodeGen and not
  committed (*Build and test* in AGENTS.md), so default setup's one Swift
  attempt, on 2026-10-10, failed ("`autobuild` detected neither an Xcode
  project or workspace, nor a Swift package"), and GitHub then removed
  Swift from default setup by itself. Ticking Swift there again fails
  the same way.
- Scanning Swift would take advanced setup: a workflow of our own, on a
  Mac runner, that generates the project and builds the app while CodeQL
  watches the compiler. It replaces default setup for every language. Not
  chosen, because:
  - CodeQL's Swift checks (CodeQL 2.27.2, read 2026-10-12) look for code
    Brickson does not have: network requests, web views, regular
    expressions, SQL, `NSPredicate` or `String(format:)` built from
    outside text, running other programs, XML, hashing or encryption,
    links opened from other apps, mixing `String` and `NSString` lengths
    (such as an `NSRange` built from `String.count`), and values whose
    names suggest secrets or private information (a password or token,
    but also a phone number, an emergency contact or a medical detail)
    written to logs, settings or the network. None of them applies to
    today's code.
  - It would add a third Mac job to every pull request, estimated at 10 to
    20 minutes (never run). GitHub runs at most five Mac jobs at a time
    for an account, and the ruleset's code scanning rule would make each
    merge wait for it.
  - CodeQL learns to read each new Swift version weeks or months after
    Xcode ships it: 31 to 115 days for Swift 6.0 to 6.3, and 10 to 45 days for their
    point releases (Swift 6.3.3, in Xcode 26.6, took 24). Today it covers
    Swift up to 6.3, which CI's Xcode 26.6 uses, and not Swift 6.4 (Xcode
    27). Every Xcode upgrade could break the job or hold up merges.
- The earlier text here said CodeQL "cannot follow Xcode 27 builds yet"
  and that GitHub "has announced a Swift scanner that needs no build". The
  first is true, but it does not stop scanning today, because CI builds
  with Xcode 26.6; it matters only as upkeep for advanced setup (above).
  The second does not hold for CodeQL, whose Swift support has only the
  `autobuild` and `manual` build modes; no mode that skips the build has
  been announced. It probably meant AI Scan, below.
- GitHub's **AI Scan for pull requests** (a public preview) is on for
  this repository, checked through GitHub's API. It reads each pull
  request's changes without building anything, when the pull request
  opens and after every new commit, and its job logs show it reading
  Swift files. It skips pull requests from forks and from Dependabot.
  Its findings are advice: GitHub's documentation says they do not block
  a merge and no ruleset can require them. By this project's practice,
  each one still gets an answer and is resolved like a review comment.
  GitHub's documentation also says its use spends AI credits, most
  likely from the owner's Copilot allowance (not confirmed).
- Dependabot's first pull request, PR #7, merged with no CodeQL analysis
  of its own: its CodeQL check said "1 configuration not found" and
  analysed nothing, and nothing blocked the merge. Its workflow change was
  scanned after the merge, on `main`. GitHub's documentation does not say
  why; check the next Dependabot pull request.
- Keep default setup on. The ruleset requires CodeQL results, and GitHub
  blocks every merge when a required tool is not set up.
- The failed Swift attempt left an error on the Tool status page (the
  repository's **Security and quality** tab, under the … menu if it is
  hidden, then **Code scanning**, then **Tool status**). It changes
  nothing else: pull request checks leave it out, and the code scanning
  rule passed on the merges after it. It stays until someone deletes it
  there (the Swift configuration, then … → **Delete configuration**).

Revisit when CodeQL can analyse Swift without a build (`none` under
`build_modes` in `swift/codeql-extractor.yml` in `github/codeql`), or
default setup can build a generated project; when Brickson adds code that
CodeQL's Swift checks look at (network code such as caregiver alerts,
opening files or links from other apps, web views, SQL, encryption, or
storing, logging or sending values whose names suggest secrets or private
information, such as an emergency contact's phone number); when AI Scan
stops reading Swift, leaves the preview with new terms, or costs more
than the owner wants; or when a Swift error appears on the Tool status
page again.

### `main` ruleset

Recommended to the owner, and matching GitHub's settings when checked
through its API on 2026-10-15:

| Rule | Setting | Why |
|---|---|---|
| Require a pull request before merging | 0 approvals; merge commits only | Nobody pushes to `main`. The owner cannot approve pull requests that show them as author, so any approval count would block every merge. Merge commits keep the commit hashes HANDOFF cites on `main`. |
| Require status checks to pass | "Unit tests" and "UI tests" | The job names in `tests.yml`. Renaming a job blocks every pull request until the ruleset is changed to match. |
| Require branches to be up to date | Off | Each update reruns the Mac tests; `main` is tested again after every merge anyway. |
| Require conversation resolution | On | Every Codex and Copilot comment, and every CodeQL alert posted on the pull request, gets an answer before a merge. AI Scan findings are answered too, by practice (*Code scanning* above). |
| Require code scanning results | CodeQL: errors, high or higher | A workflow change that CodeQL flags as an error, or as a high or critical security problem, cannot merge. It did not cover Dependabot's first pull request, which got no CodeQL analysis before merging (*Code scanning* above). |
| Automatically request Copilot code review | On; new pushes and drafts off | As above. |
| Block force pushes, restrict deletions | On | History on `main` never changes. |
| Bypass | Repository admin, for pull requests only | The owner can still merge in an emergency, such as GitHub's Mac machines being down, but never push straight to `main`. |
