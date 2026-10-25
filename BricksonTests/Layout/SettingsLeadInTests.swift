import Foundation
import Testing
@testable import Brickson

/// The words about a Settings screen's first control, from the control's
/// frame and the width its screen gives them. Widths are content widths
/// (the window less Settings' 16pt gutters): 370 a 402pt iPhone, 1000 an
/// iPad Pro 13-inch in portrait. The root's row with its words on one line
/// is about 185pt wide at the default text size, about 442pt at AX5, read
/// from CI's iPhone captures.
struct SettingsLeadInTests {
    private static let spacing: CGFloat = 16

    private static func leadIn(width: CGFloat, control: CGRect, besideWidth: CGFloat = 185) -> SettingsLeadIn {
        SettingsLeadIn(
            width: width, spacing: spacing, control: control, besideWidth: besideWidth,
            // The note wraps to more lines in a narrower column.
            wordsHeight: { $0 < 600 ? 88 : 44 }
        )
    }

    /// Fails if the note leaves the side of a row that stands at the
    /// trailing side of a wide window with room beside it, or stops sitting
    /// at the row's top, or the content stops being as tall as the taller.
    @Test func besideARowAtTheTrailingSideTheNoteSitsAtItsTop() {
        let leadIn = Self.leadIn(width: 1000, control: CGRect(x: 806.4, y: 138, width: 193.6, height: 78))
        #expect(leadIn.isTwoColumns)
        #expect(leadIn.words == CGRect(x: 0, y: 138, width: 790.4, height: 44))
        #expect(leadIn.wordsLead)
        #expect(leadIn.size == CGSize(width: 1000, height: 216))
        let tall = SettingsLeadIn(
            width: 1000, spacing: Self.spacing, control: CGRect(x: 806.4, y: 40, width: 193.6, height: 78), besideWidth: 185,
            wordsHeight: { _ in 150 }
        )
        #expect(tall.size.height == 190)
    }

    /// Fails if the note goes beside the row where the room there is
    /// narrower than the row's words on one line, or not where it is
    /// exactly as wide.
    @Test func theNoteGoesBesideOnlyWhereTheRoomHoldsTheRowsWords() {
        let exact = Self.leadIn(width: 1000, control: CGRect(x: 458, y: 0, width: 542, height: 78), besideWidth: 442)
        #expect(exact.isTwoColumns)
        let short = Self.leadIn(width: 1000, control: CGRect(x: 457.5, y: 0, width: 542.5, height: 78), besideWidth: 442)
        #expect(!short.isTwoColumns)
    }

    /// Fails if Family Setup's Set Up Step by Step stops taking the frame
    /// of the root's row that opened it (its leading edge, top and width),
    /// stops growing downward where its own words need more lines, grows
    /// shorter than the row, or leaves a content narrower than the row's
    /// screen: a look still resting where the row was must meet it.
    @Test func setUpStepByStepTakesTheRowsPlace() {
        let row = CGRect(x: 806.4, y: 138, width: 193.6, height: 78)
        #expect(SettingsLeadIn.control(inPlaceOf: row, width: 1000, height: { _ in 64 }) == row)
        #expect(SettingsLeadIn.control(inPlaceOf: row, width: 1000, height: { $0 < 245 ? 110 : 78 }) == CGRect(x: 806.4, y: 138, width: 193.6, height: 110))
        let across = CGRect(x: 0, y: 90, width: 370, height: 78)
        #expect(SettingsLeadIn.control(inPlaceOf: across, width: 370, height: { _ in 78 }) == across)
        #expect(SettingsLeadIn.control(inPlaceOf: row, width: 900, height: { _ in 78 }) == CGRect(x: 706.4, y: 138, width: 193.6, height: 78))
        #expect(SettingsLeadIn.control(inPlaceOf: across, width: 320, height: { _ in 78 }) == CGRect(x: 0, y: 90, width: 320, height: 78))
    }

    /// Fails if words go beside a row that spans the width, as on a phone
    /// and for Family Setup's Set Up Step by Step where the row did.
    @Test func aRowAcrossTheWidthHasTheWordsAboveOrUnder() {
        #expect(!Self.leadIn(width: 370, control: CGRect(x: 0, y: 0, width: 370, height: 78)).isTwoColumns)
        #expect(!Self.leadIn(width: 1000, control: CGRect(x: 0, y: 200, width: 1000, height: 78)).isTwoColumns)
    }

    /// Fails if the words go above the control where they do not fit
    /// between the top of the content and it, with the rows' gap, or under
    /// it where they do: either way they must never overlap it.
    @Test func theWordsGoAboveWhereTheyFitAndUnderWhereTheyDoNot() {
        let above = Self.leadIn(width: 370, control: CGRect(x: 0, y: 104, width: 370, height: 78))
        #expect(above.words == CGRect(x: 0, y: 0, width: 370, height: 88))
        #expect(above.control == CGRect(x: 0, y: 104, width: 370, height: 78))
        #expect(above.wordsLead)
        #expect(above.size == CGSize(width: 370, height: 182))

        let under = Self.leadIn(width: 370, control: CGRect(x: 0, y: 103.5, width: 370, height: 78))
        #expect(under.control == CGRect(x: 0, y: 103.5, width: 370, height: 78))
        #expect(under.words == CGRect(x: 0, y: 197.5, width: 370, height: 88))
        #expect(!under.wordsLead)
        #expect(under.size == CGSize(width: 370, height: 285.5))
    }

    /// Fails if a control above the content is kept there, over the
    /// navigation bar.
    @Test func theControlNeverRisesAboveTheContent() {
        #expect(Self.leadIn(width: 370, control: CGRect(x: 0, y: -20, width: 370, height: 78)).control.minY == 0)
        #expect(Self.leadIn(width: 1000, control: CGRect(x: 806, y: -20, width: 194, height: 78)).control.minY == 0)
    }
}
