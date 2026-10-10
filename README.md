# Brickson

Brickson (the working name) is a free iPhone and iPad app that speaks for
people living with ALS. A person chooses a phrase, and the app says it
aloud, in their own Personal Voice if they have made one. It is being built
to work at every stage of the disease and with every way an Apple device can
be controlled: touch, Voice Control, Switch Control, a keyboard,
AssistiveTouch with Dwell, head tracking and Eye Tracking.

Everything stays on the device. There are no accounts, no servers, no ads
and no analytics.

> **Status:** early. The app opens, shows starter phrases, and speaks them.
> Most features are still to come; `docs/HANDOFF.md` says exactly where
> things stand and what comes next.

## First time on your Mac

You need a Mac with **Xcode 26 or later** (free from the Mac App Store) and
**Homebrew** (from [brew.sh](https://brew.sh)).

1. **Open Xcode once** after installing it, so it can finish setting up.
   If it offers to download the iOS platform, accept: that gives you the
   iPhone and iPad simulators (apps that pretend to be a device on your
   Mac).

2. **Install XcodeGen**, the tool that creates the Xcode project (more on
   why below). In Terminal:

   ```sh
   brew install xcodegen
   ```

   Optional, but it makes test output much easier to read:
   `brew install xcbeautify`.

3. **Download the code** to a folder of your choice:

   ```sh
   git clone https://github.com/MiddleAgedBanana/Brickson.git
   cd Brickson
   ```

4. **Create the Xcode project** and open it:

   ```sh
   xcodegen generate
   open Brickson.xcodeproj
   ```

5. **Run the app.** At the top of the Xcode window, pick an iPad simulator
   (for example "iPad Pro 13-inch") from the device menu, then press **⌘R**
   (Product → Run). The simulator starts and shows Brickson's Home screen.
   Choose a phrase to hear it.

6. **Run the tests.** Press **⌘U** (Product → Test). A green check mark
   beside each test means it passed. Or, from Terminal in the project
   folder:

   ```sh
   scripts/test.sh
   ```

   It ends with `** TEST SUCCEEDED **` when everything passes.

### Run it on your own iPhone or iPad

A real device needs to know which Apple developer account signs the app:

1. Find your **Team ID**: sign in at
   [developer.apple.com/account](https://developer.apple.com/account) and
   look under *Membership details*. It is ten letters and numbers.
2. Put it in `project.yml`, on the `DEVELOPMENT_TEAM:` line near the top,
   between the quotes.
3. Run `xcodegen generate` again, pick your device in Xcode's device menu,
   and press ⌘R. The first time, the device may ask you to trust the
   developer (Settings → General → VPN & Device Management) and to turn on
   Developer Mode (Settings → Privacy & Security).

## Why there is no .xcodeproj file in the repository

An Xcode project file (`.xcodeproj`) is a large, machine-written file that
is hard to read and causes conflicts when two people (or agents) change it.
So Brickson describes the project in a short, readable file,
**`project.yml`**, and the tool **XcodeGen** writes the `.xcodeproj` from it
on each Mac.

Two rules follow from that:

- **Run `xcodegen generate` after you add, remove or rename a file**, and
  after pulling changes. (`scripts/test.sh` does it for you.)
- **Change project settings in `project.yml`, not in Xcode's project
  editor.** Anything changed in Xcode's editor is thrown away the next time
  the project is generated.

## What's in this folder

```
Brickson/                 the app itself
  App/                    the starting point (BricksonApp) and app-wide rules
  Speech/                 turning text into speech, choosing a voice, and
                          warning when audio fails
  Library/                the phrase library: how phrases are stored, and the
                          starter phrases a new library begins with
  Home/                   the Home screen and its colours
  Resources/              non-code files: starter phrases, colours and icon
                          (Assets), the privacy manifest, translations
  Info.plist              settings iOS reads about the app (name, background audio)
BricksonTests/            unit tests: fast checks of the app's logic
BricksonUITests/          UI tests: launch the real app and press its buttons
docs/                     the project's notes (see below)
scripts/test.sh           builds the app and runs the tests in one step
project.yml               describes the Xcode project for XcodeGen
AGENTS.md                 the rules every AI coding agent follows here
CLAUDE.md                 points Claude Code at AGENTS.md
.github/                  GitHub settings: automatic tests, pull request template
```

### How the pieces fit together

When the app starts, **`BricksonApp`** opens the phrase library (stored on
the device with Apple's **SwiftData**), fills it with the starter phrases
the first time, and creates one **`SpeechService`**, the part that speaks.
It hands both to the screens. **`HomeView`** shows the phrases as buttons;
choosing one asks `SpeechService` to speak it.

Rules that matter for safety live in small, separate pieces of plain logic
rather than inside screens, so each can be tested on its own in a fraction
of a second. For example, `SpokenUtteranceTracker` decides that choosing a
phrase that is *still being spoken* should not restart it, so a person
whose eyes rest on a button doesn't make the app stutter.

### The documents

| File | What it's for |
|---|---|
| `docs/HANDOFF.md` | Where things stand, what's verified, and what to do next. Start here. |
| `docs/DECISIONS.md` | Choices already made, and why. |
| `docs/LESSONS.md` | What went wrong in the earlier app this one learns from, and the rule each lesson gives. |
| `docs/PORTING.md` | Which parts come over from that earlier app, and in what order. |
| `docs/archive/` | Old versions of documents that were rewritten. |

## Changing the app's name

The name under the icon is set in one place: `APP_DISPLAY_NAME` in the
*App identity* block at the top of `project.yml`. Change it there, run
`xcodegen generate`, and run the app. The same block holds the bundle ID,
the version numbers and the developer team (see `docs/DECISIONS.md`,
"App identity").

## Automatic tests on GitHub

Every pull request is built and tested on GitHub's Mac machines
(`.github/workflows/tests.yml`). The result appears at the bottom of the
pull request as a green check or a red cross; a pull request should be
merged only when it is green.

## Working with AI agents

`AGENTS.md` is the shared briefing for every AI coding agent (Claude Code,
Codex and others): what's at stake, the rules that can never be broken, and
how to build and test. Agents that run in the cloud cannot build an iOS
app, so their changes count as untested until the GitHub tests or a run on
your Mac pass.
