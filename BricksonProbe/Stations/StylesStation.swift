import SwiftUI

/// A-1a, A-33, D-01, D-02, D-13, D-16, D-17, D-20, D-21 and D-24: Apple's
/// own controls, each enabled and dimmed, on one scrolling page under the
/// navigation bar, for screenshots in every appearance and for the
/// Accessibility Inspector. Nothing here is Brickson's design.
struct StylesStation: View {
    @Environment(\.appearsActive) private var appearsActive
    @State private var toggleOn = false
    @State private var segment = "Phrases"
    private let station = ProbeStation.styles

    var body: some View {
        ProbeStationScreen(station: station) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text(verbatim: "appearsActive: \(appearsActive)")
                        .font(.headline)
                    section("Control sizes, bordered prominent") {
                        ForEach(Self.sizes, id: \.name) { size in
                            button(size.name)
                                .buttonStyle(.borderedProminent)
                                .controlSize(size.size)
                        }
                    }
                    section("Styles, enabled and dimmed") {
                        pair("Automatic")
                        pair("Bordered").buttonStyle(.bordered)
                        pair("Bordered prominent").buttonStyle(.borderedProminent)
                        pair("Borderless").buttonStyle(.borderless)
                        pair("Plain").buttonStyle(.plain)
                        pair("Glass").buttonStyle(.glass)
                        pair("Glass prominent").buttonStyle(.glassProminent)
                    }
                    section("Large glass with border shapes") {
                        button("Capsule").buttonBorderShape(.capsule)
                        button("Rounded 12").buttonBorderShape(.roundedRectangle(radius: 12))
                        ProbeButton(name: "Circle", station: station, width: nil, height: nil)
                            .buttonBorderShape(.circle)
                    }
                    .buttonStyle(.glass)
                    .controlSize(.large)
                    section("Toggles and pickers") {
                        Toggle(isOn: $toggleOn) { Text(verbatim: "Switch toggle") }
                        Toggle(isOn: $toggleOn) { Text(verbatim: "Button toggle") }
                            .toggleStyle(.button)
                        ForEach(Self.sizes, id: \.name) { size in
                            Picker(selection: $segment) {
                                Text(verbatim: "Phrases").tag("Phrases")
                                Text(verbatim: "Type").tag("Type")
                            } label: {
                                Text(verbatim: "Segmented, \(size.name)")
                            }
                            .pickerStyle(.segmented)
                            .controlSize(size.size)
                        }
                    }
                    section("Glass effects") {
                        Text(verbatim: "Glass panel")
                            .padding(20)
                            .glassEffect()
                        Text(verbatim: "Interactive glass panel")
                            .padding(20)
                            .glassEffect(.regular.interactive())
                    }
                    section("Rows to scroll under the bar") {
                        ForEach(1...20, id: \.self) { number in
                            Text(verbatim: "Row \(number)")
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }
                    }
                }
                .padding(24)
            }
        }
    }

    private static let sizes: [(name: String, size: ControlSize)] = [
        ("Mini", .mini), ("Small", .small), ("Regular", .regular), ("Large", .large),
        ("Extra large", .extraLarge),
    ]

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(verbatim: title)
                .font(.title3.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }

    private func button(_ name: String) -> some View {
        ProbeButton(name: name, station: station, width: nil, height: nil)
    }

    private func pair(_ name: String) -> some View {
        HStack(spacing: 16) {
            button(name)
            button("\(name), dimmed").disabled(true)
        }
    }
}
