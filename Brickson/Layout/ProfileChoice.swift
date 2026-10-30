import Foundation

/// Which sizes Home has: the profile Family Setup's answer asks for, and
/// the layout of the largest profile, from that one down, that the window
/// holds (docs/DECISIONS.md, "Sizes that follow how the screen is
/// reached").
///
/// - Several answers ask for the largest profile any of them needs. A
///   person who touches the screen on good days and uses Eye Tracking on
///   others needs targets their eyes can hold on every day, and a larger
///   target costs touch nothing but room.
/// - No answer, never given or cleared, asks for the largest of all, Eye
///   Tracking's (docs/DECISIONS.md, "Setup answers are kept as offered,
///   never as completed").
/// - A window too small for the profile asked for takes the largest
///   smaller one it holds, and touch's where it holds none: touch's are
///   the sizes Home has always had, and apply in every window. Every
///   profile has the window's own arrangement, so nothing changes place
///   relative to anything else between them (invariant 8), and nothing
///   is made smaller than its floor to avoid scrolling: a profile that
///   would scroll is not held (invariant 11).
/// - What iOS reports about VoiceOver and Switch Control only suggests an
///   answer (`suggestion`); the profile comes from the answer alone.
///
/// Home and Settings read the profile asked for when Settings last
/// closed, so an answer changed in Family Setup moves nothing under it:
/// Settings' places are worked out from Home's frames (`SettingsCover`).
///
/// Switched on by the owner on 2026-10-30 (docs/DECISIONS.md, "Sizes that
/// follow how the screen is reached", *Switched on by the owner*).
nonisolated enum ProfileChoice {
    /// Whether Home follows Family Setup's answer. On since the owner chose
    /// the largest sizes that fit where a window cannot hold the ones asked
    /// for (2026-10-30). Off holds Home at touch's sizes for every answer,
    /// as before then, with only a UI test that asks following the answer
    /// (`LaunchOptions`): the line a build changes if it must go out
    /// without the larger sizes (docs/ROADMAP.md, R0's *Release gate*),
    /// with the pin in `ProfileChoiceTests` reversed and `HomeSizesTests`
    /// asking for `--home-profile=from-answer` again.
    static let followsTheAnswer = true

    /// The profile Home asks for: the one `methods` asks for when Home
    /// `followsAnswer`, otherwise touch's, whatever the answer.
    static func requestedForHome(by methods: Set<AccessMethod>?, followsAnswer: Bool) -> HomeLayout.Profile {
        followsAnswer ? requested(by: methods) : .touch
    }

    /// The profile `methods`, Family Setup's answer, asks for: the largest
    /// any of them needs, and Eye Tracking's when there is no answer.
    static func requested(by methods: Set<AccessMethod>?) -> HomeLayout.Profile {
        guard let methods, !methods.isEmpty else { return .eyeTracking }
        return methods.map(profile(for:)).max() ?? .eyeTracking
    }

    /// The sizes one way of reaching the screen needs. Voice Control names
    /// a control and needs no larger target than touch; someone helping
    /// touches the screen.
    static func profile(for method: AccessMethod) -> HomeLayout.Profile {
        switch method {
        case .touch, .voiceControl, .someoneElse: .touch
        case .switchControl: .switchControl
        case .headTracking: .headTracking
        case .eyeTracking: .eyeTracking
        }
    }

    /// Home's layout in `space` for the profile `requested`: the first of
    /// it and the smaller ones (`Profile.withSmallerOnes`) that the window
    /// holds (`HomeLayout.holdsProfile`) without losing anything touch's
    /// sizes have there (`keepsEverything`), or touch's.
    static func layout(
        requested: HomeLayout.Profile, space: HomeLayout.Space, text: HomeLayout.Text,
        largestCategory: Int = HomeLayout.referencePhraseCount, modes: HomeLayout.Modes
    ) -> HomeLayout {
        let touch = HomeLayout(space: space, profile: .touch, text: text, largestCategory: largestCategory, modes: modes)
        for profile in requested.withSmallerOnes where profile != .touch {
            let layout = HomeLayout(space: space, profile: profile, text: text, largestCategory: largestCategory, modes: modes)
            if layout.holdsProfile && keepsEverything(layout, of: touch) { return layout }
        }
        return touch
    }

    /// Whether `layout` keeps everything `touch`, the same window's layout
    /// at touch's sizes, has: the same arrangement, typing wherever touch
    /// offers it (typing never hides the call for help, so a safety row too
    /// tall for the keyboard's room dims Type), and every word Settings and
    /// the message show whole.
    static func keepsEverything(_ layout: HomeLayout, of touch: HomeLayout) -> Bool {
        layout.isRegular == touch.isRegular
            && layout.categoryArrangement == touch.categoryArrangement
            && layout.grid.columns == touch.grid.columns
            && (layout.offersTyping || !touch.offersTyping)
            && (layout.messageHoldsItsWords || !touch.messageHoldsItsWords)
            && (layout.settingsShowsName || !touch.settingsShowsName)
    }

    /// What the first step may say beside its question about what iOS
    /// reports.
    enum Suggestion: Equatable, Sendable {
        /// Switch Control is on: Switch Control may be one of the answers.
        case switchControlIsOn
        /// VoiceOver is on: Touch, the way VoiceOver's own gestures reach
        /// the screen, may be one of the answers.
        case voiceOverIsOn

        /// The answer it suggests.
        var answer: AccessMethod {
            switch self {
            case .switchControlIsOn: .switchControl
            case .voiceOverIsOn: .touch
            }
        }
    }

    /// The suggestion for what iOS reports: Switch Control's when it is on,
    /// since it can drive VoiceOver too; otherwise VoiceOver's when that is
    /// on. A suggestion never changes an answer: this reads only the flags,
    /// never the answer, so the words beside the question do not change as
    /// answers are chosen, and nothing moves under a choice just made.
    static func suggestion(voiceOver: Bool, switchControl: Bool) -> Suggestion? {
        if switchControl { return .switchControlIsOn }
        if voiceOver { return .voiceOverIsOn }
        return nil
    }
}
