import SwiftUI

/// A-2 and A-3: one button in the middle of rings drawn 25 to 300 points
/// from its centre. A look resting on a ring shows whether Snap to Item
/// jumps that far, and changing the button's size (Options) shows whether
/// the reach counts from its centre or its edge. The button is exactly
/// the size chosen: a plain style adds no padding around it, an outline
/// shows its edge, and the log records the size it was laid out at.
struct RingsStation: View {
    @Environment(ProbeLog.self) private var log
    @Environment(ProbeOptions.self) private var options
    private let station = ProbeStation.rings

    var body: some View {
        ProbeStationScreen(station: station) {
            ZStack {
                Canvas { context, size in
                    let centre = CGPoint(x: size.width / 2, y: size.height / 2)
                    for radius in ProbeGeometry.ringRadii {
                        let ring = Path(ellipseIn: CGRect(
                            x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2))
                        context.stroke(ring, with: .color(.secondary), lineWidth: 1)
                        context.draw(
                            Text(verbatim: "\(Int(radius))").font(.caption2).foregroundStyle(.secondary),
                            at: CGPoint(x: centre.x + radius * 0.7071 + 10, y: centre.y - radius * 0.7071 - 8))
                    }
                }
                .accessibilityHidden(true)
                ProbeButton(
                    name: "Centre", station: station,
                    width: options.ringTarget.side, height: options.ringTarget.side)
                    .buttonStyle(.plain)
                    .background {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.accentColor, lineWidth: 2)
                    }
                    .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
                        log.record(
                            "Centre laid out at \(Int(size.width.rounded())) by \(Int(size.height.rounded())) points",
                            station: station.title)
                    }
            }
        }
    }
}

/// A-12, A-29, A-36 and B-4: a grid in the window's points, from its
/// top-left corner, with no controls of its own. It lies under the
/// navigation bar too, so a filmed pointer can be read against it at the
/// corners and edges. In a full-screen window, window points are screen
/// points.
struct RulerStation: View {
    private let station = ProbeStation.ruler

    var body: some View {
        ProbeStationScreen(station: station) {
            Color.clear
        }
        .background {
            Canvas { context, size in
                let step = ProbeGeometry.rulerStep
                let every = ProbeGeometry.rulerLabelEvery
                var x: CGFloat = 0
                while x <= size.width {
                    var line = Path()
                    line.move(to: CGPoint(x: x, y: 0))
                    line.addLine(to: CGPoint(x: x, y: size.height))
                    let major = x.truncatingRemainder(dividingBy: every) == 0
                    context.stroke(line, with: .color(.secondary.opacity(major ? 0.9 : 0.3)), lineWidth: 1)
                    x += step
                }
                var y: CGFloat = 0
                while y <= size.height {
                    var line = Path()
                    line.move(to: CGPoint(x: 0, y: y))
                    line.addLine(to: CGPoint(x: size.width, y: y))
                    let major = y.truncatingRemainder(dividingBy: every) == 0
                    context.stroke(line, with: .color(.secondary.opacity(major ? 0.9 : 0.3)), lineWidth: 1)
                    if major {
                        var labelX: CGFloat = 0
                        while labelX <= size.width {
                            context.draw(
                                Text(verbatim: "\(Int(labelX)),\(Int(y))").font(.caption2.monospacedDigit()),
                                at: CGPoint(x: labelX + 2, y: y + 2), anchor: .topLeading)
                            labelX += every
                        }
                    }
                    y += step
                }
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)
        }
    }
}

/// A-8: where a press lands. "Wide" moves its activation point over
/// "Landing": a press delivered as a touch at the activation point counts
/// on Landing, one delivered as an activation or at the pointer counts on
/// Wide. A-28 and D-18: does the Eye Tracking or Head Tracking pointer
/// show Apple's hover effects?
struct LandingStation: View {
    private let station = ProbeStation.landing
    private let wideWidth: CGFloat = 200
    private let gap: CGFloat = 32
    private let landingSide: CGFloat = 120

    var body: some View {
        ProbeStationScreen(station: station) {
            VStack(spacing: 64) {
                HStack(spacing: gap) {
                    ProbeButton(name: "Wide", station: station, width: wideWidth, height: landingSide)
                        .accessibilityActivationPoint(
                            CGPoint(x: wideWidth + gap + landingSide / 2, y: landingSide / 2))
                    ProbeButton(name: "Landing", station: station, width: landingSide, height: landingSide)
                }
                HStack(spacing: 48) {
                    ProbeButton(name: "No hover", station: station, width: 110)
                    ProbeButton(name: "Highlight", station: station, width: 110)
                        .hoverEffect(.highlight)
                    ProbeButton(name: "Lift", station: station, width: 110)
                        .hoverEffect(.lift)
                }
            }
            .buttonStyle(.bordered)
        }
    }
}
