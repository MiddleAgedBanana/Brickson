import SwiftUI

/// Family Setup: everything a family member configures, one screen below
/// Settings' root.
///
/// Set Up Step by Step takes the place of the root's Family Setup row as
/// drawn (`SettingsLanding`), across the width and at least as tall, so a
/// look still resting where that row was meets a row that only opens the
/// next screen, and never Back to Talking, which would close Settings onto
/// Home (AGENTS.md, invariant 10; docs/DECISIONS.md, "Settings' first row,
/// placed from Home's frames"). The opening words go above it where they
/// fit and under it where they do not (`SettingsLeadIn`). Opening it once
/// marks Family Setup as opened, which ends Home's first-run hint.
struct FamilySetupView: View {
    @Environment(SetupStore.self) private var setup
    @Environment(SettingsLanding.self) private var landing: SettingsLanding?
    /// The check-in card was showing while this screen was open. Its place
    /// is then kept until the screen closes, so answering it moves nothing.
    @State private var checkInWasShown = false

    var body: some View {
        SettingsScreen(title: "Family Setup") {
            SettingsLeadInLayout(placement: placement, controlFirst: false, spacing: SettingsMetrics.rowSpacing) {
                SettingsParagraph("This is where a family member or carer sets up \(AppName.display): the voice it speaks with, help with reaching the screen, and how to keep it open. Nothing here is needed to start talking.")
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("familySetupOpening")

                NavigationLink(value: SettingsRoute.guidedSetup(.access)) {
                    // As tall as the place it is given.
                    SettingsRowLabel(title: "Set Up Step by Step", systemImage: "list.number")
                        .frame(maxHeight: .infinity)
                }
                .settingsRowStyle()
                .accessibilityIdentifier("guidedSetup")
            }

            // Under Set Up Step by Step, so a card that comes and goes never
            // moves it.
            CheckInCard(keepsItsPlace: checkInWasShown)
            SetupIssueText()

            NavigationLink(value: SettingsRoute.voice) {
                SettingsRowLabel(title: "Voice Settings", systemImage: "waveform")
            }
            .settingsRowStyle()
            .accessibilityIdentifier("voiceSettings")

            NavigationLink(value: SettingsRoute.reachingTheScreen) {
                SettingsRowLabel(title: "Reaching the Screen", systemImage: "hand.point.up.left.fill")
            }
            .settingsRowStyle()
            .accessibilityIdentifier("reachingTheScreen")

            NavigationLink(value: SettingsRoute.keepOpen) {
                SettingsRowLabel(title: "Keep \(AppName.display) Open", systemImage: "lock.fill")
            }
            .settingsRowStyle()
            .accessibilityIdentifier("keepOpen")

            NavigationLink(value: SettingsRoute.callsSiriAndShortcuts) {
                SettingsRowLabel(title: "Calls, Siri and Shortcuts", systemImage: "phone.fill")
            }
            .settingsRowStyle()
            .accessibilityIdentifier("callsSiriAndShortcuts")

            NavigationLink(value: SettingsRoute.moreAccessibility) {
                SettingsRowLabel(title: "More Accessibility Settings", systemImage: "accessibility")
            }
            .settingsRowStyle()
            .accessibilityIdentifier("moreAccessibility")

            NavigationLink(value: SettingsRoute.privacy) {
                SettingsRowLabel(title: "Privacy Policy", systemImage: "hand.raised.fill")
            }
            .settingsRowStyle()
            .accessibilityIdentifier("privacyPolicy")

            NavigationLink(value: SettingsRoute.about) {
                SettingsRowLabel(title: "About \(AppName.display)", systemImage: "info.circle.fill")
            }
            .settingsRowStyle()
            .accessibilityIdentifier("about")
        }
        .onAppear {
            if CheckInPolicy.isDue(setup.record, now: .now, calendar: .current) {
                checkInWasShown = true
            }
            setup.update { $0.familySetupOpened = true }
        }
    }

    private var placement: SettingsLeadInLayout.Placement {
        guard let row = landing?.rootRow else { return .atTheTop }
        return .across(top: row.minY, minHeight: row.height)
    }
}

/// Every three months, a passive card asks whether how the person reaches
/// the screen has changed (`CheckInPolicy`). Its three buttons sit apart,
/// and none of them changes how Brickson speaks.
///
/// Once it is answered, passive words take its place at the card's own size
/// until Family Setup closes. Otherwise the rows below would move up under
/// the button just chosen, where a held look or a switch's auto-select
/// could open one of them (AGENTS.md, invariant 10).
private struct CheckInCard: View {
    let keepsItsPlace: Bool
    @Environment(SetupStore.self) private var setup
    @Environment(SettingsActivity.self) private var activity: SettingsActivity?

    var body: some View {
        if CheckInPolicy.isDue(setup.record, now: .now, calendar: .current) {
            card
        } else if keepsItsPlace {
            card
                .hidden()
                .accessibilityHidden(true)
                .overlay(alignment: .topLeading) {
                    SettingsParagraph(afterword)
                }
        }
    }

    private var afterword: LocalizedStringKey {
        switch CheckInPolicy.afterword(for: setup.record) {
        case .askAgainLater: "Family Setup will ask again in 30 days."
        case .stopped: "Check-ins are off. Set Up Step by Step is always here."
        case .answered: "Family Setup will ask again in about three months."
        }
    }

    private var card: some View {
        SettingsCard {
            SettingsHeading("Time for a check-in")
            SettingsParagraph("Needs can change. Is the screen still reached the same way? Going through setup again takes a few minutes.")
            NavigationLink(value: SettingsRoute.guidedSetup(.access)) {
                SettingsRowLabel(title: "Go Through Setup Again", systemImage: "list.number")
            }
            .settingsRowStyle()
            HStack(spacing: SettingsMetrics.rowSpacing) {
                Button {
                    activity?.recordActivity()
                    setup.update { CheckInPolicy.notNow(&$0, now: .now, calendar: .current) }
                } label: {
                    SettingsPairLabel(title: "Not Now", systemImage: "clock")
                }
                .settingsRowStyle()
                Button {
                    activity?.recordActivity()
                    setup.update { CheckInPolicy.stopAsking(&$0) }
                } label: {
                    SettingsPairLabel(title: "Stop Asking", systemImage: "bell.slash")
                }
                .settingsRowStyle()
            }
        }
    }
}

/// The store's warnings, as passive text that never replaces anything.
struct SetupIssueText: View {
    @Environment(SetupStore.self) private var setup

    var body: some View {
        switch setup.issue {
        case .unreadableRecordSetAside:
            SettingsParagraph("Earlier setup answers could not be read, so setup starts again. Nothing else was changed.")
        case .couldNotSave:
            SettingsParagraph("The last change could not be saved. Try again.")
        case nil:
            EmptyView()
        }
    }
}
