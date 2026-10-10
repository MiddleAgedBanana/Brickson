import SwiftUI

/// Whether iOS Auto-Lock is suspended. Someone using Eye Tracking, head
/// tracking or a switch may be unable to unlock the device, so a locked
/// screen can silence them until a caregiver comes into the room. The app
/// therefore keeps the screen on whenever it is visible.
///
/// Deliberately not a setting yet: a stray dwell that switched it off would
/// be discovered only after the screen had already locked someone out. When
/// input profiles exist, a touch profile may follow normal Auto-Lock instead
/// (docs/DECISIONS.md, "The screen stays awake").
nonisolated enum ScreenWakePolicy {
    static func keepsScreenAwake(in phase: ScenePhase) -> Bool {
        phase != .background
    }
}
