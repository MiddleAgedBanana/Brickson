import Accessibility
import SwiftUI

/// A-6, A-42, A-44 and G-01: after a countdown, five slots change at once
/// while the person holds a look or a scan on one of them. Start and Reset
/// sit apart at the bottom, so neither turns into the other in place.
struct ChangesStation: View {
    @Environment(ProbeLog.self) private var log
    @Environment(ProbeOptions.self) private var options
    @State private var countdown: ProbeCountdown?
    @State private var changed = false
    private let station = ProbeStation.changes

    var body: some View {
        ProbeStationScreen(station: station) {
            VStack(spacing: 32) {
                Grid(horizontalSpacing: 32, verticalSpacing: 32) {
                    GridRow {
                        slot { becomesAvailable }
                        slot { appears }
                        slot { wordsChange }
                    }
                    GridRow {
                        slot { movesHere }
                        slot { moverStart }
                        slot { disappears }
                    }
                }
                Spacer(minLength: 0)
                TimelineView(.periodic(from: .now, by: 0.25)) { _ in
                    Text(verbatim: countdownWords)
                        .font(.title2.monospacedDigit())
                        .accessibilityHidden(true)
                }
                HStack {
                    Button {
                        start()
                    } label: {
                        Text(verbatim: "Start countdown").frame(width: 170, height: 60)
                    }
                    .disabled(countdown != nil)
                    Spacer()
                    Button {
                        reset()
                    } label: {
                        Text(verbatim: "Reset").frame(width: 120, height: 60)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .buttonStyle(.bordered)
            .padding(.top, 24)
        }
        .task(id: countdown) {
            guard let countdown, !changed else { return }
            try? await Task.sleep(until: countdown.startedAt + countdown.length, clock: .continuous)
            guard !Task.isCancelled else { return }
            changed = true
            log.record("The slots changed", station: station.title)
            if options.postsLayoutChanged {
                AccessibilityNotification.LayoutChanged(nil).post()
                log.record("LayoutChanged posted", station: station.title)
            }
        }
    }

    private var countdownWords: String {
        guard let countdown else { return "Not started" }
        if changed { return "Changed" }
        return "Changes in \(countdown.secondsLeft(now: .now)) s"
    }

    private func slot<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content().frame(width: 150, height: 80)
    }

    private func start() {
        countdown = ProbeCountdown(startedAt: .now)
        log.record("Countdown started", station: station.title)
    }

    private func reset() {
        countdown = nil
        changed = false
        log.record("Reset", station: station.title)
    }

    @ViewBuilder private var becomesAvailable: some View {
        ProbeButton(name: "Becomes available", station: station)
            .disabled(!changed)
    }

    @ViewBuilder private var appears: some View {
        if changed {
            ProbeButton(name: "Appears", station: station)
        } else {
            ProbeEmptyPlace(word: "Appears here")
        }
    }

    @ViewBuilder private var wordsChange: some View {
        ProbeButton(name: changed ? "Second words" : "First words", station: station)
    }

    @ViewBuilder private var movesHere: some View {
        if changed {
            ProbeButton(name: "Mover", station: station)
        } else {
            ProbeEmptyPlace(word: "Mover comes here")
        }
    }

    @ViewBuilder private var moverStart: some View {
        if changed {
            ProbeEmptyPlace(word: "Mover left")
        } else {
            ProbeButton(name: "Mover", station: station)
        }
    }

    @ViewBuilder private var disappears: some View {
        if changed {
            ProbeEmptyPlace(word: "Gone")
        } else {
            ProbeButton(name: "Disappears", station: station)
        }
    }
}

/// A-43: what happens to a press made while the app's main thread is busy.
/// "Busy" holds the main thread for three seconds on purpose; the log
/// gives the busy time, and each press on Counter is logged when the app
/// handles it. Film the screen to see when each press was made.
struct BusyStation: View {
    static let busyFor: Duration = .seconds(3)

    @Environment(ProbeLog.self) private var log
    private let station = ProbeStation.busy

    var body: some View {
        ProbeStationScreen(station: station) {
            VStack {
                HStack {
                    Button {
                        holdBusy()
                    } label: {
                        Text(verbatim: "Busy for 3 seconds").frame(width: 200, height: 80)
                    }
                    Spacer()
                }
                Spacer()
                HStack {
                    Spacer()
                    ProbeButton(name: "Counter", station: station)
                }
            }
            .padding(32)
            .buttonStyle(.bordered)
        }
    }

    private func holdBusy() {
        let clock = ContinuousClock()
        let started = clock.now
        log.record("Busy from now", station: station.title, at: started)
        let deadline = started.advanced(by: Self.busyFor)
        while clock.now < deadline {}
        log.record("Busy until now", station: station.title)
    }
}
