import SwiftUI
import Testing
@testable import Brickson

/// A locked screen can silence someone: Eye Tracking, head tracking, and
/// most switches cannot unlock the device, so if Auto-Lock fires they have
/// no voice until a caregiver comes into the room.
struct ScreenWakePolicyTests {
    @Test func screenStaysAwakeWhileTheAppIsVisible() {
        #expect(ScreenWakePolicy.keepsScreenAwake(in: .active))
        // Inactive is still visible: Control Center, a system alert, or an
        // incoming-call banner over the app. Locking then would be just as bad.
        #expect(ScreenWakePolicy.keepsScreenAwake(in: .inactive))
    }

    @Test func normalAutoLockReturnsOnceTheAppIsInTheBackground() {
        #expect(!ScreenWakePolicy.keepsScreenAwake(in: .background))
    }
}
