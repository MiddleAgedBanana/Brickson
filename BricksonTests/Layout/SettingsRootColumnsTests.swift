import Foundation
import Testing
@testable import Brickson

/// Settings' first screen, from the width its screen gives it. Widths are
/// content widths (the window less Settings' 16pt gutters): 370 a 402pt
/// iPhone, 1000 an iPad Pro 13-inch in portrait. Row widths are the row
/// with its words on one line, read from CI's iPhone captures: about 185pt
/// at the default text size, about 442pt at AX5.
struct SettingsRootColumnsTests {
    private static let spacing: CGFloat = 16

    private static func columns(width: CGFloat, rowIdealWidth: CGFloat) -> SettingsRootColumns {
        SettingsRootColumns(
            width: width,
            spacing: spacing,
            rowIdealWidth: rowIdealWidth,
            rowHeight: { _ in 110 },
            // The note wraps to more lines in a narrower column.
            noteHeight: { $0 < 600 ? 88 : 44 }
        )
    }

    /// Fails if the row leaves the bar's trailing column on a wide window,
    /// where a full-width row's centre lies farther from the spot Home's
    /// Settings was than Back to Talking's (`SettingsOnHomeTests`), or if
    /// the columns stop matching the bar's: two equal halves with its gap.
    @Test func onAWideWindowTheRowTakesTheBarsTrailingColumn() {
        for rowIdealWidth: CGFloat in [185, 442] {
            let columns = Self.columns(width: 1000, rowIdealWidth: rowIdealWidth)
            #expect(columns.isTwoColumns, "row \(rowIdealWidth)pt")
            #expect(columns.row == CGRect(x: 508, y: 0, width: 492, height: 110), "row \(rowIdealWidth)pt")
            #expect(columns.note == CGRect(x: 0, y: 0, width: 492, height: 88), "row \(rowIdealWidth)pt")
            #expect(columns.size == CGSize(width: 1000, height: 110), "row \(rowIdealWidth)pt")
        }
    }

    /// Fails if a phone squeezes the row into half its width, where its
    /// words would wrap beside the icon (AGENTS.md, "Words never break").
    @Test func onAPhoneTheRowSpansTheWidthWithTheNoteUnderIt() {
        let columns = Self.columns(width: 370, rowIdealWidth: 185)
        #expect(!columns.isTwoColumns)
        #expect(columns.row == CGRect(x: 0, y: 0, width: 370, height: 110))
        #expect(columns.note == CGRect(x: 0, y: 126, width: 370, height: 88))
        #expect(columns.size == CGSize(width: 370, height: 214))
    }

    /// Fails if the columns come where a half is narrower than the row's
    /// words, or not where a half holds them exactly.
    @Test func theColumnsComeExactlyWhereAHalfHoldsTheRow() {
        let exact = 2 * 442 + Self.spacing
        #expect(Self.columns(width: exact, rowIdealWidth: 442).isTwoColumns)
        #expect(!Self.columns(width: exact - 0.5, rowIdealWidth: 442).isTwoColumns)
    }

    /// Fails if the screen is not as tall as its taller column, so a long
    /// note would run into whatever follows it.
    @Test func sideBySideTheContentIsAsTallAsTheTallerColumn() {
        let columns = SettingsRootColumns(
            width: 1000,
            spacing: Self.spacing,
            rowIdealWidth: 185,
            rowHeight: { _ in 110 },
            noteHeight: { _ in 150 }
        )
        #expect(columns.size.height == 150)
    }
}
