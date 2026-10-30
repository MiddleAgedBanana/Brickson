# Brickson

> [!WARNING]
> **In active development.** Brickson is a work in progress and is not yet
> on the App Store. Its features, and its name, may change before release.
> It is not ready for dependable daily communication: physical-device
> accessibility and audio checks are still outstanding, and simulator tests
> do not establish reliability for someone who depends on it to communicate.

**Communication that stays familiar as needs change.**

Brickson is an iPhone and iPad app in development for people living with
ALS. It provides augmentative and alternative communication (AAC): choose
a phrase and the device speaks it, using Apple's Personal Voice when
available and authorized.

The goal is one familiar interface across touch, keyboard, Voice Control,
Switch Control, AssistiveTouch with Dwell, head tracking and Eye Tracking.
As access needs change, target sizes and spacing should adapt while
controls keep their relative positions.

[Website & support](https://middleagedbanana.github.io/Brickson/) ·
[Privacy policy](https://middleagedbanana.github.io/Brickson/privacy/) ·
[Accessibility](https://middleagedbanana.github.io/Brickson/accessibility/) ·
[Development status](docs/HANDOFF.md)

## Why Brickson?

Brickson is a name my brother made up as a teenager. More than twenty years
later, it still makes our family smile.

My brother died of ALS. I’m building Brickson in his memory, to help people
living with ALS keep expressing themselves, in their own words.

— Avery Dedmon, creator of Brickson

## Current capabilities

The initial implementation includes:

- A starter phrase library organized into everyday categories.
- Phrase buttons that speak on the first activation, plus Yes, No, Again
  and an Emergency category on Home.
- Get Attention on Home: one activation sounds an alarm to call someone
  into the room, and a Stop button, in a different place, appears while
  it sounds.
- Typing on Home: Type, beside the message, opens Apple's keyboard;
  Speak or Return says the message, Phrases goes back to the phrases,
  and Clear and Put Back each have a fixed place. The message is kept on
  the device until it is cleared, and nothing on Home moves when the
  keyboard shows. On the smallest windows at the largest text sizes,
  where the keyboard would cover Emergency, Yes, No or Get Attention,
  Type is dimmed instead.
- Settings for the family, opened from Home's Settings button: voices,
  setup guides and the privacy policy.
- Speech through Apple's built-in speech system, with Personal Voice
  selection when permission and availability allow it.
- Local phrase storage with SwiftData, without CloudKit sync.
- Audio recovery logic, visible failure warnings and protection against
  restarting a phrase that is already being spoken.
- Unit tests for core logic and simulator UI tests for the initial Home flow.

Phrase editing and backup export are not implemented yet. Home's layout comes from one tested layout
engine, at touch sizes; sizes for switches, head and eye tracking, and validation across access methods, remain
planned work. See the [handoff](docs/HANDOFF.md) for verification evidence,
known limitations and next steps.

## Design principles

- **Communication first.** Phrases speak immediately; speaking never edits
  the person's words.
- **Familiar placement.** Controls do not reorder by frequency or recency.
- **Standard accessibility.** Use native controls and Apple's input systems,
  with no custom eye, head or switch tracking.
- **Apple's current frameworks.** SwiftUI, SwiftData and Swift Testing,
  with an older framework only where nothing newer does the job without
  losing something; each such use and its reason is in
  [docs/DECISIONS.md](docs/DECISIONS.md) ("Apple's current frameworks first").
- **Privacy by design.** No accounts, app servers, ads, analytics or tracking.
  The app stores its library on the device; device backups and optional
  features are covered in the [privacy policy](https://middleagedbanana.github.io/Brickson/privacy/).
- **Testable safety rules.** Speech, persistence and interaction decisions
  live in plain Swift types, separate from views.

## Build and run

Requires a Mac with the **current release of Xcode** (Brickson is always
built with Apple's newest Xcode), its iOS simulators, and
[XcodeGen](https://github.com/yonaskolb/XcodeGen). The app targets iPhone
and iPad running iOS/iPadOS 26 or later.

```sh
brew install xcodegen
git clone https://github.com/MiddleAgedBanana/Brickson.git
cd Brickson
xcodegen generate
open Brickson.xcodeproj
```

Select the **Brickson** scheme and an iPhone or iPad simulator, then run.
For first-time Xcode setup and device signing, see the
[local development guide](docs/GETTING_STARTED.md).

`project.yml` is the source of truth for project settings. The generated
`.xcodeproj` is not committed; regenerate it after pulling changes or
adding, removing or renaming files. Do not edit the generated project.

## Tests

```sh
scripts/test.sh          # Build and run unit tests
scripts/test.sh ui       # Run simulator UI tests
python3 scripts/test-site.py  # Check the static website
```

The app test script generates the project and picks the newest
iPad Pro 13-inch simulator that both the app (its deployment target) and
the Xcode in use support, falling back to another iPad. UI tests then run
again on the newest standard iPhone. It picks by device type, so a
simulator you renamed still counts. It shuts down devices it booted after
each run; devices that were already running stay running. To run on one kind only, or on a
specific installed simulator:

```sh
SIMULATOR_FAMILY=iphone scripts/test.sh ui
DESTINATION='platform=iOS Simulator,name=iPhone 17' scripts/test.sh
```

Anything after the mode goes to `xcodebuild`, for example one test (a
Swift Testing name needs its parentheses):

```sh
scripts/test.sh unit '-only-testing:BricksonTests/PaletteTests/theContrastFormulaMatchesWCAG()'
```

Each run prints how many tests ran, fails if none did, and keeps its
results in `build/TestResults/` (open a `.xcresult` file in Xcode to see
each test, with screenshots of any UI-test failure). A unit run also
prints how much of the app's code the tests ran, and updates the String
Catalog (`Brickson/Resources/Localizable.xcstrings`, every string people
see, ready for translation) to match the code. If it changed, commit it
with your change; GitHub's run fails when the committed catalog is out of
date.

GitHub Actions runs unit and UI tests for pull requests and pushes to
`main`. Passing tests are required before merging. Physical-device checks
are still necessary for audio, dwell, Eye Tracking and other access methods.

## Repository structure

| Path | Contents |
| --- | --- |
| `Brickson/` | SwiftUI app, speech services, phrase library and resources |
| `BricksonTests/` | Unit tests for core logic and safety rules |
| `BricksonUITests/` | Simulator UI and accessibility tests |
| `project.yml` | XcodeGen project configuration |
| `scripts/` | App test runner and static website checks |
| `site/` | GitHub Pages website and privacy policy |
| `design/brand/` | Proposed logo artwork; not yet installed as the app icon |
| `docs/` | Setup, decisions, implementation status and reference lessons |

## Contributing

Before reusing or modifying Brickson's code, read the [license notice](LICENSE.md)
and obtain any required written permission.

Read [AGENTS.md](AGENTS.md) before changing code. It defines the project's
accessibility, privacy and safety requirements, along with the review
workflow. These constraints apply to human and AI-assisted contributions.

Start with the [current handoff](docs/HANDOFF.md) and
[recorded decisions](docs/DECISIONS.md). Add a failing test before new
behavior or a bug fix, keep changes focused, and document verification in
the pull request. Local Mac changes require a passing unit suite before
commit; changes made without Xcode remain untested until CI or a Mac run
passes. The maintainer merges pull requests after review and passing CI.

CodeQL scans the GitHub workflow files and the Python scripts in
`scripts/`, not Swift. AI Scan reviews eligible pull-request changes,
including Swift, but its findings do not enforce a merge gate; address
them during review. AI Scan skips forks and Dependabot pull requests. See
[Code scanning](docs/DECISIONS.md#code-scanning) for the coverage,
limitations and review requirements.

For bugs, use the **Something went wrong** issue form: it asks for the
steps, the device and OS version, and your input method. Do not
post personal phrases, medical details or private backups in public issues.
Report security vulnerabilities privately using the
[security policy](.github/SECURITY.md).

## Website development

The website is static HTML and CSS, with local artwork and no JavaScript,
analytics or external fonts. Preview it locally:

```sh
python3 -m http.server 8765 --bind 127.0.0.1 --directory site
```

Open [localhost:8765](http://127.0.0.1:8765/). Changes to `site/` deploy through
GitHub Pages after merging into `main`. Keep the existing repository name
and public page paths stable so support, privacy and accessibility links
continue to work. Policy wording changes must include an updated effective
date, and accessibility page changes an updated "Last updated" date.

## Documentation

- [Local development setup](docs/GETTING_STARTED.md)
- [Current state and verification](docs/HANDOFF.md), with a
  [record of every change](docs/log/README.md)
- [Roadmap: what comes in which release](docs/ROADMAP.md)
- [How the project is run, stage by stage](docs/SDLC.md)
- [Design and engineering decisions](docs/DECISIONS.md)
- [Accessibility features and APIs, by ALS stage](docs/ACCESSIBILITY.md)
- [Lessons from the reference app](docs/LESSONS.md)
- [Implementation and porting sequence](docs/PORTING.md)
- [Research behind the roadmap](docs/recon/README.md)

## License

Copyright (c) 2026 Avery Dedmon. **All rights reserved.**

Brickson's original source code and accompanying documentation are
proprietary. Reusing, modifying, or redistributing them requires Avery
Dedmon's prior written permission, except as permitted by applicable law
or the GitHub Terms of Service. Public visibility and permitted viewing or
forking on GitHub do not grant an open-source license or general reuse
permission. Third-party material retains its applicable terms.

See [LICENSE.md](LICENSE.md) for the full notice. To request permission, use the
contact details on the [website](https://middleagedbanana.github.io/Brickson/).
