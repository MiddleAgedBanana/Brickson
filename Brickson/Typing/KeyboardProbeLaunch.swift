import Foundation
import SwiftUI

/// Opens the keyboard probe (`KeyboardProbeScreen`) in place of Home, for
/// `KeyboardProbeTests` only. Debug builds alone honour the launch argument:
/// a release build ignores it and has no probe screen to open.
///
/// A stopgap: when the app's launch options can name a start screen, the
/// probe moves there and this type goes (docs/HANDOFF.md).
nonisolated enum KeyboardProbeLaunch {
    /// `KeyboardProbeTests` spells this out too, because UI tests cannot see
    /// the app's code; `KeyboardProbeLaunchTests` pins it.
    static let argument = "--screen=keyboard-probe"

    static func isRequested(arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        #if DEBUG
        arguments.contains(argument)
        #else
        false
        #endif
    }
}

extension View {
    /// This view, or the keyboard probe when the launch asked for it.
    @ViewBuilder
    func replacedByKeyboardProbeIfRequested() -> some View {
        #if DEBUG
        if KeyboardProbeLaunch.isRequested() {
            KeyboardProbeScreen()
        } else {
            self
        }
        #else
        self
        #endif
    }
}
