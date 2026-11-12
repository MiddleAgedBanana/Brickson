import Testing
@testable import Brickson

/// Set Up Step by Step's Next (`SettingsRoute.advance(_:from:entry:)`).
struct SettingsRouteTests {
    nonisolated static let entries: [GuidedSetupEntry] = [.setUpStepByStep, .setUpStepByStepAfterTheCheckIn, .checkIn]

    /// Next opens each step from the control the steps were opened with, so
    /// the second step, opened once the check-in card was answered, keeps
    /// its choices clear of the card's place (docs/DECISIONS.md, "The
    /// late-stage profile", *After the check-in, clear of the card's place
    /// too*). Fails if Next opens a step as if from Set Up Step by Step
    /// whatever opened the steps, as the app did when that placement was
    /// first pushed (Codex's and CodeRabbit's reviews of pull request #103).
    @Test(arguments: entries)
    func nextKeepsWhatOpenedTheSteps(entry: GuidedSetupEntry) throws {
        var path: [SettingsRoute] = [.familySetup, .guidedSetup(.access, from: entry)]
        for step in GuidedSetupStep.allCases.dropLast() {
            SettingsRoute.advance(&path, from: step, entry: entry)
            let next = try #require(step.next)
            #expect(path.last == .guidedSetup(next, from: entry))
        }
        #expect(path.count == 1 + GuidedSetupStep.count)
    }

    /// After the last step, Next goes back to the screen the steps were
    /// started from, whatever opened them. Fails if a step is left on the
    /// path or Family Setup is removed with them.
    @Test(arguments: entries)
    func nextOnTheLastStepGoesBackToWhereTheStepsStarted(entry: GuidedSetupEntry) {
        var path: [SettingsRoute] = [.familySetup] + GuidedSetupStep.allCases.map { .guidedSetup($0, from: entry) }
        SettingsRoute.advance(&path, from: .ready, entry: entry)
        #expect(path == [.familySetup])
    }
}
