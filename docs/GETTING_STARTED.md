# Local development setup

You need a Mac with the **current release of Xcode** and **Homebrew** (from
[brew.sh](https://brew.sh)). Xcode is free from the Mac App Store, whose
page lists the macOS version it needs. Brickson is always built with
Apple's newest Xcode, so install Xcode updates when the App Store offers
them. The commands below are typed into
**Terminal** (in Applications → Utilities, or search for it with ⌘Space),
or into iTerm2 or Warp if you use one of those.

1. **Open Xcode once** after installing it, so it can finish setting up.
   If it offers to download the iOS platform, accept: that gives you the
   iPhone and iPad simulators (apps that pretend to be a device on your
   Mac).

   A simulator runs on a *runtime*, a copy of iOS made for the Mac. Xcode
   may install two runtimes with the same iOS version, for example two
   called "iOS 27.2" with different build numbers in brackets. One is
   only for iPhone Duo, Apple's folding iPhone, and the other is for every
   other iPhone and iPad. Keep both. To see which is which, run
   `xcrun simctl list runtimes` in Terminal: the Duo's line ends with an
   identifier that names the device after the version (such as
   `iOS-27-2-iPhone19-4`), and the other's ends with the version alone
   (`iOS-27-2`).

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


Return to the [project overview](../README.md).
