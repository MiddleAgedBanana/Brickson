import Foundation
import OSLog
import SwiftData

/// What a test asked the app to do differently when it launched.
///
/// UI tests launch the real app. Without these options they would run
/// against whatever library and settings the simulator kept from earlier
/// runs, and one test that deleted a phrase would break every later run.
/// A test passes them as launch arguments (`XCUIApplication.launchArguments`),
/// each `--name` or `--name=value`:
///
/// - `--test-storage`: everything the app saves (the phrase library,
///   settings, files) goes to a test-only folder and settings suite, never
///   to the person's own. A later launch with the same argument finds what
///   an earlier one saved, so a test can relaunch to check that something
///   was kept.
/// - `--fresh-test-storage`: the same, erased first, so the app starts as
///   if newly installed: the starter phrases and no saved settings.
/// - `--short-timeouts`: idle limits use their short test values
///   (`AppTimeouts`), so tests don't wait minutes.
/// - `--screen=keyboard-probe`: start on the typing work's keyboard probe
///   instead of Home.
/// - `--screen=settings`: open Settings over Home at launch.
/// - `--appearance=light|dark`: request the app's colour scheme for this
///   test launch. Without it, the app follows the system appearance.
/// - `--personal-voice=ask-from-settings`: ask for Personal Voice only from
///   Voice Settings' Ask button, never at launch, with the device's own
///   permission: the build device check D1 needs (docs/HANDOFF.md, "Checks
///   that need a real device"). Added to the scheme's arguments in Xcode,
///   it needs no change to the code.
/// - `--personal-voice=stand-in-refuses`: the same, with a stand-in
///   permission that has not been asked and refuses when asked
///   (`StandInPersonalVoice`), so UI tests reach the button and its answer.
/// - `--attention-tone=silent`: Get Attention plays a silent stand-in tone
///   (`SilentAttentionTonePlayback`) instead of the real one, so UI tests
///   sound and stop the alarm without sound and without depending on the
///   simulator's audio.
///
/// Text size still uses UIKit's `-UIPreferredContentSizeCategoryName`
/// argument. Appearance needs an app-local option because command-line
/// simulator runs can report `XCUIDevice.appearance == .dark` while the
/// app stays light. The UI tests verify the rendered colours separately.
///
/// Only debug builds read launch arguments. A release build, the one people
/// install, always runs with `.standard`, so nothing here can change what
/// the app does for a person.
nonisolated struct LaunchOptions: Equatable, Sendable {
    nonisolated enum Storage: Equatable, Sendable {
        /// The person's own library and settings.
        case standard
        /// The test-only place, keeping what earlier test launches saved.
        case test
        /// The test-only place, erased at launch.
        case freshTest
    }

    nonisolated enum StartScreen: String, Equatable, Sendable {
        case home
        case keyboardProbe = "keyboard-probe"
        case settings
    }

    nonisolated enum Appearance: String, Equatable, Sendable {
        case light
        case dark
    }

    /// A launch that asks for Personal Voice from Voice Settings instead of
    /// at launch (`AppAudio.personalVoiceAskPolicy(for:)`).
    nonisolated enum PersonalVoiceTrial: String, Equatable, Sendable {
        /// The device's own permission: for device check D1.
        case askFromSettings = "ask-from-settings"
        /// A stand-in that refuses when asked: for UI tests.
        case standInRefuses = "stand-in-refuses"
    }

    /// A launch that plays a stand-in for the Get Attention tone
    /// (`AppAudio.attentionTone(for:)`).
    nonisolated enum AttentionTone: String, Equatable, Sendable {
        /// Says it is playing and makes no sound: for UI tests.
        case silent
    }

    var storage = Storage.standard
    var usesShortTimeouts = false
    var startScreen = StartScreen.home
    /// Nil leaves the system in control. This is never a saved setting.
    var appearance: Appearance?
    /// Nil is the app's own: the device's permission, asked when the app
    /// starts.
    var personalVoice: PersonalVoiceTrial?
    /// Nil is the app's own: the real tone.
    var attentionTone: AttentionTone?
    /// Arguments written like these options but not understood: a misspelt
    /// name, an unknown value. They are logged at launch, so a typo in a
    /// test shows up instead of quietly running with the defaults.
    var unrecognized: [String] = []

    /// How the app runs for everyone who installs it.
    static let standard = LaunchOptions()

    /// True in debug builds, the only ones that read launch arguments.
    /// Tests run debug builds; `LaunchOptionsTests` checks this is true
    /// there, so UI tests never run against a person's real data.
    static var readsLaunchArguments: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    /// This launch's options.
    static var current: LaunchOptions {
        guard readsLaunchArguments else { return .standard }
        let options = parse(ProcessInfo.processInfo.arguments)
        if !options.unrecognized.isEmpty {
            Logger(subsystem: AppLog.subsystem, category: "launch")
                .error("Launch arguments not understood: \(options.unrecognized.joined(separator: " "), privacy: .public)")
        }
        return options
    }

    /// Reads the options from launch arguments. Arguments that don't start
    /// with `--` belong to the system (`-UIPreferredContentSizeCategoryName`,
    /// `-AppleLanguages`, the app's own path) and are left alone.
    static func parse(_ arguments: [String]) -> LaunchOptions {
        var options = LaunchOptions()
        for argument in arguments where argument.hasPrefix("--") {
            let parts = argument.dropFirst(2).split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            let name = String(parts[0])
            let value = parts.count > 1 ? String(parts[1]) : nil
            switch (name, value) {
            case ("test-storage", nil):
                // Fresh wins, in whichever order the two are given.
                if options.storage != .freshTest {
                    options.storage = .test
                }
            case ("fresh-test-storage", nil):
                options.storage = .freshTest
            case ("short-timeouts", nil):
                options.usesShortTimeouts = true
            case ("screen", let value?) where StartScreen(rawValue: value) != nil:
                options.startScreen = StartScreen(rawValue: value) ?? .home
            case ("appearance", let value?) where Appearance(rawValue: value) != nil:
                options.appearance = Appearance(rawValue: value)
            case ("personal-voice", let value?) where PersonalVoiceTrial(rawValue: value) != nil:
                options.personalVoice = PersonalVoiceTrial(rawValue: value)
            case ("attention-tone", let value?) where AttentionTone(rawValue: value) != nil:
                options.attentionTone = AttentionTone(rawValue: value)
            default:
                options.unrecognized.append(argument)
            }
        }
        return options
    }

    // MARK: - Where things are saved

    /// The test-only folder and settings suite are both called this. The
    /// folder is inside the app's own temporary folder, well away from the
    /// person's library in Application Support.
    static let testStorageName = "BricksonTestStorage"

    static var testDirectory: URL {
        URL.temporaryDirectory.appending(path: testStorageName, directoryHint: .isDirectory)
    }

    /// Where the app keeps files of its own (a typed draft, say).
    var filesDirectory: URL {
        storage == .standard ? .applicationSupportDirectory : Self.testDirectory
    }

    /// Where settings are saved. `LaunchOptionsTests` checks that the test
    /// suite can be created, so the fallback to `.standard` is never taken.
    var settings: UserDefaults {
        guard storage != .standard, let suite = UserDefaults(suiteName: Self.testStorageName) else {
            return .standard
        }
        return suite
    }

    /// Idle limits for this launch.
    var timeouts: AppTimeouts {
        usesShortTimeouts ? .short : .standard
    }

    /// Erases the test storage when this launch asked to start fresh. Runs
    /// first in `BricksonApp.init`, before anything reads a setting or
    /// opens the library.
    func prepareStorage(
        directory: URL = LaunchOptions.testDirectory,
        settingsSuite: String = LaunchOptions.testStorageName
    ) {
        guard storage == .freshTest else { return }
        do {
            try Self.eraseTestStorage(directory: directory, settingsSuite: settingsSuite)
        } catch {
            // Only a test launch gets here. Carrying on would run the test
            // against an earlier test's library and settings, so it could
            // pass or fail for the wrong reason: stop it at once instead.
            fatalError("UI-test storage could not be erased: \(error)")
        }
    }

    static func eraseTestStorage(directory: URL, settingsSuite: String) throws {
        if FileManager.default.fileExists(atPath: directory.path(percentEncoded: false)) {
            try FileManager.default.removeItem(at: directory)
        }
        UserDefaults(suiteName: settingsSuite)?.removePersistentDomain(forName: settingsSuite)
    }

    /// The phrase library for this launch: the person's own
    /// (`PhraseLibraryStore.openForApp()`), or the test-only one. If the
    /// test library cannot be opened, the app runs from memory and Home says
    /// changes won't be kept, which `launchedApp` in the UI tests checks for.
    func openLibrary(in directory: URL = LaunchOptions.testDirectory) -> PhraseLibraryStore.Opened {
        guard storage != .standard else {
            return PhraseLibraryStore.openForApp()
        }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let configuration = ModelConfiguration(
                schema: PhraseLibraryStore.schema,
                url: directory.appending(path: "PhraseLibrary.store"),
                cloudKitDatabase: .none
            )
            return PhraseLibraryStore.Opened(
                container: try PhraseLibraryStore.makeContainer(configuration),
                isVolatile: false,
                issue: nil
            )
        } catch {
            Logger(subsystem: AppLog.subsystem, category: "launch")
                .error("UI-test library failed to open, using memory: \(error)")
            do {
                return PhraseLibraryStore.Opened(
                    container: try PhraseLibraryStore.makeInMemoryContainer(),
                    isVolatile: true,
                    issue: nil
                )
            } catch {
                fatalError("Unable to create any phrase library: \(error)")
            }
        }
    }
}
