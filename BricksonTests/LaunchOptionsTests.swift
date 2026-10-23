import Foundation
import SwiftData
import Testing
@testable import Brickson

/// UI tests start the app with launch arguments so each run begins from a
/// known library and settings, and never touches the person's own
/// (`LaunchOptions`). A release build ignores them.
struct LaunchOptionsTests {
    // MARK: Reading the arguments

    // Treating the app's own path, or any argument, as an option fails this.
    @Test func noOptionsMeansTheStandardApp() {
        #expect(LaunchOptions.parse(["/path/to/Brickson.app/Brickson"]) == .standard)
        #expect(LaunchOptions.parse([]) == .standard)
    }

    // Reading the system's single-dash arguments as ours fails this.
    @Test func theSystemsOwnArgumentsAreLeftToTheSystem() {
        let options = LaunchOptions.parse([
            "/path/to/Brickson",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
            "-AppleLanguages", "(en)",
        ])
        #expect(options == .standard)
    }

    // Dropping or misreading any one option fails this.
    @Test func everyOptionIsRead() {
        let options = LaunchOptions.parse([
            "/path/to/Brickson", "--test-storage", "--short-timeouts", "--screen=keyboard-probe",
        ])
        #expect(options.storage == .test)
        #expect(options.usesShortTimeouts)
        #expect(options.startScreen == .keyboardProbe)
        #expect(options.unrecognized.isEmpty)
        #expect(LaunchOptions.parse(["--fresh-test-storage"]).storage == .freshTest)
        #expect(LaunchOptions.parse(["--screen=settings"]).startScreen == .settings)
    }

    // Release launches use .standard. Giving that default an appearance
    // would override the person's system setting even without test flags.
    @Test func appearanceDefaultsToTheSystemAndOnlyChangesWhenRequested() {
        #expect(LaunchOptions.standard.appearance == nil)
        #expect(LaunchOptions.parse([]).appearance == nil)
        #expect(LaunchOptions.parse(["--appearance=light"]).appearance == .light)
        #expect(LaunchOptions.parse(["--appearance=dark"]).appearance == .dark)
        #expect(LaunchOptions.parse(["--appearance=dark"]).unrecognized.isEmpty)
    }

    // Release launches use .standard, which must ask at launch with the
    // device's own permission. Taking a typo for a trial, or misreading
    // one, fails this.
    @Test func thePersonalVoiceTrialIsReadOnlyWhenSpelledRight() {
        #expect(LaunchOptions.standard.personalVoice == nil)
        #expect(LaunchOptions.parse(["--personal-voice=ask-from-settings"]).personalVoice == .askFromSettings)
        #expect(LaunchOptions.parse(["--personal-voice=stand-in-refuses"]).personalVoice == .standInRefuses)
        #expect(LaunchOptions.parse(["--personal-voice=stand-in-refuses"]).unrecognized.isEmpty)

        let typos = ["--personal-voice", "--personal-voice=", "--personal-voice=refuses", "--personal-voice=Ask-From-Settings"]
        let options = LaunchOptions.parse(typos)
        #expect(options.personalVoice == nil)
        #expect(options.unrecognized == typos)
    }

    // Release launches use .standard, which plays the real tone. Taking a
    // typo for the silent stand-in, or missing it, fails this.
    @Test func theSilentToneIsReadOnlyWhenSpelledRight() {
        #expect(LaunchOptions.standard.attentionTone == nil)
        #expect(LaunchOptions.parse(["--attention-tone=silent"]).attentionTone == .silent)
        #expect(LaunchOptions.parse(["--attention-tone=silent"]).unrecognized.isEmpty)

        let typos = ["--attention-tone", "--attention-tone=", "--attention-tone=quiet", "--attention-tone=Silent"]
        let options = LaunchOptions.parse(typos)
        #expect(options.attentionTone == nil)
        #expect(options.unrecognized == typos)
    }

    // A typo must be reported, not silently interpreted as light or dark.
    @Test func malformedAppearanceArgumentsAreReportedWithoutAnOverride() {
        let arguments = ["--appearance", "--appearance=", "--appearance=system", "--appearance=DARK"]
        let options = LaunchOptions.parse(arguments)

        #expect(options.appearance == nil)
        #expect(options.unrecognized == arguments)
        #expect(LaunchOptions.parse(["--appearance=dark", "--appearance=invalid"]).appearance == .dark)
    }

    // A test asking for fresh storage must get it, whatever the order.
    @Test func freshTestStorageWinsInEitherOrder() {
        #expect(LaunchOptions.parse(["--test-storage", "--fresh-test-storage"]).storage == .freshTest)
        #expect(LaunchOptions.parse(["--fresh-test-storage", "--test-storage"]).storage == .freshTest)
    }

    // Guessing at a misspelt option, or ignoring it silently, fails this.
    @Test func misspeltOrUnknownOptionsAreReportedAndChangeNothing() {
        let arguments = ["--test-storag", "--short-timeouts=yes", "--screen=no-such-screen", "--test-storage=1", "--"]
        let options = LaunchOptions.parse(arguments)
        #expect(options.storage == .standard)
        #expect(!options.usesShortTimeouts)
        #expect(options.startScreen == .home)
        #expect(options.unrecognized == arguments)
    }

    // If DEBUG stopped being defined for test builds, UI tests would run on
    // the person's real library and settings; this fails first.
    @Test func testBuildsReadLaunchArguments() {
        #expect(LaunchOptions.readsLaunchArguments)
    }

    // MARK: Where things are saved

    // Sending the person's app to the test folder fails this.
    @Test func theStandardAppUsesThePersonsOwnPlaces() {
        #expect(LaunchOptions.standard.settings === UserDefaults.standard)
        #expect(LaunchOptions.standard.filesDirectory == URL.applicationSupportDirectory)
    }

    // Letting test storage fall back to the person's settings or folder
    // fails this.
    @Test func testStorageStaysAwayFromThePersonsPlaces() {
        #expect(UserDefaults(suiteName: LaunchOptions.testStorageName) != nil)
        for storage in [LaunchOptions.Storage.test, .freshTest] {
            var options = LaunchOptions()
            options.storage = storage
            #expect(options.settings !== UserDefaults.standard)
            #expect(options.filesDirectory == LaunchOptions.testDirectory)
            #expect(!options.filesDirectory.path().hasPrefix(URL.applicationSupportDirectory.path()))
        }
    }

    // Erasing nothing, or only the files, fails this.
    @Test func freshTestStorageErasesFilesAndSettings() throws {
        let place = try ScratchPlace()
        defer { place.remove() }
        try Data("an unsent draft".utf8).write(to: place.directory.appending(path: "draft.txt"))
        place.settings.set(0.4, forKey: "speechRate")

        var options = LaunchOptions()
        options.storage = .freshTest
        options.prepareStorage(directory: place.directory, settingsSuite: place.suiteName)

        #expect(!FileManager.default.fileExists(atPath: place.directory.path(percentEncoded: false)))
        #expect(place.settings.object(forKey: "speechRate") == nil)
    }

    // Erasing kept test storage (or the person's own) fails this.
    @Test func onlyFreshTestStorageIsErased() throws {
        let place = try ScratchPlace()
        defer { place.remove() }
        let draft = place.directory.appending(path: "draft.txt")
        try Data("an unsent draft".utf8).write(to: draft)
        place.settings.set(0.4, forKey: "speechRate")

        for storage in [LaunchOptions.Storage.standard, .test] {
            var options = LaunchOptions()
            options.storage = storage
            options.prepareStorage(directory: place.directory, settingsSuite: place.suiteName)
        }

        #expect(FileManager.default.fileExists(atPath: draft.path(percentEncoded: false)))
        #expect(place.settings.double(forKey: "speechRate") == 0.4)
    }

    @Test func erasingWhatIsNotThereIsHarmless() throws {
        let place = try ScratchPlace()
        defer { place.remove() }
        try FileManager.default.removeItem(at: place.directory)
        try LaunchOptions.eraseTestStorage(directory: place.directory, settingsSuite: place.suiteName)
    }

    // A test library that forgot between launches, or survived a fresh
    // start, fails this.
    @Test func theTestLibraryIsKeptBetweenLaunchesUntilAFreshStart() throws {
        let place = try ScratchPlace()
        defer { place.remove() }
        var kept = LaunchOptions()
        kept.storage = .test
        var fresh = LaunchOptions()
        fresh.storage = .freshTest

        do {
            let opened = fresh.openLibrary(in: place.directory)
            #expect(!opened.isVolatile)
            opened.container.mainContext.insert(PhraseCategory(name: "Mine", symbolName: "star.fill", sortOrder: 0))
            try opened.container.mainContext.save()
        }
        do {
            let opened = kept.openLibrary(in: place.directory)
            #expect(try opened.container.mainContext.fetchCount(FetchDescriptor<PhraseCategory>()) == 1)
        }
        fresh.prepareStorage(directory: place.directory, settingsSuite: place.suiteName)
        do {
            let opened = fresh.openLibrary(in: place.directory)
            #expect(try opened.container.mainContext.fetchCount(FetchDescriptor<PhraseCategory>()) == 0)
        }
    }

    // MARK: Idle limits

    // Shortening real limits, or ignoring --short-timeouts, fails this.
    @Test func shortLimitsOnlyWhenATestAsks() {
        #expect(LaunchOptions.standard.timeouts == .standard)
        #expect(LaunchOptions.parse(["--short-timeouts"]).timeouts == .short)
        #expect(AppTimeouts.standard.limit(.seconds(120), short: .seconds(3)) == .seconds(120))
        #expect(AppTimeouts.short.limit(.seconds(120), short: .seconds(3)) == .seconds(3))
    }
}

/// A folder and settings suite of a test's own, so tests running in
/// parallel never share one. Each test removes it with `defer`.
private struct ScratchPlace {
    let directory: URL
    let suiteName: String
    let settings: UserDefaults

    init() throws {
        let name = "LaunchOptionsTests-\(UUID().uuidString)"
        guard let settings = UserDefaults(suiteName: name) else {
            throw CocoaError(.featureUnsupported)
        }
        self.settings = settings
        suiteName = name
        directory = URL.temporaryDirectory.appending(path: name, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func remove() {
        try? FileManager.default.removeItem(at: directory)
        settings.removePersistentDomain(forName: suiteName)
    }
}
