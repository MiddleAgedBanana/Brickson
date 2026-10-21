# Decisions

Binding choices for Brickson, with the reason for each. Code comments point
here by section title, so keep titles stable. A settled decision is not
reopened without new evidence; to change one, edit its entry, say what
changed and why, and keep the old reasoning in a "Before" line.

"Owner" means the repository owner decided; "default" means an agent chose
a reasonable default that the owner can overrule.

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

## Typing is a state of Home

*Default, adopted 2026-10-21: the owner left these choices to the project. Reversible if the owner objects.*

When someone chooses Type, Home stays on screen and only its lower part
changes: the keyboard appears where the categories and phrase tiles were.
Typing is not a separate screen or a sheet, because either would hide or
duplicate Emergency, Get Attention, Yes and No, which must stay one
activation away in every Home state (invariants 2 and 10).

**The band rule.** A band across the top of Home holds everything the
person must always reach: the message (which shows the words being
typed), Emergency, Get Attention, Yes, No, Speak, the way back to the
phrases and the space for warnings. The band is sized so that **Apple's
keyboard never reaches it**, on the worst screen, in every orientation
and text size. Because controls keep their relative places across
profiles (invariant 8), the room Apple's keyboard leaves is the room
every profile gets, even one that never uses Apple's keyboard.

- Nothing moves when the keyboard appears or hides (invariant 11): the
  keyboard covers the lower part of Home instead of pushing it up.
- An app cannot ask how tall the keyboard will be before it appears. So
  the layout reserves room for it as a function of the window alone (its
  size and the text size), never of the device model. Measured keyboards
  are rows in the tests, and a UI test fails if the live keyboard's top
  crosses the band. `KeyboardProbeTests` measures it; the
  table itself arrives with the layout engine (docs/PORTING.md, step 4).
- The reference app's measurements on iOS 27.0 simulators with the full
  software keyboard: a 13-inch iPad in landscape, keyboard top at 534 of
  1032 points; the same iPad with Display Zoom set to Larger Text, 276 of
  774 (the worst case: one row of 88pt controls fits under the message,
  at the default text size only); an iPhone 17 Pro in portrait, 546 of
  874. Brickson's own numbers are in docs/log/2026-10-21-typing-foundation.md.
- Only controls that are harmless if a look slips up from the keyboard
  sit nearest its edge; Speak, Yes, No, Get Attention, Emergency and
  Clear sit away from the keys. Where the band has room for only one row,
  that cannot be met, and each such screen becomes a named, measured
  exception for the owner.
- While typing, nothing that speaks sits under the keyboard, so hiding
  the keyboard reveals nothing that speaks.

Why: the reference app put its quick controls in a right-hand column, and
the real keyboard covered Speak and Get Attention there (D27,
docs/LESSONS.md, "Test with the real software keyboard"). The rule is set
before Home is laid out, so that mistake cannot be built again.

## Typing uses Apple's keyboard

*Default, adopted 2026-10-21: the owner left these choices to the project. Reversible if the owner objects.*

Version 1.0 types with Apple's own keyboard, everywhere. It brings
QuickType predictions, autocorrection, Text Replacement, dictation, and
the keyboard features Apple builds into Switch Control and Eye Tracking,
and Apple keeps improving them. Two additions may follow, in this order:

1. **A row of Brickson word buttons** just above the keyboard, at the
   profile's target size, wherever the band leaves room (the larger
   iPads). After a word is put in, the word buttons stay empty until the
   next key, so a lingering look cannot keep adding words. Built only
   after the device check on what happens at the keyboard's edge
   (docs/log/2026-10-21-typing-foundation.md, check 5).
2. **A large-key Brickson keyboard** for pointer and gaze users on large
   iPads, only if device checks show Apple's keyboard is too slow or
   unsafe for them. Never on iPhone: ten keys of at least 44 points do not
   fit across any iPhone.

The typing rules live in `MessageComposer`, which does not care which
keyboard feeds it, so either addition reuses them.

Not available in SwiftUI: turning off *inline predictions* (the grey word
that Space accepts). That needs a wrapped UIKit text view; until then it
is a setup tip (Settings › General › Keyboard › Show Predictions Inline).

## Writing Tools off while typing

*Default, adopted 2026-10-21: the owner left these choices to the project. Reversible if the owner objects.*

Every field that types a message to speak turns off Apple Intelligence's
Writing Tools (`typingFieldTraits()`, which applies
`writingToolsBehavior(.disabled)`). A stray look could otherwise let it
rewrite the person's words before they are spoken in the person's own
voice (invariant 7), and AI-written replies are a hard stop (invariant
9). For the same reason no on-device language model predicts words or
finishes sentences.

## Third-party keyboards refused in 1.0

*Default, adopted 2026-10-21: the owner left these choices to the project. Reversible if the owner objects.* *Not built yet.*

Brickson refuses keyboards from other apps, so only Apple's keyboard
appears in it. Reasons: the keyboard table stays true (other keyboards
have other heights, and could cover the band), and the privacy promise
stays simple (a keyboard with Full Access can send what is typed to its
maker). The cost: someone who relies on an accessible keyboard from
another app, such as one with larger keys, could not use it in Brickson.
Revisit if people ask. It is built with the typing state, as
`application(_:shouldAllowExtensionPointIdentifier:)` returning false for
`.keyboard` in an app delegate.

## Return speaks

*Default, adopted 2026-10-21: the owner left these choices to the project. Reversible if the owner objects.*

The keyboard's Return key speaks the whole message, as an extra path;
Speak stays the main one. A typed line break is never kept in the
message. A line break inside pasted text becomes a space. Return with
nothing to say does nothing. `MessageComposer` holds the rule, so it
works the same with any keyboard (docs/LESSONS.md, "The return key must
speak": in the reference app Return added a line break, nothing was
spoken, and the line break was later read as a pause).

Still open for dwell users: Apple's Return key sits among the letter
keys, so a look that slips onto it speaks a half-written message. That
goes against invariant 10 (no speaking control beside where the person
points). Either it becomes a named, measured exception for dwell
profiles, or Return stops speaking in those profiles. That is decided
after the keyboard-edge device check (check 5 in
docs/log/2026-10-21-typing-foundation.md), not before.

## The typed message

*Default, adopted 2026-10-21: the owner left these choices to the project. Reversible if the owner objects.*

How the message being typed behaves (`MessageComposer`, `DraftStore`):

- **Speaking keeps the message**, so it can be said again or added to
  (invariant 3: speaking never changes data). A setting to clear it after
  speaking is built into `MessageComposer` but not offered.
- **Clear can be undone once.** The cleared words stay in memory, never
  on disk, until a later Clear replaces them or the app closes. Nothing
  else may take Clear's place, so there is never an Undo button where
  Clear was (invariant 10). Where the restore control sits is Home's
  layout's decision.
- **At most 2,000 characters** (about two to three minutes of speech), so
  an accidental paste cannot speak for many minutes. An edit that would
  pass the limit is refused whole and nothing is cut short. A longer
  message restored from an older version is kept whole (invariant 7).
- **Kept across launches.** The message is saved after every change to a
  small file, Application Support/Typing/draft.txt, written in one step
  so a crash leaves the old or the new message and never part of either.
  It is restored at launch without speaking and without opening typing,
  and Clear deletes the file. This is what the privacy policy promises
  ("The message you are typing, so it is still there if the app closes.
  It stays until you clear it.").
- **A failed save never loses the words.** They stay on screen and in
  memory, Home shows "Message not saved" as passive text in the warning
  space (invariant 5), and the next change or `retrySave()` tries again.
  A file that cannot be read at launch gives an empty message and
  "Message not restored". The message is never logged and never put in a
  crash message.

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

**Code review.**

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

**Dependencies.** Brickson has no packages (invariant 9), so the actions
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

**Code scanning.** *Revised 2026-10-12.* CodeQL's default setup scans
the workflow files in `.github/workflows` and nothing else. CodeQL does
not scan the Swift code, on purpose:

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

**`main` ruleset** (recommended to the owner):

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
