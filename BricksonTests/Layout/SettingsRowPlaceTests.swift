import Foundation
import Testing
@testable import Brickson

/// Where Settings' first screen puts its Family Setup row, from Home's
/// frames (`SettingsRowPlace`). Settings' screens are modelled as CI drew
/// them on PR #53: the navigation bar starts 8 points under Back to Talking
/// and is 64 points tall, the content starts 16 points under it, and the
/// sound line takes 40 points at the foot. Windows run from 320 to 1432
/// points wide at heights from a 568pt phone to a 13-inch iPad in portrait,
/// with the phone's and the iPad's safe areas, at every text size of
/// `HomeLayoutEngineTests.textSizes`, with Bold Text off and on.
struct SettingsRowPlaceTests {
    struct Window {
        let size: CGSize
        let home: HomeLayout
        let content: CGRect
        let navigationBar: CGRect
        let context: String

        /// `requested`, the profile Family Setup's answer asks for, gives
        /// Home the sizes `ProfileChoice` takes in this window; touch's by
        /// default.
        init(size: CGSize, safeArea: HomeLayout.Insets, text: HomeLayout.Text, context: String,
             requested: HomeLayout.Profile = .touch) {
            self.size = size
            home = ProfileChoice.layout(requested: requested, space: .init(size: size, safeArea: safeArea),
                text: text, modes: .phrasesAndTyping)
            navigationBar = CGRect(
                x: safeArea.leading, y: home.backToTalking.maxY + 8,
                width: size.width - safeArea.leading - safeArea.trailing, height: 64
            )
            let top = navigationBar.maxY + 16
            content = CGRect(
                x: safeArea.leading + 16, y: top,
                width: size.width - safeArea.leading - safeArea.trailing - 32,
                height: max(0, size.height - safeArea.bottom - 40 - 16 - top)
            )
            self.context = context
        }

        /// The root's row with its words on one line: 185 points at the
        /// default size, 442 at the largest, and between in proportion to
        /// the text; and its height at a width: 78 points, or two lines'
        /// worth where the width is short of its words.
        func rowIdealWidth(text: HomeLayout.Text) -> CGFloat {
            185 + (442 - 185) * (text.categoryLine - 22) / (65 - 22)
        }

        func rowHeight(text: HomeLayout.Text, width: CGFloat) -> CGFloat {
            let lines: CGFloat = rowIdealWidth(text: text) <= width ? 1 : 2
            return max(SettingsRowPlaceTests.labelMinHeight, lines * text.categoryLine) + 14
        }

        func place(text: HomeLayout.Text) -> (place: SettingsRowPlace, row: CGRect) {
            let place = SettingsRowPlace(
                home: home, rowIdealWidth: rowIdealWidth(text: text), rowHeight: { rowHeight(text: text, width: $0) },
                content: content, navigationBar: navigationBar
            )
            return (place, place.row)
        }
    }

    nonisolated(unsafe) static var labelMinHeight: CGFloat = 64

    static let phoneSafeArea = HomeLayout.Insets(top: 62, leading: 0, bottom: 34, trailing: 0)
    static let padSafeArea = HomeLayout.Insets(top: 32, leading: 0, bottom: 20, trailing: 0)

    /// CI's iPhone 17 and 13-inch iPad Pro, in each orientation CI runs.
    static func ciWindow(_ device: String, text: HomeLayout.Text) -> Window {
        switch device {
        case "phone": Window(size: CGSize(width: 402, height: 874), safeArea: phoneSafeArea, text: text, context: device)
        case "pad portrait": Window(size: CGSize(width: 1032, height: 1376), safeArea: padSafeArea, text: text, context: device)
        default: Window(size: CGSize(width: 1376, height: 1032), safeArea: padSafeArea, text: text, context: device)
        }
    }

    /// Every window, with the row the rule places in it.
    static let everyWindow: [(window: Window, text: HomeLayout.Text, place: SettingsRowPlace)] = {
        var windows: [(Window, HomeLayout.Text, SettingsRowPlace)] = []
        for (name, text) in HomeLayoutEngineTests.textSizes {
            for boldText in [false, true] {
                var text = text
                text.boldText = boldText
                for height: CGFloat in [568, 667, 744, 874, 1032, 1376] {
                    for width in stride(from: CGFloat(320), through: 1432, by: 16) {
                        let safeArea = width < 600 ? phoneSafeArea : padSafeArea
                        let context = "\(width)×\(height), \(name), Bold Text \(boldText)"
                        let window = Window(size: CGSize(width: width, height: height), safeArea: safeArea, text: text, context: context)
                        windows.append((window, text, window.place(text: text).place))
                    }
                }
            }
        }
        return windows
    }()

    private static func points(across frame: CGRect) -> [CGPoint] {
        SettingsRowPlace.points(across: frame, every: 4)
    }

    private static func nearer(_ point: CGPoint, to near: CGRect, than far: CGRect, margin: CGFloat) -> Bool {
        SettingsRowPlace.centreDistance(from: point, to: near) + margin < SettingsRowPlace.centreDistance(from: point, to: far)
            && SettingsRowPlace.edgeDistance(from: point, to: near) + margin < SettingsRowPlace.edgeDistance(from: point, to: far)
    }

    /// CI's windows, as PR #53's run measured them, where the chain engine
    /// finds no chain closing Settings under the look with the row here
    /// (`SettingsChainsTests`): fails if the rule moves the row on them, so
    /// a change to it is rescored before it lands.
    @Test func onCIsWindowsTheRowSitsWhereTheChainsWereScored() {
        let d = HomeLayoutEngineTests.defaultText
        let ax5 = HomeLayoutEngineTests.largestText
        #expect(Self.ciWindow("phone", text: d).place(text: d).row.minY == 312)
        #expect(Self.ciWindow("phone", text: d).place(text: d).place.backLimit == 312)
        #expect(Self.ciWindow("pad portrait", text: d).place(text: d).row.minY == 354)
        #expect(Self.ciWindow("pad portrait", text: d).place(text: d).place.backLimit == nil)
        #expect(Self.ciWindow("pad landscape", text: d).place(text: d).row.minY == 355)
        #expect(Self.ciWindow("pad portrait", text: ax5).place(text: ax5).row.minY == 378)
    }

    /// Fails if the row ever leaves what shows without scrolling, or rises
    /// above the content.
    @Test func theRowStaysOnTheFirstScreenful() {
        for (window, _, place) in Self.everyWindow {
            let row = place.row
            #expect(row.minY >= window.content.minY, "\(window.context)")
            #expect(row.maxY <= max(window.content.maxY, window.content.minY + row.height), "\(window.context)")
        }
    }

    /// Fails if a look resting where Home's Settings was can meet Back to
    /// Talking instead of the row, by centre or by edge, on any window: the
    /// way into Settings must only open Family Setup (docs/DECISIONS.md,
    /// "Settings on Home"). On windows at least 1304 points wide and no
    /// taller than 667 at the default size, Home's Settings' top leading
    /// corner lies as near Back to Talking's centre as the row's, within
    /// half a point, as it did with the row at the top of the content
    /// before; strictly expected there, so it fails once it clears.
    @Test func homesSettingsMeetsTheRow() {
        for (window, text, place) in Self.everyWindow {
            let row = place.row
            let settings = window.home.frame(.settings)
            let missed = Self.points(across: settings).filter { !Self.nearer($0, to: row, than: window.home.backToTalking, margin: 0.5) }
            let known = text.categoryLine == HomeLayoutEngineTests.defaultText.categoryLine
                && window.size.width >= 1304 && window.size.height <= 667
            if known {
                withKnownIssue("docs/DECISIONS.md, \"Settings' first row, placed from Home's frames\": a short, very wide window") {
                    #expect(missed.isEmpty, "\(window.context): Settings at \(settings) meets Back to Talking at \(missed.prefix(3))")
                }
            } else {
                #expect(missed.isEmpty, "\(window.context): Settings at \(settings) meets Back to Talking at \(missed.prefix(3)), row \(row)")
            }
        }
    }

    /// Fails if, where Home under Settings' Back button speaks or sounds,
    /// a look on Back can meet Back to Talking before the row once the
    /// first screen returns, wherever the row could sit low enough for it;
    /// or if, elsewhere, the row stops at that limit when it could sit
    /// lower, over Home's categories.
    @Test func whereHomeUnderBackSoundsBackMeetsTheRow() {
        var limited = 0
        for (window, _, place) in Self.everyWindow {
            let row = place.row
            if let limit = place.backLimit {
                limited += 1
                #expect(SettingsRowPlace.homeSoundsUnder(place.backSpot, in: window.home), "\(window.context)")
                guard row.minY > window.content.minY || limit > window.content.minY else { continue }
                let missed = Self.points(across: place.backSpot).filter {
                    !Self.nearer($0, to: row, than: window.home.backToTalking, margin: SettingsRowPlace.margin)
                }
                #expect(missed.isEmpty, "\(window.context): Back's spot meets Back to Talking at \(missed.prefix(3)), row \(row)")
            } else {
                #expect(!SettingsRowPlace.homeSoundsUnder(place.backSpot, in: window.home), "\(window.context)")
            }
        }
        #expect(limited > 0)
    }

    /// Fails if, where nothing holds the row up, any point of its top edge
    /// lies nearer, by centre or by edge, a Home control that speaks or
    /// sounds than one that only switches what Home shows, so a look there,
    /// once Settings closed, could speak, sound the alarm or stop it.
    @Test func whereNothingHoldsItUpTheRowsTopMeetsOnlyQuietControls() {
        var checked = 0
        for (window, _, place) in Self.everyWindow {
            let row = place.row
            guard place.backLimit == nil, row.minY == place.quietTop else { continue }
            let controls = (window.home.controls + [.phraseGrid]).map { (slot: $0, frame: window.home.frame($0)) }
            let quiet = controls.filter { !SettingsRowPlace.sounding.contains($0.slot) }.map(\.frame)
            let loud = controls.filter { SettingsRowPlace.sounding.contains($0.slot) }.map(\.frame)
            func meetsOnlyQuiet(_ top: CGFloat) -> [CGPoint] {
                SettingsRowPlace.points(across: CGRect(x: row.minX, y: top, width: row.width, height: 0), every: 4).filter {
                    !SettingsRowPlace.isNearer($0, toOneOf: quiet, thanAny: loud, margin: 0.5)
                }
            }
            checked += 1
            let loudPoints = meetsOnlyQuiet(row.minY)
            #expect(loudPoints.isEmpty, "\(window.context): row \(row) meets a loud control at \(loudPoints.prefix(3))")
        }
        #expect(checked > 0)
    }

    /// Fails if Home's controls that speak or sound stop counting as such,
    /// or one that only switches what Home shows starts to: the Back limit
    /// would then hold the row up on the iPad, or let it down on the phone.
    @Test func homeSoundsOnlyUnderYesNoAgainGetAttentionStopAndTheTiles() {
        #expect(SettingsRowPlace.sounding == [.yes, .no, .again, .getAttention, .stop, .phraseGrid])
        let d = HomeLayoutEngineTests.defaultText
        let phone = Self.ciWindow("phone", text: d)
        let pad = Self.ciWindow("pad portrait", text: d)
        #expect(SettingsRowPlace.homeSoundsUnder(phone.home.frame(.yes), in: phone.home))
        #expect(!SettingsRowPlace.homeSoundsUnder(pad.home.frame(.emergency), in: pad.home))
    }
}
