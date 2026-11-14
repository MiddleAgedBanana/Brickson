import SwiftUI

/// A-10 and A-45: two regions of three buttons. Options turn the regions'
/// containment and sort priority on and off; with sort priority on, the
/// right region comes first although it is drawn second.
struct GroupsStation: View {
    @Environment(ProbeOptions.self) private var options
    private let station = ProbeStation.groups

    var body: some View {
        ProbeStationScreen(station: station) {
            HStack(spacing: 64) {
                region(name: "Left region", buttons: ["Left 1", "Left 2", "Left 3"])
                    .accessibilitySortPriority(options.sortsGroups ? 1 : 0)
                region(name: "Right region", buttons: ["Right 1", "Right 2", "Right 3"])
                    .accessibilitySortPriority(options.sortsGroups ? 2 : 0)
            }
            .buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private func region(name: String, buttons: [String]) -> some View {
        let column = VStack(spacing: 32) {
            ForEach(buttons, id: \.self) { button in
                ProbeButton(name: button, station: station, width: 120)
            }
        }
        if options.containsGroups {
            column
                .accessibilityElement(children: .contain)
                .accessibilityLabel(Text(verbatim: name))
        } else {
            column
        }
    }
}

/// D-10, D-11, D-18, D-19 and G-21: twelve tiles for a steady look. Options
/// set same or varied sizes, rounded or capsule ends, Apple's hover
/// effects, and a moving dot beside the grid.
struct LookStation: View {
    @Environment(ProbeOptions.self) private var options
    @State private var shownAt = ContinuousClock.now
    private let station = ProbeStation.look
    private let names = [
        "One", "Two", "Three", "Four", "Five", "Six",
        "Seven", "Eight", "Nine", "Ten", "Eleven", "Twelve",
    ]

    var body: some View {
        ProbeStationScreen(station: station) {
            VStack(spacing: 0) {
                GeometryReader { proxy in
                    let columns = ProbeGeometry.lookColumns
                    let rows = ProbeGeometry.lookRows
                    let cell = CGSize(
                        width: proxy.size.width / CGFloat(columns), height: proxy.size.height / CGFloat(rows))
                    Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                        ForEach(0..<rows, id: \.self) { row in
                            GridRow {
                                ForEach(0..<columns, id: \.self) { column in
                                    let scale = ProbeGeometry.lookTileScale(
                                        row: row, column: column, sizing: options.tileSizing)
                                    tile(names[row * columns + column])
                                        .frame(
                                            width: max(44, (cell.width - 16) * scale),
                                            height: max(44, (cell.height - 16) * scale))
                                        .frame(width: cell.width, height: cell.height)
                                }
                            }
                        }
                    }
                }
                .padding(8)
                movingDot
                    .frame(height: 40)
            }
        }
    }

    private func tile(_ name: String) -> some View {
        ProbeButton(name: name, station: station, fills: true)
            .buttonStyle(.bordered)
            .buttonBorderShape(options.tileShape == .capsule ? .capsule : .roundedRectangle(radius: 12))
            .hoverEffect(
                options.hover == .lift ? HoverEffect.lift : HoverEffect.highlight,
                isEnabled: options.hover != .off)
    }

    /// Motion elsewhere on the screen (D-11): a dot that crosses the strip
    /// under the grid every four seconds, drawn, never an item.
    @ViewBuilder private var movingDot: some View {
        if options.motionElsewhere {
            TimelineView(.animation) { _ in
                Canvas { graphics, size in
                    let (seconds, attoseconds) = (ContinuousClock.now - shownAt).components
                    let phase = (Double(seconds % 4) + Double(attoseconds) / 1e18) / 4
                    let x = size.width * (phase < 0.5 ? phase * 2 : (1 - phase) * 2)
                    graphics.fill(
                        Path(ellipseIn: CGRect(x: x - 12, y: size.height / 2 - 12, width: 24, height: 24)),
                        with: .color(.accentColor))
                }
            }
            .accessibilityHidden(true)
        } else {
            Color.clear
        }
    }
}
