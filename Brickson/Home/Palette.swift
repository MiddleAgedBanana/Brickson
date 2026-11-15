import SwiftUI
import UIKit

/// The colours of every control, defined in the asset catalog. Each is a
/// token with four values, one for each appearance a person can choose:
/// light, dark, and each with Increase Contrast (Apple's "light and dark
/// variants, and an increased contrast option for each variant"). SwiftUI
/// picks the value from the environment's `colorScheme` and
/// `colorSchemeContrast`; nothing here chooses one. Today each token holds
/// the same value in all four, so the app looks as it did with one value
/// (docs/DECISIONS.md, "Colour tokens in four appearances").
///
/// Each is measured, not eyeballed (invariant 6): `PaletteTests` pins every
/// token's four values, the words on each fill in each appearance, and
/// each fill's edge (or the border that carries it) against the screen, in
/// a contrast budget whose known failures are named there. Recompute
/// before changing a value.
///
/// | Asset          | Value (all four) | Fill label on it | Against black | Against white |
/// |----------------|------------------|------------------|---------------|---------------|
/// | AccentColor    | `#0A60D6`        | 5.74:1           | 3.66:1        | 5.74:1        |
/// | ControlFill    | `#5A6474`        | 5.98:1           | 3.51:1        | 5.98:1        |
/// | EmergencyFill  | `#C8161E`        | 5.85:1           | 3.59:1        | 5.85:1        |
/// | AttentionFill  | `#B45309`        | 5.02:1           | 4.18:1        | 5.02:1        |
/// | StopFill       | `#0F766E`        | 5.47:1           | 3.84:1        | 5.47:1        |
/// | FillLabel      | `#FFFFFF`        | (the words on every fill)        |               |
///
/// Get Attention and Stop each have a colour of their own, unlike any other
/// control's, so neither is taken for the other or for Emergency at a
/// glance; their words and icons still say what they are, so nothing
/// depends on colour alone (docs/DECISIONS.md, "Solid fills on Home,
/// system glass elsewhere").
nonisolated enum Palette {
    /// Phrase tiles and the selected category.
    static let phraseFill = Color.accentColor
    /// Yes, No, Again, and categories that are not selected.
    static let controlFill = Color("ControlFill")
    /// The Emergency control and the emergency category's tiles.
    static let emergencyFill = Color("EmergencyFill")

    /// Get Attention, which sounds the alarm.
    static let attentionFill = Color("AttentionFill")
    /// Stop, which ends the alarm.
    static let stopFill = Color("StopFill")

    /// The words and icons on every fill above, wherever a control is
    /// drawn filled: Home's controls (`HomeButtonStyle`) and Settings' rows
    /// (`SettingsRowLabel`, `SettingsPairLabel`). A token of its own, so
    /// each appearance can carry its own words; white in all four today.
    static let fillLabel = Color("FillLabel")

    /// Every fill above, by asset name, for `PaletteTests`.
    static let assetNames = ["AccentColor", "ControlFill", "EmergencyFill", "AttentionFill", "StopFill"]
    /// `fillLabel`'s asset name, for `PaletteTests`.
    static let fillLabelAssetName = "FillLabel"

    /// The background of Settings and setup: UIKit's system background,
    /// the colour `PaletteTests` measures as "the screen" (and the one Home
    /// sits on, the window's own). SwiftUI has no colour of its own for it,
    /// and its background style changes with the container, so the screens
    /// use the colour that is measured (docs/DECISIONS.md, "Apple's current
    /// frameworks first").
    static let screen = Color(uiColor: screenColor)
    /// `screen` as UIKit's colour, which `PaletteTests` pins to the system
    /// background in every appearance.
    static let screenColor = UIColor.systemBackground
}
