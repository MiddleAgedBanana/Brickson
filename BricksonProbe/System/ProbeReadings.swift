import Accessibility
import Foundation
import SwiftUI

/// The values the Status and Screen stations read through the
/// Accessibility framework, Foundation and SwiftUI's environment.
enum ProbeReadings {
    static func accessibilitySettings() -> [ProbeStatusReading] {
        var readings = [
            ProbeStatusReading(
                name: "AccessibilitySettings.isAssistiveAccessEnabled",
                value: String(AccessibilitySettings.isAssistiveAccessEnabled)),
        ]
        if #available(iOS 26.1, *) {
            readings.append(ProbeStatusReading(
                name: "AccessibilitySettings.showBordersEnabled",
                value: String(AccessibilitySettings.showBordersEnabled)))
        }
        if #available(iOS 26.4, *) {
            readings.append(ProbeStatusReading(
                name: "AccessibilitySettings.isReduceHighlightingEffectsEnabled",
                value: String(AccessibilitySettings.isReduceHighlightingEffectsEnabled)))
        }
        if #available(iOS 27.0, *) {
            readings.append(ProbeStatusReading(
                name: "AccessibilitySettings.isApplicationAccessibilityEnabled",
                value: String(AccessibilitySettings.isApplicationAccessibilityEnabled)))
        }
        return readings
    }

    /// Low Power Mode and heat (A-22, A-39).
    static func power() -> [ProbeStatusReading] {
        [
            ProbeStatusReading(
                name: "ProcessInfo.isLowPowerModeEnabled",
                value: String(ProcessInfo.processInfo.isLowPowerModeEnabled)),
            ProbeStatusReading(
                name: "ProcessInfo.thermalState",
                value: ProbeStatusChanges.words(for: ProcessInfo.processInfo.thermalState)),
        ]
    }

    /// SwiftUI's own accessibility environment, as a view sees it.
    static func environment(_ values: EnvironmentValues) -> [ProbeStatusReading] {
        [
            ProbeStatusReading(name: "accessibilityEnabled", value: String(values.accessibilityEnabled)),
            ProbeStatusReading(
                name: "accessibilityVoiceOverEnabled", value: String(values.accessibilityVoiceOverEnabled)),
            ProbeStatusReading(
                name: "accessibilitySwitchControlEnabled",
                value: String(values.accessibilitySwitchControlEnabled)),
            ProbeStatusReading(
                name: "accessibilityAssistiveAccessEnabled",
                value: String(values.accessibilityAssistiveAccessEnabled)),
            ProbeStatusReading(name: "accessibilityReduceMotion", value: String(values.accessibilityReduceMotion)),
            ProbeStatusReading(
                name: "accessibilityReduceTransparency", value: String(values.accessibilityReduceTransparency)),
            ProbeStatusReading(
                name: "accessibilityDifferentiateWithoutColor",
                value: String(values.accessibilityDifferentiateWithoutColor)),
            ProbeStatusReading(name: "accessibilityInvertColors", value: String(values.accessibilityInvertColors)),
            ProbeStatusReading(
                name: "accessibilityShowButtonShapes", value: String(values.accessibilityShowButtonShapes)),
            ProbeStatusReading(name: "colorScheme", value: String(describing: values.colorScheme)),
            ProbeStatusReading(name: "colorSchemeContrast", value: String(describing: values.colorSchemeContrast)),
            ProbeStatusReading(name: "legibilityWeight", value: String(describing: values.legibilityWeight)),
            ProbeStatusReading(name: "dynamicTypeSize", value: String(describing: values.dynamicTypeSize)),
            ProbeStatusReading(name: "appearsActive", value: String(values.appearsActive)),
        ]
    }
}
