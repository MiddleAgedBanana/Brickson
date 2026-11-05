import Testing
@testable import Brickson

/// When the Library's editors offer Save (`LibraryEditorWords`). Each test
/// names the change that would make it fail.
struct LibraryEditorWordsTests {
    /// A phrase restored from a backup can hold a line break, which the
    /// field shows as a space. Fails if Save compares the field with the
    /// stored words instead of what the field first showed: the editor
    /// then opens with Save on, and a held look on it rewrites the words
    /// with nothing typed.
    @Test(arguments: ["Please\nhelp.", "Line one\r\nline two", "Water\u{2028}now", "  Tea\n"])
    func anEditorOpenedOnALineBreakSavesOnlyOnceEdited(stored: String) {
        var words = LibraryEditorWords(restoring: stored)
        #expect(!words.canSave)
        _ = words.composer.apply(.propose(words.composer.text + " please"))
        #expect(words.canSave)
    }

    /// Fails if typing back exactly what the field showed leaves Save on,
    /// or if words that differ only in the spaces around them count as a
    /// change, which the library trims away.
    @Test func wordsBackAsTheyWereDimSave() {
        var words = LibraryEditorWords(restoring: "I'm thirsty")
        _ = words.composer.apply(.propose("I'm thirsty now"))
        #expect(words.canSave)
        _ = words.composer.apply(.propose("I'm thirsty"))
        #expect(!words.canSave)
        _ = words.composer.apply(.propose(" I'm thirsty "))
        #expect(!words.canSave)
    }

    /// Fails if words emptied, or left as spaces, can be saved: the library
    /// refuses them, so Save stays dimmed.
    @Test func emptiedWordsDimSave() {
        var words = LibraryEditorWords(restoring: "I'm thirsty")
        _ = words.composer.apply(.propose(""))
        #expect(!words.canSave)
        _ = words.composer.apply(.propose("   "))
        #expect(!words.canSave)
    }

    /// Fails if a new phrase or category can be saved blank, or cannot be
    /// saved once words are typed.
    @Test func aNewEditorSavesOnlyWords() {
        var words = LibraryEditorWords()
        #expect(words.shown.isEmpty)
        #expect(!words.canSave)
        _ = words.composer.apply(.propose("   "))
        #expect(!words.canSave)
        _ = words.composer.apply(.propose("Music"))
        #expect(words.canSave)
    }
}
