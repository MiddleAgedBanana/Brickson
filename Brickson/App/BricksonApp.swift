import SwiftData
import SwiftUI
import UIKit

/// The app's entry point. It opens the phrase library, creates the one
/// speech engine and the Get Attention alarm, and hands them to every screen
/// through the environment.
@main
struct BricksonApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var audioSafety: AudioSafetyMonitor
    @State private var speech: SpeechService
    @State private var attention: AttentionAlertPlayer
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

        let audio = AppAudio.makeForApp(settings: launch.settings)
        _audioSafety = State(initialValue: audio.safety)
        _speech = State(initialValue: audio.speech)
        _attention = State(initialValue: audio.attention)

        let opened = launch.openLibrary()
        let library = PhraseLibraryLaunch.prepare(container: opened.container, isVolatile: opened.isVolatile)
        container = library.container
        isVolatileStore = library.isVolatile
        phraseLibraryIssue = library.issue
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(audioSafety)
                .environment(speech)
                .environment(attention)
                .environment(\.isVolatileStore, isVolatileStore)
                .environment(\.phraseLibraryIssue, phraseLibraryIssue)
                .environment(\.appTimeouts, launch.timeouts)
                .preferredColorScheme(testColorScheme)
        }
        .modelContainer(container)
        .onChange(of: scenePhase, initial: true) { _, phase in
            UIApplication.shared.isIdleTimerDisabled = ScreenWakePolicy.keepsScreenAwake(in: phase)
            if phase == .active {
                // Back in the foreground: read again what may have changed
                // while away, the volume and an alarm that went quiet.
                audioSafety.refreshOutputVolume()
                attention.checkHealth()
            }
        }
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
}
