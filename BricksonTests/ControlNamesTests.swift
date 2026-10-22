import Testing
@testable import Brickson

/// The names Voice Control and Full Keyboard Access use for Home's
/// controls (`accessibilityInputLabels`), and the check that no two
/// controls on one screen answer to the same name. The check over the
/// starter library is `HomeNameCollisionTests`.
struct ControlNamesTests {
    // MARK: Fixed controls

    /// Fails if a fixed control's names do not start with the words it
    /// shows. Voice Control lists the first name when a person says "Show
    /// names", and people say what they read on the screen.
    @Test func everyFixedControlAnswersFirstToTheWordsItShows() {
        for control in HomeControlNames.fixed {
            #expect(!control.visible.isEmpty)
            #expect(control.inputLabels.first == control.visible)
        }
    }

    /// Fails if a name has nothing to say in it, or a control lists the same
    /// name twice: neither gives the person another way to reach it.
    @Test func everyNameOfAFixedControlIsSayableAndNew() {
        for control in HomeControlNames.fixed {
            let forms = control.inputLabels.map(HomeControlNames.spokenForm)
            #expect(!forms.contains(""), "\(control.visible) has a name with nothing to say")
            #expect(Set(forms).count == forms.count, "\(control.visible) lists a name twice")
        }
    }

    /// Fails if the fixed controls change their names or order without
    /// docs/DECISIONS.md, "Home's scan order and names", changing too.
    @Test func theFixedControlsAndTheirNamesAreTheDecidedOnes() {
        #expect(HomeControlNames.fixed.map(\.inputLabels) == [
            ["Yes"],
            ["No"],
            ["Emergency"],
            ["Again", "Repeat"],
        ])
    }

    // MARK: Comparing names

    /// Fails if case, accents, punctuation or spacing make two names that
    /// sound the same count as different.
    @Test func namesAreComparedWithoutCaseAccentsPunctuationOrSpacing() {
        #expect(HomeControlNames.spokenForm("Yes.") == "yes")
        #expect(HomeControlNames.spokenForm("  Wait a moment,   please. ") == "wait a moment please")
        #expect(HomeControlNames.spokenForm("I'm okay.") == HomeControlNames.spokenForm("Im okay"))
        #expect(HomeControlNames.spokenForm("Café") == "cafe")
        #expect(HomeControlNames.spokenForm("Room 2") == "room 2")
    }

    /// Fails if a name made only of symbols counts as something to say.
    @Test func aNameWithNoLettersOrDigitsHasNothingToSay() {
        #expect(HomeControlNames.spokenForm("👍") == "")
        #expect(HomeControlNames.spokenForm(" ... ") == "")
    }

    @Test func twoControlsThatAnswerToTheSameNameCollide() {
        #expect(HomeControlNames.collisions(among: [["Yes"], ["yes."]]) == ["yes"])
        #expect(HomeControlNames.collisions(among: [["Again", "Repeat"], ["Basics"], ["Repeat!"]]) == ["repeat"])
        #expect(HomeControlNames.collisions(among: [["No"], ["Help"], ["no"], ["help"]]) == ["help", "no"])
    }

    /// Fails if one control repeating its own name, names that only share
    /// a word, or names with nothing to say are reported as collisions.
    @Test func onlyTwoDifferentControlsWithOneNameCollide() {
        #expect(HomeControlNames.collisions(among: [["Again", "again."]]) == [])
        #expect(HomeControlNames.collisions(among: [["Again", "Repeat"], ["Can you repeat that?"]]) == [])
        #expect(HomeControlNames.collisions(among: [["👍"], ["👍"]]) == [])
    }

    // MARK: Home's screen

    /// Fails if `onHome` leaves out the fixed controls, the category row or
    /// the phrase tiles, which would let a collision through unseen.
    @Test func homeListsEveryControlOnTheScreen() {
        #expect(HomeControlNames.collisions(among: HomeControlNames.onHome(categoryRow: ["Basics"], phrases: ["Again."])) == ["again"])
        #expect(HomeControlNames.collisions(among: HomeControlNames.onHome(categoryRow: ["Yes"], phrases: [])) == ["yes"])
        #expect(HomeControlNames.collisions(among: HomeControlNames.onHome(categoryRow: [], phrases: ["Repeat"])) == ["repeat"])
        #expect(HomeControlNames.collisions(among: HomeControlNames.onHome(categoryRow: ["Needs"], phrases: ["Needs"])) == ["needs"])
    }
}
