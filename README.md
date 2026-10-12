# Brickson

Brickson (the working name) is a free iPhone and iPad app that speaks for
people living with ALS. A person chooses a phrase, and the app says it
aloud, in their own Personal Voice if they have made one. It is being built
to work at every stage of the disease and with every way an Apple device can
be controlled: touch, Voice Control, Switch Control, a keyboard,
AssistiveTouch with Dwell, head tracking and Eye Tracking.

Everything stays on the device. There are no accounts, no servers, no ads
and no analytics.

> **Status:** early. On GitHub's test machines the app builds, opens on an
> iPad simulator, shows its starter phrases and speaks one when it is
> chosen. Nobody has run it on a real device yet, and most features are
> still to come; `docs/HANDOFF.md` says exactly where things stand.

## First time on your Mac

You need a Mac with **Xcode 26 or later** (free from the Mac App Store; its
App Store page lists the macOS version it needs) and **Homebrew** (from
[brew.sh](https://brew.sh)). The commands below are typed into
**Terminal** (in Applications → Utilities, or search for it with ⌘Space),
or into iTerm2 or Warp if you use one of those.

1. **Open Xcode once** after installing it, so it can finish setting up.
   If it offers to download the iOS platform, accept: that gives you the
   iPhone and iPad simulators (apps that pretend to be a device on your
   Mac).

2. **Install XcodeGen**, the tool that creates the Xcode project (more on
   why below). If you have just installed Homebrew, first run the commands
   its installer printed under *Next steps*; until you do, Terminal answers
   `brew: command not found`. Then:

   ```sh
   brew install xcodegen
   ```

   Optional, but it makes test output much easier to read:
   `brew install xcbeautify`.

3. **Download the code.** Move to the folder you keep projects in (for
   example `cd ~/Developer`; create it first with `mkdir -p ~/Developer`),
   then:

   ```sh
   git clone https://github.com/MiddleAgedBanana/Brickson.git
   cd Brickson
   ```

4. **Create the Xcode project** and open it:

   ```sh
   xcodegen generate
   open Brickson.xcodeproj
   ```

5. **Run the app.** At the top of the Xcode window there are two menus
   side by side. In the first (the *scheme*), choose **Brickson**, not
   Brickson-UI. In the second, choose an iPad simulator, for example
   "iPad Pro 13-inch". Then press **⌘R** (Product → Run). The simulator
   starts and shows Brickson's Home screen. Choose a phrase to hear it.

6. **Run the tests.** With the **Brickson** scheme chosen, press **⌘U**
   (Product → Test). A green check mark beside each test means it passed.
   Or, from Terminal in the project folder:

   ```sh
   scripts/test.sh
   ```

   It ends with **All unit tests passed.** when everything passes. Anything
   else, including a list of failures, means something needs fixing. The
   script starts the simulator first and leaves it running in the
   background afterwards; `xcrun simctl shutdown all` stops it.

7. **The UI tests** (optional) launch the real app on a simulator and press
   its buttons, so they take a few minutes. Choose the **Brickson-UI**
   scheme and press ⌘U, or run `scripts/test.sh ui`, which ends with
   **All UI tests passed.** GitHub runs them on every pull request too.

### Run it on your own iPhone or iPad

The device needs iOS or iPadOS 26 or later, and Xcode needs to know which
Apple account signs the app (its *team*).

1. **Find your Team ID.**
   - With a paid Apple Developer Program membership: sign in at
     [developer.apple.com/account](https://developer.apple.com/account)
     and look under *Membership details*. It is ten letters and numbers.
   - With a free Apple Account: in Xcode, open Settings → Accounts and add
     your Apple Account; Xcode creates a *Personal Team* for it. Then, in
     the project, select the Brickson target, open **Signing &
     Capabilities** and choose that team in the **Team** menu. Its ID now
     appears in **Build Settings** under *Development Team* (search for
     "team"). The choice made in Xcode is thrown away the next time the
     project is generated, which is why the ID goes into `project.yml`.
2. **Put it in `project.yml`**, on the `DEVELOPMENT_TEAM:` line near the
   top, between the quotes. If you are not the app's owner, also change
   `APP_BUNDLE_ID` to something of your own (for example
   `com.yourname.brickson`), because a bundle ID belongs to one team, and
   keep both changes on your Mac: don't commit them.
3. **Connect the device** with a cable, unlock it, and tap **Trust** when
   it asks whether to trust this computer.
4. Run `xcodegen generate` again, choose your device in Xcode's device
   menu, and press ⌘R. The first time:
   - **Developer Mode:** the switch appears in Settings → Privacy &
     Security only after the device has been connected to Xcode. Turning
     it on restarts the device.
   - **Trust the developer:** Settings → General → VPN & Device Management.

> **Don't rely on a free-account install.** An app installed with a free
> Personal Team stops opening after **7 days** until it is installed again
> from Xcode. For someone who depends on Brickson to communicate, that
> could take their voice away without warning. Use a paid membership
> (installs last a year) or, later, the App Store or TestFlight.

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
site/                     the public web pages: the privacy policy and the
                          support page (see "The website" below)
scripts/test.sh           builds the app and runs the tests in one step
project.yml               describes the Xcode project for XcodeGen
AGENTS.md                 the rules every AI coding agent follows here
CLAUDE.md                 points Claude Code at AGENTS.md
.github/                  GitHub settings: automatic tests, website publishing,
                          Dependabot, review instructions for Copilot,
                          security policy, pull request template
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
`xcodegen generate`, and run the app. Right below it, `APP_SPOKEN_NAME`
sets how VoiceOver says the name; change it to a sound-alike spelling if
VoiceOver gets it wrong. The same block holds the bundle ID, the version
numbers and the developer team (see `docs/DECISIONS.md`, "App identity").

## Automatic tests on GitHub

Every pull request is built and tested on GitHub's Mac machines
(`.github/workflows/tests.yml`). The result appears at the bottom of the
pull request as a green check or a red cross; a pull request should be
merged only when it is green.

## Reviews and updates on GitHub

Two AI reviewers comment on pull requests: Codex on every change pushed
to one, and GitHub Copilot once, when it opens. To ask Copilot again, or to
have it look at one of Dependabot's pull requests, choose **Re-request
review** (or **Request**) next to Copilot under *Reviewers*. Both check the
changes against the *Code Review Rules* in `AGENTS.md`. Their comments are
suggestions to weigh, not orders, but each one should get an answer before
the pull request merges.

Dependabot keeps the pieces the GitHub workflows borrow (such as
`actions/checkout`) up to date. Once a month it opens one pull request with
any new versions, and it opens one straight away for a security fix.

To report a security problem privately, see `.github/SECURITY.md`.

## The website

Apple needs two web addresses before the app can be listed: a privacy
policy and a support page with a way to reach the developer. Both live in
`site/` and are published for free by GitHub Pages:

- https://middleagedbanana.github.io/Brickson/privacy/ (the privacy policy)
- https://middleagedbanana.github.io/Brickson/ (the support page)

Every change to `site/` that is merged into `main` republishes them
(`.github/workflows/pages.yml`, shown as "Publish website" on the Actions
tab). The run refuses to publish while a page still has a bracketed blank
such as `[Contact Email]`.

- **Edit the policy's words in `site/privacy/index.html`**, and change its
  "Effective" date whenever the words change.
- **Never rename the repository or make it private.** GitHub does not
  redirect Pages addresses after a rename, a private repository on a free
  account takes the site down, and the address is built into the App Store
  listing and the app. The address is case-sensitive: `/Brickson/`, not
  `/brickson/`.
- **One-time setup:** in the repository's Settings → Pages, *Source* must
  be **GitHub Actions**. Until it is, the publish run fails at
  "Configure Pages".

## Working with AI agents

`AGENTS.md` is the shared briefing for every AI coding agent (Claude Code,
Codex and others): what's at stake, the rules that can never be broken, and
how to build and test. Agents that run in the cloud cannot build an iOS
app, so their changes count as untested until the GitHub tests or a run on
your Mac pass.
