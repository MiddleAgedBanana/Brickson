import AVFoundation
import Foundation
import Testing

@testable import Brickson

@MainActor
struct AudioSessionCoordinatorTests {
    /// `.playback` plays with the silent switch on and the screen locked
    /// (invariant 4). `.default`, not `.spokenAudio`: with spoken audio,
    /// another app's spoken prompt could pause the person's sentence or the
    /// alarm. Fails if either changes.
    @Test func theSessionIsPlaybackInTheDefaultMode() {
        let harness = AudioHarness()

        harness.coordinator.configure()

        #expect(AudioSessionCoordinator.category == .playback)
        #expect(AudioSessionCoordinator.mode == .default)
        #expect(harness.audioSession.categoryCalls == [CategoryCall(category: .playback, mode: .default, options: [])])
        #expect(harness.audioSession.activeCalls.isEmpty)
    }

    @Test func aFailedConfigurationShowsAudioFailed() {
        let harness = AudioHarness()
        harness.audioSession.refusesCategory = true

        harness.coordinator.configure()

        #expect(!harness.safety.audioSessionHealthy)
    }

    @Test func anActivationThatIsNotRefusedIsExclusive() {
        let harness = AudioHarness()

        let activation = harness.coordinator.acquire(for: .speech)

        #expect(activation == .exclusive)
        #expect(harness.audioSession.isActive)
        #expect(harness.safety.audioSessionHealthy)
    }

    /// During a call an unmixed session is refused; a mixing one still
    /// plays. Fails if the fallback is missing or reported as a failure.
    @Test func duringACallTheSessionMixesRatherThanFailing() {
        let harness = AudioHarness()
        harness.audioSession.refusesUnmixedActivation = true

        let activation = harness.coordinator.acquire(for: .attentionAlert)

        #expect(activation == .mixedWithOtherAudio)
        #expect(harness.audioSession.categoryCalls.last?.options == [.mixWithOthers])
        #expect(harness.safety.audioSessionHealthy)
    }

    @Test func aRefusedActivationShowsAudioFailedUntilOneSucceeds() {
        let harness = AudioHarness()
        harness.audioSession.refusesActivation = true

        #expect(harness.coordinator.acquire(for: .speech) == .failed)
        #expect(!harness.safety.audioSessionHealthy)
        // The hold is still taken: the sound is attempted whatever happens.
        #expect(harness.coordinator.isHeld(by: .speech))

        harness.audioSession.refusesActivation = false
        #expect(harness.coordinator.acquire(for: .speech) == .exclusive)
        #expect(harness.safety.audioSessionHealthy)
    }

    /// 1.0 never deactivates, so the next phrase never waits and a release
    /// can never cut the alarm off. Fails if a release deactivates.
    @Test func keepActiveNeverDeactivates() {
        let harness = AudioHarness(policy: .keepActive)
        harness.coordinator.acquire(for: .speech)

        harness.coordinator.release(for: .speech)

        #expect(harness.audioSession.activeCalls == [true])
        #expect(harness.coordinator.holders.isEmpty)
    }

    /// The tested-only policy: deactivate once nobody holds the session,
    /// never while the alarm still sounds. Fails if speech ending
    /// deactivates under a sounding alarm.
    @Test func releaseWhenIdleWaitsForTheLastHolder() {
        let harness = AudioHarness(policy: .releaseWhenIdle)
        harness.coordinator.acquire(for: .attentionAlert)
        harness.coordinator.acquire(for: .speech)

        harness.coordinator.release(for: .speech)
        #expect(harness.audioSession.isActive)

        harness.coordinator.release(for: .attentionAlert)
        #expect(!harness.audioSession.isActive)
    }

    @Test func releasingWithoutAHoldChangesNothing() {
        let harness = AudioHarness(policy: .releaseWhenIdle)
        var changes = 0
        harness.coordinator.onHoldersChanged { changes += 1 }

        harness.coordinator.release(for: .speech)

        #expect(changes == 0)
        #expect(harness.audioSession.activeCalls.isEmpty)
    }

    /// Observers hear each real change once, after it is made. The alarm
    /// relies on this to set its level.
    @Test func holderObserversSeeEachChangeAfterItIsMade() {
        let harness = AudioHarness()
        var seen: [Bool] = []
        harness.coordinator.onHoldersChanged {
            seen.append(harness.coordinator.isHeld(by: .speech))
        }

        harness.coordinator.acquire(for: .speech)
        harness.coordinator.acquire(for: .speech)
        harness.coordinator.release(for: .speech)

        #expect(seen == [true, false])
    }

    /// Apple asks apps to restore the configuration after a media-services
    /// reset but to wait for the person's next action before activating.
    /// Fails if a reset activates the session.
    @Test func aResetRestoresTheConfigurationWithoutActivating() {
        let harness = AudioHarness()

        harness.notifications.mediaServicesReset()

        #expect(harness.audioSession.categoryCalls.count == 1)
        #expect(harness.audioSession.activeCalls.isEmpty)
        #expect(!harness.safety.audioSessionHealthy)
    }

    @Test func onlyAnEmptySessionDeactivatesAndOnlyUnderReleaseWhenIdle() {
        let holderSets: [Set<AudioSessionHolder>] = [[.speech], [.attentionAlert], [.speech, .attentionAlert]]
        for holders in holderSets {
            #expect(!AudioSessionLeasePolicy.releaseWhenIdle.deactivates(whenRemainingHolders: holders))
            #expect(!AudioSessionLeasePolicy.keepActive.deactivates(whenRemainingHolders: holders))
        }
        #expect(AudioSessionLeasePolicy.releaseWhenIdle.deactivates(whenRemainingHolders: []))
        #expect(!AudioSessionLeasePolicy.keepActive.deactivates(whenRemainingHolders: []))
    }
}
