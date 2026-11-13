import Foundation
import Testing
@testable import Brickson

/// Voice Settings reached with a held look (docs/DECISIONS.md, "Voice
/// Settings, reached with a held look"), scored by the chain engine on the
/// frames CI drew on `main` (run 43180245909, at `3f92a8b`): Family Setup
/// in its five windows, and Voice Settings where CI drew it. Under
/// AssistiveTouch Dwell, head tracking, Eye Tracking or Switch Control's
/// auto-select, a look held after choosing Family Setup's Voice Settings row
/// can choose whatever is nearest it once Voice Settings shows, and every
/// control there acts on the voice. Each test names the change that would
/// make it fail.
struct VoiceSettingsChainsTests {
    /// A window CI drew Family Setup in, in window coordinates, to a tenth
    /// of a point.
    nonisolated struct Window: CustomStringConvertible, Sendable {
        let name: String
        /// Settings' content as it shows unscrolled
        /// (`SettingsScreenFrames.content`): every Settings screen's starts
        /// at the same place in the window.
        let content: CGRect
        /// The standard Back button and Back to Talking, which sit in the
        /// same places on Family Setup and on Voice Settings.
        let navigation: [Control]
        /// Family Setup's rows, unscrolled.
        let familySetup: [Control]
        /// Voice Settings' controls under its navigation bar, as CI drew
        /// them on `main`, one list for each version of the screen CI drew
        /// in this window: without the Personal Voice card's button, and
        /// with Ask to Use Personal Voice
        /// (`--personal-voice=ask-from-settings`). Each goes down to the
        /// first voice's Hear and Use; the voices under them have the same
        /// frames lower down, so they are farther from every look above.
        let voiceSettings: [[Control]]

        var description: String { name }

        /// Family Setup's Voice Settings row, unscrolled.
        var row: CGRect {
            familySetup.first { $0.name == SettingsChains.voiceSettingsRow }!.frame
        }

        /// How far Family Setup scrolls: until its last row's foot reaches
        /// the foot of what shows.
        var furthestScroll: CGFloat {
            max(0, (familySetup.map(\.frame.maxY).max() ?? 0) - content.maxY)
        }
    }

    /// Where Family Setup's rows show in `window`: the content and the
    /// gutter around it, from the navigation bar's foot to the scroll
    /// view's.
    static func shows(in window: Window) -> ClosedRange<CGFloat> {
        (window.content.minY - SettingsMetrics.gutter)...(window.content.maxY + SettingsMetrics.gutter)
    }

    /// Every 4 points of Family Setup's scroll at which at least a point of
    /// its Voice Settings row shows, and the furthest.
    static func scrollsShowingTheRow(in window: Window) -> [CGFloat] {
        let first = max(0, window.row.minY - shows(in: window).upperBound + 1)
        let last = min(window.furthestScroll, window.row.maxY - shows(in: window).lowerBound - 1)
        guard first <= last else { return [] }
        return Array(stride(from: first, through: last, by: 4)) + [last]
    }

    typealias Control = (name: String, frame: CGRect)

    // MARK: - The frames CI drew

    /// The seven speeds, from the slowest: `top` is the first one's, and
    /// each is `step` below the one before.
    private nonisolated static func speeds(top: CGFloat, step: CGFloat, x: CGFloat = 16, width: CGFloat, height: CGFloat) -> [Control] {
        ["60% of normal speed", "70% of normal speed", "80% of normal speed", "90% of normal speed", "Normal speed",
         "110% of normal speed", "120% of normal speed"].enumerated().map { index, name in
            (name, CGRect(x: x, y: top + CGFloat(index) * step, width: width, height: height))
        }
    }

    /// Family Setup's rows under Set Up Step by Step, from Phrases and
    /// Categories, each `step` below the one before.
    private nonisolated static func rows(from top: CGFloat, step: CGFloat, width: CGFloat, height: CGFloat) -> [Control] {
        ["library", "voiceSettings", "reachingTheScreen", "keepOpen", "callsSiriAndShortcuts", "moreAccessibility",
         "privacyPolicy", "about"].enumerated().map { index, name in
            (name, CGRect(x: 16, y: top + CGFloat(index) * step, width: width, height: height))
        }
    }

    /// The iPhone 17 in portrait at the default text size.
    nonisolated static let phone = Window(
        name: "iPhone 17, portrait, default text",
        content: CGRect(x: 16, y: 222, width: 370, height: 566.3),
        navigation: [
            ("BackButton", CGRect(x: 16, y: 152, width: 44, height: 44)),
            ("backToTalking", CGRect(x: 252, y: 70, width: 134, height: 64)),
        ],
        familySetup: [("guidedSetup", CGRect(x: 16, y: 312, width: 370, height: 78))]
            + rows(from: 508.3, step: 94, width: 370, height: 78),
        voiceSettings: [
            speeds(top: 515.7, step: 94, width: 370, height: 78) + [
                ("Hear Automatic", CGRect(x: 16, y: 1288, width: 177, height: 78)),
                ("Use Automatic", CGRect(x: 209, y: 1288, width: 177, height: 78)),
            ],
            [("askPersonalVoice", CGRect(x: 32, y: 2381.3, width: 338, height: 78))]
                + speeds(top: 2865.3, step: 94, width: 370, height: 78) + [
                    ("Hear Automatic", CGRect(x: 16, y: 3637.7, width: 177, height: 78)),
                    ("Use Automatic", CGRect(x: 209, y: 3637.7, width: 177, height: 78)),
                ],
        ]
    )

    /// The iPhone 17 in portrait at the largest text size.
    nonisolated static let phoneLargestText = Window(
        name: "iPhone 17, portrait, AX5 text",
        content: CGRect(x: 16, y: 257, width: 370, height: 432),
        navigation: [
            ("BackButton", CGRect(x: 16, y: 187, width: 44, height: 44)),
            ("backToTalking", CGRect(x: 252, y: 70, width: 134, height: 99)),
        ],
        familySetup: [
            ("guidedSetup", CGRect(x: 16, y: 317, width: 370, height: 209.7)),
            ("library", CGRect(x: 16, y: 1304, width: 370, height: 274.7)),
            ("voiceSettings", CGRect(x: 16, y: 1594.7, width: 370, height: 144.7)),
            ("reachingTheScreen", CGRect(x: 16, y: 1755.3, width: 370, height: 144.7)),
            ("keepOpen", CGRect(x: 16, y: 1916, width: 370, height: 209.7)),
            ("callsSiriAndShortcuts", CGRect(x: 16, y: 2141.7, width: 370, height: 209.7)),
            ("moreAccessibility", CGRect(x: 16, y: 2367.3, width: 370, height: 274.7)),
            ("privacyPolicy", CGRect(x: 16, y: 2658, width: 370, height: 144.7)),
            ("about", CGRect(x: 16, y: 2818.7, width: 370, height: 144.7)),
        ],
        voiceSettings: [
            [("askPersonalVoice", CGRect(x: 32, y: 2583.3, width: 338, height: 274.7))]
                + speeds(top: 3275, step: 95.7, width: 370, height: 79.7) + [
                    ("Hear Automatic", CGRect(x: 16, y: 4484.3, width: 177, height: 106)),
                    ("Use Automatic", CGRect(x: 209, y: 4452, width: 177, height: 170.7)),
                ],
        ]
    )

    /// The 13-inch iPad in portrait at the default text size.
    nonisolated static let iPad = Window(
        name: "13-inch iPad, portrait, default text",
        content: CGRect(x: 16, y: 216, width: 1000, height: 1088),
        navigation: [
            ("BackButton", CGRect(x: 10, y: 146, width: 44, height: 44)),
            ("backToTalking", CGRect(x: 721.5, y: 40, width: 193.5, height: 88)),
        ],
        familySetup: [("guidedSetup", CGRect(x: 822.5, y: 354, width: 193.5, height: 78))]
            + rows(from: 448, step: 94, width: 1000, height: 78),
        voiceSettings: [
            speeds(top: 438.5, step: 94, width: 1000, height: 78) + [
                ("Hear Automatic", CGRect(x: 16, y: 1191, width: 492, height: 78)),
                ("Use Automatic", CGRect(x: 524, y: 1191, width: 492, height: 78)),
            ],
            [("askPersonalVoice", CGRect(x: 32, y: 1008, width: 968, height: 78))]
                + speeds(top: 1244.5, step: 94, width: 1000, height: 78) + [
                    ("Hear Automatic", CGRect(x: 16, y: 1997, width: 492, height: 78)),
                    ("Use Automatic", CGRect(x: 524, y: 1997, width: 492, height: 78)),
                ],
        ]
    )

    /// The 13-inch iPad in landscape at the default text size. CI drew
    /// Family Setup here, but not Voice Settings.
    nonisolated static let iPadLandscape = Window(
        name: "13-inch iPad, landscape, default text",
        content: CGRect(x: 16, y: 216, width: 1344, height: 744),
        navigation: [
            ("BackButton", CGRect(x: 10, y: 146, width: 44, height: 44)),
            ("backToTalking", CGRect(x: 962.5, y: 40, width: 262.5, height: 88)),
        ],
        familySetup: [("guidedSetup", CGRect(x: 1097.5, y: 355, width: 262.5, height: 78))]
            + rows(from: 449, step: 94, width: 1344, height: 78),
        voiceSettings: []
    )

    /// The 13-inch iPad in portrait at the largest text size.
    nonisolated static let iPadLargestText = Window(
        name: "13-inch iPad, portrait, AX5 text",
        content: CGRect(x: 16, y: 227, width: 1000, height: 1033),
        navigation: [
            ("BackButton", CGRect(x: 10, y: 157, width: 44, height: 44)),
            ("backToTalking", CGRect(x: 721.5, y: 40, width: 193.5, height: 99)),
        ],
        familySetup: [("guidedSetup", CGRect(x: 578.5, y: 378, width: 437.5, height: 145))]
            + rows(from: 804.5, step: 96, width: 1000, height: 80),
        voiceSettings: [
            [("askPersonalVoice", CGRect(x: 32, y: 1062, width: 968, height: 80))]
                + speeds(top: 1382, step: 96, width: 1000, height: 80) + [
                    ("Hear Automatic", CGRect(x: 16, y: 2329.5, width: 492, height: 106)),
                    ("Use Automatic", CGRect(x: 524, y: 2329.5, width: 492, height: 106)),
                ],
        ]
    )

    nonisolated static let windows = [phone, phoneLargestText, iPad, iPadLandscape, iPadLargestText]

    // MARK: - The model

    /// Family Setup scrolled `offset` points: its rows moved up, and those
    /// that no longer show left out.
    static func familySetup(in window: Window, scrolledBy offset: CGFloat) -> [Control] {
        window.navigation + window.familySetup.compactMap { name, frame in
            let shown = frame.offsetBy(dx: 0, dy: -offset)
            let shows = shows(in: window)
            return shown.maxY > shows.lowerBound && shown.minY < shows.upperBound ? (name, shown) : nil
        }
    }

    /// The Voice Settings row where it showed with Family Setup scrolled
    /// `offset` points, in Voice Settings' content (`SetupAnswersPlace.shown`),
    /// as Family Setup's row records it.
    static func rowAsShown(in window: Window, scrolledBy offset: CGFloat) -> CGRect {
        SetupAnswersPlace.shown(inContent(window.row, of: window), scrolledBy: offset)
    }

    static func inContent(_ frame: CGRect, of window: Window) -> CGRect {
        frame.offsetBy(dx: -window.content.minX, dy: -window.content.minY)
    }

    /// A version of Voice Settings as it is placed from `row`: Back to
    /// Family Setup in the row's place, at least as tall, and the screen's
    /// controls as one block at `LibraryQuestionPlace.choicesTop`, with no
    /// words between (`VoiceSettingsView`). The way back is taken to be as
    /// tall as the row; the UI tests read its real height.
    static func voiceSettings(_ version: [Control], in window: Window, placedFrom row: CGRect) -> [Control] {
        let place = LibraryQuestionPlace(
            row: row, width: window.content.width, visibleHeight: window.content.height,
            backHeight: { _ in row.height }, wordsHeight: { _ in 0 },
            spacing: SettingsMetrics.rowSpacing, rowHeight: SettingsMetrics.rowHeight
        )
        let wayBack = place.back.offsetBy(dx: window.content.minX, dy: window.content.minY)
        return window.navigation + [(SettingsChains.voiceWayBack, wayBack)]
            + version.map { ($0.name, $0.frame.offsetBy(dx: 0, dy: place.choicesTop)) }
    }

    /// Where CI did not draw Voice Settings, and as a version in every
    /// window: a speed across the content at its top stands in for the
    /// screen's first control, the nearest any of them can be to the look.
    static func firstControl(in window: Window) -> [Control] {
        [("60% of normal speed", CGRect(x: window.content.minX, y: window.content.minY, width: window.content.width, height: 78))]
    }

    static func versions(in window: Window) -> [[Control]] {
        window.voiceSettings + [firstControl(in: window)]
    }

    /// Family Setup and Voice Settings as the chain engine reads them, with
    /// the controls it does not know. Settings' first screen is left empty:
    /// chains that go back to it meet nothing.
    static func map(familySetup: [Control], voiceSettings: [Control]) -> (map: ChainMap, unknown: [String]) {
        SettingsChains.map(
            SettingsChains.Screens(root: [], familySetup: familySetup, firstStep: nil, voiceSettings: voiceSettings),
            closingOnto: "Home"
        )
    }

    /// The chains from choosing the Voice Settings row, with the look
    /// anywhere across the part of it that shows in `window`, and from
    /// every control of Voice Settings. A look cannot rest on the part of a
    /// row hidden under the navigation bar or past the scroll view's foot.
    static func chains(in map: ChainMap, window: Window) -> [Chain] {
        let shows = shows(in: window)
        let row = map.starts(in: SettingsChains.familySetup, lookPoints: { ChainEngine.points(across: $0) })
            .filter { $0.chosen?.name == SettingsChains.voiceSettingsRow && shows.contains($0.look.y) }
        return map.chains(from: row + map.starts(in: SettingsChains.voiceSettings))
    }

    static func paths(_ chains: [Chain]) -> Set<String> {
        Set(chains.filter { $0.end == .hazard }.map(\.path))
    }

    // MARK: - Tests

    /// Voice Settings as it is on `main`, with nothing in the row's place:
    /// on the iPhone 17 and the 13-inch iPad in portrait at the default text
    /// size, a look held on the row meets a speed, which changes how
    /// Brickson speaks. Fails if the chain surface cannot see Voice
    /// Settings, as before this change, when Family Setup's row led to a
    /// screen the chains did not follow.
    @Test func theScreenAsOnMainMeetsASpeed() {
        for window in [Self.phone, Self.iPad] {
            let (map, unknown) = Self.map(
                familySetup: Self.familySetup(in: window, scrolledBy: 0),
                voiceSettings: window.navigation + window.voiceSettings[0]
            )
            #expect(unknown == [], "\(window)")
            let chains = Self.chains(in: map, window: window)
            #expect(Self.paths(chains).contains("choosing voiceSettings → 70% of normal speed (changesData)"), "\(window)")
            #expect(
                chains.filter { $0.end == .hazard }.allSatisfy { SettingsChains.kind(of: $0) == .actsOnTheVoice },
                "\(window)"
            )
        }
    }

    /// With Back to Family Setup where the row showed and the screen's
    /// controls below it, no held look acts on the voice, in any of CI's
    /// five windows, at any scroll of Family Setup that shows the row, in
    /// every version of the screen; and a held look from the row meets the
    /// way back. Fails with the way back at the top of the screen, or the
    /// controls not moved down.
    @Test(arguments: windows)
    func noHeldLookActsOnTheVoice(in window: Window) {
        let scrolls = Self.scrollsShowingTheRow(in: window)
        #expect(!scrolls.isEmpty, "\(window)")
        for offset in scrolls {
            let familySetup = Self.familySetup(in: window, scrolledBy: offset)
            for version in Self.versions(in: window) {
                let (map, unknown) = Self.map(
                    familySetup: familySetup,
                    voiceSettings: Self.voiceSettings(version, in: window, placedFrom: Self.rowAsShown(in: window, scrolledBy: offset))
                )
                #expect(unknown == [], "\(window)")
                let chains = Self.chains(in: map, window: window)
                #expect(Self.paths(chains) == [], "\(window), scrolled \(offset)")
                let fromTheRow = chains.filter { $0.start.chosen?.name == SettingsChains.voiceSettingsRow }
                #expect(
                    fromTheRow.contains { $0.steps.contains { $0.control.name == SettingsChains.voiceWayBack } },
                    "\(window), scrolled \(offset)"
                )
            }
        }
    }

    /// Why the way back's place follows Family Setup's scroll: placed from
    /// where the row sits in Family Setup's content instead, on the iPhone
    /// at the default text size with the row scrolled up to the top of
    /// what shows, the way back lies lower than the look, which meets Back
    /// to Talking and closes Settings onto Home under it. Fails if the way
    /// back's place ignored the scroll and no such chain followed, which
    /// would mean the scroll test above proves nothing.
    @Test func placedFromTheContentAScrolledRowMeetsBackToTalking() {
        let window = Self.phone
        let offset = window.row.minY - window.content.minY
        let familySetup = Self.familySetup(in: window, scrolledBy: offset)
        let fromContent = Self.map(
            familySetup: familySetup,
            voiceSettings: Self.voiceSettings(window.voiceSettings[0], in: window, placedFrom: Self.inContent(window.row, of: window))
        ).map
        let closes = { (chains: [Chain]) in
            chains.contains { chain in
                chain.start.chosen?.name == SettingsChains.voiceSettingsRow
                    && chain.steps.contains { !$0.asked && $0.control.name == SettingsChains.backToTalking }
            }
        }
        #expect(closes(Self.chains(in: fromContent, window: window)))
        let asShown = Self.map(
            familySetup: familySetup,
            voiceSettings: Self.voiceSettings(
                window.voiceSettings[0], in: window, placedFrom: Self.rowAsShown(in: window, scrolledBy: offset)
            )
        ).map
        #expect(!closes(Self.chains(in: asShown, window: window)))
    }

    /// What each of Voice Settings' controls does for the chain engine, and
    /// where its ways back lead once Family Setup's check-in was answered.
    /// Fails if a control is unknown or misread: a speed, Use or Ask taken
    /// for something that changes nothing, Hear for something silent, Open
    /// Personal Voice Settings for a screen inside Brickson, or a way back
    /// leading anywhere but the Family Setup the screen was opened from.
    @Test func theSurfaceKnowsEveryVoiceControl() {
        let frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        let names = [
            SettingsChains.back, SettingsChains.voiceWayBack, SettingsChains.askPersonalVoice,
            SettingsChains.openPersonalVoiceSettings, "Normal speed", "70% of normal speed", "Hear Daniel", "Use Daniel",
        ]
        let (map, unknown) = SettingsChains.map(
            SettingsChains.Screens(
                root: [],
                familySetup: [(SettingsChains.voiceSettingsRow, frame), (SettingsChains.checkInNotNow, frame)],
                firstStep: nil,
                voiceSettings: names.map { ($0, frame) }
            ),
            closingOnto: "Home"
        )
        #expect(unknown == [])
        for (state, familySetup) in [
            (SettingsChains.voiceSettings, SettingsChains.familySetup),
            (SettingsChains.voiceSettingsAfterCheckIn, SettingsChains.familySetupAfterCheckIn),
        ] {
            let controls = Dictionary(uniqueKeysWithValues: (map.states[state] ?? []).map { ($0.name, $0) })
            #expect(controls[SettingsChains.back]?.leadsTo == familySetup, "\(state)")
            #expect(controls[SettingsChains.voiceWayBack]?.leadsTo == familySetup, "\(state)")
            #expect(controls[SettingsChains.back]?.effect == .navigates, "\(state)")
            #expect(controls[SettingsChains.voiceWayBack]?.effect == .navigates, "\(state)")
            #expect(controls[SettingsChains.askPersonalVoice]?.effect == .changesData, "\(state)")
            #expect(controls[SettingsChains.openPersonalVoiceSettings]?.effect == .leavesBrickson, "\(state)")
            #expect(controls["Normal speed"]?.effect == .changesData, "\(state)")
            #expect(controls["70% of normal speed"]?.effect == .changesData, "\(state)")
            #expect(controls["Hear Daniel"]?.effect == .speaks, "\(state)")
            #expect(controls["Use Daniel"]?.effect == .changesData, "\(state)")
        }
        let row = { (state: String) in map.states[state]?.first { $0.name == SettingsChains.voiceSettingsRow }?.leadsTo }
        #expect(row(SettingsChains.familySetup) == SettingsChains.voiceSettings)
        #expect(row(SettingsChains.familySetupAfterCheckIn) == SettingsChains.voiceSettingsAfterCheckIn)
        #expect(ChainEffect.leavesBrickson.isHazard)

        let leaving = ChainControl(SettingsChains.openPersonalVoiceSettings, frame, .leavesBrickson)
        let chain = Chain(
            start: .choosing(ChainControl(SettingsChains.voiceSettingsRow, frame, .navigates), in: SettingsChains.familySetupAfterCheckIn),
            rule: .centre, pointer: .staysOnControl,
            steps: [ChainStep(state: SettingsChains.voiceSettingsAfterCheckIn, control: leaving, asked: false)],
            end: .hazard
        )
        #expect(SettingsChains.kind(of: chain) == .actsOnTheVoice)
    }
}
