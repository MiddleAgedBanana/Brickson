# Apple's doors in Family Setup

*2026-10-23. Pull request (`claude/project-thread-h04elr`). The "Family
Setup guides and Assistive Access" thread, in a cloud session that
cannot build or run anything. Wave 3 item 1 (docs/ROADMAP.md).*

## What changed and why

**Brickson asks for full screen in Assistive Access.** Assistive Access
is Apple's simpler iPhone and iPad, with only the apps a family chooses.
Without a request, iOS draws an app there "in a reduced frame", the size
of a smaller screen. `UISupportsFullScreenInAssistiveAccess` in the
Info.plist (set in `project.yml`) asks for "all the available space
above the Back button" instead, with Brickson's own layout.
`UISupportsAssistiveAccess`, Apple's separate streamlined interface,
stays absent, because its controls would sit somewhere else there than
everywhere else (invariant 8; docs/DECISIONS.md, "Accessibility API
coverage"). `AppBundleTests` pins both.

**Inside Assistive Access, guides give written paths, not links.**
Apple's Assistive Access User Guide says most settings are changed only
after leaving Assistive Access, so a button that opens the Settings app
would lead nowhere the family can use. A new plain type,
`SettingsAppLink`, decides whether a screen offers an Open … Settings
button: only where iOS can open the page and never inside Assistive
Access (`accessibilityAssistiveAccessEnabled`). Open Dwell Control
Settings (Reaching the Screen) and Open Personal Voice Settings (Voice
Settings) both ask it. The written path was already shown for Personal
Voice; Dwell Control's path is now a step of the Eye Tracking and Head
Tracking guides. Inside Assistive Access each guide also opens with a
line saying how to leave it first (`LeaveAssistiveAccessNote`). It
cannot appear or go while Brickson is open, so it never moves a control
under a resting pointer.

**New guides, each checked against Apple's user guides on the day.**
Where they live is a decision recorded in docs/DECISIONS.md, "Setup
answers are kept as offered, never as completed":

- *Reaching the Screen* (and so step 3 of Set Up Step by Step, for the
  ways chosen): Touch Accommodations, with the caution that quick taps
  can then seem to do nothing, and its Accessibility Shortcut set before
  it is turned on (review, below); Switch Control's six switch sources and
  its timing (scanning style, Auto Scanning Time, Hold Duration, Ignore
  Repeat, Auto Tap); Eye Tracking's calibration each time it starts and
  Dwell Control's written path; eye trackers made for iPad, which the
  guide says Apple describes for iPad only.
- *Keep Brickson Open* (and so step 4): keeping the Accessibility
  Shortcut during Guided Access; that Brickson fills the screen in
  Assistive Access and is added without the "Other apps" heading (an app
  that asks for full screen is listed as optimized); that most settings
  change only outside Assistive Access; *Screen lock*, with Low Power
  Mode's 30-second Auto-Lock and Guided Access's own Display Auto-Lock.
- *Calls, Siri and Shortcuts*, a new Family Setup screen: Live Speech
  (and that its phrases are its own, so families type in a few), Live
  Speech on Apple Watch (with the watch's own Accessibility Shortcut,
  which its triple-click needs), Vocal Shortcuts, Listen for Atypical Speech
  with Apple's English (U.S.) limit and Siri Pause Time, and the Action
  button on an iPhone that has one.
- *More Accessibility Settings*, a new Family Setup screen: the
  Accessibility Shortcut (with Guided Access's and Assistive Access's
  own settings, and a slower click speed), Zoom (with the Accessibility
  Shortcut and Zoom Controller for when three-finger gestures are hard)
  and Share Accessibility Settings.

A guide for one kind of device says so in words, never by checking the
device (AGENTS.md, *Layout on every device and window*). Where iOS 26
and iOS 27 word a step differently (Live Speech's speak button, Touch
Accommodations' setup), the words fit both. No step gives a count or
time Apple's pages do not give: Apple does not say how many times a
Vocal Shortcut is repeated, nor list Display Auto-Lock's choices, so the
guide says "as the screen asks" and "the longest time offered".
"The Home button on older models" became "the Home button, on a model
that has one", since Apple now names iPhone SE and some iPads.

**Audits.** Apple's accessibility audit now runs on every Family Setup
guide and About (`testFamilySetupGuidesPassTheAccessibilityAudit`) and
on each of Set Up Step by Step's five steps
(`testTheStepByStepSetupPassesTheAccessibilityAudit`), light, on both
simulator families. Two of these titles carry the app's name, which is
not final, so the test knows each guide by words of its own.

**Headers were already in place.** The plan asked for guide headings to
become headers; every Settings heading has had the header trait since
PR #23 (`SettingsHeading`). docs/ACCESSIBILITY.md's row said "R0-7" and
now says in place; docs/ROADMAP.md's item notes it.

**The String Catalog** was brought up to date by hand: 83 strings added
and 10 removed, written in Xcode's own format by a script that first
reproduced the existing file byte for byte. CI's catalog check is the
proof that it matches what `xcstringstool sync` would write.

Documents: docs/ACCESSIBILITY.md's rows for each feature move to in
place; docs/DECISIONS.md records where the guides live and the
Assistive Access choice; docs/HANDOFF.md's summary and two device-check
rows; docs/ROADMAP.md marks item 1 built; AGENTS.md lists
`SettingsAppLink`; the website's accessibility page names the new
audits and the full-screen request, and says Brickson has not been
tried inside Assistive Access.

Review on the pull request found two steps in the wrong order or
missing, both confirmed against Apple's guides and fixed: the Touch
Accommodations guide now selects Touch Accommodations in the
Accessibility Shortcut *before* turning it on, since Hold Duration can
make ordinary taps do nothing and the way back must exist first; and
Live Speech on Apple Watch now selects Live Speech in the watch's
Accessibility Shortcut, which Apple's watch guide lists as its own step
(the iPhone's guide has no such step). Both say "make sure … is
selected" rather than "choose", because choosing an item already ticked
unticks it.

## Apple's pages behind it

Read on 2026-10-23 by three research helpers in this session, each page
in its iOS 26 and iOS 27 version where both exist, iPhone and iPad:

| Guide | Apple pages |
|---|---|
| Full screen in Assistive Access | [`UISupportsFullScreenInAssistiveAccess`](https://developer.apple.com/documentation/bundleresources/information-property-list/uisupportsfullscreeninassistiveaccess), [Optimizing your app for Assistive Access](https://developer.apple.com/documentation/accessibility/optimizing-your-app-for-assistive-access), [`accessibilityAssistiveAccessEnabled`](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityassistiveaccessenabled) (read in this session) |
| Assistive Access and Settings | [Change settings](https://support.apple.com/guide/assistive-access-iphone/change-settings-dev073880b40/ios), [Enter and exit](https://support.apple.com/guide/assistive-access-iphone/enter-and-exit-assistive-access-devdedddc678/27/ios/27) |
| Guided Access | [iPhone](https://support.apple.com/guide/iphone/lock-iphone-to-one-app-iph7fad0d10/27/ios/27), [iPad](https://support.apple.com/guide/ipad/lock-ipad-to-one-app-ipada16d1374/27/ipados/27) |
| Touch Accommodations | [iPhone](https://support.apple.com/guide/iphone/adjust-how-iphone-responds-to-your-touch-iph77bcdd132/27/ios/27), [iPad](https://support.apple.com/guide/ipad/adjust-how-ipad-responds-to-your-touch-ipadc70af050/27/ipados/27) |
| Switch Control switches and timing | [iPhone](https://support.apple.com/guide/iphone/set-up-and-turn-on-switch-control-iph400b2f114/27/ios/27), [iPad](https://support.apple.com/guide/ipad/set-up-and-turn-on-switch-control-ipad93dce3d5/27/ipados/27), Auto Tap from [Apple Support 119835](https://support.apple.com/en-us/119835) |
| Eye trackers for iPad | [iPad, eyes](https://support.apple.com/guide/ipad/control-ipad-with-the-movement-of-your-eyes-ipad2cd35723/27/ipados/27) |
| Dwell Control's path | [iPhone, AssistiveTouch](https://support.apple.com/guide/iphone/use-assistivetouch-iph96b21954/27/ios/27), [iPad, AssistiveTouch](https://support.apple.com/guide/ipad/use-assistivetouch-ipad9a2466d3/27/ipados/27) |
| Live Speech | [iPhone](https://support.apple.com/guide/iphone/type-to-speak-iphcf92d2d9b/27/ios/27), [iPad](https://support.apple.com/guide/ipad/type-to-speak-ipad32ad5293/27/ipados/27), [Apple Support 105018](https://support.apple.com/en-us/105018) |
| Live Speech on Apple Watch | [watchOS](https://support.apple.com/guide/watch/type-to-speak-apd86a007717/27/watchos/27) |
| Vocal Shortcuts | [iPhone](https://support.apple.com/guide/iphone/use-vocal-shortcuts-iph7f242ea2c/27/ios/27), [iPad](https://support.apple.com/guide/ipad/use-vocal-shortcuts-ipaddc8c53732/27/ipados/27) |
| Listen for Atypical Speech | [iPhone](https://support.apple.com/guide/iphone/change-siri-accessibility-settings-iphaff1d606/27/ios/27), [iPad](https://support.apple.com/guide/ipad/change-siri-accessibility-settings-ipadd58b8673/27/ipados/27) |
| Action button | [iPhone](https://support.apple.com/guide/iphone/use-and-customize-the-action-button-iphe89d61d66/27/ios/27) |
| Accessibility Shortcut | [iPhone](https://support.apple.com/guide/iphone/quickly-turn-accessibility-features-on-or-off-iph3e2e31a5/27/ios/27), [iPad](https://support.apple.com/guide/ipad/quickly-turn-accessibility-features-on-or-off-ipad9a245f9e/ipados) |
| Zoom | [iPhone](https://support.apple.com/guide/iphone/zoom-iph3e2e367e/27/ios/27), [iPad](https://support.apple.com/guide/ipad/zoom-in-ipad9a245e3e/ipados) |
| Share Accessibility Settings | [iPhone](https://support.apple.com/guide/iphone/share-accessibility-settings-device-ipha21bc67e7/27/ios/27), [iPad](https://support.apple.com/guide/ipad/share-accessibility-settings-device-ipad8b6a8cd0/ipados) |
| Auto-Lock and Low Power Mode | [iPhone](https://support.apple.com/guide/iphone/keep-the-iphone-display-on-longer-iph7117338a8/27/ios/27), [iPad](https://support.apple.com/guide/ipad/keep-the-ipad-display-on-longer-ipad11dbabaf/ipados) |

## Commits

On `claude/project-thread-h04elr`, from `main` at `e42a3da`: see the
pull request's commit list.

## Verified

- `python3 scripts/test-docs.py` (45 tests), `scripts/test-site.py`
  and `scripts/test-hooks.py` passed in this session.
- Every key in the String Catalog is still a string in the code, and
  every new string in the changed files is in the catalog (a script in
  this session that lists the code's string literals; it found no
  difference on `main` before the change).
- New tests, and what makes each fail: `AppBundleTests`'
  `assistiveAccessShowsBricksonFullScreenInItsOwnLayout` fails if the
  key is dropped or false, or if `UISupportsAssistiveAccess` is added;
  `SettingsAppLinkTests` fails if Assistive Access stops hiding the
  button, if a page iOS cannot open gets one, or if Personal Voice's
  written path goes with its button; the two UI audits fail on any
  audit finding, or if a guide stops opening or loses the words the
  test knows it by.
- GitHub CI on the first push (`6ff8dc7`, 2026-10-23): Unit tests,
  with the String Catalog check, passed in about 10 minutes; UI tests,
  with the new audits on iPad and iPhone, passed in about 53 minutes,
  inside the job's 75-minute limit; CodeQL passed. The run for the
  review fixes is on the pull request.

## Not verified

- Nothing was built or run here: a cloud session cannot. Until CI
  passes, the code is untested.
- The guides' steps rest on Apple's pages, not on a device: nobody has
  followed them on an iPhone, iPad or Apple Watch. Apple's pages did not
  confirm: how many times a Vocal Shortcut is repeated; Display
  Auto-Lock's and Auto-Lock's choices (whether "Never" is one); whether
  iOS 27 still adds Touch Accommodations to the Accessibility Shortcut by
  itself; the exact on-screen labels for Auto Tap and the Add New Switch
  sources on iOS 26 and 27; which page `.dwellControl` opens.
- Brickson has not run inside Assistive Access: its window there, and
  that the guides show no button, are from the code and Apple's pages
  (docs/HANDOFF.md, *Checks that need a real device*).
- The audits run in light only, at the default text size, on each
  screen as it opens; whether Apple's audit reads the parts of a long
  guide below the screen's edge is not established.
- VoiceOver reading each new heading as a header is from the code
  (`SettingsHeading`), not a test.

## Follow-ups

- Read & Speak's setup note and Switch Control's keyboard options
  (docs/ACCESSIBILITY.md, still R0-7): the keyboard options belong with
  typing on Home (Wave 3 item 5); Read & Speak's note with the next
  Family Setup change. *(the thread that takes each)*
- Device checks: each guide on iOS 26 and iOS 27, Brickson inside
  Assistive Access, and where Open Dwell Control Settings lands.
  *(owner, with a device)*
- iOS 27's Guided Access has Pose Changes and Display Changes for
  iPhone Duo; Keep Brickson Open can name them when Wave 3 item 6 makes
  Home ready for iPhone Duo. *(item 6's thread)*
- iOS opens AssistiveTouch's Devices page (`.assistiveTouchDevices`,
  iOS 26); the iPad eye-tracker guide could offer it as a button once
  its place is scored like the other Settings buttons. *(a later
  Settings thread)*
