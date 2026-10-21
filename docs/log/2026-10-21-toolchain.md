# Build with Apple's current Xcode, and decide the minimum iOS

*2026-10-21. Pull request #12 (`claude/project-thread-rre1no`). The
"Toolchain and iOS version targets" thread (Claude Code on the web), with
the owner's workflow commit. Written by that thread inside the old
`docs/HANDOFF.md`, and moved here unchanged in substance when pull
request #15 split the handoff.*

## What changed and why

The owner asked that Brickson always build with the toolchain Apple
currently recommends, after seeing "26.0" throughout the repository
without having chosen it. The rule is recorded in docs/DECISIONS.md,
"Build with Apple's current Xcode", with a pointer in AGENTS.md, *Build
and test*, and a review rule in *Code Review Rules*.

What was current, read on Apple's pages on 2026-10-21 (not recalled):

- Newest Xcode release: **Xcode 27.1** (27A9275, 15 October 2026), with
  the iOS 27.1 and iPadOS 27 SDKs and Swift 6.4; it needs macOS Tahoe
  26.6 or later and an Apple silicon Mac. Xcode 27.2 is a release
  candidate (27B48, 19 October). Swift 6 is still the newest language
  mode. Sources: https://developer.apple.com/news/releases/ and
  https://developer.apple.com/xcode/system-requirements/.
- App Store uploads need Xcode 26 and the iOS 26 SDK today, and **from
  April 2027 the iOS and iPadOS 27 SDK** (Apple's submitting page). Xcode
  27.1 also adds support for iPhone Duo, Apple's new iPhone, and from
  April 2027 submissions need iPhone Duo screenshots (Apple Developer
  News).
- Before this change CI ran on GitHub's `macos-26` image (version
  20260907.0351.1) with its default **Xcode 26.6** (17F113) and iOS 26.2
  to 26.5 simulators only (Brickson's CI logs, 12 to 14 October). GitHub
  now publishes one image per major Xcode: `xcode-27` (macOS 27, Xcode 27)
  has been generally available since 15 October (GitHub's changelog).
- The owner's Mac ran Xcode 27.0 with iOS 27.0 simulators on 12 and 13
  October ([`HANDOFF-LOG.md`](../HANDOFF-LOG.md)).

What changed:

- `.github/workflows/tests.yml`: both jobs run on `xcode-27`, choose the
  newest released Xcode installed there, and the Unit tests job compares
  it with Apple's releases feed (a warning, never a failure). Job names,
  triggers and permissions are unchanged. **This file could not be pushed
  from the cloud session** (AGENTS.md, *Gotchas*); the owner committed its
  full new text on the branch (`a16838f`).
- `scripts/select-xcode.py` and its tests, `scripts/test-select-xcode.py`.
  The check compares the build as well as the version, so an older build
  of Apple's newest version also warns (Copilot's review). `choose` lets
  Apple's feed decide by build number and goes by names only for a build
  the feed does not list: the first `xcode-27` run skipped the released
  27.1 because GitHub had installed it as
  `Xcode_27.1_Release_Candidate.app`, and built with 27.0 (Codex's
  review; below). A later review found two silent paths, fixed in the
  next commit: when the feed cannot be read or lists no Xcode release,
  `choose` now warns on the run itself, so the UI tests job (which has no
  `check` step) says so too; and a plain-named Xcode newer than Apple's
  newest release is skipped by `choose` and warned about by `check`, since
  Apple has not released it.
- `scripts/test-runner.py`, *WorkflowTests*: every job that runs
  `scripts/test.sh` must first run `select-xcode.py choose` and
  `xcode-select --switch`, and the workflow may name no Xcode app path,
  `DEVELOPER_DIR` or `xcode-version`. The workflow on `main` fails the
  first test, so the Unit tests job stayed red on this branch until the
  owner committed the new workflow. That was on purpose: the pull request
  could not merge, even with auto-merge on, without the change that
  applies the rule (Codex's review).
- `scripts/test.sh`: the simulator's iOS must lie between the deployment
  target, read from the generated project, and the SDK of the Xcode in
  use. Six fixture tests in `scripts/test-runner.py` cover the range, the
  error when nothing fits, iPads only, the 13-inch iPad Pro preference,
  and that an unreadable deployment target stops the run (a first version
  carried on, because `set -e` does not stop inside `$(...)`).
- README.md and docs/GETTING_STARTED.md ask for the current Xcode release
  instead of "Xcode 26 or later". docs/DECISIONS.md *Code scanning* notes
  that CodeQL cannot trace Swift builds with Xcode 27 (GitHub's changelog,
  2026-10-19), which changes nothing today: default setup scans only the
  workflow files and the Python scripts, which need no build.

Not changed, on purpose:

- The deployment target stays **iOS and iPadOS 26.0** (`project.yml`,
  `.github/copilot-instructions.md`, README.md, docs/GETTING_STARTED.md).
  It is now decided rather than inherited: the owner set the rule that
  every device able to use eye tracking must run the app, and left the
  rest to the project. A third-party eye tracker (eyeV's Skyle 3) works
  with the 2018 iPad Pros, which run iPadOS 26 but not 27, so 26.0 is the
  highest minimum that keeps every eye-tracking user; Apple's built-in Eye
  Tracking alone would have allowed 27.0. Evidence and the second rule
  (accessibility APIs) are in docs/DECISIONS.md, "Minimum iOS, iPhone and
  iPad". Not re-checked by a second reader: the Skyle and TD Pilot pages
  were read once, on 2026-10-21.
- Dated records of what was checked on (`docs/HANDOFF-LOG.md`,
  `docs/archive/`) keep their versions: they are history.

## Commits

- `258fcf4` Take the test simulator's OS range from the project, not the
  script
- `b70e742` Add a script that picks the newest released Xcode for CI
- `f9d09cc` Make the simulator preference test able to fail, and test
  iPads only
- `48ef865` Record the rule: build with Apple's current Xcode, never a
  pinned one
- `5ef45ed` Warn when CI has an older build of Apple's newest Xcode
  version
- `809a333` Test that CI switches to the newest released Xcode before
  testing
- `a16838f` Update GitHub Actions to use latest Xcode version (the owner,
  the workflow file)
- `4198e94` Let Apple's feed, not the app's name, decide which Xcode is a
  release
- `846929c` Warn when the Xcode choice falls back to names, and never take
  an unreleased version
- `59b77fb` Decide the minimum iOS from two rules: eye tracking and
  accessibility APIs
- Merged into `main` as `6891f0c`.

## Verified

Written on a cloud machine that cannot run Xcode. Both Python test files
pass on Linux (Python 3.13). Every new test was seen failing: before the
code it covers existed, or under a deliberate break of that code.

The first CI run on GitHub's `xcode-27` image (the owner's `a16838f`,
image `xcode-27-arm64` version 20261012.0260.1) found:

- Installed: `Xcode.app` (27.0, 27A266a, the default);
  `Xcode_27.1_Release_Candidate.app` (27.1, 27A9275, the released
  build), also reached as `Xcode_27.1.app` and `Xcode_27.1.0.app`; and
  `Xcode_27.2_beta_2.app`, also reached as `Xcode_27.2.app` and
  `Xcode_27.2.0.app`. The selector of that commit skipped every app but
  27.0 by name, so the run built with Xcode 27.0, and `check` warned that
  Apple's newest release is 27.1 (27A9275). Fixed in `4198e94`: its run
  chose `Xcode_27.1_Release_Candidate.app` (27.1, 27A9275), built with
  the iOS 27.1 SDK, and `check` posted a notice that CI matches Apple's
  newest release. Under 27.1 the only iOS simulator runtime was still
  iOS 27.0. Unit tests and UI tests both passed on that run; the first UI
  test took 39 seconds.
- Homebrew is there: XcodeGen 2.46.0 installed. Under Xcode 27.0 the only
  iOS simulators were iOS 27.0; `scripts/test.sh` chose iPad Pro 13-inch
  (M5), iOS 27.0.
- Unit tests passed under Xcode 27.0. The one build warning:
  `UITraitCollection(traitsFrom:)` in `BricksonTests/PaletteTests.swift`,
  deprecated since iOS 17.
- UI tests failed in the first test after the simulator started,
  `testAPhraseSpeaksOnTheFirstTap` ("Failed to get matching snapshots:
  Error getting main window kAXErrorServerNotFound"), and the next test
  took 187 seconds. On `48ef865` (`macos-26`, Xcode 26.6) the same first
  test had failed differently ("Again was still off 10 s after "Hello."
  was tapped"). Both match the slow first launch in AGENTS.md *Gotchas*;
  this pull request changes neither the app nor its UI tests.

## Not verified

- The Skyle and TD Pilot pages behind the minimum iOS were read once, by
  one reader, on 2026-10-21.
- Nothing ran on the owner's Mac with Xcode 27.1.

## Follow-ups

- **Recheck the minimum iOS** (26.0) against its two rules when Apple's
  next major release drops devices (docs/DECISIONS.md, "Minimum iOS,
  iPhone and iPad"). The toolchain is not a choice: always Apple's
  newest Xcode. *(Toolchain and iOS version targets)*
- **On the owner's Mac: Xcode's "recommended settings".** XcodeGen marks
  the generated project as last checked by Xcode 14.3 (`LastUpgradeCheck`
  1430, XcodeGen's default, seen on the owner's Mac on 15 and 16
  October), so the current Xcode offers to update the project to its
  recommended settings each time it opens it. Accepting changes only the
  generated project, which the next `xcodegen generate` throws away. The
  fix is to read that list in the current Xcode (open the project, then
  the warning in the Issue navigator, and copy the list without
  accepting it), bring the settings that fit into `project.yml`, and set
  XcodeGen's `options.xcodeVersion` to that Xcode in the same pull
  request. Setting `xcodeVersion` alone would hide the advice instead of
  following it. Done blind from the cloud, it was not done here.
  *(The owner's Mac, or an agent on it)*
- **Orientation and iPhone Duo.** Apple's iOS 27 release notes say that
  on iPad, an app built with the iOS 27 SDK no longer needs all four
  orientations to resize continuously, and supported orientations are
  honoured only until the person resizes the window. Xcode 27.1 adds
  iPhone Duo, Apple's foldable iPhone (on sale from 23 October 2026),
  which Apple says has new "poses and orientations". The iPhone's
  orientation choice (docs/DECISIONS.md, "Orientations") should be
  checked against both in the iPhone Duo simulator; Apple also requires
  iPhone Duo screenshots in App Store submissions from April 2027.
  *(Phone layout and word fitting; App Store readiness and ASO)*
- **iOS 27 APIs at a 26.0 target** need `if #available(iOS 27, *)` with an
  iOS 26 path, for example the new `AVAudioSession` life-cycle
  notifications (reported by the owner's Mac's review on 15 and 16
  October; not checked here). *(Speech engine and Get Attention;
  Accessibility API coverage)*
- Xcode 27.1's release notes list "Initial Simulator launch can take
  several minutes" as a known issue. `scripts/test.sh` waits for each
  simulator to finish starting and, before UI tests, launches the app
  once to warm it up (updated by PR #13,
  [`2026-10-21-test-seams.md`](2026-10-21-test-seams.md)); a slow first
  UI test on the new image is still the first thing to suspect.
  *(Test seams and CI evidence)*
- Xcode 27.2 (a release candidate on 2026-10-21) adds a JSON project
  format (`.xcproj`) meant to be readable and merge-friendly. Worth
  weighing against XcodeGen when it is released (docs/DECISIONS.md,
  "Generated Xcode project"). *(Toolchain and iOS version targets)*
- Noticed, not changed: GitHub's changelog of 2026-10-15 says AI Scan for
  pull requests is now generally available; docs/DECISIONS.md *Code
  scanning* still calls it a public preview. *(Project guardrails)*
