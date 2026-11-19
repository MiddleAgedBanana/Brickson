import SwiftUI

/// A-1 first: what Snap to Item, Switch Control, Voice Control and Full
/// Keyboard Access do with each kind of element, set well apart so the
/// nearest item to each is never in doubt.
struct SnapStation: View {
    private enum Item: CaseIterable {
        case counter, dimmed, plainWords, interactiveWords, hidden, empty
        case actions, toggle, picker, roundShape, notResponding, traitWords
    }

    @Environment(ProbeLog.self) private var log
    @State private var toggleOn = false
    @State private var segment = "Phrases"
    private let station = ProbeStation.snap

    var body: some View {
        ProbeStationScreen(station: station) {
            GeometryReader { proxy in
                let columns = proxy.size.width < 600 ? 2 : 4
                let rows = (Item.allCases.count + columns - 1) / columns
                Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                    ForEach(0..<rows, id: \.self) { row in
                        GridRow {
                            ForEach(0..<columns, id: \.self) { column in
                                let index = row * columns + column
                                Group {
                                    if index < Item.allCases.count {
                                        cell(Item.allCases[index])
                                    } else {
                                        Color.clear
                                    }
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                    }
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .onChange(of: toggleOn) { _, on in
            log.record("Toggle turned \(on ? "on" : "off")", station: station.title)
        }
        .onChange(of: segment) { _, chosen in
            log.record("Picker: \(chosen) chosen", station: station.title)
        }
    }

    @ViewBuilder
    private func cell(_ item: Item) -> some View {
        switch item {
        case .counter:
            ProbeButton(name: "Counter", station: station)
        case .dimmed:
            ProbeButton(name: "Dimmed", station: station)
                .disabled(true)
        case .plainWords:
            Text(verbatim: "Plain words")
                .font(.title3)
        case .interactiveWords:
            Text(verbatim: "Interactive words")
                .font(.title3)
                .accessibilityRespondsToUserInteraction(true)
        case .hidden:
            ProbeButton(name: "Hidden", station: station)
                .accessibilityHidden(true)
        case .empty:
            ProbeEmptyPlace(word: "Empty place")
                .frame(width: 150, height: 80)
        case .actions:
            ProbeButton(name: "Actions", station: station)
                .accessibilityAction(named: Text(verbatim: "First action")) {
                    log.record("Actions: First action chosen", station: station.title)
                }
                .accessibilityAction(named: Text(verbatim: "Second action")) {
                    log.record("Actions: Second action chosen", station: station.title)
                }
        case .toggle:
            Toggle(isOn: $toggleOn) {
                Text(verbatim: "Toggle")
                    .font(.title3.weight(.semibold))
                    .frame(width: 150, height: 80)
            }
            .toggleStyle(.button)
        case .picker:
            Picker(selection: $segment) {
                Text(verbatim: "Phrases").tag("Phrases")
                Text(verbatim: "Type").tag("Type")
            } label: {
                Text(verbatim: "Phrases or Type")
            }
            .pickerStyle(.segmented)
            .frame(width: 180)
        case .roundShape:
            ProbeButton(name: "Round shape", station: station, width: 110, height: 110)
                .contentShape(.accessibility, Circle())
        case .notResponding:
            ProbeButton(name: "Not responding", station: station)
                .accessibilityRespondsToUserInteraction(false)
        case .traitWords:
            Text(verbatim: "Trait words")
                .font(.title3)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction {
                    log.record("Trait words: accessibility action", station: station.title)
                }
        }
    }
}
