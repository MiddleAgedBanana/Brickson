import SwiftUI
import UIKit

/// The fills behind every control on Home, defined in the asset catalog.
/// Each is measured, not eyeballed (invariant 6): white text on it clears
/// 4.5:1, and its edge clears 3:1 against both a white and a black screen,
/// so one value works in light and dark mode. `PaletteTests` holds
/// the line; recompute before changing a value.
///
/// | Asset          | Value     | White text | Against black | Against white |
/// |----------------|-----------|------------|---------------|---------------|
/// | AccentColor    | `#0A60D6` | 5.74:1     | 3.66:1        | 5.74:1        |
/// | ControlFill    | `#5A6474` | 5.98:1     | 3.51:1        | 5.98:1        |
/// | EmergencyFill  | `#C8161E` | 5.85:1     | 3.59:1        | 5.85:1        |
/// | AttentionFill  | `#B45309` | 5.02:1     | 4.18:1        | 5.02:1        |
/// | StopFill       | `#0F766E` | 5.47:1     | 3.84:1        | 5.47:1        |
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

    /// Every fill above, by asset name, for `PaletteTests`.
    static let assetNames = ["AccentColor", "ControlFill", "EmergencyFill", "AttentionFill", "StopFill"]

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
