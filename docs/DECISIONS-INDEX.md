# Decision index

What each decision in docs/DECISIONS.md chose, over what, and why. Before deciding anything, read the groups your work touches, then search docs/DECISIONS.md for each quoted title that applies; the full entry wins. "Owner's call" marks the owner's own choice. Change a decision, change its line here; `scripts/test-docs.py` checks.

## Owner and identity
- "Waiting on the owner": Only the owner settles name, bundle id, price, pronunciation and EU trader status.
- "Brickson's code is all rights reserved": Chose all rights reserved over an open-source licence, so the owner controls reuse.
- "Decided by default on 2026-10-21": Choices the owner left to the project, each reversible and recorded with its reason.
- "App identity": One identity block in project.yml, because the bundle id is public and fixed after the first upload.
- "Brand name and founder story": Chose the name Brickson and a short founder note over a longer backstory.
- "Price not decided": No price is stated anywhere until the owner decides.
- "App Store category": Chose Utilities over Medical, which asks for a regulated-device declaration.
- "Age rating answers": None to every question (4+); the phrases are the person's own words.

## Layout
- "Layouts from the space available": Chose window, safe areas, Dynamic Type and profile over device checks; floors are physical sizes.
- "One spacing scale": Chose one Spacing scale over numbers in each view, so equal gaps stay equal and a test measures them.

## Build and platform
- "Generated Xcode project": Chose XcodeGen from project.yml over a committed project, for reviewable settings and no merge conflicts.
- "Xcode's JSON project format": XcodeGen stays until a trial and its gates pass; then one planned pull request moves.
- "Build with Apple's current Xcode": Chose the newest released Xcode over a pinned version or a beta.
- "Warnings are errors": Chose failing builds over warnings nobody reads; a silenced warning needs its line there.
- "Minimum iOS, iPhone and iPad": iOS 26.0 on iPhone and iPad, because every eye-tracking-capable device runs it.
- "No outside packages": Apple's frameworks only, never third-party packages or SDKs.
- "Apple's current frameworks first": Chose SwiftUI, SwiftData, Swift Testing, App Intents and Observation over legacy APIs; exceptions have rows.
- "No servers, accounts, ads or analytics": None of them, so no one's words leave the device (invariant 9).

## Data and saving
- "Versioned storage": Chose a versioned SwiftData schema and migration plan from 1.0 over an unversioned model.
- "Every save is explicit": Autosave off; plan, then apply in a separate context, so a failed save changes nothing.
- "No iCloud sync in 1.0": Chose on-device only over sync, so a sync conflict never reaches someone mid-sentence.
- "The screen stays awake": The screen stays on while Brickson is open (invariant 12).

## Speech and audio
- "Background audio": Chose the .playback session and one coordinator, so speech goes on when the device locks.
- "Get Attention": A start-only looping tone with a separate Stop, ducked under speech, not silenced.
- "A phrase the system cuts off": An early finish counts as cut off only with an interruption within 3 s.
- "A phrase that does not start": Chose a 15 s start limit over a watchdog, because an unheard phrase showed Speaking.
- "Audio session notices": One adapter, also reading iOS 27's deactivation notice; Brickson never resumes by itself.

## Devices and windows
- "Orientations": iPhone portrait only for now; iPad all four, as multitasking needs.
- "iPhone Duo": Ship optimized for iPhone Duo with the current SDK, its screenshots in every submission.
- "The fold": Owner's call. A wider gap at the fold keeps controls off it; each control keeps its region and order.

## The library and backups
- "Starter phrases": 34 neutral, practical phrases in five categories; if seeding fails, Home speaks them from memory.
- "The emergency category is always there": Exactly one emergency category, always with a phrase; no edit or import empties it.
- "Editing the library": Rules in LibraryRules and LibraryEdit.plan; names trimmed, distinct, never a Home control's.
- "Importing a backup": Only through the system file picker in the family area; words kept byte for byte; Add only adds.
- "Replacing the library": Runs only when it removes none of the person's own words; no safety-copy exception.
- "Backup file format": One JSON file, read and written by BackupCodec.
- "An unreadable library is reported, never replaced": Chose leaving the file untouched and speaking starter phrases over replacing it.
- "The Library in Settings": Editing and backups live in Settings, Family Setup, never on Home.
- "The Library's question screens": Each delete, move or replace asks on its own screen, Keep where the asking row was.
- "Three or four everyday categories": Owner's call. An edit leaving other than three or four everyday categories is refused.
- "Four phrases in every category": Owner's call. A floor of four, over empty grid cells beside controls.
- "Exporting and restoring a backup": Export is a ShareLink keeping no copy; Restore checks off the main thread before changing anything.

## Words people read
- "Text people read is in American English": American English (MND in UK and Australian store text); a person's words are never respelled.
- "Words wider than Home's narrowest buttons": Owner's call. A phrase is allowed with a note; a category name is refused.
- "Phrases named like Home's controls": Owner's call. No phrase is named like a control one activation away; other clashes get a note.

## Home layout
- "Home version 0 is a stand-in": History; see "The layout engine".
- "Home's stand-in layout": History; see "The layout engine".
- "Where the grid still scrolls": History; see "The layout engine".
- "Phrase-grid drag cancellation": A vertical scroll never speaks: scrollBounceBehavior(.always) and standard Buttons.
- "Why a drag spoke": A Button speaks on lift unless the scroll view takes over the touch.
- "Sideways slides": Owner's call. A sideways slide speaks its phrase; silencing it swallows presses from weak hands.
- "Home's slot plan": Every control has a fixed slot framed by space, profile and text size, never by state or use.
- "The layout engine": Chose one HomeLayout engine turning window, safe areas, profile and text size into frames; it names no device.
- "Home on the engine": Home takes every frame from HomeLayout.
- "Home's scan order and names": Yes, No and Emergency come first for VoiceOver and switches, by fixed region priority.
- "Settings on Home": Settings is the last cell of the categories region.
- "Get Attention and Stop on Home": In the safety row under Emergency, never beside the message; Stop has its own place.
- "One chain engine for dwell safety": Chose one ChainEngine scoring held-activation chains on every screen over per-screen scripts.

## Typing
- "Typing is a state of Home": Chose typing inside Home, safety controls above the keyboard, over a screen that hides them.
- "Typing uses Apple's keyboard": Apple's keyboard for predictions, dictation and accessibility; word buttons wait on device checks.
- "Writing Tools off while typing": Off in every typing field, and no model predicts words, so nothing rewrites the person's words.
- "Third-party keyboards refused in 1.0": Refused, so the keyboard table stays true and typing stays private.
- "Return speaks": Return speaks the whole message as an extra path; in dwell profiles it waits on a device check.
- "The typed message": Speaking keeps the message; Clear undoes once, from memory only; at most 2,000 characters.
- "Typing on Home": Built in the slot plan's places (HomeLayout's typing modes), with no exception to an invariant.

## Settings and setup
- "Get Attention in Settings' bar: the owner decides": Owner's call, open. The place stays empty; scoring showed it would sound unasked.
- "Personal Voice permission is asked at launch, for now": Asked at launch; asking after an explanation waits for onboarding.
- "First launch opens Home; setup lives in Settings": Straight onto Home, never a setup gate; one passive line points family to Settings.
- "Settings is a cover with a fixed safety bar": A full-screen cover under one fixed bar; the root holds one row that only navigates.
- "Settings' first row, placed from Home's frames": So a held look from Home meets a row that only navigates.
- "The first step's own rows": Learn About Each Way sits in the frame just activated; answers start below where a look rests.
- "Speed is a set of fixed choices": Chose seven fixed speeds over Slower and Faster buttons a held look could walk.
- "Settings resets when idle and never closes": After 90 idle seconds it returns to its root and stays open.
- "Setup answers are kept as offered, never as completed": Each answer is kept when chosen; an unreadable record is moved aside, not deleted.
- "Check-ins come every three months": A passive card in Family Setup, never on Home; answered words take its place.

## Stage profiles and release
- "Sizes that follow how the screen is reached": Four profiles of floors and gaps follow the access answer; no control changes relative place.
- "The late-stage profile": Chose Yes/No mode and the rest board as one profile of the layout engine over new screens.
- "Items 8 and 9 come before the first App Review build": Owner's call. Sizes by reach and the late-stage profile ship in that build.
- "Every release passes the quality bar": Owner's call. Every roadmap quality gate passes, with a log record, before App Review; the owner's yes is last.
- "The queued dwell checks run before sound": The queued real-device dwell checks run first, because they settle open design questions.

## Privacy and website
- "The privacy policy ships inside the app": Chose showing the site's policy page in the app, so copies never differ, and the live page in an in-app sheet.
- "The website's accessibility page and the policy's trim": Only what is built and checked; never "works with" before a real-device check.

## Voices
- "Automatic keeps the person's Personal Voice": Once Automatic picks a Personal Voice, no other voice replaces it unasked.
- "A Personal Voice is used only while it is allowed": Used only while access is allowed; the choice is kept and returns with access.
- "The voice list never holds up launch": Read off the main thread and nothing waits for it, so Home draws at once.
- "Voice Settings keeps its places while it is open": Rows keep their places for the visit; a voice that goes keeps its row.
- "Asking for Personal Voice from Voice Settings": One explained button asks once; its answer takes the button's place as passive words.
- "Voice Settings, reached with a held look": Back takes the Family Setup row's frame, so a held look meets no speed choice.
- "Personal Voice is never written to a file": Chose live speech over audio files, which could leave the device.

## Accessibility and look
- "Accessibility API coverage": One row per API in docs/ACCESSIBILITY.md; Assistive Access runs full-screen, never in its own scene.
- "Solid fills on Home, system glass elsewhere": Chose measured solid fills on Home over Liquid Glass, whose contrast cannot be promised.
- "Colour tokens in four appearances": Chose asset-catalog colour sets over code colours, whose provider runs off the main thread.
- "Concentric corners": Chose one CornerRule over computing window radii; Home keeps a fixed 12pt corner until the owner picks.
- "Show Borders and the Large Content Viewer on Home": A 2pt inner border under Show Borders and in dark mode; no Large Content Viewer on Home but Settings' gear, since a slow press then said nothing.
- "Guards for Apple's look": Chose a script refusing app-added glass, PrimitiveButtonStyle and the like over review alone.

## Tests and checks
- "Tests": Swift Testing for unit tests, XCTest only for UI tests, which only it drives; launchedApp turns animations off.
- "A check for code the app must never contain": Chose a script for rules a script can decide over reviewers remembering them.
- "A probe app for the experiments, kept out of Brickson": Chose a separate BricksonProbe target on public API that CI builds.
- "A design review sheet in debug builds": A debug-only sheet rendering the real Palette, so the owner picks colours from real renders.

## Privacy and personal details
- "Personal details stay out of the repository": Chose a local check against an owner-kept list over an outside service; it never prints the words.
- "Avery's decision of 2026-11-08": Avery's name, their brother's first name, Avery's emails and session links may be public; other family and private details stay out.

## Reviews and GitHub
- "Reviews, updates and GitHub settings": The settings live on GitHub; this records what they are meant to be.
- "Code review": Several reviewers, each configured in a file; Copilot once per code pull request; CodeRabbit on request.
- "Dependencies": No packages; actions pinned by commit in a lockfile; grouped monthly Dependabot after a 7-day wait.
- "Code scanning": Chose CodeQL default setup for actions and Python over a Swift scan, which needs a Mac runner.
- "SonarQube Cloud's alerts": Every alert on a pull request is answered before merge, without making it a required check.
- "Security review context": A root SECURITY.md summarising boundaries for reviewers; it adds no accepted risk.
- "`main` ruleset": A pull request, merge commits, "Unit tests" and "UI tests" passing, resolved conversations, no force pushes.

## Instructions for agents
- "AGENTS.md puts first what Codex reads": Chose one rules file under 32 KiB, reasons elsewhere, over nested files cloud threads miss.
- "A one-line index of every decision": Chose this index, which AGENTS.md sends every agent to before deciding, over loading it into every session or reading all of DECISIONS.md.
