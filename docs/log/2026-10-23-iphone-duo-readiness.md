# Getting ready for iPhone Duo

*2026-10-23. The pull request from `claude/project-thread-k0cmyj`. The
"iPhone Duo readiness" thread, a cloud session that cannot build: it read
Apple's pages, the code on `main` (`412f4cf`) and the Xcode skills the
owner exported into the Mac's checkout. Documents only; no Swift code or
`project.yml` changed.*

## What changed and why

iPhone Duo, Apple's foldable iPhone, went on sale on 23 October 2026. The
owner passed on Apple's notice that iPhone Duo screenshots become
required in April 2027, and exported Apple's Xcode skills for agents to
use. This record keeps exactly what Apple says, checks Brickson against
it, and plans the work:

- **docs/ROADMAP.md:** R0 item 13, *Ready for iPhone Duo*, inside the
  release gate, so no build goes to App Review before it is done.
- **docs/DECISIONS.md:** a new entry, "iPhone Duo", with the routine
  choices as reversible defaults, and two fold choices that were the
  owner's (*The fold*), because they change Home's columns and spacing on
  iPhone Duo. The pull request first asked them as questions; the owner
  accepted both recommendations the same day, before holding an iPhone
  Duo: Home keeps its controls off the fold when the phone is partially
  folded, by widening the gap there, and uses an even number of columns
  on a display that folds.
- **docs/APP-STORE.md**, sections 2, 9 and 13: the April 2027 requirements
  in Apple's words, the Duo screenshot sizes, and a correction (the inner
  display's screenshots do not wait for the iPhone orientation decision,
  because that display ignores it).
- **docs/ACCESSIBILITY.md:** the iPhone Duo row now points at R0 item 13.
- **AGENTS.md:** *Skills* names Apple's Xcode skills, where they are
  installed and why they are not committed; *Layout on every device and
  window* says the fold and the camera are part of the space available;
  one review rule also names interface orientation and idiom.
- **docs/HANDOFF.md:** a known gap, an owner step and the next step for
  agents. **`.gitignore`:** `/xcode-skills/`, so an export left in the
  checkout is never committed.

**The owner's summary, checked.** Mostly right, with two corrections. Apple
does not make "supporting" iPhone Duo a condition of using the iOS 27.1
SDK: every app runs on iPhone Duo, and an app *built* with the iOS 27.1
SDK or later is treated as optimized for it automatically (it fills both
displays and its system bars can turn vertical). What Apple requires is
the screenshots, from April 2027. And iPhone Duo is "kind of an iPad"
only on its inner display: Apple says "it is still an iPhone app", with
iPad-like size classes inside and iPhone ones outside. The sentence "Get
your apps ready for iPhone Duo so they look and work great across the
latest devices" was not found on the public pages read (it may be from
App Store Connect or an email); the second sentence of the quote is word
for word on the screenshot specifications page.

**The SDK target does not change.** CI already builds with Xcode 27.1
(27A9275) and the iOS 27.1 SDK (run 39923081723's notice: "CI builds with
Xcode 27.1 (27A9275). Apple's newest release is Xcode 27.1 (27A9275).").
Apple's releases page, read 2026-10-23, lists Xcode 27.2 only as a release
candidate (27B48, 19 October). So every build is already a Duo-optimized
build, and the toolchain rule (docs/DECISIONS.md, "Build with Apple's
current Xcode") keeps it that way. Nothing for the toolchain thread to do.

## What Apple says

Every page read on 2026-10-23. Quotes are Apple's words, and nothing is
added to them. The few sentences that apply them to Brickson (what it
must submit, which requirements it meets, why it must run on iPhone Duo)
are this record's reading, and each names Brickson.

**Three steps to make your app shine on iPhone Duo**
(https://developer.apple.com/iphone-duo/prepare/, no date on the page):

- "Apps built with the iOS 27 SDK and later resize dynamically on iPhone
  Duo. Unfold it and your app expands to fill the inner display; fold it
  and your app returns to the outer display. Hardcoded screen sizes, fixed
  orientations, and device assumptions can break layouts, leading to
  stretched, clipped, or misplaced content."
- By SDK: "Apps built with the iOS 26 SDK or earlier run on iPhone Duo,
  but won't adapt to all layouts" (centred on the inner display; "to the
  left of the status bar and camera" on the outer one). "Apps built with
  the iOS 27 SDK resize to fill most of the inner display on iPhone Duo,
  but still avoid the status bar on the right edge." "Apps built with the
  iOS 27.1 SDK or later are optimized for iPhone Duo. Apps will extend to
  use the full display, with toolbars and tab bars appearing vertically
  below the status bar."
- "Before shipping an app build with the iOS 27.1 SDK, make sure your
  app's content adapts to the bars becoming vertical."
- Step 1: ask Xcode's coding assistant to "get my app ready for iPhone
  Duo"; "If you use a different coding agent, export the skill by running
  this in Terminal: `xcrun agent skills export`". "The skill finds most
  issues, but not all of them."
- Step 2: stop sizing from `UIScreen.main`; "Avoid using orientation to
  make layout decisions"; "With iPhone Duo and resizable iPhone Mirroring,
  an iPhone app can have any combination of size classes. On the inner
  display, your app should look like a natural extension of its iPad
  layout." "Don't treat 'regular width' as 'iPad.'" "Remove checks for
  specific device sizes."
- Step 3: test with "The iOS resizable simulator in Device Hub", "iPhone
  Mirroring on macOS 27" and "The iPhone Duo simulator in Xcode 27.1",
  which "is the best way to test the full native experience."
- Go further: iPhone Duo screenshots earn a badge "to let people know your
  app is optimized for iPhone Duo"; a "new preview tool in App Store
  Connect"; a featuring nomination can say the app is "optimized for
  iPhone Duo, including support for all device poses."

**Prepare and submit your apps for iPhone Duo**, Apple Developer News,
5 October 2026 (https://developer.apple.com/news/?id=kkphp5qo): "iPhone Duo
will be available to customers starting October 23, 2026." "Recompile
existing apps with Xcode 27.1, which adds development support for iPhone
Duo." "Starting April 2027, any apps or games submitted will need to
include screenshots for iPhone Duo." The same sentence is on *What's new
in App Store* (https://developer.apple.com/app-store/whats-new/).

**Screenshot specifications**
(https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications):
iPhone Duo screenshots are 1398 × 2034 or 2034 × 1398 pixels (outer
display) and 2007 × 2853 or 2853 × 2007 pixels (inner display). "Starting
in April 2027, screenshots will be required for any app using the iOS
27.1 SDK or later." Required today: "At least one screenshot for iPhone
with Dynamic Island (medium display)" and, for an iPad app, "At least one
screenshot for iPad 13-inch display."

The two statements differ (all submissions, or apps using the iOS 27.1
SDK or later). For Brickson they come to the same thing: it builds with
the newest SDK, so every submission from April 2027 needs them.

**Submitting** (https://developer.apple.com/app-store/submitting/):
"Starting April 2027, apps and games uploaded to App Store Connect need to
meet the following minimum requirements": "iOS and iPadOS apps must be
built with the iOS & iPadOS 27 SDK or later, and target iOS 15 or later".
Brickson builds with the iOS 27.1 SDK and targets iOS 26.0, so it meets
both.

**Preparing your app for iPhone Duo**
(https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo):

- "Check how your app appears on both displays, when closed, open, or
  partially folded. Rotate iPhone Duo in each pose".
- "Identify elements or controls in your views that appear in the fold,
  and are difficult to see or interact with."
- "Size your views relative to their container rather than to fixed
  iPhone dimensions." "Make layout calculations based on your scene or
  containing view's bounds rather than screen dimensions."
- Bars turn vertical "on the outer display when the device is closed, and
  for some views in the leading or trailing position on the inner display
  when the device is open". "On the outer display, the system presents
  bars vertically for sheets by default", and `toolbarVerticalBehavior(_:)`
  turns that off.
- Reserved regions: "A division occurs when a folding region divides a
  large view into smaller views. An occlusion is an area of a view where a
  hardware element, such as the camera, covers your content". "The inner
  front-facing camera can block your view when it's active, and the outer
  front-facing camera always occludes your view." SwiftUI reads them with
  `GeometryProxy.reservedRegions(kind:options:layoutDirectionBehavior:)`;
  "a reserved region that represents the fold is active when iPhone Duo is
  partially open, but inactive when it is fully open."
- Arrangement views (`ArrangementView`): a container for a primary and a
  secondary view; "Avoid placing an arrangement view inside a navigation
  split view, list, scroll view, or other container that might cause part
  of your view to become inaccessible."

**Designing for iPhone Duo**, Human Interface Guidelines, new page of
9 September 2026
(https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo):

- "Although iPhone Duo is a new form factor, keep in mind that you're
  still designing for iPhone".
- "Supporting the device's various poses doesn't mean designing a custom
  layout for each one: instead, use size classes so your app adapts
  naturally as it changes size." "Avoid fixed widths and display-specific
  dependencies."
- "In a grid-style layout, prefer an even number of columns so content
  divides cleanly. Use the `ReservedRegion` API to keep important elements
  clear of the center if the system doesn't move them automatically."
- "Avoid extreme layout changes as people fold the device. Move only
  what's necessary to keep elements visible and easy to tap."
- "Keep controls consistent across device poses. … keep controls'
  relative positions as similar as possible so people don't have to
  relearn where actions live as they change between poses."
- "In general, don't override the default bar placement."

**Tech talks** (transcripts on developer.apple.com):

- *Prepare your app for iPhone Duo*
  (https://developer.apple.com/videos/play/tech-talks/111461/): the outer
  display has iPhone size classes; "On the inner display … it has regular
  horizontal and vertical size classes." "The inner display doesn't honor
  your supported interface orientations." Later: "iPhone Duo will continue
  to honor the UIRequiresFullScreen key, but your app will still resize
  when someone opens or closes their iPhone Duo. iPhone Duo respects your
  supported interface orientations, but your app will scale on the inner
  display, including in Split View multitasking." "Your app may react to
  different size class boundaries, but it is still an iPhone app." The
  main screen "is ambiguous and will be deprecated in a future release."
  "With Xcode 27.1, this skill has a new name: App Resizability. It now
  supports SwiftUI and iPhone Duo."
- *Strike a pose with adaptive layouts on iPhone Duo*
  (https://developer.apple.com/videos/play/tech-talks/111463/): "On iPhone
  Duo, the fold's division region is only active when someone has folded
  the device. When flat, it's inactive and has a width of zero." In
  grid-like layouts, "you could prefer even numbers of columns when a
  division region is present regardless of its active state." For a grid
  that must stay usable when folded: "I can preserve the outer margins
  while increasing the spacing around the hinge". "Continuous scrolling
  content … don't displace."
- *Design for iPhone Duo*
  (https://developer.apple.com/videos/play/tech-talks/111466/): "We found
  buttons are tough to tap when they land right in the fold. So we
  designed a behavior that nudges interactive elements aside whenever
  iPhone Duo is partially folded. It's built into a bunch of system
  components, including sheets, alerts, menus, toolbar buttons, and more."
  "You don't want to tie functionality to a specific pose."
- *Raise the bar with iPhone Duo*
  (https://developer.apple.com/videos/play/tech-talks/111462/): "Keep
  control placement consistent so people don't have to relearn where
  actions live as they use iPhone Duo"; a sheet "control-heavy with only
  one item" may disable its vertical bar with `toolbarVerticalBehavior`.
- *Leverage multiple displays and scenes on iPhone Duo*
  (https://developer.apple.com/videos/play/tech-talks/111464/): "All apps
  participate in multitasking on iPhone Duo, where two apps can be placed
  in a side-by-side layout." "iPhone Duo is the first iPhone to support
  multiple instances of your app's UI. If your app supports this on iPad,
  it will on iPhone Duo as well." "On the outer display of iPhone Duo, new
  windows cannot be created." Of `onHingeChange`: "Hinge data is observed
  live, and is ideal for driving interactions or effects. For layout, use
  the arrangement and region APIs."

**iPhone Duo technical specifications**
(https://www.apple.com/iphone-duo/specs/): inner display "7.6‑inch
(diagonal)", "1878‑by‑2670-pixel resolution at 430 ppi"; outer display
"5.4‑inch (diagonal)", "1398‑by‑2034-pixel resolution at 460 ppi"; ships
with iOS 27; its accessibility features include Eye Tracking, Switch
Control, AssistiveTouch, Voice Control, Personal Voice, Live Speech and
Assistive Access. Because it can use Eye Tracking, docs/DECISIONS.md,
"Minimum iOS, iPhone and iPad", rule 1, already says Brickson must run
on it.

## Apple's Xcode skills

The owner exported them on 2026-10-23 into a folder `xcode-skills/` at
the root of the Mac's checkout (untracked; 84 files). Ten skills:
`app-resizability`, `swiftui-specialist`, `swiftui-whats-new-27`,
`app-intents-specialist`, `app-intents-whats-new-27`, `modernize-tests`,
`device-interaction`, `audit-xcode-security-settings`,
`adopt-c-bounds-safety` and `building-document-based-swiftui-applications`.
Five of them say "This guidance was written and published by Apple";
Apple's page calls the export "the skill" Xcode's assistant runs.

**Not committed.** No file carries a license. They ship inside Xcode,
which the *Xcode and Apple SDKs Agreement* governs (EA2002, 06/08/2026,
https://www.apple.com/legal/sla/docs/xcode.pdf). Its section 2.7 says:
"unless otherwise expressly permitted by Apple in writing, You agree not
to rent, lease, lend, upload to or host on any website or server, sell,
redistribute, or sublicense the Apple Software and Apple Services, in
whole or in part". Apple's page permits exporting them for "a different
coding agent", which is use on the owner's own Mac, not publishing.
Committing them to this public repository would host and redistribute
them, so they stay per machine, like the other skills (AGENTS.md,
*Skills*). This is a reading of the agreement's words, not legal advice.

**Installed on the Mac** (2026-10-23): eight were copied into the
checkout's `.agents/skills/` (ignored by git), with `.claude/skills/`
symlinks for every skill there, as AGENTS.md describes. The two that do
not apply were left out: `adopt-c-bounds-safety` (Brickson has no C) and
`building-document-based-swiftui-applications` (Brickson is not a
document app). The export in `xcode-skills/` is untouched; the owner can
delete it.

**Running the App Resizability skill's checks.** This session cannot run
Xcode's assistant, so it applied the skill's prerequisites and detection
patterns by hand to `main` (`412f4cf`):

| Check | Result |
|---|---|
| Launch screen | Satisfied: `UILaunchScreen` in `project.yml` |
| iPad orientations | Satisfied: all four |
| `UIRequiresFullScreen` | Absent: satisfied |
| `UIScreen.main`, `UIDevice`, `userInterfaceIdiom`, interface orientation, size classes for layout | None anywhere in `Brickson/` |
| Scene lifecycle | Not applicable: a SwiftUI `App` with one `WindowGroup`, no app delegate |
| Safe areas | No inset arithmetic. Home sizes from `GeometryReader`'s `proxy.size`, already inside the safe area; its 16pt side padding is a design margin, not a stand-in for an inset; `.ignoresSafeArea(.keyboard)` is scoped. Two broad uses: the privacy policy's Safari sheet (`.ignoresSafeArea()` on `SFSafariViewController`, which lays out its own bars) and the debug-only keyboard probe (`.ignoresSafeArea(.container)`) |

## How Brickson stands

**Already covered:**

- **Built with the iOS 27.1 SDK**, so the Duo-optimized behaviour already
  applies, and the toolchain rule keeps the SDK current.
- **Layouts from the space available** (AGENTS.md, *Layout on every
  device and window*; docs/DECISIONS.md, "Layouts from the space
  available"): `HomeShape` takes only the width it is given; nothing names
  a device, an orientation or an idiom. This is what Apple asks for first.
- **Positions never move** (invariant 8) is a stricter form of the HIG's
  "keep controls' relative positions as similar as possible".
- **Standard buttons** (invariant 1): Eye Tracking, Switch Control and
  Voice Control on iPhone Duo reach them like on any iPhone.
- **Deployment target 26.0** meets April 2027's "target iOS 15 or later".

**Not covered, or not known yet:**

1. **Never run on iPhone Duo.** CI's image listed only the iOS 27.0
   simulator runtime on 2026-10-23 (run 39923081723), and
   `scripts/choose-simulator.py` picks only standard models
   (`iPhone-<number>`), so CI never tests a Duo. The owner's Mac lists an
   "iPhone Duo" simulator on iOS 27.1 (2026-10-23).
2. **Landscape on the inner display.** The iPhone is portrait-only
   (docs/DECISIONS.md, "Orientations"; `AppBundleTests`), but "The inner
   display doesn't honor your supported interface orientations." So Home
   meets a landscape phone window there whatever the setting says. The
   layout already works in wide windows (iPad), but the starter library
   scrolls in some small landscape iPad windows (docs/DECISIONS.md, *Where
   the grid still scrolls*); the inner display is not measured.
3. **The outer display's shape.** Apple: "the outer display is wider and
   shorter than the display on other iPhone devices", with the status bar
   and camera on one side. Whether the starter library fits without
   scrolling (invariant 11) is not measured.
4. **The fold.** Partially folded, a division region crosses the inner
   display. Home's phrase grid has three columns where they fit, and its
   category row can be three columns; the slot plan (docs/DECISIONS.md,
   "Home's slot plan") has three columns at compact widths and five at
   regular widths. With an odd count, a column sits on the fold. Apple's
   system components move their own buttons out of the fold; whether that
   also moves Home's buttons, which sit in plain stacks, is unknown. If it
   does, a fold already moves Home's controls without Brickson choosing
   it, which matters for dwell (invariant 10).
5. **Settings' bars.** Settings' `NavigationStack` shows a title and the
   standard Back button. On the outer display, and on the inner display in
   landscape, the system may put that bar vertically at one side, while
   `SettingsSafetyBar` (Back to Talking) stays a row at the top. Where
   Back lands, and what is nearest the spot after it is used, is not
   scored (`SettingsOnHomeTests` runs on the iPad and iPhone 17 only).
6. **Sheets.** The privacy policy's web version opens in a sheet; on the
   outer display "the system presents bars vertically for sheets by
   default". Not looked at.
7. **Split View and windows.** On the inner display Brickson can share
   the screen with another app, at half width or in the layout Apple
   describes as "stacking video and apps together". Whether Brickson asks
   for more than one window is not set explicitly (`Brickson/Info.plist`
   has no scene manifest), and two Brickson windows would mean two Homes.
8. **Floors without a device table.** The profiles' floors assume the
   densest screen is about 163 points per inch (docs/DECISIONS.md,
   "Layouts from the space available"). Apple gives iPhone Duo's pixels
   per inch (430 and 460), not its scale, so its points per inch were not
   checked. The simulator's `displayScale` answers it.
9. **Screenshots.** None yet. The Duo set is required from April 2027.

**What a fun idea has to respect.** The owner wondered what iPhone Duo
makes possible. Apple's hinge API (`onHingeChange`) reads the fold angle
"for driving interactions or effects". Folding the phone is a gesture, so
it may not speak, alarm, change data or move a control (invariants 1 and
9), and Apple itself says layout uses regions, not the hinge. A layout for
one pose is ruled out too: Apple says "You don't want to tie functionality
to a specific pose", and invariant 8 allows only sizes and spacing to
change. What the device does offer Brickson: a phone with an iPad-sized
display and Eye Tracking, where the inner display may give the gaze
profile's larger targets room (to measure in item 13). The R2 listener
display cannot use the outer display yet: the talks describe showing
content there only for camera apps (`CameraCaptureAccessory`).

## For the release checklist

- **Every submission from April 2027, and the first one whenever it is:**
  iPhone Duo screenshots, outer display (1398 × 2034, or rotated) and inner
  display (2007 × 2853, or rotated), captured from the real app in the
  iPhone Duo simulator on the current Xcode, never mock-ups; then checked
  in App Store Connect's preview tool. They also earn the "optimized for
  iPhone Duo" badge. Re-read the screenshot specifications before each
  submission.
- **Before the first submission:** R0 item 13's checks logged (Home,
  Settings and setup on both displays, open, folded and rotated, in Split
  View, at the default and largest text sizes, light and dark), and the
  owner's two fold choices built.
- **Optional:** a featuring nomination that says Brickson supports iPhone
  Duo, once item 13 holds in every pose.

## Commits

See the pull request.

## Verified

- Apple's pages above, fetched and read on 2026-10-23 (the
  developer.apple.com pages as Markdown where Apple offers it, otherwise
  as HTML).
- The code checks in the App Resizability table, by searching `main`
  (`412f4cf`).
- CI's Xcode and simulator runtimes, from run 39923081723's log; the Mac's
  simulators, from its simulator list (2026-10-23).

## Not verified

- GitHub CI on this pull request, which is the build for a change made
  where nothing can be built, had not finished when this was written; the
  pull request records its result. No Swift changed.
- Brickson has not run on the iPhone Duo simulator or a device. Nothing
  here says how it looks or behaves on iPhone Duo.
- Whether the system moves Home's own buttons out of the fold, where
  Settings' Back goes on each display, whether Brickson can open two
  windows, and the Duo's points per inch.
- The Xcode skills' advice was read, not run in Xcode.
- The license reading is not a lawyer's.

## Follow-ups

In order, each owned as R0 item 13 in docs/ROADMAP.md unless named:

1. **Look first, on the owner's Mac** (a Mac thread, or the owner): run
   the app in the iPhone Duo simulator (Device Hub), outer and inner
   displays, open, partially folded and rotated, and in Split View, at
   the default and largest text sizes; save screenshots; record in a
   `docs/log/` file whether the system moves Home's buttons when folded,
   where Settings' Back goes, whether a second window can open, the
   `displayScale` of each display, and where the starter library scrolls.
2. **The owner's two fold choices** (docs/DECISIONS.md, "iPhone Duo",
   *The fold*), built by the layout engine thread with dwell scoring of a
   fold, and looked at again once follow-up 1 has shown Brickson on
   iPhone Duo.
3. **A Duo UI test family** in `scripts/choose-simulator.py` and
   `scripts/test.sh` (no workflow change), once GitHub's image has an iOS
   27.1 runtime and the iPhone Duo simulator; until then, on the Mac.
   *(Test seams and CI evidence)*
4. **Screenshots** for App Store Connect. *(App Store readiness and ASO)*
5. The iPhone landscape decision (docs/DECISIONS.md, "Orientations")
   measures the outer display in landscape (a tent on a table) too. *(the
   layout engine)*
6. Copy Apple's skills again after each new Xcode release, since they
   change with Xcode (the App Resizability skill was renamed in 27.1).
   *(whoever works on the Mac)*
