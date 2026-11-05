import Foundation

/// The words in one of the Library's editors (Edit Phrase, New Phrase,
/// Rename Category and New Category): the field's `MessageComposer`, and
/// the words Save compares it with. Plain logic, tested without a screen.
///
/// Save is dimmed until the field differs from what it first showed, not
/// from the words as stored. The composer shows a stored line break as a
/// space, and a phrase restored from a backup can hold one, so compared
/// with the stored words such an editor opened with Save on: a held look
/// resting on Save would rewrite the person's words with nothing typed.
/// The chain sweeps take Save to change nothing until the words are edited
/// (`LibraryChains`; AGENTS.md, invariant 10).
nonisolated struct LibraryEditorWords: Equatable, Sendable {
    var composer: MessageComposer
    /// The words as the field first showed them, trimmed as the library
    /// keeps them; empty for a new phrase or category.
    let shown: String

    init(restoring stored: String = "") {
        composer = MessageComposer(restoring: stored)
        shown = LibraryText.trimmed(composer.text)
    }

    /// Words that differ from what the field first showed, and are not
    /// blank.
    var canSave: Bool {
        !LibraryText.isBlank(composer.text) && LibraryText.trimmed(composer.text) != shown
    }
}
