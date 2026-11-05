import Accessibility
import SwiftUI

/// A phrase or a category, for the screens that ask about either.
nonisolated enum LibraryItem: Hashable, Sendable {
    case phrase(UUID)
    case category(UUID)

    var id: UUID {
        switch self {
        case .phrase(let id), .category(let id): id
        }
    }
}

/// Words the Library's screens can show for a change that was not made.
enum LibraryMessages {
    /// Why a planned change was not written (`LibraryEditError`).
    static var failures: [String] {
        [LibraryEditError.libraryUnreadable, .libraryChanged, .saveFailed].map(\.message)
    }

    /// Why a change could not be planned, whatever it was.
    static var anyChange: [String] {
        [LibraryEditRejection.notFound, .libraryNeedsRepair].map(\.message) + failures
    }
}

/// A line kept for what a change did, or why it could not be made, as
/// passive words. Every version the line can show while its screen is
/// open is laid out hidden under it, and the line keeps the tallest height
/// it has had, so words that come and go never move a control below them
/// (AGENTS.md, "Controls keep their frames across every state of a
/// screen"). A person's own words in it are never translated.
struct LibraryResultLine: View {
    let text: String?
    let alternatives: [String]
    var identifier = "libraryResult"

    var body: some View {
        SettingsReservedParagraph(
            text: Text(verbatim: text ?? ""),
            alternatives: alternatives.map { Text(verbatim: $0) }
        )
        .settingsKeepsItsTallestHeight()
        .accessibilityElement(children: .combine)
        .accessibilityHidden(text == nil)
        .accessibilityIdentifier(identifier)
        .onChange(of: text) { _, words in
            // Said once as it appears, so a VoiceOver user hears what
            // their choice did without hunting for it.
            if let words, !words.isEmpty {
                AccessibilityNotification.Announcement(words).post()
            }
        }
    }
}

/// A row that opens one of the Library's question screens. It says where
/// it was on screen as it was chosen (`LibraryModel.askedFrom`), so the
/// question puts its way back there (`LibraryQuestionPlace`).
struct LibraryAskingRow: View {
    let title: LocalizedStringKey
    let systemImage: String
    let route: SettingsRoute
    @Binding var path: [SettingsRoute]

    @Environment(LibraryModel.self) private var library
    @Environment(SettingsActivity.self) private var activity: SettingsActivity?
    @Environment(\.settingsScrollPosition) private var scroll
    @State private var frame: CGRect?

    var body: some View {
        Button {
            activity?.recordActivity()
            library.askedFrom = frame.map { $0.offsetBy(dx: 0, dy: -(scroll?.offset ?? 0)) }
            path.append(route)
        } label: {
            SettingsRowLabel(title: title, systemImage: systemImage)
        }
        .settingsRowStyle()
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(SettingsMetrics.contentSpace)) } action: { frame = $0 }
    }
}

/// The field a phrase or a category's name is typed in. Like Home's
/// message field, it has no placeholder (the system's placeholder grey
/// measures under 4.5:1) and its edge is the control fill, which stands out
/// from the screen at 3:1 or better (`PaletteTests`). It keeps room for
/// `lines` lines whatever is typed, and scrolls past them, so Save and the
/// rows under it never move while words are typed.
struct LibraryTextField: View {
    let label: LocalizedStringKey
    let lines: Int
    @Binding var text: String
    let isFocused: FocusState<Bool>.Binding

    var body: some View {
        TextField(text: $text, prompt: Text(verbatim: ""), axis: .vertical) {
            Text(label)
        }
        .typingFieldTraits()
        .font(.title3)
        .foregroundStyle(.primary)
        .lineLimit(lines, reservesSpace: true)
        .focused(isFocused)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Palette.controlFill, lineWidth: 2)
        }
    }
}

/// Places a question screen's words, its way back and its choices where
/// `LibraryQuestionPlace` says, from the row that opened the screen. Its
/// three views are the words, the way back and the choices, in the order
/// VoiceOver reads them.
nonisolated struct LibraryQuestionLayout: Layout {
    /// The row that opened the screen, in this screen's content as it
    /// first shows; nil puts the way back at the top.
    let row: CGRect?
    /// How much of the content shows without scrolling.
    let visibleHeight: CGFloat
    /// The gap between the way back and the words: the rows' gap.
    let spacing: CGFloat
    /// A row's least height (`LibraryQuestionPlace`).
    let rowHeight: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let placed = placed(width: proposal.width, subviews: subviews) else { return .zero }
        return CGSize(width: placed.width, height: placed.frames.map(\.maxY).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let placed = placed(width: bounds.width, subviews: subviews) else { return }
        for (subview, frame) in zip(subviews, placed.frames) {
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(width: frame.width, height: frame.height)
            )
        }
    }

    /// The words', the way back's and the choices' frames, in that order.
    private func placed(width: CGFloat?, subviews: Subviews) -> (width: CGFloat, frames: [CGRect])? {
        guard subviews.count == 3 else { return nil }
        let words = subviews[0]
        let back = subviews[1]
        let choices = subviews[2]
        let width = width.flatMap { $0.isFinite ? $0 : nil } ?? choices.sizeThatFits(.unspecified).width
        let place = LibraryQuestionPlace(
            row: row, width: width, visibleHeight: visibleHeight,
            backHeight: { back.sizeThatFits(ProposedViewSize(width: $0, height: nil)).height },
            wordsHeight: { words.sizeThatFits(ProposedViewSize(width: $0, height: nil)).height },
            spacing: spacing, rowHeight: rowHeight
        )
        let choicesHeight = choices.sizeThatFits(ProposedViewSize(width: width, height: nil)).height
        return (width, [place.words, place.back, CGRect(x: 0, y: place.choicesTop, width: width, height: choicesHeight)])
    }
}

/// A Library question screen's content: the words, the way back in the
/// place of the row that asked, and the choices that change something
/// well below both (docs/DECISIONS.md, "The Library's question screens").
struct LibraryQuestion<Words: View, Back: View, Choices: View>: View {
    @ViewBuilder let words: Words
    @ViewBuilder let back: Back
    @ViewBuilder let choices: Choices

    @Environment(\.settingsScreenFrames) private var frames
    @Environment(LibraryModel.self) private var library

    var body: some View {
        LibraryQuestionLayout(
            row: library.askedFrom,
            visibleHeight: frames?.content.height ?? .greatestFiniteMagnitude,
            spacing: SettingsMetrics.rowSpacing,
            rowHeight: SettingsMetrics.rowHeight
        ) {
            VStack(alignment: .leading, spacing: SettingsMetrics.rowSpacing) {
                words
            }
            back
            VStack(alignment: .leading, spacing: SettingsMetrics.rowSpacing) {
                choices
            }
        }
    }
}

/// A question screen's way back: it only goes back to the screen that
/// asked. It is as tall as the place it is given, the asking row's.
struct LibraryWayBack: View {
    let title: LocalizedStringKey
    @Binding var path: [SettingsRoute]
    @Environment(SettingsActivity.self) private var activity: SettingsActivity?

    var body: some View {
        Button {
            activity?.recordActivity()
            if !path.isEmpty {
                path.removeLast()
            }
        } label: {
            SettingsRowLabel(title: title, systemImage: "arrow.uturn.backward")
                .frame(maxHeight: .infinity)
        }
        .settingsRowStyle()
        .accessibilityIdentifier("libraryWayBack")
    }
}
