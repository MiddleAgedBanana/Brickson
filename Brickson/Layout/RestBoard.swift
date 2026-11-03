import Foundation

/// The rest board: one everyday category the family chose in Set Up Step by
/// Step's second step, shown with Emergency's phrases, the grid's rows
/// taken from the larger of the two, with Yes, No, Emergency, Again and
/// Get Attention grown toward 4 degrees, at the late stage's sizes (docs/DECISIONS.md, "The late-stage
/// profile"). The other categories stay in their places, dimmed, so nothing
/// moves (invariant 8).
///
/// Plain logic: the family's choice (`SetupRecord.restBoardCategory`)
/// resolved against the library, read when Settings closes
/// (`ProfileChoice.request`), so nothing it decides changes under Settings.
nonisolated struct RestBoard: Equatable, Sendable {
    /// What the board needs to know of a category in the library.
    struct Category: Equatable, Sendable {
        var id: UUID
        var isEmergency: Bool
        var phrases: Int
    }

    /// The everyday category the board shows.
    let category: UUID
    /// How many phrases the grid leaves room for: the board's or
    /// Emergency's, whichever has more, so both show without scrolling
    /// wherever the board's sizes hold; at least one.
    let phrases: Int

    /// The board for `choice` in `library`, in Home's order: nil where
    /// nothing was chosen, or where the choice is no longer an everyday
    /// category of the library (a library made again has new categories),
    /// so Home shows every category. Emergency is never a board: its
    /// phrases show on every board already, from Emergency's own button.
    init?(choice: UUID?, in library: [Category]) {
        guard let choice, let chosen = library.first(where: { $0.id == choice && !$0.isEmergency }) else { return nil }
        let emergency = library.first(where: \.isEmergency)?.phrases ?? 0
        category = choice
        phrases = max(1, chosen.phrases, emergency)
    }
}
