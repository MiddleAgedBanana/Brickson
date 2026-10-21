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

    init() {
        let audio = AppAudio.makeForApp(settings: .standard)
        _audioSafety = State(initialValue: audio.safety)
        _speech = State(initialValue: audio.speech)
        _attention = State(initialValue: audio.attention)

        let opened = PhraseLibraryStore.openForApp()
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
}

extension EnvironmentValues {
    /// True when the library is running in memory because the store on disk
    /// could not be opened: nothing changed now will be kept.
    @Entry var isVolatileStore: Bool = false
    /// Set when the starter phrases could not be prepared at launch.
    @Entry var phraseLibraryIssue: PhraseLibraryIssue? = nil
}
