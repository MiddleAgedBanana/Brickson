import Foundation
import Testing
@testable import Brickson

/// With the project's default main-actor isolation, a closure handed to a
/// system framework silently becomes main-actor isolated, and Swift 6 traps
/// at run time if the framework calls it from another thread. The reference
/// app crashed this way (docs/LESSONS.md, "Closures a framework may call off
/// the main thread"). Every such callback gets a test that calls it from a
/// background thread.
struct OffMainThreadCallbackTests {
    /// AVAudioSession documents outputVolume as KVO-observable but gives no
    /// thread guarantee. The observation must tolerate a background delivery.
    @Test func outputVolumeChangeCanArriveOnABackgroundThread() async {
        let monitor = AudioSafetyMonitor(
            initialOutputVolume: 0.5,
            readOutputVolume: { 0.1 },
            notificationCenter: NotificationCenter(),
            notificationObject: NSObject()
        )
        let handler = monitor.outputVolumeChangeHandler

        await Task.detached { handler() }.value
        // The handler only schedules a main-actor read; wait for it to land.
        for _ in 0..<100 where monitor.outputVolume != 0.1 {
            await Task.yield()
        }

        #expect(monitor.outputVolume == 0.1)
    }
}
