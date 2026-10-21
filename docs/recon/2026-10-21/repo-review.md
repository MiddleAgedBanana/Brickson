# Repository review against the owner's goal, 2026-10-21

> **Research, not instructions.** Written on 2026-10-21 by three reviewers working for the "Roadmap, decisions and repo review" thread, reading the repository at `f88766e` (two documentation commits after `main` at `9362eca`) and open PR #12. A second, adversarial pass that was meant to check each finding did not run (a usage limit stopped it), so every finding here is **unverified**: the owning work checks it before acting. Where a finding asks the owner to decide, `docs/DECISIONS.md` now records the decision made by default on 2026-10-21 or lists it under *Waiting on the owner*. Two more areas, Apple's design guidelines with Liquid Glass and the accessibility APIs, were not reviewed here; the second is the "Accessibility API coverage" work.

## Summaries

### Layouts keyed to devices

The shipped code is mostly clean. The only Swift that chooses layout from the environment is HomeView's column count, which reads the size class. That is Apple's own signal, but it moves tiles whenever a window crosses the size-class boundary. The device-keyed problems are in three places. First, the rules: AGENTS.md says target floors are "computed in physical size per device", and the portrait-only iPhone decision is pinned by AppBundleTests. Second, the plans: the layout blueprint keys density, which profiles are offered, window class and keyboard height to device tables. It cuts off SE-class phones, does not offer gaze on any phone, and was written five weeks after iPhone Duo was announced without mentioning it. The typing study sizes one band for every screen from a single worst-case iPad. Third, the porting list says to bring over reference code that checks for an iPad (userInterfaceIdiom), as if it needed no changes. Apple's current pages argue against all of this. WWDC26 session 278 says idiom is "no longer meaningful for any kind of layout decision" and that orientation is "a preference... ignored when your app is running in a resizable environment". The HIG Layout page (updated 2026-09-09) says "Determine layout based on size classes, not device type or orientation" and no longer has device-size tables. The iPhone Duo guidance says "Avoid fixed widths, breakpoints, or any metrics tied to a specific screen" and "prefer an even number of columns". Its fold APIs, ReservedRegion and ArrangementView, need iOS 27.1. From April 2027, every submission needs iPhone Duo screenshots. Test matrices, dated measurement records and point-based floors are acceptable and listed separately. The central decision for the owner is how to keep target floors physical without a device table. I propose fixed point values per profile, with three options and numbers in device-2. Verified on Apple's .md pages, Apple's developer releases and news feeds, the nonstrict.eu WWDC transcript and apple.com, all on 2026-10-21. Context7 needed sign-in and the GitHub tool failed to connect, so neither was used. Not verified: whether a portrait-only app gets landscape windows on iPhone Duo, whether the minimum window size holds in iPhone Duo split view, Slide Over or iPhone Mirroring, and how Eye Tracking behaves on external displays. The branch moved from 9362eca to f88766e during this review, and the research files were being edited at the same time, so their line numbers are as read on 2026-10-21. Nothing was edited.

### App Store and ASO gaps

Brickson cannot be submitted to the App Store yet. There are hard blockers in four areas. (1) Identity: there is no developer team, and the bundle ID, which can never change, is still undecided. (2) Missing pieces: the app has no Privacy row, which guideline 5.1.1(i) requires; its icon is a placeholder that looks like Messages; there are no screenshots and no pipeline to make them; the store text, App Review notes and age-rating answers are not written. (3) Accuracy: the privacy policy, README and support page describe features that are not built, or say "in development". (4) Readiness: Home is a stand-in, nothing has run on a real device, and the phone layout is broken at the default text size. Guidelines 2.1(a), 2.3 and 4.2 all apply.

Apple has also changed some requirements recently. I checked these on Apple's pages on 2026-10-21; the guidelines page was last updated 2026-10-16:
- The required iPhone screenshot size is now the medium Dynamic Island display (iPhone 17: 1206×2622), plus the iPad 13-inch (2064×2752).
- iPhone Duo screenshots become mandatory in April 2027 for apps built with the iOS 27.1 SDK or later. Xcode 27.1 is already released, so PR #12's newest-Xcode rule triggers this. Apple also warns that fixed orientations and size assumptions break layouts on iPhone Duo.
- From April 2027, uploads must be built with the iOS 27 SDK or later.
- The age-rating questionnaire is new: an in-app browser counts as "Unrestricted Web Access", which rates 16+.
- A Regulated Medical Device declaration is required if the category is Medical or Health & Fitness.
- EU trader status (Digital Services Act) is required to stay on the EU store, and individual traders must publish an address.
- iPhone and iPad apps are published on Mac and Vision Pro by default unless opted out in App Store Connect.
- Accessibility Nutrition Labels are voluntary now and will become mandatory. They also boost search relevance, and Brickson can claim several of them once each claim has logged evidence.
- New guidelines 2.3.14 (creative assets) and 2.5.19 (no hidden features) apply to the store art and to test-only launch options.

What is already correct: the privacy manifest (UserDefaults CA92.1, nothing collected), the export-compliance key, the launch screen and background audio. Each of these needs a test pin or a re-check when planned features land (microphone, calls, backups, keyboard detection).

Not verified:
- Context7 was not used; it needs authorization, so every Apple fact came from Apple's own pages, fetched directly.
- Whether App Intents (Siri and Shortcuts) needs NSSiriUsageDescription. Apple documents that key only for SiriKit.
- Whether the SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD build setting has any effect on store availability.
- Whether simulator screenshots contain an alpha channel, which App Store Connect rejects.
- The exact syntax of the xcresulttool and simctl commands.
- How Apple indexes keywords from secondary localizations.

### The way of working (SDLC playbook)

I read the whole 54-page playbook and compared it with the repository: branch claude/project-thread-9b2zvk at f88766e, which is two commits ahead of main 9362eca and not identical to it, plus the untracked docs/ROADMAP.md and HANDOFF.md edits in progress. I also used GitHub's REST API (read only) and Claude Code's and Apple's current documentation.

Brickson already does much of the playbook well:
- One shared briefing (AGENTS.md, loaded through CLAUDE.md).
- Binding decisions (DECISIONS.md) and lessons (LESSONS.md).
- Test-first rules, and CI on every pull request.
- Codex, Copilot, AI Scan and CodeQL reviews against written Code Review Rules.
- A main ruleset, and a website pipeline with its own gate.
- Dependabot, plus PR #12's Xcode check.
- One log file per pull request.

What is missing is the committed chain around the code:
- No intent home and no issue forms (the API shows no issues at all, only pull requests).
- No per-change spec or plan before the code.
- No verification block, verifier subagent, CI artifacts, evals, release or TestFlight runbook, incident record, or Maintain loop.

Two structural risks matter most:
- **Hooks would not run.** This session clones both Brickson and the reference app and starts above them. Claude Code's docs say such sessions ignore a repository's hooks and permission rules. They also load the reference app's 63 KB briefing, whose rules conflict with Brickson's.
- **Nothing enforces the owner's merge.** Agents act under the owner's GitHub account, the ruleset requires 0 approvals, and the admin bypass applies.

Ten threads now feed one beginner reviewer. The playbook advises two or three sessions, adding more only while review keeps up.

Corrections to the task's inputs: PR #12's head is 4198e94, and the owner already committed tests.yml (a16838f); the local ref is stale at 809a333. HANDOFF, ROADMAP and README cite docs/SDLC.md and a *Proposed decisions* section that do not exist yet.

The 12-page "2026 Swift Open-Source Ecosystem Report" changes no recommendation. It is an unsourced list of third-party libraries, and the ones it promotes for process (Fastlane, swift-snapshot-testing, Tuist, Komondor git hooks, KeychainAccess, DeviceKit) are excluded here by invariant 9, the no-Keychain rule and the owner's rule against layouts keyed to device models. The playbook's own hooks, Apple-only tests and the owner's App Store Connect upload cover the same needs.

## Findings by owner

### Owner

#### device-2: (b) Needs change, owner decision: 'Target floors are physical ... computed in physical size per device' contradicts the new layout principle

*High. Release: R1 (decision needed before the engine).*

AGENTS.md's design rule asks for floors computed in physical size per device. Doing that needs a device or density table (device-1), because iOS reports no physical density. The rule's intent is sound: a gaze or head pointer needs a fixed visual angle, roughly 2.7 degrees at 45 cm for a gaze tile, about 21 mm. Apple's own target rule is one number in points on every iOS device (44×44 pt, 28×28 minimum), and Apple accepts that a point's physical size varies. Reconciliation for the owner, using the blueprint's proposed angles and distances (hand arithmetic from published ppi, not measured). (A) Floors in points that hold on the densest supported screen, about 165 pt/in on the iPhone 12/13 mini (163 on the iPad mini and SE): gaze 139/113/92 pt (tile/quick/category), head 131/108/91, touch 80/72/60/48. They need no table and hold physically everywhere. Cost: about 25% larger than needed on 132 pt/in iPads. By the blueprint's own arithmetic, the gaze starter library on 11-inch iPads in landscape goes from 80-94 pt spare to about zero (+27, +22 and +18 pt per region), so the engine must measure it. Display Zoom gives no relief: a zoomed point is physically bigger, so fewer targets fit. (B) The reference's numbers in points at 132 pt/in, the density of every non-mini iPad (blueprint: 111/90/74). They match what the reference shipped and Apple's convention. Cost: on an iPad mini or a phone a gaze tile is about 17 mm instead of 21 mm. (C) A or B, plus a zoom correction from the system's own scale values (the screen's nativeScale divided by displayScale). It names no device, but it needs a screen reference Apple now discourages, and nobody has checked what it reports in iPhone Mirroring or on an external display. The reference repository's briefing (private, commit 6a22c1a) records that its gaze numbers were tuned on a 264-ppi 13-inch iPad, which answers the blueprint's calibration question 10.

**Recommendation.** Owner chooses one option, with the engine's printed fit table in front of them (blueprint commit 7). Recommended: A for the pointer profiles (gaze and head), where a physically small target causes misfires the person cannot undo; B for touch, keyboard and voice, and switch, which are Apple's convention and fit phones. In every option, add a 'Larger targets' step the person or family chooses in the profile. It changes sizes only, never positions, and is never set automatically. Then rewrite the rule as: 'Target floors are points per profile and role, chosen so each keeps its visual angle on the densest supported screen [or: at the reference density]; never computed from the device.' Record the choice and its cost in docs/DECISIONS.md. The Roadmap thread drafts the text, and the owner approves it, because it changes a rule reviewers enforce.

**Evidence.**

- AGENTS.md:232-235 ('Target floors are physical. Each profile sets its floors from viewing distance and visual angle, computed in physical size per device. For gaze at about 45 cm the reference used phrase tiles of at least 110pt...')
- docs/recon/2026-10-15/layout-blueprint.md:134-159 (angles, distances; points per device table: iPad 111/90/74, iPhone 17 129/105/86, SE touch 79/71/59/48)
- docs/recon/2026-10-15/layout-blueprint.md:127 (iPhone 12/13 mini nativeScale 2.88, 6.51 pt/mm, the densest row)
- docs/recon/2026-10-15/layout-blueprint.md:161 and :564 (calibration device unconfirmed)
- docs/recon/2026-10-15/layout-blueprint.md:29-32 and :438-450 (fit by floor reading; 11-inch landscape spare 94 and 80 pt at reference floors)
- docs/ROADMAP.md:90-94 (roadmap already flags the device table and points to a proposed decision 'Target sizes without a device table', which docs/DECISIONS.md does not contain yet)
- https://developer.apple.com/design/human-interface-guidelines/accessibility.md (iOS, iPadOS: default 44x44 pt, minimum 28x28 pt)
- https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo.md ('steer clear of fixed widths or anything tied to a specific display')

#### device-3: (b) Needs change, owner decision: the portrait-only iPhone and the ~ipad orientation split

*High. Release: R1 (decision with the slot layout); before 1.0 at the latest.*

project.yml and Info.plist lock the iPhone to portrait and use the device-specific key UISupportedInterfaceOrientations~ipad to give the iPad all four orientations. AppBundleTests pins both. DECISIONS.md records the reason: the reference's phone layout lost Emergency off screen in landscape. Under iOS 27 the lock no longer guarantees a portrait-shaped window. Apple says supported orientations are 'a preference provided to the system' that is 'ignored when your app is running in a resizable environment'. In iPhone Mirroring the app 'will always be running in the portrait interface orientation, regardless of the aspect ratio'. TN3192 lists 'Supports all interface orientations' among the requirements for resizable scenes. iPhone Duo has landscape poses and side-by-side apps. So a phone layout that loses Emergency in a wide, short window is still reachable. The lock hides the invariant-2 risk instead of removing it. Not verified: whether a portrait-only app gets landscape windows on iPhone Duo. The recon's claim that all orientations 'will soon be required' comes from a beta console message; I found no Apple page that says it.

**Recommendation.** Owner decides. Recommended: declare all orientations in a single UISupportedInterfaceOrientations list for every device and drop the ~ipad split. Make the layout engine's job explicit: safety controls must stay visible in any window aspect, at any text size, on any device. Test that with wide, short windows in the matrix, not with the lock. If the owner keeps portrait for now, rewrite DECISIONS 'Orientations' so it no longer says the lock protects the layout. The engine must still pass its landscape rows on the phone, because iPhone Mirroring and iPhone Duo can produce them. AppBundleTests changes in the same pull request as the decision.

**Evidence.**

- project.yml:76-84 (iPhone portrait only; ~ipad all four)
- Brickson/Info.plist:40-50
- BricksonTests/AppBundleTests.swift:68-83 (theIPhoneIsPortraitOnly, theIPadKeepsAllFourOrientations)
- docs/DECISIONS.md:153-161 ('Orientations': portrait for now, revisit with the layout engine)
- docs/recon/2026-10-15/layout-blueprint.md:431 and :559 (iPhone landscape kept as engine-only rows; recommends staying portrait only)
- docs/recon/2026-10-15/apple-platform.md:106 and README.md:332-334, :698
- docs/ROADMAP.md:98-100
- https://nonstrict.eu/wwdcindex/wwdc2026/278/ ('In iOS 27, an app's supported interface orientation is a preference provided to the system. It will be ignored when your app is running in a resizable environment. You should not consider interface orientation for any layout calculations.')
- https://developer.apple.com/documentation/technotes/tn3192-migrating-your-app-from-the-deprecated-uirequiresfullscreen-key.md (rev. 2026-10-09: resizable scenes require 'Supports all interface orientations'; the system drops portraitUpsideDown on iPhones without a Home button whatever the app declares)
- https://developer.apple.com/design/human-interface-guidelines/layout.md ('Even if your app is locked to a certain orientation ... it's still important to ensure your interface resizes well')

#### device-10: (b) Needs change, owner decision: the rulebook does not yet state the layout principle, and some rules assume a fixed set of devices

*Medium. Release: Now (rulebook).*

The owner's 2026-10-21 principle ('available space and system-managed layouts ... never by identifying individual device configurations') is in docs/ROADMAP.md but not in AGENTS.md, which reviewers enforce. The Code Review Rules have no check for layout or behaviour keyed to userInterfaceIdiom, UIDevice, interface orientation, UIScreen bounds or a device table, so Codex and Copilot would not flag a regression. Invariant 11 promises no scrolling 'on any supported device and window'. That cannot hold at arbitrary window sizes: Slide Over, Duo split halves and iPhone Mirroring windows can be smaller than the safety controls need, and the minimum window is only a preference. 'Run it, don't just read it' names only 'an iPad and an iPhone simulator', with no resized windows or poses. 'Say what each result was measured on' lacks window size and pose.

**Recommendation.** The Roadmap thread drafts and the owner approves three changes. (1) A design rule: 'Lay out from the space you are given: container size, safe areas, reserved regions and Dynamic Type; size classes only as hints; never userInterfaceIdiom, the device model, interface orientation, UIScreen bounds or a device table.' (2) A review rule under 'Dwell and gaze safety' that flags exactly those. Mirror it in .github/skills/code-review/SKILL.md if needed. (3) Invariant 11 reworded to 'in every window at or above the engine's minimum size; below it the safety controls stay visible and only the phrase grid scrolls'. This is a recorded exception, so it is the owner's call. Also extend 'Run it' with resized windows (Device Hub resize mode) and iPhone Duo poses, and extend 'Say what each result was measured on' with window size, pose and display.

**Evidence.**

- AGENTS.md:183-187 (invariant 11 'on any supported device and window')
- AGENTS.md:232-235 (physical floors per device, see device-2)
- AGENTS.md:374-381 ('Run it' and 'Say what each result was measured on')
- AGENTS.md *Code Review Rules*, 'Dwell and gaze safety' (:286-295): no idiom, orientation or screen rule
- docs/ROADMAP.md:19-25 (the owner's goal, including the layout principle)
- https://developer.apple.com/design/human-interface-guidelines/layout.md ('Determine layout based on size classes, not device type or orientation')
- https://nonstrict.eu/wwdcindex/wwdc2026/278/ ('Stop checking the user interface idiom for any layout decisions in your code ... If you need finer control, use the surrounding view's size')

#### appstore-4: No developer team, and the permanent bundle ID is undecided, so nothing can be uploaded

*High. *

DEVELOPMENT_TEAM is empty, so there are no device builds, no TestFlight and no upload. Apple says the bundle ID 'can't change after you upload a build'. The current ID contains the owner's first name and is public, outside the recorded exception for personal names. The account type decides several things:
- Individual accounts show the person's legal name as the seller. Only company accounts can set a developer name.
- An organization account needs a legal entity, and it changes the policy's 'we'.
- Guideline 5.1.1(ix) says apps 'in highly regulated fields (such as ... healthcare ...) or that require sensitive user information should be submitted by a legal entity ... not by an individual developer'. Brickson provides no healthcare service and collects nothing, so the store text and review notes should say so. Store text that frames the app as treatment invites this rule.
The Account Holder must sign the latest agreement before any app record can be created.

**Recommendation.** Decide the account type, individual or organization. Then choose a bundle ID without a personal name before the first upload, ideally the reverse-DNS form of a domain you control. Put the Team ID in project.yml and register the App ID. Record all three in DECISIONS.md, 'App identity', and update the policy's 'Who we are' if an organization is chosen.

**Evidence.**

- project.yml:25-26 (APP_BUNDLE_ID, DEVELOPMENT_TEAM: "")
- docs/DECISIONS.md:22-23 (bundle ID permanent after first upload; team empty)
- https://developer.apple.com/help/app-store-connect/reference/app-information/app-information ('You can't change this property after you upload a build')
- https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app (Account Holder signs the latest agreement; developer name only for companies)
- https://developer.apple.com/app-store/review/guidelines/ 5.1.1(ix)
- site/privacy/index.html:44 ("we" = the individual developer)
- docs/recon/2026-10-15/README.md:685-686 (account and bundle ID decisions)
- docs/NAME_AVAILABILITY.md:13 (brickson.app had no registry record on 2026-10-12)
- docs/GETTING_STARTED.md:69-100 (team setup; free installs expire in 7 days)

#### appstore-10: The category is undecided, and it decides whether a Regulated Medical Device declaration and guideline 1.4.1 scrutiny apply

*Medium. *

Apple's category definitions:
- Medical: 'medical education, information management, or health reference'.
- Education includes 'special education'.
- Utilities: 'solve a problem or complete a specific task'.
The primary and secondary categories are indexed by search, so this is an ASO decision too. Choosing Medical or Health & Fitness, or answering 'frequent' medical information, requires a Regulated Medical Device declaration for the EU, UK and US; the answer would be No. Guideline 1.4.1 gives 'greater scrutiny' to apps that 'could be used for diagnosing or treating patients'. Guideline 1.4 covers physical harm, and Brickson's Emergency phrases make sound only. Store text must never suggest that Emergency contacts emergency services or that the app treats anything.

**Recommendation.** Choose the primary and secondary categories using the ASO thread's evidence. If Medical or Health & Fitness is chosen, declare 'not a regulated medical device' in every region. Record the choice in DECISIONS.md. Make the description and review notes say plainly that Emergency and Get Attention make sound and never call anyone.

**Evidence.**

- https://developer.apple.com/app-store/categories/ (Medical, Education, Utilities, Productivity definitions)
- https://developer.apple.com/help/app-store-connect/manage-app-information/declare-regulated-medical-device-status
- https://developer.apple.com/help/app-store-connect/reference/app-information/app-information (Regulated Medical Devices row)
- https://developer.apple.com/app-store/search/ (primary and secondary category indexed)
- https://developer.apple.com/app-store/review/guidelines/ 1.4, 1.4.1, 2.3.5
- site/privacy/index.html:111 ('They never call emergency services')
- docs/recon/2026-10-15/README.md:713 (recon: Utilities or Education, not Medical)

#### appstore-13: EU Digital Services Act trader status is undecided; without it the app is not distributed in the EU

*Medium. *

Since 2025-02-17, apps without a declared and verified trader status are removed from the EU App Store. Every developer must declare a status, even one that does not distribute in the EU. An individual who is a trader must give an address or P.O. box, a phone number and an email, and Apple shows them on EU product pages. Apple's trader factors include revenue from the app, commercial practices, VAT registration and acting in a professional capacity; a hobbyist with no commercial intent may not be a trader. The price is undecided, and that affects this answer. The policy already addresses EU and UK users (GDPR).

**Recommendation.** Decide trader status, with legal advice if unsure, before the first submission. If you are a trader, consider a P.O. box and a dedicated phone number and email rather than a home address. Record the decision (not the address) in DECISIONS.md.

**Evidence.**

- https://developer.apple.com/news/upcoming-requirements/ ('DSA trader status required for apps in the EU', since February 17, 2025)
- https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements
- docs/DECISIONS.md:84-94 ('Price not decided')
- site/privacy/index.html:97-99 (GDPR rights)

#### appstore-14: The app will appear on the Mac and Vision Pro stores unless that is switched off in App Store Connect

*Medium. *

The owner's goal is iPhone and iPad, not macOS. Apple's submitting page says 'by default, your compatible apps are published automatically on the App Store for Apple Vision Pro or Mac'. Opting out is a checkbox in Pricing and Availability for each platform. DECISIONS says Mac and Vision Pro are 'switched off', but that refers only to Xcode build settings. Apple's pages say store availability is set in App Store Connect, and I found nothing saying those build settings opt out. Storefront choices also matter: for example, the China mainland can require extra filings.

**Recommendation.** In App Store Connect, under Pricing and Availability, deselect 'Make this app available' for Apple silicon Macs and for Apple Vision Pro before the first release. Choose the storefronts. Change DECISIONS.md to say where the switch actually lives.

**Evidence.**

- https://developer.apple.com/app-store/submitting/ ('By default, your compatible apps are published automatically on the App Store for Apple Vision Pro or Mac')
- https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/manage-availability-of-iphone-and-ipad-apps-on-macs-with-apple-silicon
- https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/manage-availability-of-iphone-and-ipad-apps-on-apple-vision-pro
- project.yml:39-40 (SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD / SUPPORTS_XR_... NO)
- docs/DECISIONS.md:62-69
- https://developer.apple.com/help/app-store-connect/reference/app-information/app-information (Availability in China mainland)

#### appstore-21: The App Store Connect record is not created; its fixed fields are undecided

*Medium. *

Creating the record needs a registered bundle ID, the store name, a primary language, a SKU (which can never change and should not identify anyone), and user access. Before submission it also needs a privacy policy URL, the Copyright line ('year + owner'), Content Rights, App Review contact details including a phone number, and the age rating. A store name can be used by only one app per localization, so creating the record early holds the name. DECISIONS keeps the name Brickson, but NAME_AVAILABILITY says it must be confirmed in the intended account. The store name (up to 30 characters) can carry more than the name under the icon; the ASO thread drafts it.

**Recommendation.** Once the account and bundle ID are settled (appstore-4), create the record. Use the ASO thread's name and subtitle and a neutral SKU such as 'brickson-ios'. Answer Content Rights: the starter phrases and icon are original, the voices come from the OS, and the symbols are SF Symbols. Note the app's Apple ID for the review link.

**Evidence.**

- https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app ('You can use an app name for one app per localization')
- https://developer.apple.com/help/app-store-connect/reference/app-information/app-information (Name, SKU, Content Rights, Primary Language)
- https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information (Copyright required; review contact)
- docs/NAME_AVAILABILITY.md:47-51
- docs/DECISIONS.md:36-50

#### appstore-30: Several App Store Connect steps wait on the undecided price

*Low. *

Submission needs Pricing and Availability set, the Digital Goods and Services questionnaire answered where it appears, and the agreements the business model needs. Apple says the questionnaire's EU answers 'remain locked for 12 months' once submitted. DECISIONS forbids stating any price until the owner decides, and guideline 2.3.7 bars pricing in names, subtitles and screenshots.

**Recommendation.** Decide the business model before the first submission and record it in DECISIONS.md. Until then, keep every file silent on price. Answer the Digital Goods questionnaire only after deciding, because the EU answers lock.

**Evidence.**

- docs/DECISIONS.md:84-94 ('Price not decided')
- https://developer.apple.com/help/app-store-connect/manage-app-information/complete-the-digital-goods-and-services-questionnaire (EU choices locked 12 months)
- https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app (agreements)
- https://developer.apple.com/app-store/review/guidelines/ 2.3.7

#### sdlc-5: Build: sessions clone two repositories, so committed hooks and permission rules would not run, and two conflicting briefings load

*High. Release: R0.*

This session, spawned by the Roadmap thread, runs at the cloud session's home folder, above two clones: brickson and ALS-app, the private reference app. Its project folder is -home-user, and the Brickson working directory reports 'Is a git repository: false'.

Claude Code's current documentation says an Anthropic-hosted session with several repositories reads only enabledPlugins and extraKnownMarketplaces from each repository's .claude/settings.json, 'not permission rules, hooks, env, or other keys'. A session with one repository reads the hooks and permissions. So every hook and permission recommendation below (sdlc-6, sdlc-7, sdlc-12) does nothing until the environment changes.

Both CLAUDE.md files also load: Brickson's AGENTS.md (30 KB, about 4,600 words) and the reference app's (63 KB, about 9,100 words). The reference app's rules contradict Brickson's:
- 'A single-task commit may go straight onto main', against Brickson's 'never push to main'.
- 'Push only when the owner asks'.
- 'This app never ships to the App Store', where Brickson is App Store bound.
- One user, with Eye Tracking as the primary input.

The playbook asks for a CLAUDE.md under a page, because stale text costs context every session (p.23). The reference clone also has a push URL, while Brickson's rule is reference only.

Not verified: whether every Brickson thread uses this same two-repository environment.

**Recommendation.** In claude.ai's cloud environment settings, give the Brickson project an environment that clones only the Brickson repository. Add the reference repository only for a thread that is porting code, and have that thread read the files it needs; LESSONS.md carries the reference app's rules otherwise.

Until then, add one line to AGENTS.md: 'If the reference app's AGENTS.md is also loaded, it describes a different app; Brickson's rules win wherever they differ.'

To confirm the change worked, commit a harmless SessionStart hook that prints the HANDOFF 'State as of' line, and check that a new thread shows it.

**Evidence.**

- ls the cloud session's home folder: ALS-app, brickson; this session's paths are under the session's own folder 
- https://code.claude.com/docs/en/settings.md, 'Settings in cloud sessions' (read 2026-10-21): several-repository sessions read only enabledPlugins and extraKnownMarketplaces
- https://code.claude.com/docs/en/cloud-environments.md, 'What carries over from your setup': hooks and permission rules 'Yes, in a session with one repository'
- wc: brickson/AGENTS.md 30,438 bytes; ALS-app/AGENTS.md 63,387 bytes
- ALS-app AGENTS.md: 'a single-task commit may go straight onto main'; 'this app never ships to the App Store'
- AGENTS.md:60-63 (reference only, never push); docs/PORTING.md:4-6 (without access, docs/LESSONS.md carries its rules)
- Playbook p.23 step 5

#### sdlc-7: Deploy: the owner's merge is the only human gate, and nothing technical stops an agent from merging

*High. Release: R0.*

The playbook's governing principle is that the agent may act up to the production gate and cannot pass it. It rests on separation of duties: the agent that wrote the code cannot approve it, and each run acts under the agent's own identity (pp.39, 46).

In Brickson:
- Every agent pull request is authored by the owner's GitHub account. The API shows that author on #1 to #6 and #8 to #12; agents' review replies on PR #12 appear as the owner too.
- The ruleset therefore requires 0 approvals, because the owner cannot approve their own pull requests.
- The repository admin may bypass the rules for pull requests.
- 'The owner merges' is a sentence in AGENTS.md.

An agent holding the owner's token could merge a green pull request after resolving its conversations, or, through the bypass, a red one. This was not tested; the task was read only. The gh error text in this session even lists auto-merge and resolve-thread routes.

For the website, the merge is also the deploy: pages.yml publishes on push to main.

**Recommendation.** Do this now: sdlc-6's deny rules and Bash guard for merge, auto-merge, approve and bypass actions, which need sdlc-5 first.

Add a rule to AGENTS.md's *Code Review Rules*: a pull request whose merge event was not made by the owner in person is an incident (sdlc-20).

Later, if agents get their own GitHub identity (for example, a GitHub App), set the ruleset to require one approval from the owner and keep the bypass for real emergencies. Record the choice in DECISIONS.md, 'main ruleset'.

**Evidence.**

- GET /repos/MiddleAgedBanana/Brickson/pulls/{1..12}: user.login is the owner's account except #7 (dependabot); PR #12 reviews list
- docs/DECISIONS.md:303-305 (owner appears as author of every agent PR), 408 (0 approvals), 415 (admin bypass for pull requests)
- AGENTS.md:398-401 ('The owner merges')
- gh CLI 403 message (2026-10-21) listing /pulls/{n}/ccr/auto_merge and resolve routes
- Playbook p.39 (separation of duties), p.46 ('acts under the agent's own identity'; 'cannot pass it')
- .github/workflows/pages.yml:14-20 (publishes on push to main)

#### sdlc-22: Maintain: the privacy policy's retention promises have no process

*Medium. Release: R0.*

The privacy policy, which AGENTS.md calls a promise App Review and privacy law hold the app to, commits the developer to:
- deleting TestFlight feedback and screenshots within one year;
- removing testers' names and email addresses when they leave the test;
- deleting support emails within one year after the conversation ends, or sooner on request;
- honouring access, correction and deletion requests.

No runbook, reminder or record exists. These duties start with the first external TestFlight tester or support email.

**Recommendation.** Add a 'Privacy duties' checklist to the release runbook and docs/MAINTAIN.md:
- every quarter, delete TestFlight feedback and screenshots older than 11 months in App Store Connect, and remove testers who left;
- every quarter, delete support emails whose conversation ended more than 11 months ago;
- answer rights requests within the time the law sets; the App Store readiness thread checks the exact period.

The owner can create a quarterly scheduled reminder. Agents only draft the checklist and never see the data.

**Evidence.**

- site/privacy/index.html:93 (TestFlight retention), 95 (support email retention), 97-98 (rights requests)
- AGENTS.md:192-199 (the privacy policy is a promise)
- docs/ROADMAP.md:72 (TestFlight to a small group in R0)

### Toolchain and iOS version targets

#### device-13: (b) Needs change: the minimum-iOS decision assumes Eye Tracking is iPad-only and ignores the iOS 27.1 fold APIs

*Low. Release: Now (with the minimum-iOS decision).*

DECISIONS 'Minimum iOS 26, iPhone and iPad' justifies its choice with 'Eye Tracking needs a recent iPad anyway'. PR #12 renames the section but keeps the sentence. Eye Tracking also runs on iPhone; the recon lists iPhone 12 and later, and Apple lists it on iPhone Duo. The fold APIs, ReservedRegion and ArrangementView, need iOS 27.1. Apple says apps must be built with Xcode 27.1, and that apps built with Xcode 26 'don't extend under the status bar and camera' on iPhone Duo. CI on main still builds with Xcode 26.6; PR #12 moves it to the newest Xcode. The minimum iOS stays 26.0 until the owner decides.

**Recommendation.** When the owner decides the minimum iOS, correct the sentence (Eye Tracking is on iPhone and iPad). Note that reserved regions and arrangement views need iOS 27.1, so with a 26.0 minimum they come behind if #available(iOS 27.1, *) (every iPhone Duo runs 27.1 or later). Note too that building with the newest Xcode, which PR #12 does, is what lets the app use the whole iPhone Duo display.

**Evidence.**

- docs/DECISIONS.md:62-69 ('Eye Tracking needs a recent iPad anyway')
- git diff main...origin/claude/project-thread-rre1no -- docs/DECISIONS.md (sentence retained under 'Minimum iOS, iPhone and iPad'; decision open)
- docs/HANDOFF.md:26-31 (CI on main: Xcode 26.6, iOS 26.5)
- docs/recon/2026-10-15/als-aac-research.md:107 (Eye Tracking device list includes iPhones)
- https://www.apple.com/iphone-duo/specs/ (Eye Tracking listed)
- https://developer.apple.com/documentation/swiftui/reservedregion.md and https://developer.apple.com/documentation/swiftui/arrangementview.md (iOS 27.1+)
- https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo.md ('When you build with Xcode 26 and earlier, your app doesn't extend under the status bar and camera')
- https://developer.apple.com/news/releases/rss/releases.rss (Xcode 27.1 27A9275 released 2026-10-15; Xcode 27.2 RC 2026-10-19)

#### appstore-17: No rule for version and build numbers, and no documented archive and upload path

*Medium. *

MARKETING_VERSION is 0.1.0 and CURRENT_PROJECT_VERSION is a fixed '1'. Each upload is identified by bundle ID, version and build string, so every upload needs a new build number. AppBundleTests checks only that the numbers are not empty. A 0.x version on the store reads as a beta, and guideline 2.2 says betas belong in TestFlight. scripts/test.sh can build for a device but cannot archive or export. Uploads must be built with Xcode 26 or later now, and from April 2027 with the iOS 27 SDK and a deployment target of iOS 15 or later; Brickson's 26.0 passes. Apple supports uploading from Xcode, Transporter, altool or the API, and credentials must never be committed.

**Recommendation.** Ship 1.0.0 as the first store version. Write down how the build number goes up: bumped in project.yml in each release pull request, or passed on the archive command line. Add a check that it increases. Document the owner's upload route, either Xcode Organizer or `xcodebuild archive` plus `-exportArchive` with an app-store-connect export options file, using the same released Xcode as CI. Keep dSYMs for crash reports.

**Evidence.**

- project.yml:27-28
- BricksonTests/AppBundleTests.swift:51-57
- scripts/test.sh:107 (device build only)
- https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds (bundle ID + version + build string; Xcode/Transporter/altool; supported Xcode 26 or later)
- https://developer.apple.com/app-store/submitting/ (April 2027: iOS & iPadOS 27 SDK, target iOS 15 or later)
- https://developer.apple.com/news/upcoming-requirements/ (SDK minimum since April 28, 2026)
- https://developer.apple.com/app-store/review/guidelines/ 2.2

#### sdlc-23: Maintain: the toolchain check and Dependabot are deterministic detectors, but their warnings do not become work

*Low. Release: All the time.*

PR #12's scripts/select-xcode.py check compares the Xcode in use with Apple's releases feed and warns rather than fails. That is a deterministic detector with no model involved, as p.49 asks.

But the warning appears only on pull request and push runs of the Unit tests job. No scheduled run exists: tests.yml triggers on pull_request, push to main and workflow_dispatch. Nothing turns a warning into an intent or a pull request.

Dependabot's monthly grouped update and the CodeQL 'Revisit when' conditions in DECISIONS.md are the same kind of detector, also without an owner or due date.

Apple's requirement, quoted in PR #12, that uploads from April 2027 use the iOS 27 SDK is a dated band too.

**Recommendation.** Make the sweep in sdlc-21 also run select-xcode.py check. When Apple's newest release is ahead of the Xcode on GitHub's image or in the project, it opens a toolchain intent.

List Dependabot's monthly pull request and the CodeQL revisit conditions in docs/MAINTAIN.md, each with an owner.

If the owner prefers GitHub to run it, a weekly schedule trigger on tests.yml is the owner's workflow commit. Keep the job names unchanged, because they are required checks.

**Evidence.**

- PR #12 head 4198e94 .github/workflows/tests.yml:16-20 (triggers), 47-48 ('Compare with Apple's newest Xcode release')
- PR #12 docs/DECISIONS.md 'Build with Apple's current Xcode' (warns, never fails; April 2027 SDK requirement, quoted from Apple's submitting page by that thread, not re-checked here)
- docs/DECISIONS.md:307-319 (Dependabot monthly), 390-399 (CodeQL revisit conditions)
- Playbook p.49 steps 2-4

### Test seams and CI evidence

#### device-11: (b) Needs change: the test matrix is one iPad Pro 13-inch, with no iPhone, resized windows or iPhone Duo

*Medium. Release: R0.*

Testing on a named device is acceptable in itself. But scripts/test.sh, PR #12's version of it, and CI all prefer one device ('iPad Pro 13-inch'), and DECISIONS records that 'CI tests the iPad only'. The typing study notes the iPhone keyboard table can only be checked locally. LESSONS asks for a matrix of 'every Display Zoom variant, both orientations, each multitasking mode'. It should name window shapes instead of devices, and add iPhone Duo poses, iPhone Mirroring sizes, external displays and Slide Over. Xcode 27's Device Hub has a resize mode for checking arbitrary sizes, and Apple recommends testing the largest and smallest layouts. The simulator picker matches on display names, so on a Mac whose simulators have been renamed it finds no iPad.

**Recommendation.** Keep a default simulator, but choose it by device type identifier, not display name. Add the planned iPhone UI job as a new job so the required check names stay the same. Make the engine's unit matrix the main source of coverage: it covers window sizes and aspects, including very narrow, very wide and short, Duo outer and inner, folded, Slide Over and below-minimum windows, with no device names in the engine's inputs. Add an iPhone Duo simulator run when CI's Xcode has one (Xcode 27.1+). Rename the LESSONS heading 'window matrix', and list iPhone Mirroring and external displays as manual checks.

**Evidence.**

- scripts/test.sh:10-13 and :27-49 (rank prefers name.startswith('iPad Pro 13-inch'))
- git diff main...origin/claude/project-thread-rre1no -- scripts/test.sh (PR #12 keeps the iPad Pro 13-inch preference)
- .github/workflows/tests.yml:4-5
- docs/DECISIONS.md:223-224 ('CI tests the iPad only')
- docs/recon/2026-10-15/directions/typing.md:69
- docs/LESSONS.md:194-205 ('The device matrix must include the real windows')
- docs/recon/2026-10-15/tests-ci-audit.md:67 (custom-named simulators defeat name matching)
- https://nonstrict.eu/wwdcindex/wwdc2026/278/ ('In the new Device Hub app as well as in Xcode Previews, click the "enter resize mode" icon')
- https://developer.apple.com/design/human-interface-guidelines/layout.md ('first testing versions of your experience that use the largest and the smallest layouts')

#### appstore-5: No screenshots and no way to generate them from UI tests; the required sizes changed

*High. *

App Store Connect now requires at least one screenshot for 'iPhone with Dynamic Island (medium display)', 1206×2622 or 1179×2556 (iPhone 17 or 17 Pro). It also requires one for the iPad 13-inch, 2064×2752 or 2048×2732. Larger iPhone sizes are optional. There can be up to 10 per size. Images 'can't include alpha channels'. Guideline 2.3.3 says screenshots show the app in use; overlays that demonstrate input mechanisms are allowed. Nothing in the repo captures screenshots: LaunchTests attaches none, CI keeps no result bundle, and CI tests the iPad only. The iPhone layout is broken at the default text size, and the required iPhone shot would show it. Guideline 2.5.19 (new 2026-10-16) forbids hidden or undocumented features, so launch options that set up screenshot states should compile only in Debug.

**Recommendation.** Add an opt-in UI test (its own scheme, or gated by an environment variable):
- Debug-only launch options give deterministic states: a category open, a message showing, dark mode, AX text sizes.
- Each state is captured with XCUIScreen.main.screenshot() as an XCTAttachment with lifetime .keepAlways.
- Before capture, set the status bar with `xcrun simctl status_bar <udid> override`.
- Export the images with `xcrun xcresulttool export attachments` (check the exact syntax), then check size and alpha with `sips` and convert to JPEG if needed.
- Run it on iPhone 17, iPad Pro 13-inch (M5), optionally iPhone 17 Pro Max, and the iPhone Duo simulator.
The ASO thread supplies the shot list. Keep the images as CI artifacts or upload them by hand; do not commit them.

**Evidence.**

- https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications (Required device sizes; no alpha; up to 10)
- BricksonUITests/LaunchTests.swift:32,45,69,89 (four tests, no XCTAttachment or screenshot)
- git show main:.github/workflows/tests.yml (no result-bundle or artifact upload)
- docs/DECISIONS.md:223-224 ('CI tests the iPad only')
- docs/HANDOFF.md, Known gaps (iPhone: 'Emergency' breaks mid-word, the category row scrolls, labels clip)
- https://developer.apple.com/app-store/review/guidelines/ 2.3.3, 2.5.19

#### appstore-23: The privacy manifest is correct today, but nothing catches a new required-reason API

*Low. *

Since 2024-05-01, uploads that use a required-reason API without a declared reason are rejected. Today the app uses only UserDefaults (CA92.1); ContinuousClock is part of the Swift runtime, not a listed API. Planned work is likely to touch listed APIs:
- Backups: file timestamps (creationDate, modificationDate, contentModificationDateKey), reason C617.1 inside the container or 3B52.1 for files picked by the person; disk space (volumeAvailableCapacityForImportantUsageKey), reason E174.1.
- The keyboard probe: UITextInputMode.activeInputModes, reason 54BD.1.
- Timing code: systemUptime or mach_absolute_time, reason 35F9.1.
- An App Group shared with an App Intents or widget extension: UserDefaults reason 1C8F.1.
AppBundleTests checks only the UserDefaults entry.

**Recommendation.** Add a test that scans Brickson/ for the listed API names and fails unless PrivacyInfo.xcprivacy declares the matching category. Tell the Library editing, Typing and Speech threads which codes apply.

**Evidence.**

- Brickson/Resources/PrivacyInfo.xcprivacy:5-15
- BricksonTests/AppBundleTests.swift:97-108
- Brickson/Speech/SpeechService.swift:56,60,84 (UserDefaults)
- https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api.md
- https://developer.apple.com/tutorials/data/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype.json (categories and reason codes)

#### appstore-24: Bundle settings Apple checks at upload are not all pinned: launch screen, entitlements, single scene

*Low. *

UILaunchScreen is present, which satisfies Apple's launch-screen upload check, but no test pins it. No test pins the absence of an iCloud entitlement. AGENTS.md makes that absence a privacy promise, and HANDOFF lists it as untested. Nothing pins the absence of a multiple-scenes key either. Export compliance (ITSAppUsesNonExemptEncryption = false) is correct and pinned. It must be re-answered if any encrypted transport ships: Apple lists 'crypto functionality within Apple's operating system' as needing a determination, and the policy's caregiver section promises encryption.

**Recommendation.** Add AppBundleTests for UILaunchScreen and for the absence of UIApplicationSupportsMultipleScenes = true. Add a CI step that reads the signed device build's entitlements (`codesign -d --entitlements :-`) and fails on any iCloud or CloudKit key. Note in DECISIONS that the export answer changes if network or encryption code ever ships.

**Evidence.**

- project.yml:73-75; Brickson/Info.plist:38-39 (UILaunchScreen)
- BricksonTests/AppBundleTests.swift:27-108 (no launch-screen or entitlement test)
- AGENTS.md:188-189 (no iCloud capability)
- docs/HANDOFF.md, Known gaps (cloudKitDatabase and iCloud capability not pinned)
- docs/recon/2026-10-15/apple-platform.md:62,64 (single window; launch-screen check)
- https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance
- site/privacy/index.html:74

#### appstore-25: Localization: the String Catalog is committed empty, some strings bypass it, and there is no metadata localization plan

*Low. *

Localizable.xcstrings has no entries. The voice sample sentence and the speech-rate names are plain string literals. There is no InfoPlist String Catalog for the display name or for future usage strings. English-only is acceptable for 1.0. For ASO, Apple recommends localizing the product page, and it offers English (U.K.), (Canada) and (Australia) among 50 metadata locales. I could not verify on Apple's pages how keywords from extra locales are indexed per storefront. Translated starter phrases fall under invariant 7.

**Recommendation.** Commit a synced catalog with a test that every localizable key in code is in it. Add InfoPlist.xcstrings when the first usage string lands. Ask the ASO thread to plan the English variants of the metadata. Add a UI language only after native speakers review the phrases.

**Evidence.**

- Brickson/Resources/Localizable.xcstrings:1-6
- Brickson/Speech/SpeechService.swift:192; Brickson/Speech/SpeechRateSteps.swift:27
- project.yml:42-45
- docs/HANDOFF.md, Known gaps ('English only ...')
- https://developer.apple.com/help/app-store-connect/reference/app-information/app-store-localizations
- https://developer.apple.com/app-store/search/ ('Support a global audience')

#### sdlc-13: Test: cloud threads cannot see test results or screenshots

*High. Release: R0.*

The playbook says the session must check its own work before a person sees it, and for UI 'a way for Claude to see the result is crucial' (pp.31-32).

For Brickson's cloud threads, the only Swift test runner is CI:
- Each run takes 6 to 11 minutes.
- Neither job uploads anything: no .xcresult bundle, no UI-test screenshots, no summary of failed tests.
- A thread reads raw job logs. It cannot see what its layout change looks like, and cannot compare it with the Figma mock.

ROADMAP item 2 plans 'result bundles from CI'. The recon audit lists 'Result bundles and screenshots uploaded from CI' as a leverage item.

**Recommendation.** Both jobs keep their names. In each, after the tests and with if: always():
- export the UI tests' screenshots and a failures summary from the result bundle using xcresulttool;
- upload them with actions/upload-artifact, a GitHub-published action, with short retention.

Add a recipe to AGENTS.md for fetching them (gh run download <run-id>). A thread can then open the PNGs and compare them with the Figma frames, two or three rounds per change (p.32).

The screenshots show only starter phrases, so there is no personal data.

Cloud sessions cannot push workflow files, so the owner commits the workflow change (PR #12's AGENTS.md gotcha).

**Evidence.**

- .github/workflows/tests.yml:28-57 on main; PR #12 head 4198e94 tests.yml:35-82: no upload step
- docs/recon/2026-10-15/README.md:226-229 (item 4, result bundles and screenshots), 257-258 (runs take 6 to 11 minutes)
- docs/ROADMAP.md:63 (item 2, result bundles from CI, in progress)
- AGENTS.md:107-109
- Playbook pp.31-32 (steps 5-6; the visual loop)

#### sdlc-14: Test: AGENTS.md has no 'Verifying your work' block with expected outputs

*Medium. Release: R0.*

The playbook puts each command and an example of healthy output into CLAUDE.md, and makes running them and pasting the output part of 'done' (pp.32-33).

Brickson's scripts print clear success lines:
- 'All unit tests passed.'
- 'All UI tests passed.'
- 'The device build succeeded.'
- The Python suites end in unittest's 'OK'.

AGENTS.md lists the commands, but not these lines, not what a cloud thread should run (the Python suites, then CI), and not the rule 'fix the code, not the test'. That rule appears only as a review rule.

**Recommendation.** Add a block under AGENTS.md *Build and test*:

'## Verifying your work
- Mac: scripts/test.sh must end with "All unit tests passed."; scripts/test.sh ui with "All UI tests passed."; scripts/test.sh device with "The device build succeeded."
- Anywhere: python3 scripts/test-site.py and python3 scripts/test-runner.py (and scripts/test-select-xcode.py) end with "OK".
- Cloud: nothing builds Swift; push, then quote the CI run's URL, its Xcode and simulator lines, and its result.
- Paste the output into the docs/log file's Verified section. If a test fails, fix the code, not the test; never skip or delete one.'

Revise the lines when the test-seams work changes the scripts.

**Evidence.**

- scripts/test.sh:99-111 (success messages)
- scripts/test-runner.py, scripts/test-site.py (unittest)
- AGENTS.md:66-109 (commands without expected output)
- AGENTS.md:331-335 (a weakened assertion is a review finding)
- Playbook p.33 (example block)

#### sdlc-15: Test: failing-test-first leaves no record that the test failed

*Medium. Release: R0.*

AGENTS.md requires a failing test first, with a named change that would make it fail, and LESSONS.md asks agents to try that change once. The playbook adds three steps (p.32 steps 4 and 7):
- commit the failing test first;
- confirm it fails for the expected reason;
- make it pass without editing the test, protected by a hook or by review.

For cloud threads, the only proof that a Swift test failed is a red CI run, and nothing asks for one. The docs/log template's Verified section records only 'the change that would make it fail'.

A hook cannot tell a fix task from new work, so the protection has to come from the order of commits plus review. GitHub's Mac runners cost nothing for this public repository (tests.yml header), so a red run is cheap.

**Recommendation.** For a bug fix:
1. Push the reproduction test alone.
2. Cite the red CI job, with its URL and the failing line, in the docs/log Verified section.
3. Push the fix. The fix commit must not change that test file.

Add a *Code Review Rules* bullet: 'a fix commit that edits its own reproduction test, unless the pull request says why'.

For new behaviour, the same order is welcome but not required.

**Evidence.**

- AGENTS.md:368-374 (test first; name the change that would make it fail)
- docs/LESSONS.md:184-191 ('A check that cannot fail is not a check')
- docs/log/README.md:36-41 (Verified asks for the change that would make it fail, not the red run)
- .github/workflows/tests.yml:1-2 ('Free for public repositories')
- Playbook p.32 steps 4 and 7

### Speech engine and Get Attention

#### device-14: (b) Needs change, minor: the Get Attention placement study argues dwell safety per device and orientation

*Low. Release: R0 (Get Attention).*

The alarm direction justifies Stop Alert's placement with device- and orientation-specific geometry: 'On iPad the columns line up: Again over Get Attention, and Clear or Stop over Emergency'; 'On iPhone the quick controls take two rows'; 'In portrait, Get Attention sits under Again's empty slot'. Under resizable windows the same device can produce either arrangement, so a placement that is safe 'on iPad' may not be safe in a narrow iPad window.

**Recommendation.** State the placement rule in slot terms that hold in every arrangement: Stop never nearest Get Attention, and Stop's disappearance leaves a harmless control nearest. Verify it with UI tests across narrow and wide windows, and later with the chain engine across the window matrix, rather than per device.

**Evidence.**

- docs/recon/2026-10-15/directions/alarm-and-audio.md:88
- docs/recon/2026-10-15/directions/alarm-and-audio.md:197-198

#### appstore-12: Planned features need Info.plist usage keys, and a missing key quits the app

*Medium. *

Today's Info.plist correctly has no usage strings. Planned features change that:
- Calls ('Add Audio in Calls', iOS 18.2) need NSMicrophoneInjectionUsageDescription; Apple's sample says requesting permission without it makes the system quit the app.
- Recorded phrases need NSMicrophoneUsageDescription, plus guideline 2.5.14's 'clear visual and/or audible indication when recording'.
- SiriKit authorization needs NSSiriUsageDescription and the Siri capability. I could not confirm whether App Intents or App Shortcuts alone need either. App Shortcuts phrases may be extracted by Apple for training, which matters for the policy's Siri section.
- The Assistive Access full-screen key is optional (appstore-29).
Each key must land with its feature, its privacy-policy sentence and an AppBundleTests pin, and its text should be localizable through an InfoPlist String Catalog. Calls have no thread yet (HANDOFF).

**Recommendation.** Make a usage-key checklist part of each feature's definition of done: the key in project.yml, a localized string, an AppBundleTests pin (and a pin that the key is absent while the feature is off), and the policy sentence with a new Effective date in the same pull request. Settle the App Intents question on Apple's documentation before the Siri work starts.

**Evidence.**

- project.yml:57-84 (info properties: no usage-description keys)
- https://developer.apple.com/documentation/avfaudio/adding-synthesized-speech-to-calls.md (NSMicrophoneInjectionUsageDescription required; 'results in the system quitting the app')
- https://developer.apple.com/documentation/bundleresources/information-property-list/nsmicrophoneusagedescription.md
- https://developer.apple.com/documentation/sirikit/requesting-authorization-to-use-siri.md (Siri capability + NSSiriUsageDescription for SiriKit)
- https://developer.apple.com/documentation/appintents/app-shortcuts.md ('Apple may extract anonymized App Shortcuts data such as localized phrases')
- https://developer.apple.com/app-store/review/guidelines/ 2.5.14
- site/privacy/index.html:67-68, :78-79
- docs/recon/2026-10-15/directions/recorded-phrases.md:328-351

#### appstore-20: Background audio (2.5.4) behaviour has open questions that the review demo depends on

*Medium. *

UIBackgroundModes audio is legitimate for speech and the future alarm, as long as no silent audio is ever played. Three things are unsettled:
- Whether a Personal Voice keeps speaking after the device locks is unverified.
- The session is never deactivated, so other apps' audio does not resume. Releasing it is an open decision tied to the alarm.
- The recon reports that the interruption notification is deprecated from iOS 27, and guideline 2.5.1 asks apps to phase out deprecated APIs.
A reviewer who locks the device mid-phrase must hear speech continue.

**Recommendation.** Run the device check (lock mid-phrase, with a system voice and with a Personal Voice) before the review notes promise it. Decide when the session is released, together with the alarm. Move to the non-deprecated session lifecycle API. Keep a test that no audio plays unless the person started it.

**Evidence.**

- Brickson/Info.plist:34-37; BricksonTests/AppBundleTests.swift:63-66
- docs/DECISIONS.md:132-151 ('Background audio', open decision)
- Brickson/Speech/SpeechService.swift:345-366
- docs/recon/2026-10-15/apple-platform.md:34,101-102
- https://developer.apple.com/app-store/review/guidelines/ 2.5.1, 2.5.4

### Library editing and backup format

#### sdlc-19: Deploy: iOS has no rollback; plan to fix forward, and test that a fix-forward build still opens newer stores

*Medium. Release: R0.*

The playbook makes rollback 'a single command' and rehearses it (p.45 step 6). An App Store app cannot be rolled back:
- Phased release can be paused, but manual downloads continue.
- Removing the app from sale ends phased release for that version.
- The remedy is a new build with a higher build number.

Data is the harder problem. DECISIONS 'Versioned storage' says every later version migrates from what 1.0 ships and V1 is never edited. A build that reverts a feature must still open a store an earlier build already migrated to the newer schema, or the person's library is lost.

The rehearsed path is therefore a migration fixture test plus the owner practising the App Store Connect pause once.

Not verified: Apple's expedited review process.

**Recommendation.** Add unit tests that open fixture stores written by each shipped schema version, with V1 from the start, and check that every phrase survives.

Add a rule: a fix-forward build keeps every schema version it ever shipped.

The release runbook (sdlc-18) gets a 'Stop and fix forward' section:
- pause the phased release;
- write an incident record;
- open a fix pull request and raise the build number;
- decide whether to remove the app from sale, only for harm to communication.

The owner rehearses the pause once on the first update.

**Evidence.**

- docs/DECISIONS.md:96-111 (Versioned storage)
- docs/DECISIONS.md:25 (build number up with every upload)
- https://developer.apple.com/help/app-store-connect/update-your-app/release-a-version-update-in-phases/ (pause; manual downloads; removal stops phased release)
- AGENTS.md invariant 7 ('Nothing (repair, migration, import) may delete a person's own words')
- Playbook p.45 step 6, p.49 (rollback path as prerequisite)

### Phone layout and word fitting

#### device-1: (b) Needs change: the blueprint converts floors through a device density table read from the screen

*High. Release: R1 (decide before any engine commit).*

The R1 layout-engine blueprint reads the screen's native pixel size and native scale (nativeBounds and nativeScale) through a UIKit helper. It looks the screen up in a ppi table keyed by native panel pixels, and gives unknown devices 'the largest ppi in the table for their idiom'. Its engine input carries a 'DeviceMetrics' value (DeviceClass, pointsPerMillimetre, fullScreenSize). That is layout keyed to device identity. It also breaks in cases Apple now treats as normal. iPhone Mirroring and external displays change which screen the scene is on, so the table lookup misses. iPhone Duo, announced 2026-09-09, is in no row: its inner display is 1878×2670 px at 430 ppi and its outer 1398×2034 px at 460 ppi. Apple says to remove screen references and screen bounds, and to use the trait collection's displayScale instead of the screen's scale. The blueprint says the opposite ('Do not use SwiftUI displayScale'). UIScreen.main is deprecated after iOS 26.0. Apple offers no public API that reports physical pixel density.

**Recommendation.** Before the engine is built, remove DeviceMetrics, the density table, DeviceClass and the screen reader from the blueprint's design. The engine's only geometry inputs become the container size and safe-area insets, read with a custom Layout or onGeometryChange (iOS 16+; GeometryReader only where a proxy is needed). Reserved regions (iOS 27.1+), Dynamic Type and the window's own aspect complete the inputs; the blueprint's rule that orientation comes from aspect (:322) is already right. Floors become constants in points per profile (device-2). Use displayScale only for drawing (hairlines, images), never for sizing. Record the change as an amendment to the blueprint in docs/DECISIONS.md, without editing the research snapshot.

**Evidence.**

- docs/recon/2026-10-15/layout-blueprint.md:96-97 (UIKit reader of nativeBounds, nativeScale; 'fixed per-device-class table')
- docs/recon/2026-10-15/layout-blueprint.md:118-132 (ppi table keyed by native panel pixels; unknown devices get largest ppi for their idiom; iPhone Mirroring not covered)
- docs/recon/2026-10-15/layout-blueprint.md:124-125 ('Do not use SwiftUI displayScale')
- docs/recon/2026-10-15/layout-blueprint.md:294 (var device: DeviceMetrics // DeviceClass, pointsPerMillimetre, fullScreenSize)
- docs/recon/2026-10-15/layout-blueprint.md:515-517 and :534 (PixelDensityTableTests, DeviceMetricsTests, commit 2 'density table, DeviceClass')
- docs/recon/2026-10-15/README.md:529-533 (synthesis repeats the device table and native-pixel density)
- https://nonstrict.eu/wwdcindex/wwdc2026/278/ (WWDC26 278 transcript: 'do not reference the main screen'; 'Accessing the scale of the screen should be replaced with the trait collection's displayScale'; 'if you still have any references to screen bounds in your app, now is the time to remove these')
- https://developer.apple.com/documentation/uikit/uiscreen/main.md (availability iOS 2.0-26.0; 'Apple discourages the use of this symbol')
- https://www.apple.com/iphone-duo/specs/ (inner 7.6-inch 1878x2670 at 430 ppi; outer 5.4-inch 1398x2034 at 460 ppi)
- https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo.md ('Make layout calculations based on your scene or containing view's bounds rather than screen dimensions')

#### device-4: (b) Needs change: which profiles are offered comes from a device-class table (SE cut-off, no gaze on phones, default 'strictest for the device')

*Medium. Release: R1.*

The blueprint's section 3.3 decides which input profiles are 'offered' from a fixed table of device classes. 'Compact-height phone (SE 2/3, any phone under about 700 pt of screen height)' gets touch only. 'Other phones' get no gaze or head. iPad mini, 'iPad 9th gen ... Pro 11' and 'Air 13, Pro 13' each get their own row. The grid's shape is computed at 'the strictest offered profile for the device class', and the first-launch default is 'the strictest offered profile for the device'. The synthesis and its decision table repeat this: 'Gaze and head on phones: Not offered'; 'SE-class phones: Not offered the switch profile'. This is behaviour keyed to device identity. It changes what the app does by device, which Apple's HIG says not to do ('Don't change your app's functionality based on the space it occupies'). It is already wrong for a shipping device: iPhone Duo is a phone with a 7.6-inch inner display, close to the iPad mini's 8.3 inches, and Apple lists Eye Tracking among its accessibility features. The verdict 'profileDoesNotFitDevice', measured against 'the device's full screen', depends on the screen size, which Apple says not to use.

**Recommendation.** Offer every profile everywhere. For the current window the engine reports 'fits', 'scrolls at the floor' or 'window too small, needs W×H', and setup shows that as a passive note; it never blocks a choice and never reads the device. Get topology that is the same across profiles from one global rule instead of a device table: either a constant column count (device-6), or columns that fit one global reference floor in the available width. Replace profileDoesNotFitDevice with windowTooSmall(minimum:), and drop the SE and phone rows from the owner decision list. Choose the first-launch default without the device: for example touch, with setup asking which input method the person uses. Running accessibility features may suggest a profile, as the roadmap already says.

**Evidence.**

- docs/recon/2026-10-15/layout-blueprint.md:163-179 (device-class offered table; shape at strictest offered profile for the device class; default strictest offered for the device)
- docs/recon/2026-10-15/layout-blueprint.md:36-49 and :557-558 (SE-class phones; gaze and head not offered on phones)
- docs/recon/2026-10-15/layout-blueprint.md:317 and :324 (profileDoesNotFitDevice against 'the device's full screen')
- docs/recon/2026-10-15/README.md:558-570 and :704-707 (decision table rows)
- docs/recon/2026-10-15/directions/typing.md:212 ('Gaze typing on a phone is poor with any keyboard')
- https://www.apple.com/iphone-duo/specs/ (7.6-inch inner display; Eye Tracking listed under Accessibility)
- https://developer.apple.com/design/human-interface-guidelines/layout.md ('Keep functionality the same as size classes change'; 'a device's orientation and type (also called its idiom) aren't useful for making layout decisions')

#### device-6: (b) Needs change: Home v0 picks columns from the size class, and 'fixed column counts' is undefined for resizable windows and folds

*Medium. Release: R0 (honest stand-in) and R1 (engine).*

HomeView uses 3 columns when the horizontal size class is regular and 2 when it is compact. The size class is Apple's recommended signal, not device identity, so the code itself is acceptable. But resizing an iPad window, a Stage Manager window or an iPhone Duo pose then moves every tile, because phrase i lands in a different row and column. The same phrase also sits in different cells on the person's iPhone and iPad, which works against 'one app that follows a person'; the editing study raised the same gap. Invariant 8 says 'fixed column counts', but it does not say whether that means constant everywhere or never changing with content. On a partially folded iPhone Duo, whose inner display is regular width, a 3-column grid and the 3-button quick-control row each put their middle control in the fold. Apple says 'prefer an even number of columns so content divides cleanly'. The blueprint's regular arrangement also has odd rows: 5 quick controls, and 4 categories plus a pinned Stop Alert.

**Recommendation.** Owner clarifies invariant 8. Recommended reading: the phrase grid's column count is one constant for every window where the profile fits, chosen by the engine's matrix against the longest starter word and even (for example 4), so a phrase keeps its cell on the iPhone, the iPad and every window. Below the minimum window it may drop columns as a named exception. Wherever the column count does depend on width, it comes from the available width and the floor, never from the device, and is tested across resizes. For odd rows on a folded inner display, keep the middle slot harmless, or use ReservedRegion (iOS 27.1+) to keep slots out of the fold. The honest stand-in Home in R0 should already avoid odd safety rows centred on the fold.

**Evidence.**

- Brickson/Home/HomeView.swift:17 and :38-41 (columnCount: horizontalSizeClass == .regular ? 3 : 2)
- Brickson/Home/HomeView.swift:161-188 (three equal quick controls in one HStack)
- AGENTS.md:162-166 (invariant 8: 'fixed column counts; a slot keeps its place across categories')
- AGENTS.md:290-291 (review rule flags only 'a column count that changes with content')
- docs/recon/2026-10-15/directions/editing-and-backup.md:43 and :318 ('Position is not device-independent today'; 'make the column count a property of the library, not of the device class'; line numbers as read 2026-10-21, file being edited)
- docs/recon/2026-10-15/layout-blueprint.md:215-225 (compact 3 columns, regular 4; C row of five; B of four plus Stop)
- https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo.md ('In a grid-style layout, prefer an even number of columns so content divides cleanly'; 'Avoid extreme layout changes as people fold the device')
- https://developer.apple.com/videos/play/tech-talks/111466/ ('compact width on the outer display and regular width on the inner display')

#### device-7: (b) Needs change: nothing in the repository plans for iPhone Duo, folds, reserved regions or external displays

*Medium. Release: R0 (stand-in avoids the fold) and R1 (engine).*

iPhone Duo reaches customers on 2026-10-23. Neither the rulebook nor the recon mentions it, its fold, or the reserved regions Apple now defines: the outer camera (always present), the inner camera (when active) and the folding region (when partially open). The only mention is one line in the roadmap. System components avoid the fold by themselves, but a custom Layout such as the blueprint's SlotLayout does not. Apple says to use ReservedRegion or an ArrangementView for custom content. Folding moves content, which counts as a position change under invariants 8 and 10. Apple's guidance ('keep controls' relative positions as similar as possible'; 'Avoid extreme layout changes') matches Brickson's own rule, but the change still has to be named and scored. External displays appear only once, in an unrelated sentence; iPad apps 'move to external displays seamlessly', which changes the screen.

**Recommendation.** Add reserved regions to the engine's inputs. They are window-relative, come from the system, and identify no device: the engine treats occlusions as exclusion zones and treats a division as a seam that no safety control may straddle. Gate them with if #available(iOS 27.1, *), while the deployment target stays 26.0. Add rows to the matrix: the iPhone Duo outer display, the inner display fully open, and partially folded in both aspects, each in Device Hub. Name 'fold changes positions' as an exception scored by the chain engine, and record it in docs/DECISIONS.md. Add reserved regions to the 'Keep corners clear' design rule. In SwiftUI screens such as Settings, use NavigationStack and toolbar(content:) so the system's vertical-bar and fold behaviour comes for free.

**Evidence.**

- docs/ROADMAP.md:99 (only mention: 'foldable iPhones bring new orientations and window shapes')
- AGENTS.md:236-239 ('Keep corners clear' lists hot corners, window controls and the home indicator; no reserved regions)
- docs/recon/2026-10-15/layout-blueprint.md:569-577 (risks list: Mirroring and iPad windowing, no fold or Duo)
- https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo.md (reserved regions: divisions and occlusions; use GeometryProxy.reservedRegions; 'Size your views relative to their container rather than to fixed iPhone dimensions'; 'Don't use userInterfaceIdiom or UIInterfaceOrientation for layout decisions')
- https://developer.apple.com/documentation/swiftui/reservedregion.md (iOS 27.1+)
- https://developer.apple.com/documentation/swiftui/arrangementview.md (iOS 27.1+)
- https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo.md ('Keep controls consistent across device poses ... so people don't have to relearn where actions live')
- https://developer.apple.com/news/?id=kkphp5qo (available to customers October 23, 2026; recompile with Xcode 27.1)
- https://nonstrict.eu/wwdcindex/wwdc2026/278/ ('people expect apps to resize and move to external displays seamlessly')

#### appstore-6: iPhone Duo: its screenshots become mandatory in April 2027, and the portrait lock and size-class column switch will misbehave

*High. *

Apple's specifications say iPhone Duo screenshots 'will be required for any app using the iOS 27.1 SDK or later' starting April 2027. The sizes are 1398×2034 on the outer display and 2007×2853 on the inner display, in both orientations. Xcode 27.1 is already released (27A9275), and PR #12 makes the build use the newest released Xcode, so Brickson will build with the iOS 27.1 SDK. Apple's preparation page says apps built with that SDK resize when the device folds or unfolds, with bars that turn vertical. It also says 'hardcoded screen sizes, fixed orientations, and device assumptions can break layouts', and that layout should not be chosen by idiom or by treating regular width as an iPad. Brickson locks the iPhone to portrait. Home picks 3 or 2 columns from horizontalSizeClass, so unfolding mid-session changes the column count. Invariant 8 requires fixed column counts, so the owner must decide how positions survive a fold. Submitting iPhone Duo screenshots also earns an 'optimized for iPhone Duo' badge, which helps ASO.

**Recommendation.** Make the layout engine size everything from the space available, never from idiom or orientation. Keep relative positions and Emergency visibility across fold and unfold and on the outer display. Get the owner's decision on iPhone orientation and on column counts per width (DECISIONS 'Orientations'). Add the iPhone Duo and resizable simulators to the test destinations (Test seams thread) and to the screenshot set, before Xcode 27.1 becomes the CI default.

**Evidence.**

- https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications (iPhone Duo sizes; required from April 2027 for iOS 27.1 SDK)
- https://developer.apple.com/iphone-duo/prepare/ (SDK behaviour; avoid fixed orientations, idiom and size-class device assumptions; test in the iPhone Duo simulator in Xcode 27.1)
- https://developer.apple.com/news/releases/ (Xcode 27.1 27A9275 released; 27.2 RC)
- git diff main...origin/claude/project-thread-rre1no -- docs/DECISIONS.md ('Build with Apple's current Xcode')
- project.yml:78-79 and Brickson/Info.plist:40-43 (iPhone portrait only); BricksonTests/AppBundleTests.swift:69-72 pins it
- Brickson/Home/HomeView.swift:17,40 (columnCount from horizontalSizeClass)
- AGENTS.md:150-154 (invariant 8: fixed column counts)

#### appstore-28: The Assistive Access full-screen key is not set

*Low. *

UISupportsFullScreenInAssistiveAccess (iOS 17) lets the app fill the space above Assistive Access's Back button, and lists it as 'Optimized for Assistive Access' in Settings. That helps families who lock a device down find Brickson, and fits the owner's goal of using every relevant Apple capability. It needs the layout engine measured at the reduced frame, with Emergency still visible.

**Recommendation.** Adopt the key once the layout engine handles the Assistive Access frame. Pin it in AppBundleTests and add it to the family setup copy.

**Evidence.**

- Brickson/Info.plist (key absent)
- https://developer.apple.com/documentation/bundleresources/information-property-list/uisupportsfullscreeninassistiveaccess.md
- docs/recon/2026-10-15/apple-platform.md:53,91

### Typing foundation

#### device-5: (b) Needs change: the keyboard allowance is a per-device table, and one worst-case iPad sets the band for every screen

*Medium. Release: R0 typing foundation (design rule now; table when typing lands).*

LESSONS asks for 'a measured worst-case keyboard height per device class and orientation'. The blueprint's engine input is 'KeyboardAllowance // worst-case docked height for (class, aspect, OS)' from a KeyboardHeightTable keyed by device class. The typing study asks for 'a measured table of keyboard tops for each device, orientation and Display Zoom setting'. It also says the room left on 'the worst screen' (a zoomed 13-inch iPad in landscape) 'is the room every profile gets'. That reads one device's worst case as a global constant, where invariant 8 only needs every profile on one window to share a layout. The study also proposes a Brickson keyboard 'on big iPads' only, which offers a feature by device. The reference code measured the keyboard from screen bounds, which Apple says to remove, and in Stage Manager the keyboard frame must be converted into window coordinates.

**Recommendation.** Express the allowance as a function of the window alone: a worst-case keyboard fraction, or a height, by window width, height and aspect, with no device field. Keep the measured probes as test-matrix rows (device, orientation, Display Zoom, multitasking mode, keyboard type, OS), plus a UI test that fails when the live keyboard top crosses the band line. Compute the band per window from that window's own allowance, so a roomy window is not cut down to the zoomed 13-inch's room. Measure the live keyboard in window coordinates: convert the keyboard frame, or use the keyboard layout guide or safe area as a check. If a Brickson keyboard is ever built, offer it wherever its keys fit the profile's floor in the current window, with a defined fallback below that, rather than 'on big iPads'.

**Evidence.**

- docs/LESSONS.md:155-163 ('Lay out against a measured keyboard' ... 'per device class and orientation')
- docs/recon/2026-10-15/layout-blueprint.md:299 and :332 (KeyboardAllowance keyed by class and aspect; KeyboardHeightTable)
- docs/recon/2026-10-15/directions/typing.md:27 and :66 (worst screen's room is every profile's; table per device, orientation and Display Zoom)
- docs/recon/2026-10-15/directions/typing.md:38 and :42 (Brickson keyboard is 'an iPad option', 'on big iPads')
- docs/recon/2026-10-15/README.md:428-443, :591, :710
- Reference app (private, 6a22c1a) FamilyVoice/Views/HomeView.swift:166-171 (keyboardHeight = screen.bounds.maxY - end.minY)
- docs/recon/2026-10-15/apple-platform.md:59 (keyboard frame is in screen space; convert it in Split View and Stage Manager)
- https://nonstrict.eu/wwdcindex/wwdc2026/278/ (remove screen-bounds references; use the view's available size)

### Settings and first run

#### appstore-2: No Privacy row in the app, which guideline 5.1.1(i) requires

*High. *

Guideline 5.1.1(i): 'All apps must include a link to their privacy policy in the App Store Connect metadata field and within the app in an easily accessible manner.' The app contains no privacy link at all; Settings does not exist yet. AGENTS.md requires a Privacy row that opens the web page in SFSafariViewController. That page links out to apple.com and docs.github.com, so a person could keep browsing inside the app. The new age-rating questionnaire defines 'Unrestricted Web Access' as 'navigate to any webpage within the app... May include: embedded browser', and that maps to 16+. The recon's option P2 avoids most of this: show a native bundled copy of the policy first, with the web version behind one deliberate button. HANDOFF says Settings and first run, which includes the Privacy row, has no thread yet.

**Recommendation.** Build the Privacy row in R0's Settings. It shows a native, bundled copy of the policy with a large Back and no links, plus a clearly labelled 'Open the web version' that presents SFSafariViewController. Add a CI check that fails when the bundled copy or its Effective date differs from site/privacy/index.html. Give the App Store readiness thread the resulting answer to the age-rating 'Unrestricted Web Access' question.

**Evidence.**

- grep: no 'privacy', 'Safari' or site URL in Brickson/**/*.swift
- AGENTS.md:203-205 (Privacy row, SFSafariViewController, 'not Safari (App Review Guideline 5.1.1(i))')
- https://developer.apple.com/app-store/review/guidelines/ 5.1.1(i) and 5.1.1(vii)
- https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions (Unrestricted Web Access → 16+)
- site/privacy/index.html:61,79,89,113 (outbound links in the policy page)
- docs/recon/2026-10-15/directions/onboarding-and-settings.md:235-241 (P1/P2/P3; P2 recommended)
- docs/HANDOFF.md, Known gaps ('No Privacy row in the app, which App Review requires'); Next steps ('Settings and first run ... no thread yet')

### Figma and Claude Design screens

#### appstore-1: The app icon is a placeholder that resembles Messages; no Liquid Glass layered icon exists

*High. *

The installed icon is a single flat 1024 PNG in an asset catalog: a white speech bubble on blue. Guideline 2.1(a) says temporary content must be scrubbed before submission. Guideline 5.2.5 forbids looking confusingly similar to an Apple app, and it names Messages. The brand artwork in design/brand/ is a raster image that is not installed and has no vector masters. Apple's current icon model has layers: a background plus foreground layers, built in Icon Composer, with default, dark, clear and tinted appearances. If no variants are given, the system generates its own, so a flat AI-generated raster will look worse in dark and tinted mode than a layered icon. The accent colour (#0A60D6) matches the placeholder blue, not the brand navy (#172e47) and ivory. Guideline 2.3.8 asks for the icon and the metadata to be consistent. XcodeGen added built-in .icon support in 2.45.1 (PR #1600), so project.yml can carry an Icon Composer file.

**Recommendation.** Redraw the B mark as vector SVG layers. Build AppIcon.icon in Icon Composer: a navy solid background set in Icon Composer and the ivory B as a foreground group. Annotate the dark and mono appearances, and preview clear, tinted and small sizes. Then replace the AppIcon asset catalog through project.yml; the Test seams thread confirms CI's XcodeGen is 2.45.1 or later. The owner approves the artwork. Align AccentColor with the brand and pin any new colour pair in PaletteTests.

**Evidence.**

- Brickson/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json:2-9 (one universal ios 1024x1024 PNG)
- Brickson/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png (viewed: white speech bubble on solid blue)
- design/brand/README.md:12-13 ('raster artwork deliverables, not an installed app icon or vector masters')
- Brickson/Resources/Assets.xcassets/AccentColor.colorset/Contents.json:5 (#0A60D6)
- project.yml:90 (ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon)
- https://developer.apple.com/design/human-interface-guidelines/app-icons.md (layers, Icon Composer, appearances default/dark/clear/tinted; 'the system automatically generates variants you don't provide'; prefer vector)
- https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer.md (an Icon Composer file replaces the icon asset catalog; Xcode generates images for older OS versions)
- https://developer.apple.com/app-store/review/guidelines/ 2.1(a), 2.3.8, 5.2.5 (read 2026-10-21, Last Updated October 16, 2026)
- https://github.com/yonaskolb/XcodeGen/releases (2.45.1: built-in .icon folder support, #1600)

#### sdlc-26: Design: make the Figma frames the UI spec, and compare CI screenshots against them

*Low. Release: R1.*

The playbook's front-end path runs: a mock made from the accepted intent, iteration, export to Claude Code, then a visual loop that screenshots and compares against the mock (pp.15, 32).

The Figma thread is building screens from Apple's iOS 27 UI kit (ROADMAP item 9, docs/DESIGN.md, not yet in the repository). The owner's 2026-10-21 rule asks for layouts built from available space, never per-device screens. Invariant 8 requires that a control keeps its position across profiles.

Without a shared slot vocabulary, a thread cannot check its built screen against the design, and the owner cannot see that positions do not move.

**Recommendation.** For each screen, docs/DESIGN.md names its slots with stable identifiers (for example, message, Again, Clear or Stop, Yes, No, Emergency, Get Attention). Each slot gets a rule from available space, not a device table, and a link to its Figma frame.

Set the UI tests' accessibility identifiers to the same slot names. The screenshots and frames from sdlc-13 can then be checked slot by slot, and a test can show positions unchanged across text sizes and window shapes.

**Evidence.**

- docs/ROADMAP.md:70 (item 9, screens from Apple's iOS 27 UI kit; positions shown not to move)
- docs/ROADMAP.md:24-25 (space-based layouts, never one device)
- AGENTS.md invariant 8 (relative position never changes across profiles)
- Playbook p.15 (Claude Design mock to Claude Code), p.32 step 5 (visual loop)

### App Store readiness and ASO

#### device-8: (b) Needs change: from April 2027, App Store submissions need iPhone Duo screenshots

*Medium. Release: Before first submission.*

Apple's developer news says: 'Starting April 2027, any apps or games submitted will need to include screenshots for iPhone Duo'. Submitting Duo screenshots also earns an 'optimized for iPhone Duo' badge on the product page. The screenshot specifications are updated 'across orientations'. Brickson's store assets and any ASO plan need a Duo set, and a portrait-only phone app limits which Duo screenshots can be honest (device-3).

**Recommendation.** Add iPhone Duo screenshots (outer and inner displays) to docs/APP-STORE.md and docs/ASO.md as a requirement for any submission from April 2027, and as an early badge opportunity before then. Shoot them from real layouts in Device Hub, never mock-ups, and plan them after the orientation decision.

**Evidence.**

- https://developer.apple.com/news/?id=kkphp5qo (Prepare and submit your apps for iPhone Duo, 2026-10-05: screenshots required from April 2027; badge; preview tool in App Store Connect)
- https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo.md (Resources: Screenshot specifications)
- docs/ROADMAP.md:19-25 (goal: App Store ready, meeting or exceeding ASO requirements)

#### appstore-3: The privacy policy, the live listing's source of truth, describes features the app does not have

*High. *

Guideline 2.3 requires privacy information to reflect the app's core experience. 5.1.1(i) requires the policy to state what the app does. The policy describes several things the app does not do yet, and each must be built or deleted before submission. In the 'what stays on your device' section: a typed message that persists, a text-size setting, and deleting in the app. Further down: exported backups, recorded phrases with the microphone, caregiver alerts over the local network, Siri and Shortcuts, and Get Attention. Caregiver alerts need network code, which invariant 9 forbids, and the owner has not decided. Every wording change moves the Effective date. The policy also promises that 'when a change comes with an app update, that update's notes will say so'.

**Recommendation.** Keep a release checklist, for example in docs/APP-STORE.md, that maps each policy sentence to a shipped feature or to a deletion. For 1.0, delete the caregiver-alerts section, and the recorded-phrases and Siri sections unless they ship. Drop 'text size' if text size stays Dynamic Type only. Update the Effective date and the in-app copy in the same pull request, and mention policy changes in What's New.

**Evidence.**

- site/privacy/index.html:49 (typed message persists), :50 ('text size you chose'), :52 and :105 (delete in the app), :65 (backups you export), :67-68 (recorded phrases), :69-77 (caregiver alerts), :78-79 (Siri and Shortcuts), :111 (Get Attention)
- site/privacy/index.html:39 (Effective October 12, 2026), :115 (update notes will say so)
- AGENTS.md:195-202 (three planned sections; a release that doesn't ship one deletes it; caregiver alerts need network code)
- AGENTS.md:155 (invariant 9: no network code)
- docs/recon/2026-10-15/docs-repo-audit.md:86 (sentence-by-sentence list)
- https://developer.apple.com/app-store/review/guidelines/ 2.3, 5.1.1(i)

#### appstore-8: Accessibility Nutrition Labels: no evaluation matrix, no accessibility URL, and some claims are not yet true

*Medium. *

Apple says the labels are voluntary now but 'over time, you'll be required to share accessibility support details to submit'. Labels show on iOS 26 product pages, and searches like 'VoiceOver ... apps' rank apps that claim a label higher. That makes them central to Brickson's ASO. A label may be claimed only if all common tasks can be completed with that feature: first launch, settings, and the primary functions. Guideline 2.3 applies to the claims. Responses can be published only for devices that have a live version. Status per label:
- VoiceOver and Voice Control: plausible, because every control is a standard Button and the UI tests run the accessibility audit. Needs device runs of every common task, including typing and Settings once they exist.
- Larger Text: not claimable yet. Phone labels clip at the largest size, and no test runs at AX sizes.
- Dark Interface: no dark-mode test exists, and the colour assets have no dark variants.
- Sufficient Contrast: PaletteTests measures asset values, not rendered pixels. Apple asks for testing with Bold Text, Increase Contrast and Reduce Transparency all on.
- Differentiate Without Color Alone: likely; the selected category shows a check mark.
- Reduced Motion: likely; audit any symbol effects.
- Captions: Apple accepts text transcripts of spoken audio, and Brickson shows every spoken phrase as text. So this may be truthful, contrary to the recon's 'never', if every sound (alarm, voice samples) also shows text.
- Audio Descriptions: no video, so never claim it.
Switch Control, Eye Tracking and Dwell are not labels; they belong on the optional accessibility URL page, which does not exist.

**Recommendation.** Keep a per-device matrix in docs/APP-STORE.md: common tasks as rows, the nine labels as columns. Mark each cell claimable only when there is logged evidence: a UI test at AX1 to AX5, a dark-mode and Increase Contrast rendered-pixel test (Test seams thread), and owner device runs with VoiceOver and Voice Control. Publish labels only after the first build is live. Add a site/accessibility page as the Accessibility URL.

**Evidence.**

- https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels (voluntary then mandatory; common tasks; accessibility URL; search relevance)
- https://developer.apple.com/help/app-store-connect/manage-app-accessibility/manage-accessibility-nutrition-labels (publish only for devices with a live version)
- https://developer.apple.com/help/app-store-connect/manage-app-accessibility/larger-text-evaluation-criteria, .../sufficient-contrast-evaluation-criteria, .../captions-evaluation-criteria ('text transcripts of audio-only content, such as ... spoken dialogue'), .../audio-descriptions-evaluation-criteria
- docs/HANDOFF.md, Verification ('No test sees ... any accessibility text size, or dark mode') and Known gaps (phone labels clip)
- Brickson/Resources/Assets.xcassets/EmergencyFill.colorset/Contents.json (one appearance only)
- Brickson/Home/HomeView.swift:75-76 (spoken text shown in the message row)
- BricksonUITests/LaunchTests.swift:89 (accessibility audit)
- docs/recon/2026-10-15/apple-platform.md:78 (recon says never claim Captions)

#### appstore-9: Age-rating answers are not prepared, and two questions are easy to answer wrongly

*Medium. *

The questionnaire is required; an Unrated app cannot be published. New questions have applied since 2026-01-31. Two traps:
- 'Medical or Treatment Information' gives 'emergency medical care' and 'medication guidance' as examples; infrequent is 13+, frequent is 16+. The starter phrases include 'I can't breathe.', 'I'm choking.' and 'I need my medication.'. These are the person's own words, not guidance, so 'None' is defensible but should be written down.
- 'Unrestricted Web Access' rates 16+, and depends on how the Privacy row is built (appstore-2).
User-Generated Content covers only broadly distributed content, and Messaging and Chat covers communication between users of the app, so both are No for 1.0. Guideline 2.3.6 asks for honest answers. The policy's 'not directed to children under 13' is consistent with a 4+ or 9+ rating that is not Made for Kids.

**Recommendation.** Draft every questionnaire answer, with a reason, in docs/APP-STORE.md and ask the owner to confirm. Re-answer when caregiver alerts (messaging), an in-app browser, or new phrase sets land.

**Evidence.**

- https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions (category definitions; 13+ and 16+ triggers)
- https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating
- https://developer.apple.com/news/upcoming-requirements/ (Age Rating Updates, since January 31, 2026)
- Brickson/Resources/StarterPhrases.json (Emergency and Needs phrases)
- site/privacy/index.html:100-101 (Children)
- https://developer.apple.com/app-store/review/guidelines/ 2.3.6

#### appstore-11: App Review notes and demo instructions are not written

*Medium. *

Guideline 2.3.1(a) requires new features to be 'described with specificity in the Notes for Review'. The Notes field holds 4000 bytes, and contact details are required. Several behaviours need explaining:
- background audio (2.5.4);
- speech playing with the Silent switch on, because of the .playback category, which a reviewer might read against 2.5.9;
- the screen never locking;
- the unexplained Personal Voice prompt at first launch;
- no login and no demo account, since the starter library loads at once;
- Emergency making sound only.
DECISIONS proposes the demo 'choose a long phrase, then lock the device'. Whether a Personal Voice keeps speaking in the background is unverified, so the demo should use a system voice. Reviewers usually have no Personal Voice, and the app falls back to a system voice.

**Recommendation.** Draft the review notes as a plain-text file kept with the store metadata (appstore-15). Cover how to speak a phrase; the lock-screen demo with a system voice; why the Silent switch and the screen lock behave as they do; the Personal Voice prompt and its fallback; that Emergency and the alarm only make sound; and, once shipped, how to test the alarm, typing and call audio. Optionally link a short device-recorded demo of Eye Tracking or Switch Control.

**Evidence.**

- https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information (App Review information: contact, Notes up to 4000 bytes)
- https://developer.apple.com/app-store/review/guidelines/ 2.3.1(a), 2.5.4, 2.5.9
- docs/DECISIONS.md:132-142 (background audio; review-notes demo), :124-130 (screen stays awake), :226-242 (Personal Voice asked at launch)
- Brickson/Speech/SpeechService.swift:156 (request at launch), :345-366 (.playback, .spokenAudio)
- docs/recon/2026-10-15/apple-platform.md:102 (Personal Voice in background unverified)

#### appstore-15: No store metadata is kept in the repository, and nothing tests its limits or claims

*Medium. *

There is no plain-text source for the store name, subtitle, promotional text, description, keywords, What's New, review notes or test information. Apple's limits:
- name: 2 to 30 characters, one per localization;
- subtitle: 30;
- promotional text: 170;
- description: 4000, plain text;
- keywords: 100 bytes, comma-separated, without repeating the name, company or category, and no competitor names;
- What's New: 4000;
- review notes: 4000 bytes.
Guidelines 2.3.7 and 2.3.14 forbid pricing and 'unverifiable product claims' in names, subtitles and creative assets. The owner's goal of 'the best ALS app' is a goal, not copy, and DECISIONS forbids reliability claims and price words. A test like the website's free/paid check would keep the text honest.

**Recommendation.** Keep one plain-text file per field per locale, for example store/en-US/name.txt, subtitle.txt, keywords.txt and so on, plus review_notes.txt and testflight_description.txt. Add a Python test that enforces Apple's limits (keywords counted in bytes), rejects free/paid and price words, 'best' and other superlatives, competitor names and keywords that repeat the name, and checks that every feature named is built.

**Evidence.**

- repository tree on main: no store/ folder, no docs/APP-STORE.md or docs/ASO.md
- https://developer.apple.com/help/app-store-connect/reference/app-information/app-information (name 30, subtitle 30)
- https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information (promotional 170, description 4000, keywords 100 bytes, What's New 4000, Notes 4000 bytes, Copyright required)
- https://developer.apple.com/app-store/search/ (keyword rules)
- https://developer.apple.com/app-store/review/guidelines/ 2.3.7, 2.3.14
- docs/DECISIONS.md:47-49 (no reliability claims), :84-94 (no price)
- scripts/test-site.py:84 (free/paid check pattern)

#### appstore-16: The support and marketing site still says 'in development', gives only an email, and has no accessibility page

*Medium. *

Apple says the Support URL 'must lead to actual contact information (legal address, email address, telephone number), as may be required by local law'. Guideline 1.5 asks for an easy way to make contact. The site has an email address only. At release, the status lines must change; one of them is pinned by a test. The site never mentions Eye Tracking, Switch Control or Dwell, Brickson's main differentiators. The optional Accessibility URL on the product page needs a page to point to.

**Recommendation.** Prepare a release-day pull request for the site, the README and test-site.py. Add a short support FAQ (Personal Voice setup, how to get help, not for emergencies) and a site/accessibility page that honestly describes the supported input methods. Decide what contact details to publish together with the DSA decision (appstore-13).

**Evidence.**

- site/index.html:9,28 ('being built'), :33 ('In development for iPhone and iPad.'), :57 (email only; 'not for emergencies')
- scripts/test-site.py:79-84 (pins 'In development for iPhone and iPad.')
- README.md:5,19-22
- https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information (Support URL contact requirement)
- https://developer.apple.com/app-store/review/guidelines/ 1.5
- https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels (accessibility URL)

#### appstore-19: An automatic rating prompt would conflict with invariant 2; ratings still matter for search

*Medium. *

Apple says ratings and reviews 'can influence how your app ranks in App Store search'. SKStoreReviewController can prompt up to three times in 365 days, and Apple says to 'make sure not to interrupt their activity'. On Brickson, a system sheet over Home could cover Emergency, which invariant 2 forbids, and a resting gaze could activate its stars or its dismiss button. No rating plan is written down.

**Recommendation.** Record a decision: never request a review automatically on Home. Offer a 'Rate Brickson' row on a family Settings screen that opens the App Store write-review page; it needs the app's Apple ID from the App Store Connect record. Reply to reviews as part of support.

**Evidence.**

- https://developer.apple.com/app-store/ratings-and-reviews/
- https://developer.apple.com/app-store/search/ (Foster positive ratings and reviews)
- AGENTS.md:113-117 (invariant 2: Emergency never covered)
- https://developer.apple.com/app-store/review/guidelines/ 3.2.2(x) as fetched: must not force users to rate

#### appstore-22: The privacy label answer 'Data Not Collected' is right, but its reasoning is not written down

*Low. *

The privacy manifest collects nothing and declares no tracking, and a test pins this. Apple defines 'collect' as transmitting data off the device so that the developer or its third-party partners can access it. It is 'not responsible for disclosing data collected by Apple' (crash reports, TestFlight). Optional disclosure covers user-initiated support requests. Three edge cases should be written down:
- Support email: user-initiated, so it meets the optional-disclosure criteria.
- The in-app web policy: Apple says 'data collected via web traffic must be declared, unless you are enabling the user to navigate the open web'. GitHub Pages logs visitors' IP addresses, which a native policy copy avoids.
- Future caregiver alerts would change the answer.

**Recommendation.** In docs/APP-STORE.md, record the answer 'No, we do not collect data from this app' with the reasoning for each edge case above, and re-check it in every pull request that adds a feature.

**Evidence.**

- Brickson/Resources/PrivacyInfo.xcprivacy:16-21
- BricksonTests/AppBundleTests.swift:97-108
- https://developer.apple.com/app-store/app-privacy-details/ (definition of collect; optional disclosure; web views; Apple frameworks)
- site/privacy/index.html:91-93 (Apple-shared crash and TestFlight data), :113 (GitHub logs IPs)

#### appstore-26: No app preview is planned; it is optional but the strongest way to show Eye Tracking and speech

*Low. *

App previews are optional. They run 15 to 30 seconds, up to three per size per localization, in .mov, .m4v or .mp4, and they show before screenshots. Guideline 2.3.4 allows only screen captures of the app, with narration or text overlays. Simulator audio is unreliable, so speech must be recorded on a device; QuickTime Player on a Mac can record a connected device.

**Recommendation.** After R0 is device-verified, record one preview per required device class: a phrase chosen by Dwell or Switch Control and spoken. Add captions as text overlays. Do not use it to promise unbuilt features.

**Evidence.**

- https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications
- https://developer.apple.com/app-store/review/guidelines/ 2.3.4
- AGENTS.md, Gotchas ('Simulator audio is unreliable')

#### appstore-29: No plan for the App Store's discovery surfaces: tags, custom product pages, creative assets, featuring

*Low. *

Apple's search page says search results can include 'app tags ... generated using large language models (LLMs) based on the metadata you've provided'. Custom product pages can be assigned keywords, for example one page per input method. New product-page headers and search-result 'creative assets' (guideline 2.3.14, added 2026-10-16) must avoid unverifiable claims. Featuring Nominations let developers pitch their app to Apple's editors. None of this is planned, and the marketing page does not describe the input methods it would promote.

**Recommendation.** In docs/ASO.md, plan:
- keyword research and competitor names to avoid;
- custom product pages by input method;
- creative assets made from real app captures;
- a Featuring Nomination after the first live release, which can include iPhone Duo support.
All of it is held to the same no-claims and no-price test (appstore-15).

**Evidence.**

- https://developer.apple.com/app-store/search/
- https://developer.apple.com/app-store/submitting/ (custom product pages, product page optimization, featuring nominations)
- https://developer.apple.com/news/?id=ljpl7kyn (new creative assets, 2026-10-05)
- https://developer.apple.com/app-store/review/guidelines/ 2.3.14
- site/index.html (no mention of Eye Tracking, Switch Control or Dwell)

#### sdlc-18: Deploy: no release or TestFlight runbook, though R0 is 'done' only through TestFlight

*High. Release: R0.*

R0's 'Done when' says people use Brickson daily 'through TestFlight', and item 11 plans TestFlight for the owner and a small group. No document says how to archive, upload, test or submit.

What exists:
- project.yml has DEVELOPMENT_TEAM empty, and DECISIONS.md says CURRENT_PROJECT_VERSION must rise with every upload.
- DECISIONS.md asks for App Review notes showing background audio.
- The privacy policy already describes what TestFlight shares.

Apple's current help pages, checked 2026-10-21:
- A build can be tested for up to 90 days.
- Up to 100 internal testers and up to 10,000 external testers.
- The first build added to a group goes to App Review.
- Testers send feedback and screenshots from the TestFlight app, and these appear in App Store Connect.
- Phased release spreads an update over 7 days and can be paused for a total of 30 days, but anyone can still download the update manually.

The playbook's production gate (pp.40-46) maps directly onto this: agents prepare everything, and the owner uploads and releases.

**Recommendation.** Write docs/RELEASE.md, or a section of docs/APP-STORE.md, with these steps.

1. Preflight, prepared by an agent in a pull request:
   - main is green;
   - the build number has gone up;
   - the privacy policy matches the build, with its Effective date;
   - every device-check row this release touches has a result;
   - store text has no price words;
   - review notes cover background audio and Personal Voice.
2. Archive and upload: the owner does this in Xcode's Organizer. Agents never upload; enforce it with the hook in sdlc-6.
3. TestFlight internal group (the owner's devices), then an external group of a person living with ALS, a caregiver and an SLP, with test information and a feedback address.
4. Submit, with phased release on for updates.
5. Afterwards, Maintain (sdlc-21).

Each release gets a docs/log record of what was uploaded, from which commit.

**Evidence.**

- docs/ROADMAP.md:55-58 (R0 done when ... through TestFlight), 72 (item 11)
- project.yml:26-28; docs/DECISIONS.md:22-25, 132-142
- site/privacy/index.html:93 (TestFlight section)
- https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/ (90 days; 100 internal, 10,000 external; first build reviewed)
- https://developer.apple.com/help/app-store-connect/test-a-beta-version/view-tester-feedback/
- https://developer.apple.com/help/app-store-connect/update-your-app/release-a-version-update-in-phases/ (7 days; pause up to 30 days total; manual downloads continue)
- Playbook pp.45-46

### Roadmap, decisions and repo review

#### device-9: (b) Needs change: PORTING.md lists idiom-gated reference code as 'almost as-is'

*Medium. Release: R0/R1 as each piece is ported.*

The 'almost as-is' tier includes WindowSizePolicy and SettingsSafetyBarLayout. In the reference, WindowSizePolicy applies a minimum window height only when userInterfaceIdiom is .pad. It is derived from insets measured on specific iPads (a 32 pt status bar on the mini), and its result has a 'notAnIPad' case. SettingsSafetyBarLayout takes 'isPhone' from UIDevice.current.userInterfaceIdiom. BackupImportQuestion words its message by Device (.iPhone or .iPad, from the idiom). The reference keyboard code reads screen bounds, and BoardPlanTests convert to physical size with one model's zoom constant (2752/2064). PORTING step 2 already says to take out 'their device', but the tier list contradicts it. The recon also frames the minimum window as an iPad question, whereas iPhone Duo split view and iPhone Mirroring resize phones too. To the reference's credit, its HomeArrangement chooses board or compact from the container size and orientation from aspect, which is the right pattern.

**Recommendation.** Move WindowSizePolicy and SettingsSafetyBarLayout to 'Port and generalize' and add a porting rule: 'remove every userInterfaceIdiom, UIDevice, UIScreen and orientation check; replace it with container width and height'. Apply the minimum window to every scene. In SwiftUI, use .windowResizability(.contentMinSize) with a minimum frame taken from the engine's minimumWindow, and treat it as best effort, with a defined layout below it (blueprint 5.1). Word the backup message without the device ('this device'), or use the device's own model name, never the idiom. Express the zoom test rows as window sizes.

**Evidence.**

- docs/PORTING.md:17-19 ('Take out anything written for one person: their window, their phrases, their device')
- docs/PORTING.md:73-74 (SettingsSafetyBarLayout, WindowSizePolicy as 'almost as-is')
- docs/recon/2026-10-15/README.md:583-584 ('the minimum window size on iPad')
- Reference app (private, 6a22c1a) FamilyVoice/Models/WindowSizePolicy.swift:61-94 (guard idiom == .pad; largestTopInset 32 'on the mini')
- Reference app FamilyVoice/FamilyVoiceSceneDelegate.swift:33-36 (passes windowScene.traitCollection.userInterfaceIdiom)
- Reference app FamilyVoice/Views/SettingsView.swift:74-79 and FamilyVoice/Models/SettingsSafetyBarLayout.swift:44-56 (isPhone from UIDevice)
- Reference app FamilyVoice/Views/BackupImportQuestionView.swift:64-66 (Device from userInterfaceIdiom)
- Reference app FamilyVoiceTests/BoardPlanTests.swift:147-154 (one model's displayZoomMagnification 2752/2064)
- Reference app FamilyVoice/Models/BoardPlan.swift:9-25 (size-based HomeArrangement.resolve(for:) - keep)
- https://developer.apple.com/documentation/technotes/tn3192-migrating-your-app-from-the-deprecated-uirequiresfullscreen-key.md (sizeRestrictions is a preference; rotation is not prevented; SwiftUI: windowResizability(.contentMinSize))

#### device-12: (b) Needs change: the device-check table lacks the new window environments

*Low. Release: R0 step zero onward.*

HANDOFF's 'Checks that need a real device' lists keyboard coverage 'in each orientation', but nothing on iPhone Duo (Eye Tracking and Snap to Item across the fold, whether a portrait-only app gets landscape windows), Stage Manager or windowed iPad (keyboard shifting, window controls under Snap to Item), external displays (where the Eye Tracking or AssistiveTouch pointer goes), Slide Over, or iPhone Mirroring. These checks settle device-3, device-5 and device-7, and invariant 11's minimum-window wording.

**Recommendation.** Add rows, each naming the decision it settles: iPhone Duo with Eye Tracking, fully open and folded; portrait-only behaviour on Duo; Stage Manager keyboard and window controls; external display with Eye Tracking and Dwell; Slide Over at the largest text size; iPhone Mirroring resized wide and short. Record results in docs/log/ with window size and pose. The owner runs whichever they have hardware for.

**Evidence.**

- docs/HANDOFF.md:102-121 (device-check table)
- docs/recon/2026-10-15/layout-blueprint.md:585-593 (proposed additions: window controls, Stage Manager keyboard shifting, Display Zoom sizes; no Duo or external display)
- https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo.md ('Check how your app appears on both displays, when closed, open, or partially folded. Rotate iPhone Duo in each pose')

#### device-15: (a) Acceptable: test defaults, dated records, product scope and adaptive choices already made

*Low. *

These name devices or orientations without driving layout or behaviour, or they already follow the new principle. Keep them. Dated measurement records: HANDOFF's Verification lines and the recon simulator findings. Record-keeping rules: AGENTS 'Say what each result was measured on', the pull request template, and the Display Zoom and rotation gotchas. Test defaults: the README and GETTING_STARTED instructions to pick an iPad Pro 13-inch simulator. Product scope: TARGETED_DEVICE_FAMILY 1,2 with Mac, Catalyst and Vision Pro off, which matches the owner's 'not macOS'. iPhone Mirroring still shows the iPhone app in a resizable window on a Mac (WWDC26 278), so layouts must handle it anyway; I could not confirm that it can be switched off. Single-window app (no UIApplicationSupportsMultipleScenes), one Home and one Emergency. LESSONS' minimum window derived from the safety controls at the largest text size. The blueprint's orientation-from-aspect rule and its rule that window position is not an input, both of which match Apple. ROADMAP R0 item 3, 'sized from the space available rather than the device model'. Home v0's literal sizes (64, 88, 96, 52 pt) are not device-keyed; the stand-in decision already records them as placeholders.

**Recommendation.** No change. When the rulebook is updated (device-10), say that test matrices may name devices and dated records keep their versions, but layout code and engine inputs may not name devices. Add iPhone Mirroring to the manual-check list, because Brickson will appear there whether or not the Mac options are on.

**Evidence.**

- docs/HANDOFF.md:26-38
- docs/recon/2026-10-15/simulator-and-build-findings.md:5-11
- AGENTS.md:377-381 and :460-466
- .github/pull_request_template.md:13
- README.md:98-102; docs/GETTING_STARTED.md:45
- project.yml:36-40 and :89
- docs/recon/2026-10-15/apple-platform.md:62 (single scene by omission of the scene manifest)
- docs/LESSONS.md:223-228
- docs/recon/2026-10-15/layout-blueprint.md:322-323 (orientation from aspect; window position not an input)
- docs/ROADMAP.md:64
- Brickson/Home/HomeView.swift:109, :200, :230, :268 and docs/DECISIONS.md:181-188

#### appstore-7: The current build would likely fail guidelines 2.1(a) and 4.2: a stand-in Home, no device testing, and a README that says 'not ready'

*High. *

Guideline 2.1(a) asks for final versions 'tested on-device for bugs and stability' and rejects 'obvious technical problems'. Guideline 4.2 rejects apps without 'adequate utility'. Guideline 2.2 says TestFlight builds must also comply. Today there is no typing, no editing, no Settings and no Get Attention. Home is a declared stand-in with known phone layout failures, and no physical device has run the app. README.md and the website say the app is 'not ready for dependable daily communication' and 'in development'. That is honest now, but those lines contradict a store listing. There is no written release gate saying when a build may go to external TestFlight or to review.

**Recommendation.** Write an R0 release gate in docs/ROADMAP.md and docs/SDLC.md:
- the R0 features are complete;
- every device check is logged in docs/log;
- UI tests are green on iPhone and iPad at default and AX sizes, light and dark;
- the policy, README and site lines are updated in the same pull request as the release.
Only then send a build to external TestFlight or to App Review.

**Evidence.**

- https://developer.apple.com/app-store/review/guidelines/ 2.1(a), 2.2, 4.2
- docs/DECISIONS.md:181-224 ('Home version 0 is a stand-in', accepted shortfalls)
- docs/HANDOFF.md, Verification ('Physical devices: none') and 'Checks that need a real device'
- README.md:19-22 (Early development — not ready ...), README.md:48-52 (not implemented list)
- site/index.html:9,28,33 ('being built', 'In development')

#### appstore-18: No TestFlight process or release cadence is documented

*Medium. *

TestFlight facts:
- Internal testing allows up to 100 App Store Connect users.
- External testing allows up to 10,000 testers and needs a Beta App Description and a feedback email; the first build of a version gets a full TestFlight App Review.
- Builds expire after 90 days.
The privacy policy already promises how TestFlight data is handled: feedback and screenshots deleted within a year, names removed when a tester leaves. The recon proposes testers including a person living with ALS and a speech-language pathologist. Release settings matter for an app people depend on: 'Manual' release control, and phased release over 7 days for updates. What's New is required from the second version, and the policy says it will mention privacy changes.

**Recommendation.** Add a release stage to docs/SDLC.md:
- an internal build to the owner's devices first;
- the device checks, logged in docs/log;
- an external group with consented testers;
- 'What to Test' for each build;
- feedback handled as the policy promises, with no tester names or phrases in the repository;
- manual release for 1.0 and phased release for updates.
The owner runs the TestFlight steps.

**Evidence.**

- https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview
- https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-test-information
- https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers (first build full review; six builds per 24 hours)
- https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information (Version Release Settings; Phased Release; What's New)
- site/privacy/index.html:93 (TestFlight data promises), :115
- docs/recon/2026-10-15/README.md:507-510

#### appstore-27: AGENTS.md cites guideline 5.1.1(i) for 'not Safari', which the guideline does not say

*Low. *

Guideline 5.1.1(i) asks only for a link 'within the app in an easily accessible manner'. It does not require an in-app sheet. Keeping people inside the app is still right, because leaving strands a person who cannot navigate back, but that is a safety reason, not App Review's. The rule also has an age-rating cost (appstore-2) that it does not mention. AGENTS changes go to the owner.

**Recommendation.** Propose to the owner rewording the rule: give the dwell-safety reason, prefer a native copy with an optional in-app web sheet, and note the age-rating question. Do not change the rule's intent.

**Evidence.**

- AGENTS.md:203-205
- https://developer.apple.com/app-store/review/guidelines/ 5.1.1(i)

#### sdlc-1: Plan: there is no intent home; the owner's goals live only in chat and get paraphrased into other files

*Medium. Release: R0.*

The playbook's Plan stage needs one committed artifact per idea, written in the originator's words, that the owner accepts by merging (pp.11-13). Brickson has none.

- The owner's rewritten goal of 2026-10-21 exists only as a paraphrase in the untracked ROADMAP.md ('The goal').
- Decisions go straight into DECISIONS.md.
- GitHub Issues are enabled, but the API lists only numbers #1 to #12, all pull requests. No issue has ever been filed, and there are no milestones or releases.
- PR #12's description links its project thread, which gives some linkage (p.22). The docs/log template has no line for the thread or the intent.

So there is no record of what was asked before work started, no survival rate, and no way to see later edits to intent (p.13).

**Recommendation.** Create docs/intents/ with a README template:
- Author, date, status (draft, accepted, closed) and the project-thread message link.
- Problem, in the owner's words.
- Who it is for: stage of ALS, input method, iPhone or iPad.
- Proposed outcome.
- Invariants and privacy-policy sentences it touches.
- Constraints, including the hard stops.
- Open questions.

The Roadmap thread writes each intent from the owner's chat message and opens a pull request; the owner's merge is the acceptance (p.13). Make docs/intents/2026-10-21-goal.md, holding the five-point goal verbatim, the first one.

Add 'Intent:' and 'Thread:' lines to the docs/log template and the PR template (linkage, p.22).

Never put family, health or private account details in an intent; the repository is public.

Measure two things from git: hours from the chat message to the intent commit, and how many intents are accepted versus closed.

**Evidence.**

- docs/ROADMAP.md:16-25 (untracked working copy, 2026-10-21): the goal 'In the owner's words', paraphrased
- GET /repos/MiddleAgedBanana/Brickson/issues?state=all (2026-10-21): 12 items, all pull requests; 0 milestones; 0 releases
- docs/log/README.md:22-52: template has no Intent or Thread line
- PR #12 body, first line: link to the project thread (linkage, p.22)
- Playbook pp.11-13: intent.md template, intent/ folder in the product repo, merge = accept, leading/lagging indicators

#### sdlc-2: Plan: no issue forms or triage labels, though LESSONS.md and README.md send people to issues

*Medium. Release: R0.*

Some work has to arrive as tickets (p.11): crash reproductions, device-check failures, CI flakes and bug reports.

- docs/LESSONS.md tells agents to 'open a GitHub issue' for a disabled crash reproduction.
- README asks bug reporters for steps, device and iOS version, and warns them not to post personal phrases.
- No .github/ISSUE_TEMPLATE exists. The labels are GitHub's defaults plus accessibility, dependencies and github_actions.
- The reference app had an issue form ('Something went wrong') and triage labels: needs-triage, needs-info, ready-for-agent, ready-for-human, wontfix. Its wording is about one person and needs generalizing.

**Recommendation.** Add .github/ISSUE_TEMPLATE/something-went-wrong.yml. It is not a workflow file, so a cloud session can push it. Its fields:
- What you were trying to say or do.
- What happened instead.
- Device, iOS version and orientation.
- Input method: touch, Voice Control, Switch Control, Full Keyboard Access, AssistiveTouch Dwell, head tracking or Eye Tracking.
- How often it happens.

It should open with a warning: 'This is public. Do not include your own phrases, screenshots that show them, names or medical details.'

Also add:
- An agent-facing 'crash reproduction' form that names the disabled test.
- A config.yml that turns off blank issues and links to private vulnerability reporting (.github/SECURITY.md) and the support page.

The owner creates the labels: needs-triage, needs-info, ready-for-agent, ready-for-human, crash, device-check. A triaged issue ready for work becomes an intent (sdlc-1) or a small fix PR.

**Evidence.**

- docs/LESSONS.md:58-64 ('open a GitHub issue for it')
- README.md:141-145 (bug reports; no personal phrases or medical details in public issues)
- ls .github: no ISSUE_TEMPLATE; GET /repos/.../labels: default labels plus accessibility, dependencies, github_actions
- Reference app .github/ISSUE_TEMPLATE/something-went-wrong.yml (private repo, read only)
- Playbook p.11: intent can enter as a filed ticket

#### sdlc-3: Design: no per-change spec, and *Proposed decisions* is cited but missing

*Medium. Release: R0.*

The playbook pairs each accepted intent with a spec.md (pp.15-17). The spec flags concerns first, each resolved with its policy owner, and accepting the spec is what starts the plan. Brickson's nearest equivalents are:
- The 2026-10-15 direction memos, which the recon index calls 'research, not instructions'.
- The recon synthesis's table of decisions only the owner can make.
- A Figma thread's docs/DESIGN.md, which is not in the repository yet.

None is a per-change artifact the owner accepts before build. HANDOFF.md and ROADMAP.md send the owner to DECISIONS.md *Proposed decisions*, which does not exist on this branch.

Brickson's 'policies as skills' (p.15) already exist in other forms: AGENTS.md's invariants and dwell design rules, the privacy policy, LESSONS.md, and App Store requirements (docs/APP-STORE.md, in progress). A spec pass should load them and list every conflict as a flagged concern. Example: the recon table records that invariants 3 and 7 pull apart on 'Replace on import'.

**Recommendation.** Keep each spec next to its intent, as docs/intents/<topic>.spec.md or a 'Spec' section in the intent file. Its sections:
1. Flagged concerns first: each names the invariant, decision or policy sentence, the owner (always the owner for product calls), and a recommendation.
2. Requirements.
3. Design: named slots and positions, never device models (the owner's 2026-10-21 rule).
4. Privacy-policy and App Store sentences affected.
5. Acceptance tests, each with the change that would make it fail.
6. Device checks needed.

Ask the flagged concerns in one batched decision card (AGENTS.md, *Working with the owner*). The owner's merge of the spec starts the plan.

Add the *Proposed decisions* section to DECISIONS.md in this same pull request, or remove the citations.

**Evidence.**

- docs/recon/README.md:7-12 (research, not instructions)
- docs/recon/2026-10-15/README.md:681-719 (decisions only the owner can make; invariants 3 and 7 conflict on replace)
- docs/HANDOFF.md:86 and docs/ROADMAP.md:12,94,100 cite *Proposed decisions*; grep finds no such heading in docs/DECISIONS.md
- Playbook pp.15-17: flagged concerns first, policy owner, 'the pair', spec acceptance starts plan mode

#### sdlc-4: The branch cites docs/SDLC.md and other targets that do not exist yet

*Medium. Release: R0.*

Commit f88766e makes AGENTS.md point every agent and reviewer to docs/SDLC.md, and README, HANDOFF and ROADMAP link to it too. The file does not exist. HANDOFF also cites *Proposed decisions* (see sdlc-3).

ROADMAP's 'All the time' list cites DECISIONS.md 'Build with Apple's current Xcode', which exists only in open PR #12.

The working copy of HANDOFF.md now says workflow files are committed by the owner per 'docs/SDLC.md, *Deploy*'.

Nothing in CI checks repository markdown links. scripts/test-site.py checks only the website's links. A heading mismatch of exactly this kind already happened once: AGENTS.md and the review skill cited 'Known gaps' while the heading said something longer (fixed in 131ccdc).

**Recommendation.** Land docs/SDLC.md and *Proposed decisions* in the same pull request as the links to them. Keep ROADMAP's citation of the Xcode decision until PR #12 merges, but say 'once PR #12 merges'.

Then add the deterministic configuration check described in sdlc-16. It catches this whole class of drift for every agent, not only Claude.

**Evidence.**

- AGENTS.md:41-44 (docs/SDLC.md entry, commit f88766e)
- docs/HANDOFF.md:6-7; README.md 'Documentation' list; docs/ROADMAP.md:73
- ls docs: no SDLC.md (2026-10-21)
- docs/ROADMAP.md:131-132 cites 'Build with Apple's current Xcode' (only in PR #12's DECISIONS.md diff)
- scripts/test-site.py: test_links_and_assets_remain_local_and_resolve checks site/ only
- commit 131ccdc message: 'Known gaps' heading now matches what AGENTS.md and the review skill cite

#### sdlc-6: Build: no committed .claude/settings.json, so AGENTS.md's 'never' rules are advisory only

*Medium. Release: R0.*

There is no .claude/ directory in the repository. .gitignore ignores only .claude/settings.local.json, .claude/worktrees/ and .claude/skills/, so a committed .claude/settings.json and .claude/agents/ would be tracked.

The playbook backs each must-hold policy with a hook (pp.26-27, 40-41). Several AGENTS.md rules are written as 'never' and enforced only by reading:
- Never edit the generated project.
- Never use git add -A.
- Never force-push or push to main.
- Agents never add Copilot as a reviewer, because each review spends the owner's credits. This session's tool list includes mcp__github__request_copilot_review.
- Snapshots in docs/archive/ are read-only, and the research in docs/recon/ is kept as written.
- docs/log/ takes only new files.
- The privacy policy changes only with a new Effective date.

One limit applies: hooks cover Claude sessions only. Changes from Codex, Jules or the owner are still caught only by CI and review (sdlc-16).

**Recommendation.** After sdlc-5, commit .claude/settings.json with these pieces.

1. A PreToolUse hook on Bash running .claude/hooks/guard-bash.sh (stdlib only, fast). It parses the command and denies, with a reason that cites the AGENTS.md line:
   - git add -A, --all or '.';
   - git push with --force, -f or a '+' refspec, or any push to main;
   - gh pr merge, merge or auto-merge calls through gh api, and gh pr review --approve;
   - App Store uploads: xcrun altool, iTMSTransporter, an xcodebuild export with an upload destination.
   Parse the command in a script rather than rely on rules alone, because simple patterns are bypassable.

2. A PreToolUse hook on Edit|Write that:
   - denies changes to Brickson.xcodeproj/**, docs/archive/** and docs/recon/**;
   - asks before changing an existing docs/log/ file, since only corrections are allowed;
   - adds a reminder when site/privacy/index.html is edited (update the Effective date) or when .github/workflows/** is edited (the owner commits it; put the full text in the pull request);
   - denies any absolute home-folder path written into a committed file.

3. Under permissions.deny: mcp__github__merge_pull_request, mcp__github__enable_pr_auto_merge, mcp__github__request_copilot_review, mcp__github__assign_copilot_to_issue and mcp__github__create_pull_request_with_copilot.

4. A SessionStart command hook that prints git status, git log --oneline -15 and HANDOFF's 'State as of' line, and says 'cloud session: nothing here builds Swift' when $CLAUDE_CODE_REMOTE is true.

Each block explains itself (p.40). Test the guard scripts with the Python suite that CI already runs.

**Evidence.**

- ls -la .claude: does not exist
- .gitignore, Claude Code block
- AGENTS.md:96-97 (agents never add Copilot), 111-113 (never edit the generated project), 396-401 (stage only your own changes, never force-push, never push to main)
- docs/log/README.md:3-5,54-56; docs/recon/README.md:4-5; docs/archive/README.md
- https://code.claude.com/docs/en/permissions.md: 'Bash(git push *)' does not match 'git -C . push origin main' (bypass forms)
- https://code.claude.com/docs/en/hooks.md: PreToolUse permissionDecision allow/deny/ask; SessionStart stdout added as context
- Playbook pp.26-27, 40-41

#### sdlc-8: Build: no plan is written and committed before code

*Medium. Release: R0.*

The playbook commits plan.md before any code (pp.19-20). It names the files that change, the order of work, the risks and the proof, and the reviewer later checks the diff against it.

Brickson's pull request template (Before and After, How, Verified, checklist) and its docs/log template (What changed and why, Commits, Verified, Not verified, Follow-ups) are both written after the code. The plans threads make exist only in each session's transcript.

So no reviewer can check that the diff matches an accepted plan, and higher-risk changes reach the owner only as finished diffs. Examples of higher risk: speech and audio, storage migrations, dwell placement, the privacy policy, workflows, AGENTS.md.

AGENTS.md already has the pieces a good plan needs: test first, naming the change that would make each test fail, and asking the owner only about real trade-offs.

**Recommendation.** Make each pull request's first commit its docs/log/<date>-<topic>.md with a new '## Plan' section:
- Intent link.
- Files that change.
- Order of work.
- Risks: the invariants touched, and the dwell chains to score.
- Proof: each new test and the change that would make it fail.
- Device checks needed.
- What the owner must decide.

Open it as a draft. Copilot's automatic review skips drafts (DECISIONS.md:413); whether Codex does is not verified. Mark it ready when it is done.

A plan that touches invariants 2, 3, 4, 5, 7 or 10, the schema, the privacy policy, workflows or AGENTS.md waits for the owner's answer on one batched decision card before code. Routine plans proceed.

When the work departs from the plan, update it in the same commit (p.20).

Add a compliance rule to *Code Review Rules*: the diff does what the Plan says, or the Plan was changed with it.

**Evidence.**

- .github/pull_request_template.md:1-35
- docs/log/README.md:22-52 (record written after the change)
- AGENTS.md:368-374 (test first; name the change that would make it fail), 415-423 (routine decisions yourself; ask about real trade-offs, batched)
- Playbook pp.19-21: plan.md, interrogate the plan, update it in the same commit when it changes, routine changes approved by the engineer, higher risk to a lead

#### sdlc-9: Build: AGENTS.md follows the CLAUDE.md practice but is nine pages long and repeats DECISIONS.md

*Low. Release: All the time.*

Brickson already does much of the CLAUDE.md practice (pp.23-24):
- One shared briefing, loaded through CLAUDE.md as @AGENTS.md.
- Gotchas play the role of 'Things Claude gets wrong'.
- New rules go into AGENTS.md as part of 'Document every change'.
- DECISIONS.md says Codex, Copilot and Claude all review against AGENTS.md's Code Review Rules.

Two gaps remain:
- It is 525 lines (30 KB), where the playbook says 'under a page'. Its 'Reviews and updates on GitHub' paragraph restates DECISIONS.md, *Code review* and *Code scanning*.
- Its *Build and test* lists commands without the healthy output each should print (p.32 step 2; see sdlc-14).

Cutting invariants or review rules is not the fix: Codex and Copilot read only AGENTS.md and the files GitHub names.

**Recommendation.** Keep the invariants, design rules and *Code Review Rules* in AGENTS.md. Replace restated settings detail with one-line pointers into DECISIONS.md, and move long dated gotcha stories into LESSONS.md, leaving a one-line rule.

Track 'a mistake made twice': when a Codex or Copilot finding cites the same rule on two pull requests, the fix goes into AGENTS.md as part of that pull request (p.38 step 5).

Snapshot AGENTS.md under docs/archive/ before trimming it (AGENTS.md:409-412).

**Evidence.**

- CLAUDE.md: '@AGENTS.md'; AGENTS.md:1-6
- wc -l AGENTS.md: 525
- AGENTS.md:90-105 restates docs/DECISIONS.md:263-305 and 321-399
- AGENTS.md:402-412 ('this file for any new rule or gotcha')
- Playbook p.23 (under a page; mistake twice goes in), p.38 step 5

#### sdlc-10: Build: ten parallel threads feed one beginner reviewer, past the playbook's ceiling

*High. Release: R0.*

The playbook advises starting with two or three sessions, because 'the practical ceiling is how many streams one person can review properly'. Tasks that share files should run one after another in a single session (p.28).

The working copy of HANDOFF.md now says ten threads work in parallel. The one merger is new to programming. Threads also overlap on files:
- ROADMAP rows 3, 4 and 5 all change Home (Get Attention's placement 'waits for item 3's slots').
- PR #12 and the test-seams work both change scripts/test.sh and project.yml settings.
- Several threads edit AGENTS.md and DECISIONS.md.

PR #12 alone carries 13 review comments. The split into docs/log/ (131ccdc) removed one hot file, but nothing limits how many pull requests wait on the owner at once.

**Recommendation.** Set a WIP limit in docs/SDLC.md: at most three pull requests ready for the owner's review at once, with a merge order in ROADMAP. Other threads keep working, as drafts or plans.

Add a 'Files it changes' column to ROADMAP. Threads that share HomeView, project.yml, scripts/test.sh or AGENTS.md take turns, in ROADMAP order.

Keep each pull request reviewable in about ten minutes: one task, with 'What changes for the person' first.

Track the indicator 'ready pull requests waiting on the owner, and the age of the oldest' (p.29).

**Evidence.**

- docs/HANDOFF.md working copy, line 10: 'Ten threads are working in parallel on the first release, R0'
- docs/ROADMAP.md:60-73 (rows 1-5, shared Home and test-script work)
- GET /pulls/12: 13 review comments, 8 commits, mergeable_state blocked
- commit 131ccdc (one log file per PR so parallel threads stop conflicting)
- AGENTS.md:415-423 (the owner is new to programming)
- Playbook p.28 steps 1 and 3

#### sdlc-11: Build: the committed review skill is given only to Copilot; Claude threads could self-review with it before asking for review

*Low. Release: All the time.*

Skills are advisory controls that ship with the code (pp.25-26). Brickson's only committed skill is .github/skills/code-review/SKILL.md. It holds review steps that cite AGENTS.md rules, and it is written for Copilot.

Per-machine skills are gitignored, and cloud agents 'usually have none'. AGENTS.md says new review rules go in AGENTS.md, not a skill, so adding policy skills would split the rules.

What is missing is Claude using the same method on its own branch before a pull request is marked ready. That would catch findings before Codex, Copilot and the owner do, and save the owner's Copilot credits on re-requests.

Measure it the playbook's way: findings that cite a given rule should fall towards zero (p.26).

**Recommendation.** Add to AGENTS.md *Workflow rules*: 'Before marking a pull request ready, apply .github/skills/code-review/SKILL.md to your own diff against main and fix or answer each finding in the docs/log file.'

Do not add policy skills. If a procedure skill is ever wanted (for example, writing an intent, or recording a device check), keep it method-only like the review skill. Note that .claude/skills/ is gitignored, so it needs another folder or a .gitignore change, and the owner decides.

**Evidence.**

- .github/skills/code-review/SKILL.md:1-20 (method only; rules in AGENTS.md)
- AGENTS.md:441-453 (skills per machine, ignored by git; new review rules go in AGENTS.md)
- docs/DECISIONS.md:279-298 (rules in one place; the skill is an accepted reviewer file)
- Playbook pp.25-26

#### sdlc-12: Build and Test: no verifier subagent for cloud threads

*Medium. Release: R0.*

The playbook packages the final check as a verifier subagent in .claude/agents/. It runs in a fresh context, reports what ran and any mismatch with the plan, and fixes nothing (pp.29, 31).

Brickson's cloud threads cannot build Swift; AGENTS.md says to treat their changes as untested until CI or a Mac run passes. Today each thread checks CI by hand. PR #12's thread posted a 'CI status for this PR' comment explaining a red UI-test run.

The repository has no .claude/agents/. Claude Code's documentation says repo subagents load in cloud sessions, but in the two-repository setup described in sdlc-5 that is not verified.

**Recommendation.** Add .claude/agents/verifier.md (tools: Bash, Read, Grep; report only). It:
- runs the Python suites (scripts/test-site.py, scripts/test-runner.py, and scripts/test-select-xcode.py once PR #12 lands);
- finds the branch's latest CI run through GitHub's REST API, reads the job logs and states the Xcode and simulator lines from the 'Show the Xcode version' steps;
- downloads screenshots once sdlc-13 exists;
- compares the diff with the docs/log Plan;
- writes what ran, where, and what was not verified.

For a change that needs a simulator run CI does not do (iPhone, the largest text size, dark mode), ask the owner to approve a Remote Control session on the Mac running scripts/test.sh with a DESTINATION.

This is a new instruction file, so the owner decides (AGENTS.md, *Tests, workflows and the rules themselves*). It depends on sdlc-5.

**Evidence.**

- ls .claude: does not exist
- AGENTS.md:107-109 (cloud agents cannot build; untested until CI or a Mac run)
- PR #12 issue comment by the agent (2026-10-21T02:23:19Z): 'CI status for this PR, so a red check isn't read as broken code'
- https://code.claude.com/docs/en/claude-code-on-the-web.md:281 (repo .claude/agents/ picked up); sub-agents.md frontmatter fields name, description, tools
- Playbook p.29 (verifier example), p.31 (verifier versus feedback loop)

#### sdlc-16: Test: nothing checks the agent configuration, so drift has already slipped through twice

*Medium. Release: R0.*

The playbook reruns evals whenever the agent's configuration changes, and turns every incident into a permanent eval (pp.34-35). Brickson's agent configuration is AGENTS.md, CLAUDE.md, .github/copilot-instructions.md and .github/skills/code-review/SKILL.md, plus any future .claude/ files.

Drift a check would have caught:
- A heading cited by the review skill and AGENTS.md ('Known gaps') did not exist; fixed in 131ccdc.
- Copilot's privacy exception was narrower than AGENTS.md's, so it flagged the README; fixed in f88766e.
- docs/SDLC.md and *Proposed decisions* are cited today but missing (sdlc-4).

PR #12's WorkflowTests in scripts/test-runner.py already test configuration deterministically, which is the right model.

The playbook's agent-evals.yml (p.35) does not fit as written. It needs an Anthropic API key secret in CI, which costs the owner money and is the kind of secret exposure AGENTS.md's *Code Review Rules* flag. Running evals against Codex or Copilot through real pull requests would spend the owner's credits.

**Recommendation.** Tier 1, now: deterministic checks added to a Python script that tests.yml already runs, so no workflow change is needed. They check that:
- every *Section title* cited by SKILL.md, copilot-instructions.md and AGENTS.md exists in the cited file;
- every relative link in README.md and docs/ resolves;
- every 'docs/DECISIONS.md, "Title"' in Swift comments resolves;
- no committed file holds an absolute home-folder path.

Tier 2, offline: evals/review/, with about 20 seeded-defect diffs drawn from the invariants and real history. Examples:
- a confirm step before speaking;
- Emergency inside a ScrollView;
- white on system red;
- Date() used for elapsed time;
- cloudKitDatabase not .none;
- a phrase in fatalError;
- the Keychain;
- URLSession;
- a renamed required job;
- pull_request_target;
- a price word.
Each names the expected invariant. A Claude subagent applying the review skill runs them whenever AGENTS.md or the skill changes, and monthly, inside a cloud session, with no API key in CI. A drop is reported to the owner before the change merges. Every incident adds a case (p.35 step 5).

**Evidence.**

- commit 131ccdc message (heading now matches what AGENTS.md and the review skill cite)
- commit f88766e (copilot-instructions privacy exception aligned with AGENTS.md)
- PR #12 diff: scripts/test-runner.py WorkflowTests (tests.yml must switch Xcode, no version written)
- AGENTS.md:337-340 (secrets reachable from pull request code is a finding)
- Playbook pp.34-35 (20-50 tasks; run on config change; gate; incident becomes eval); p.34 (offline cadence allowed)

#### sdlc-17: Deploy: the review loop is strong; do not add REVIEW.md, but take its compliance pass and its monthly tuning

*Low. Release: All the time.*

What exists already matches most of pp.37-39:
- Codex reviews every push, Copilot each pull request once when it opens, and AI Scan each push.
- The ruleset requires conversation resolution, the 'Unit tests' and 'UI tests' checks, and CodeQL results.
- Findings never approve; Copilot's auto-approval stays off.
- The review skill sets High, Medium and Low severity and says 'You review. You do not approve'.
- *Not findings* already excludes formatting.
- Baseline from GitHub's API: the first bot review came within about 6 minutes on 9 of 11 agent pull requests, which meets the playbook's 'minutes' target.

REVIEW.md is the file Claude's managed Code Review reads (p.38), and Brickson does not use that service. Copilot would read a REVIEW.md if one were added, making a second rule location. DECISIONS.md and AGENTS.md keep the rules in one place and flag any new reviewer-instruction file.

What REVIEW.md has that Brickson lacks:
- a compliance pass against the spec and plan (see sdlc-8);
- an explicit 'do not report what CI enforces';
- monthly tuning (p.38 step 6).

**Recommendation.** Record in DECISIONS.md: 'No REVIEW.md; AGENTS.md *Code Review Rules* is Brickson's review policy.'

Add to *Code Review Rules*:
- a compliance bullet (the diff against the Plan and spec);
- under *Not findings*, 'anything the Python checks or CI already fail on'.

Once a month, the Roadmap thread lists the merged pull requests' Codex, Copilot and AI Scan comments through the REST API, and counts which were fixed, which were answered as not findings, and which rules repeat. A repeated mistake becomes an AGENTS.md line, and noise becomes a *Not findings* line. The owner approves both, since they change reviewer instructions.

**Evidence.**

- docs/DECISIONS.md:263-305, 401-415
- AGENTS.md:518-524 (Copilot reads REVIEW.md if added), 343-347 (a new reviewer-instruction file is a finding)
- .github/skills/code-review/SKILL.md:19-20, 133-141
- GET /pulls/{n}/reviews (2026-10-21): first bot review 1.4-6 minutes after opening on #1, #3, #5, #6, #8-#12; 44 minutes on #2; none on #4 and #7
- Playbook pp.38-39

#### sdlc-20: Maintain: there is no incident record; past incidents are scattered across five documents

*Medium. Release: All the time.*

The incident record is the Maintain stage's artifact (p.7), and post-mortems go to a version-controlled lessons file (p.52). Brickson has already had several incidents, each written somewhere different and without a standard record or regression check:
- PR #7 merged with no CodeQL analysis.
- A failed Swift CodeQL configuration still sits on the Tool status page.
- The first UI test on a just-started CI simulator fails intermittently.
- A cloud session's push of tests.yml was refused.
- HANDOFF grew to 474 stale lines.
- A cited heading drifted.
- Versions were pinned without the owner choosing them.

docs/LESSONS.md holds the reference app's lessons, not Brickson's own. Once people use the app, a user-facing incident (a crash, a phrase that did not speak, Emergency out of reach) must be recorded without copying their words. The privacy policy promises that TestFlight screenshots, which show phrases, are never shared.

**Recommendation.** Create docs/incidents/YYYY-MM-DD-<topic>.md, with a template:
- What the person experienced, if anyone.
- How it was found.
- Severity, using the review skill's scale; anything that stopped communication is High.
- Cause.
- Fix pull request.
- Regression test or eval added (sdlc-16).
- AGENTS.md or LESSONS.md rule added.
- Never a person's phrases, screenshots, names or health details.

Backfill the seven incidents above in one pull request.

Add a 'Lessons from Brickson' part to LESSONS.md for the rules they produced.

**Evidence.**

- docs/DECISIONS.md:376-388 (PR #7 without CodeQL; failed Swift configuration)
- AGENTS.md Gotchas: 'A just-started simulator is slow' (CI flake); PR #12 diff, 'Cloud agents cannot change .github/workflows/'
- commit 131ccdc (HANDOFF 474-line log); PR #12 DECISIONS 'Why' (26.0 written without the owner choosing)
- docs/LESSONS.md:1-17 (lessons from the reference app)
- site/privacy/index.html:93 ('Screenshots show your phrases ... never share them')
- Playbook p.7, p.35 step 5, p.50 step 7, p.52

#### sdlc-21: Maintain: no signal list, thresholds or scheduled sweep, though non-analytics signals exist

*Medium. Release: All the time.*

The playbook keeps detection deterministic and lets Claude act only through gated routes (pp.48-51). Brickson collects nothing itself, but it still has signals.

From Apple:
- Xcode Organizer crash reports, from people who turned on Share With App Developers. TestFlight testers share crashes automatically.
- Watchdog, jetsam and thermal events are not in the Organizer.
- Apple's App Privacy Details says 'You are not responsible for disclosing data collected by Apple', so using these keeps the 'no data collected' manifest true. The privacy policy already describes them.
- TestFlight feedback, screenshots and crash comments.
- App Store ratings and reviews.

From GitHub and Apple's release feeds:
- CI on main: 10 of 11 push runs succeeded.
- Pull request runs: 18 success, 7 failure, 20 cancelled, out of 46.
- Time to merge: 41 minutes to 2.2 days for PRs #1 to #11.
- Dependabot's monthly pull request.
- PR #12's check, which warns when Apple ships a newer Xcode.

Western Electric sigma bands do not fit counts this small; fixed thresholds do. Claude Code scheduled tasks can start a fresh cloud session on a cron schedule (minimum hourly), so the sweep needs no API key in CI.

**Recommendation.** Write docs/MAINTAIN.md with a version-controlled thresholds table:
- any crash on a released or TestFlight build: incident, High;
- main red twice in a row, not explained by infrastructure: diagnose;
- more than three ready pull requests waiting on the owner: stop starting new work;
- the Xcode in use behind Apple's newest for more than 14 days: toolchain pull request;
- a Dependabot pull request open for 7 days: the owner reads it;
- a major iOS release: rerun the device-check table.

Add scripts/maintain-report.py (stdlib, reads GitHub's REST API). The owner creates a weekly scheduled task that runs it and writes a draft intent or issue for each breach. Claude only diagnoses or opens pull requests.

The owner reads the Organizer, TestFlight feedback and ratings monthly, because agents have no App Store Connect access. An App Store Connect API key would be the owner's decision and never goes in the repository.

**Evidence.**

- https://developer.apple.com/documentation/xcode/acquiring-crash-reports-and-diagnostic-logs.md (Organizer from opted-in users; TestFlight automatic; watchdog, jetsam, thermal not in Organizer)
- https://developer.apple.com/app-store/app-privacy-details/ ('You are not responsible for disclosing data collected by Apple')
- https://developer.apple.com/help/app-store-connect/monitor-ratings-and-reviews/ratings-and-reviews-overview/
- site/privacy/index.html:91-93
- GET /actions/workflows/tests.yml/runs (2026-10-21): push 10 success, 1 failure; pull_request 18 success, 7 failure, 20 cancelled
- GET /pulls/{1..11} created_at and merged_at
- .github/dependabot.yml:17-27; PR #12 scripts/select-xcode.py check
- Scheduled-task tool schema in this session (fresh session per firing, minimum hourly)
- Playbook pp.49-51

#### sdlc-24: Measure each stage from git and GitHub, starting from today's baselines

*Low. Release: All the time.*

Every play names a leading and a lagging indicator (pp.13, 17, 21, 24, 26, 29, 33, 35, 39, 44, 46, 51). Several rely on an OpenTelemetry export, a dashboard or an incident tracker, which Brickson does not have.

Most can be read from git and the GitHub REST API instead:
- hours from chat message to intent commit, and the intent survival rate;
- intent-to-spec time, and spec edits after the plan;
- pull requests merged from the first pass, and plan-to-diff match;
- first-pass CI success on pull requests;
- time to first review, which already meets the target;
- comments resolved without the owner touching the branch;
- ready pull requests waiting on the owner;
- incidents and repeat incidents.

No document records any of these today.

**Recommendation.** In docs/SDLC.md, list one leading and one lagging indicator per stage, using the substitutes above, with the 2026-10-21 baselines.

The monthly review (sdlc-17) and the weekly sweep (sdlc-21) update them through scripts/maintain-report.py.

Report them to the owner in plain words, and only when one moves past its threshold.

**Evidence.**

- Playbook indicator tables pp.13, 17, 21, 24, 26, 29, 33, 35, 39, 44, 46, 51
- GitHub API baselines (2026-10-21): first bot review about 1.4-6 minutes on 9 of 11 agent PRs; merge 41 minutes to 2.2 days; pull request runs 18 success, 7 failure, 20 cancelled of 46

#### sdlc-25: Say plainly which plays do not transfer to a no-server, no-analytics iOS app

*Low. Release: R0.*

These parts of the playbook assume an organization, servers or telemetry that Brickson does not have:
- **Managed settings** through MDM or the admin console, allowManagedHooksOnly, approved marketplaces and requiredMinimumVersion (pp.40, 42-43). There is one owner and no IT department, and device-delivered managed settings do not reach cloud sessions.
- **OpenTelemetry and the analytics dashboard** (pp.29, 33, 44). Use GitHub metadata instead (sdlc-24).
- **Deploy tools behind MCP, per-environment tiers, and one-command rollback** (pp.44-46). The owner uploads; TestFlight is the staging tier; the App Store has no rollback (sdlc-19).
- **Post-deploy 5xx rates, Prometheus and sigma bands on production metrics** (pp.49-51). There are no servers and no analytics; use fixed thresholds over Apple-held signals (sdlc-21).
- **claude-code-action or managed Code Review with an API key on pull requests** (pp.37-38, 45). Codex and Copilot already review, and secrets reachable from pull request code are a review finding.
- **Claude Tag in Slack** (p.52). The project's threads already play that role.
- **The legacy-system sidebar** (p.22). The repository is the source of truth, and project-thread links are the linkage.
- **TestFlight feedback webhooks to the developer's web server.** They need a server.
- **MetricKit payloads sent off the device.** That is network code, a hard stop.
- **DORA lead time.** It includes App Review's wait, which the project does not control.

**Recommendation.** Put a 'What we do not adopt, and why' table in docs/SDLC.md, with the substitute for each: GitHub metadata, owner-run uploads, fix forward, fixed thresholds, Codex and Copilot, project threads, and the repository as source of truth.

That way no thread later adds an API-key workflow, a webhook server or a telemetry SDK in the playbook's name.

**Evidence.**

- Playbook pp.22, 29, 33, 37-38, 40-46, 49-52
- https://code.claude.com/docs/en/cloud-environments.md ('What carries over': MDM or managed settings files do not apply in cloud sessions)
- AGENTS.md:115-191 invariant 9 (no servers, network code or analytics); AGENTS.md Code Review Rules (secrets reachable from pull request code)
- https://developer.apple.com/help/app-store-connect/test-a-beta-version/view-tester-feedback/ (webhooks to your web server)
