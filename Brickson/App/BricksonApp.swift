import OSLog
import SwiftData
import SwiftUI
import UIKit

/// The app's entry point. It opens the phrase library, creates the one
/// speech engine, and hands both to every screen through the environment.
@main
struct BricksonApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var audioSafety: AudioSafetyMonitor
    @State private var speech: SpeechService
    private let container: ModelContainer
    private let isVolatileStore: Bool
    private let phraseLibraryIssue: PhraseLibraryIssue?

    init() {
        let audioSafety = AudioSafetyMonitor()
        _audioSafety = State(initialValue: audioSafety)
        _speech = State(initialValue: SpeechService(audioSafetyMonitor: audioSafety))

        let library = PhraseLibraryStore.openForApp()
        container = library.container
        isVolatileStore = library.isVolatile

        var issue: PhraseLibraryIssue?
        do {
            try PhraseLibrarySeeder.seedIfEmpty(library.container, with: StarterLibrary.bundled())
        } catch {
            // Not fatal: the quick controls still speak with an empty library.
            Logger(subsystem: AppLog.subsystem, category: "app")
                .error("Starter phrases could not be seeded: \(error)")
            issue = .starterPhrasesUnavailable
        }
        phraseLibraryIssue = issue
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(audioSafety)
                .environment(speech)
                .environment(\.isVolatileStore, isVolatileStore)
                .environment(\.phraseLibraryIssue, phraseLibraryIssue)
        }
        .modelContainer(container)
        .onChange(of: scenePhase, initial: true) { _, phase in
            UIApplication.shared.isIdleTimerDisabled = ScreenWakePolicy.keepsScreenAwake(in: phase)
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
