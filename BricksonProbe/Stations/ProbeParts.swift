import SwiftUI

/// A standard SwiftUI Button that writes each activation to the log with
/// its count. It sets no style of its own, so a station's style applies:
/// what each experiment measures is Apple's own control.
struct ProbeButton: View {
    let name: String
    let station: ProbeStation
    /// A fixed size, or nil for the size the style gives its words.
    var width: CGFloat? = 150
    var height: CGFloat? = 80
    /// Fills the space its parent gives it instead.
    var fills = false

    @Environment(ProbeLog.self) private var log
    @State private var count = 0

    var body: some View {
        Button {
            count += 1
            log.record("\(name) activated (#\(count))", station: station.title)
        } label: {
            Text(verbatim: name)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                // Only where a fixed size cannot hold the words (the
                // Rings station's 44-point button).
                .minimumScaleFactor(0.5)
                .frame(width: fills ? nil : width, height: fills ? nil : height)
                .frame(maxWidth: fills ? .infinity : nil, maxHeight: fills ? .infinity : nil)
        }
    }
}

extension View {
    /// A plain button with an outline for its edge. The plain style adds
    /// no padding, so the button's frame is exactly the size it was given:
    /// the Rings and Landing stations measure it.
    func probeExactButton() -> some View {
        buttonStyle(.plain)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.accentColor, lineWidth: 2)
            }
    }
}

/// The station's newest log line, large, at the top. Hidden from
/// accessibility, so it is never an item a pointer or scan can stop on.
/// It keeps two lines' height from the start, so a longer line never
/// moves the controls below it.
struct ProbeReadout: View {
    let station: ProbeStation

    @Environment(ProbeLog.self) private var log

    var body: some View {
        let entry = log.latest(on: station.title)
        Text(verbatim: entry.map { "\(ProbeLogFormat.seconds($0.elapsed)) s  \($0.event)" } ?? "Nothing yet")
            .font(.headline.monospacedDigit())
            .lineLimit(2, reservesSpace: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .accessibilityHidden(true)
    }
}

/// A place with nothing an assistive technology can find: a dashed
/// outline and a word, drawn, not laid out as views.
struct ProbeEmptyPlace: View {
    let word: String

    var body: some View {
        Canvas { context, size in
            let outline = Path(roundedRect: CGRect(origin: .zero, size: size).insetBy(dx: 2, dy: 2),
                               cornerRadius: 12)
            context.stroke(outline, with: .color(.secondary), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
            context.draw(
                Text(verbatim: word).font(.callout).foregroundStyle(.secondary),
                at: CGPoint(x: size.width / 2, y: size.height / 2))
        }
        .accessibilityHidden(true)
    }
}

/// Every station's screen: its readout on top, its content below, and the
/// standard Back button the navigation stack gives it.
struct ProbeStationScreen<Content: View>: View {
    let station: ProbeStation
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            ProbeReadout(station: station)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle(Text(verbatim: station.title))
        .toolbarTitleDisplayMode(.inline)
    }
}
