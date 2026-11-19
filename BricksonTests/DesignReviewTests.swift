import CoreGraphics
import SwiftUI
import Testing
import UIKit
@testable import Brickson

/// The design review sheet shows every building block on `main`
/// (`DesignReviewCatalogue`), and its readout says each setting the app
/// received (`DesignReviewReadoutLine`), so the capture script can refuse a
/// capture taken before a setting arrived. Debug builds only, like the
/// sheet; the unit tests are a debug build.
@MainActor
struct DesignReviewTests {
    // A fill added to `Palette` and not to the sheet, or one dropped from
    // it, fails this.
    @Test func everyFillIsOnTheSheetInPalettesOrder() {
        #expect(DesignReviewCatalogue.roles.map(\.asset) == Palette.assetNames)
    }

    // A role named twice, or a symbol that is not one, would hide a fill.
    @Test func everyRoleHasItsOwnNameAndASymbol() {
        let roles = DesignReviewCatalogue.roles
        #expect(Set(roles.map(\.name)).count == roles.count)
        for role in roles {
            #expect(UIImage(systemName: role.systemImage) != nil, "\(role.systemImage) is not an SF Symbol")
        }
    }

    // A step added to the spacing scale and not to the sheet fails this.
    @Test func everySpacingStepIsOnTheSheet() {
        #expect(DesignReviewCatalogue.spacing == Spacing.steps)
    }

    // Each kind of corner Apple's design uses, the concentric one with the
    // app's minimum, set where it measures what `CornerShapesTests` pins.
    @Test func everyKindOfCornerIsOnTheSheet() {
        let kinds = DesignReviewCatalogue.corners.map(\.kind)
        #expect(kinds.contains(.fixed(CornerRule.minimum)))
        #expect(kinds.contains(.capsule))
        #expect(kinds.contains(.concentric(minimum: CornerRule.minimum)))
        #expect(kinds.count == 3)
        let inner = CornerRule.concentricRadius(
            containerRadius: DesignReviewCatalogue.containerRadius,
            inset: DesignReviewCatalogue.containerInset,
            minimum: CornerRule.minimum
        )
        // Above the minimum, so the specimen shows a concentric corner, not
        // the minimum it falls back to.
        #expect(inner == 30)
        #expect(inner > CornerRule.minimum)
    }

    // Home's controls in every state each fill can take, and Settings'
    // rows in each fill they are drawn in.
    @Test func everyControlStateIsOnTheSheet() {
        let identifiers = DesignReviewCatalogue.identifiers
        for role in DesignReviewCatalogue.roles {
            for state in DesignReviewCatalogue.State.allCases {
                #expect(identifiers.contains(DesignReviewCatalogue.control(role, state)))
            }
        }
        #expect(DesignReviewCatalogue.settingsRoles.map(\.asset).sorted() == ["AccentColor", "ControlFill"])
        for role in DesignReviewCatalogue.settingsRoles {
            #expect(identifiers.contains(DesignReviewCatalogue.settingsRow(role, .on)))
            #expect(identifiers.contains(DesignReviewCatalogue.settingsRow(role, .off)))
        }
    }

    // The script finds each specimen by its identifier: two alike would
    // measure one twice and the other never.
    @Test func everySpecimenHasItsOwnIdentifier() {
        let identifiers = DesignReviewCatalogue.identifiers
        #expect(Set(identifiers).count == identifiers.count)
        #expect(!identifiers.contains(DesignReviewCatalogue.readout))
        #expect(identifiers.allSatisfy { $0.hasPrefix("review.") })
        // 5 swatches, 2 inks, 7 steps, 3 corners, 5 fills in 4 states,
        // 2 tiles, 2 Settings fills in 2 states.
        #expect(identifiers.count == 5 + 2 + 7 + 3 + 20 + 2 + 4)
    }

    // Each setting changes its own word, and only that word: a readout
    // that missed one would let a capture be saved under a setting the app
    // never received.
    @Test func theReadoutSaysEverySettingTheAppReceived() {
        let plain = DesignReviewReadoutLine(window: CGSize(width: 402, height: 874))
        #expect(plain.text == "scheme=light contrast=standard transparency=standard borders=off differentiate=off bold=off text=large window=active space=402x874")

        let changes: [(WritableKeyPath<DesignReviewReadoutLine, Bool>, String, String)] = [
            (\.dark, "scheme=light", "scheme=dark"),
            (\.increasedContrast, "contrast=standard", "contrast=increased"),
            (\.reduceTransparency, "transparency=standard", "transparency=reduced"),
            (\.showBorders, "borders=off", "borders=on"),
            (\.differentiateWithoutColour, "differentiate=off", "differentiate=on"),
            (\.boldText, "bold=off", "bold=on"),
        ]
        for (setting, before, after) in changes {
            var line = plain
            line[keyPath: setting] = true
            #expect(line.text == plain.text.replacingOccurrences(of: before, with: after))
        }
        var inactive = plain
        inactive.active = false
        #expect(inactive.text == plain.text.replacingOccurrences(of: "window=active", with: "window=inactive"))
        var largest = plain
        largest.textSize = .accessibility5
        #expect(largest.text == plain.text.replacingOccurrences(of: "text=large", with: "text=AX5"))
    }

    // Every text size has a name of its own, so AX4 is never read as AX5.
    @Test func everyTextSizeHasItsOwnName() {
        let names = DynamicTypeSize.allCases.map(DesignReviewReadoutLine.name(of:))
        #expect(Set(names).count == DynamicTypeSize.allCases.count)
        #expect(!names.contains("unknown"))
    }
}
