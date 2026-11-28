import SwiftUI

extension View {
    /// This view, or the design review sheet when the launch asked for it
    /// (`--screen=design-review`, read by `LaunchOptions`). Only debug
    /// builds read launch arguments, and only they have the sheet: in a
    /// release build this is always the view itself.
    @ViewBuilder
    func replacedByDesignReview(when isRequested: Bool) -> some View {
        #if DEBUG
        if isRequested {
            DesignReviewScreen()
        } else {
            self
        }
        #else
        self
        #endif
    }
}

#if DEBUG
/// The design review sheet: every visual building block on `main`, drawn
/// by the app's own code, for the capture script in
/// `scripts/design-review/` to photograph in each appearance the system
/// offers (light, dark, Increase Contrast, Reduce Transparency, Show
/// Borders, Differentiate Without Colour, Bold Text, the largest text
/// size, an inactive window). Debug builds only, opened by the launch
/// argument `--screen=design-review` in place of Home; nothing on it
/// does anything or is saved (docs/DECISIONS.md, "A design review sheet in
/// debug builds").
///
/// It draws, never imitates: each colour is `Palette`'s, each control is
/// a standard `Button` in `HomeButtonStyle` or `settingsRowStyle`, each
/// corner is `CornerRule.Kind.shape`. It sets no appearance and writes no
/// accessibility setting into the environment: every appearance comes
/// from the system, and the readout at the top says which settings the
/// app received, so a capture can be checked against the setting it was
/// taken for. It prints no contrast ratio of its own: the script measures
/// each one from the screenshot's pixels, where a colour the system
/// changed after the token was read shows up (docs/DECISIONS.md, "Colour
/// tokens in four appearances").
struct DesignReviewScreen: View {
    private typealias Catalogue = DesignReviewCatalogue

    /// Room for one specimen across; a wide window takes several.
    private static let columns = [GridItem(.adaptive(minimum: 160), spacing: Spacing.large, alignment: .top)]
    /// A Home control's height on the sheet: twice the 44-point floor.
    private static let controlHeight: CGFloat = 88
    private static let tileHeight: CGFloat = 120

    /// The space the window gives the sheet, for the readout.
    @State private var window = CGSize.zero
    /// The word "Next word" has marked on the stepped sample; nil before
    /// the first.
    @State private var steppedWord: Int?
    @Environment(\.colorSchemeContrast) private var contrast

    /// The sentence the word marking is shown on.
    private static let spokenWords = MessageWords("Could you please bring me a glass of water?")
    /// The fixed places the sheet marks: before any word is reported, the
    /// first, a middle and the last word, and not speaking at all.
    private static let spokenSpecimens: [(name: String, marking: WordMarking?)] = [
        ("Speaking, no word reported yet", .nothingReported),
        ("First word", spokenWords.marking(reported: spokenWords.places[0])),
        ("Middle word", spokenWords.marking(reported: spokenWords.places[4])),
        ("Last word", spokenWords.marking(reported: spokenWords.places[spokenWords.places.count - 1])),
        ("Not speaking", nil),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xLarge) {
                DesignReviewReadout(window: window)
                section("Color tokens: words on each fill") {
                    grid(Catalogue.roles) { role in
                        specimen(role.asset) { swatch(role) }
                    }
                }
                section("Words on the screen") {
                    // The full width, as Home's message has it, so the
                    // words wrap as they do there.
                    VStack(alignment: .leading, spacing: Spacing.large) {
                        ForEach([Catalogue.primaryInk, Catalogue.statusInk], id: \.self) { identifier in
                            let isStatus = identifier == Catalogue.statusInk
                            specimen(isStatus ? "Status line" : "Primary ink") {
                                Text(verbatim: isStatus ? "Speaking" : "Choose a phrase to speak it.")
                                    .font((isStatus ? LabelFont.status : LabelFont.message).font)
                                    .foregroundStyle(.primary)
                                    .padding(Spacing.small)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .accessibilityElement(children: .combine)
                                    .accessibilityIdentifier(identifier)
                            }
                        }
                    }
                }
                section("Word being spoken") {
                    // Home's message as it is drawn while a phrase is
                    // spoken, at fixed places, and a button that steps the
                    // mark one word at a time. The full width, as on Home.
                    VStack(alignment: .leading, spacing: Spacing.large) {
                        ForEach(Self.spokenSpecimens, id: \.name) { specimen in
                            self.specimen(specimen.name) { spokenSample(marking: specimen.marking) }
                        }
                        self.specimen("Stepped by hand: \(steppedWord.map { "word \($0 + 1)" } ?? "nothing reported")") {
                            spokenSample(marking: steppedWord.map { Self.spokenWords.marking(reported: Self.spokenWords.places[$0]) } ?? .nothingReported)
                        }
                        // Debug only, like the whole sheet, so its words
                        // stay out of the String Catalog.
                        Button {
                            let next = (steppedWord ?? -1) + 1
                            steppedWord = next < Self.spokenWords.places.count ? next : nil
                        } label: {
                            Text(verbatim: "Next word")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                section("Spacing scale") {
                    grid(Catalogue.spacing) { step in
                        specimen("\(Int(step)) points") { spacing(step) }
                    }
                }
                section("Corners") {
                    grid(Catalogue.corners) { corner in
                        specimen(corner.name) { shape(corner) }
                    }
                }
                ForEach(Catalogue.roles, id: \.asset) { role in
                    section("Home control: \(role.name)") {
                        grid(Catalogue.State.allCases) { state in
                            specimen(state.rawValue) { control(role, state) }
                        }
                    }
                }
                section("Phrase tiles") {
                    grid([Catalogue.roles[0], Catalogue.roles[2]]) { role in
                        specimen(role.name) { tile(role) }
                    }
                }
                section("Settings rows") {
                    // The full width, as Settings gives its rows.
                    VStack(alignment: .leading, spacing: Spacing.large) {
                        ForEach(Catalogue.settingsRoles, id: \.asset) { role in
                            ForEach(Catalogue.settingsStates, id: \.self) { state in
                                specimen("\(role.name), \(state.rawValue)") { settingsRow(role, state) }
                            }
                        }
                    }
                }
            }
            .padding(Spacing.large)
        }
        .background {
            // The whole window, safe areas included.
            Color.clear
                .ignoresSafeArea(.container)
                .onGeometryChange(for: CGSize.self) { $0.size } action: { window = $0 }
        }
    }

    // MARK: - Layout

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            Text(verbatim: title)
                .font(.title2.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }

    private func grid<Item, Cell: View>(_ items: [Item], @ViewBuilder cell: @escaping (Item) -> Cell) -> some View {
        LazyVGrid(columns: Self.columns, alignment: .leading, spacing: Spacing.large) {
            ForEach(items.indices, id: \.self) { index in
                cell(items[index])
            }
        }
    }

    /// A specimen with its name under it, in primary ink.
    private func specimen(_ name: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            content()
            Text(verbatim: name)
                .font(.footnote)
                .foregroundStyle(.primary)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Specimens

    /// The sample sentence drawn as Home's message draws it
    /// (`SpokenMessageWords`), with `marking`.
    private func spokenSample(marking: WordMarking?) -> some View {
        SpokenMessageWords(
            content: SpokenMessageText.text(for: Self.spokenWords.message, setIn: nil),
            marking: marking,
            style: SpokenWordStyle(increasedContrast: contrast == .increased)
        )
        .font(LabelFont.message.font)
        .foregroundStyle(.primary)
        .padding(Spacing.small)
        .padding(.bottom, SpokenWordStyle.mostRoomBelow)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: Self.spokenWords.message))
    }

    private func fill(_ role: Catalogue.Role) -> Color {
        Palette.fills.first { $0.asset == role.asset }?.color ?? Palette.controlFill
    }

    /// A fill with the words every control draws on it, fitted as a
    /// control fits them (`FittedLabel`), so they never break.
    private func swatch(_ role: Catalogue.Role) -> some View {
        FittedLabel(role.name, font: .quickControl)
            .foregroundStyle(Palette.fillLabel)
            .padding(.horizontal, HomeLayout.labelInset.horizontal)
            .padding(.vertical, HomeLayout.labelInset.vertical)
            .frame(maxWidth: .infinity)
            .frame(height: Self.controlHeight)
            .background(fill(role), in: RoundedRectangle(cornerRadius: CornerRule.minimum, style: .continuous))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(Catalogue.colour(role))
    }

    /// Two blocks the step apart.
    private func spacing(_ step: CGFloat) -> some View {
        HStack(spacing: step) {
            ForEach(0..<2, id: \.self) { _ in
                Rectangle()
                    .fill(Palette.controlFill)
                    .frame(width: 44, height: 44)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(Int(step)) points"))
        .accessibilityIdentifier(Catalogue.spacing(step))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Each kind of corner, filled with the phrase fill; the concentric
    /// one inside a container of the control fill, as `CornerShapesTests`
    /// draws it.
    @ViewBuilder
    private func shape(_ corner: Catalogue.Corner) -> some View {
        let phrase = Palette.phraseFill
        Group {
            if case .concentric = corner.kind {
                ZStack {
                    RoundedRectangle(cornerRadius: Catalogue.containerRadius, style: .continuous)
                        .fill(Palette.controlFill)
                    corner.kind.shape
                        .fill(phrase)
                        .padding(Catalogue.containerInset)
                }
                .concentricContainer(radius: Catalogue.containerRadius)
            } else {
                corner.kind.shape.fill(phrase)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.controlHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: corner.name))
        .accessibilityIdentifier(Catalogue.corner(corner))
    }

    /// A Home control in one state, as Home draws it. A pressed specimen
    /// is drawn at rest: the script holds a touch on it for its capture.
    private func control(_ role: Catalogue.Role, _ state: Catalogue.State) -> some View {
        Button {} label: {
            FittedLabel(
                role.name,
                systemImage: state == .selected ? "checkmark.circle.fill" : role.systemImage,
                font: .quickControl
            )
        }
        .buttonStyle(HomeButtonStyle(fill: fill(role), isSelected: state == .selected, sideInset: HomeLayout.selectableSideInset))
        .disabled(state == .off)
        .frame(height: Self.controlHeight)
        .accessibilityIdentifier(Catalogue.control(role, state))
    }

    /// A phrase tile, as Home draws one on a wide window.
    private func tile(_ role: Catalogue.Role) -> some View {
        Button {} label: {
            FittedLabel(Catalogue.tileWords, font: .regularTile)
        }
        .buttonStyle(HomeButtonStyle(fill: fill(role)))
        .frame(height: Self.tileHeight)
        .accessibilityIdentifier(Catalogue.tile(role))
    }

    /// A Settings row: the system's bordered prominent button.
    private func settingsRow(_ role: Catalogue.Role, _ state: Catalogue.State) -> some View {
        Button {} label: {
            SettingsRowLabel(text: Text(verbatim: role.name), systemImage: role.systemImage)
        }
        .settingsRowStyle(fill: fill(role))
        .disabled(state == .off)
        .accessibilityIdentifier(Catalogue.settingsRow(role, state))
    }
}

/// The settings the app received, as one line at the top of the sheet,
/// so every capture says which appearance it shows
/// (`DesignReviewReadoutLine`).
private struct DesignReviewReadout: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityShowBorders) private var showBorders
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiate
    @Environment(\.legibilityWeight) private var legibilityWeight
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.appearsActive) private var appearsActive
    let window: CGSize

    var body: some View {
        let line = DesignReviewReadoutLine(
            dark: colorScheme == .dark,
            increasedContrast: contrast == .increased,
            reduceTransparency: reduceTransparency,
            showBorders: showBorders,
            differentiateWithoutColour: differentiate,
            boldText: legibilityWeight == .bold,
            textSize: dynamicTypeSize,
            active: appearsActive,
            window: window
        ).text
        Text(verbatim: line)
            .font(.footnote.monospaced())
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier(DesignReviewCatalogue.readout)
    }
}
#endif
