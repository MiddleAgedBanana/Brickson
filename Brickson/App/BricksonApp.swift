import SwiftData
import SwiftUI
import UIKit

/// The app's entry point. It opens the phrase library, creates the one
/// speech engine, the Get Attention alarm and the typed draft, and hands
/// them to every screen through the environment.
@main
struct BricksonApp: App {
    /// Refuses keyboards from other apps (`BricksonAppDelegate`).
    @UIApplicationDelegateAdaptor(BricksonAppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var audioSafety: AudioSafetyMonitor
    @State private var speech: SpeechService
    @State private var attention: AttentionAlertPlayer
    @State private var setup: SetupStore
    /// The message being typed on Home, kept across launches
    /// (Application Support/Typing; test storage under UI tests).
    @State private var drafts: DraftStore
    /// Whether Settings covers Home. Home's Settings button opens it; UI
    /// tests can open it at launch (`--screen=settings`).
    @State private var showsSettings: Bool
    /// The sizes Home asks for: Family Setup's answer when Settings last
    /// closed, while the owner's switch has Home follow it, so an answer
    /// changed there moves nothing under Settings, whose places come from
    /// Home's frames (`ProfileChoice`); a UI test's own in a debug build
    /// with test storage (`LaunchOptions`).
    @State private var requestedProfile: HomeLayout.Profile
    private let container: ModelContainer
    private let isVolatileStore: Bool
    private let phraseLibraryIssue: PhraseLibraryIssue?
    /// What a UI test asked for at launch; always `.standard` in a release
    /// build (`LaunchOptions`).
    private let launch: LaunchOptions

    init() {
        // First, before anything reads a setting or opens the library.
        let launch = LaunchOptions.current
        launch.prepareStorage()
        self.launch = launch

        let audio = AppAudio.makeForApp(
            settings: launch.settings,
            personalVoiceTrial: launch.personalVoice,
            attentionTone: launch.attentionTone
        )
        _audioSafety = State(initialValue: audio.safety)
        _speech = State(initialValue: audio.speech)
        _attention = State(initialValue: audio.attention)
        let setup = SetupStore(defaults: launch.settings)
        _setup = State(initialValue: setup)
        _requestedProfile = State(initialValue: Self.requestedProfile(answer: setup.record, launch: launch))
        _drafts = State(initialValue: DraftStore(directory: DraftFile.directory(in: launch.filesDirectory)))
        _showsSettings = State(initialValue: launch.startScreen == .settings)

        let opened = launch.openLibrary()
        let library = PhraseLibraryLaunch.prepare(
            container: opened.container,
            isVolatile: opened.isVolatile,
            issue: opened.issue
        )
        container = library.container
        isVolatileStore = library.isVolatile
        phraseLibraryIssue = library.issue
    }

    var body: some Scene {
        WindowGroup {
            HomeView(showsSettings: $showsSettings)
                .replacedByKeyboardProbe(when: launch.startScreen == .keyboardProbe)
                // Before the environment below, so Settings receives it too.
                .settingsCover(isPresented: $showsSettings)
                .environment(audioSafety)
                .environment(speech)
                .environment(attention)
                .environment(setup)
                .environment(drafts)
                .environment(\.showsSetupHint, FirstRunHint.isShown(for: setup.record))
                .environment(\.isVolatileStore, isVolatileStore)
                .environment(\.phraseLibraryIssue, phraseLibraryIssue)
                .environment(\.appTimeouts, launch.timeouts)
                .environment(\.requestedHomeProfile, requestedProfile)
                // The owner's switch, not a test's fixed sizes, decides,
                // so Settings' UI tests draw the first step as people see it.
                .environment(\.homeSizesFollowTheAnswer, ProfileChoice.followsTheAnswer || launch.activeHomeFollowsAnswer)
                .preferredColorScheme(testColorScheme)
                .onChange(of: showsSettings) { _, shows in
                    // Settings has closed: Home takes the sizes the answer
                    // now asks for.
                    if !shows {
                        requestedProfile = Self.requestedProfile(answer: setup.record, launch: launch)
                    }
                }
        }
        .modelContainer(container)
        .onChange(of: scenePhase, initial: true) { _, phase in
            UIApplication.shared.isIdleTimerDisabled = ScreenWakePolicy.keepsScreenAwake(in: phase)
            if phase == .active {
                // Back in the foreground: read again what may have changed
                // while away, the volume, an alarm that went quiet, and
                // whether a Personal Voice may be used.
                audioSafety.refreshOutputVolume()
                attention.checkHealth()
                speech.refreshPersonalVoiceAvailability()
            } else if phase == .background {
                // A save that failed while typing gets one more try before
                // the app may be closed (`DraftStore`).
                drafts.retrySave()
            }
        }
    }

    private static func requestedProfile(answer: SetupRecord, launch: LaunchOptions) -> HomeLayout.Profile {
        launch.activeHomeProfile
            ?? ProfileChoice.requestedForHome(by: answer.plannedAccessMethods, followsAnswer: followsAnswer(launch))
    }

    /// Whether Home's sizes follow Family Setup's answer: while the owner's
    /// switch is on (`ProfileChoice.followsTheAnswer`), or for a UI test
    /// that asks, never while a test has fixed the sizes.
    private static func followsAnswer(_ launch: LaunchOptions) -> Bool {
        launch.activeHomeProfile == nil && (ProfileChoice.followsTheAnswer || launch.activeHomeFollowsAnswer)
    }

    /// Release launches always use .standard, whose appearance is nil.
    /// A UI test's preference affects this presentation, not saved settings
    /// or the simulator's global appearance.
    private var testColorScheme: ColorScheme? {
        switch launch.appearance {
        case .some(.light): .light
        case .some(.dark): .dark
        case .none: nil
        }
    }
}

extension EnvironmentValues {
    /// True when the library is running in memory because the store on disk
    /// could not be opened: nothing changed now will be kept.
    @Entry var isVolatileStore: Bool = false
    /// Set when the starter phrases could not be prepared at launch.
    @Entry var phraseLibraryIssue: PhraseLibraryIssue? = nil
    /// The sizes Home and Settings lay Home out at (`ProfileChoice`):
    /// touch's, the ones Home has always had, unless the app sets them.
    @Entry var requestedHomeProfile: HomeLayout.Profile = .touch
    /// Whether the first step says what its answers do to Home's sizes:
    /// while the owner's switch has them follow the answer
    /// (`ProfileChoice.followsTheAnswer`), even where a UI test fixes them.
    @Entry var homeSizesFollowTheAnswer = false
}
