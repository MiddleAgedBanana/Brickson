import Foundation
import Testing
@testable import Brickson

/// The rest board resolved against the library (`RestBoard`), and what
/// Home asks for with it (`ProfileChoice.Request`): docs/DECISIONS.md,
/// "The late-stage profile"; docs/work/late-stage-profile.md.
struct RestBoardTests {
    typealias Category = RestBoard.Category

    static let basics = Category(id: UUID(), isEmergency: false, phrases: 8)
    static let conversation = Category(id: UUID(), isEmergency: false, phrases: 6)
    static let small = Category(id: UUID(), isEmergency: false, phrases: 3)
    static let emergency = Category(id: UUID(), isEmergency: true, phrases: 6)
    static let library = [basics, conversation, small, emergency]

    /// Fails if a board shows where nothing was chosen, where the choice is
    /// no longer in the library, or where the choice is Emergency's, whose
    /// phrases every board shows already from Emergency's own button.
    @Test func aBoardShowsOnlyForAnEverydayCategoryInTheLibrary() {
        #expect(RestBoard(choice: nil, in: Self.library) == nil)
        #expect(RestBoard(choice: UUID(), in: Self.library) == nil)
        #expect(RestBoard(choice: Self.emergency.id, in: Self.library) == nil)
        #expect(RestBoard(choice: Self.conversation.id, in: [])?.category == nil)
        #expect(RestBoard(choice: Self.conversation.id, in: Self.library)?.category == Self.conversation.id)
    }

    /// Fails if the grid leaves room for fewer phrases than the board or
    /// Emergency has, either of which would then scroll, or for none.
    @Test func theGridLeavesRoomForTheBoardAndEmergency() {
        #expect(RestBoard(choice: Self.basics.id, in: Self.library)?.phrases == 8)
        #expect(RestBoard(choice: Self.conversation.id, in: Self.library)?.phrases == 6)
        // A board smaller than Emergency leaves room for Emergency's.
        #expect(RestBoard(choice: Self.small.id, in: Self.library)?.phrases == 6)
        let largerEmergency = Category(id: UUID(), isEmergency: true, phrases: 9)
        #expect(RestBoard(choice: Self.conversation.id, in: [Self.conversation, largerEmergency])?.phrases == 9)
        // No Emergency category (the repair puts one back at launch).
        #expect(RestBoard(choice: Self.small.id, in: [Self.small])?.phrases == 3)
        let empty = Category(id: UUID(), isEmergency: false, phrases: 0)
        #expect(RestBoard(choice: empty.id, in: [empty])?.phrases == 1)
    }

    /// Fails if a board leaves the sizes to the first step's answers, if
    /// no board asks for anything but the answers' sizes, if a held Home
    /// asks for anything but touch's, or if a UI test's own sizes do not
    /// win.
    @Test func aBoardAsksForTheLateStagesSizes() {
        var record = SetupRecord(createdAt: Date(timeIntervalSince1970: 1_800_000_000))
        let answers: [Set<AccessMethod>?] = [nil, [.touch], [.eyeTracking], [.switchControl, .voiceControl]]
        for answer in answers {
            if let answer { record.answerAccessMethods(answer, at: record.createdAt) }
            record.chooseRestBoard(nil)
            let everyCategory = ProfileChoice.request(for: record, library: Self.library, followsAnswer: true)
            #expect(everyCategory == .init(profile: ProfileChoice.requested(by: answer), restBoard: nil), "\(String(describing: answer))")
            #expect(everyCategory.phraseArea == .everyCategory)

            record.chooseRestBoard(Self.conversation.id)
            let board = ProfileChoice.request(for: record, library: Self.library, followsAnswer: true)
            #expect(board.profile == .lateStage, "\(String(describing: answer))")
            #expect(board.restBoard?.category == Self.conversation.id)
            #expect(board.phraseArea == .restBoard(phrases: 6))
            #expect(ProfileChoice.request(for: record, library: Self.library, followsAnswer: false).profile == .touch)
            #expect(ProfileChoice.request(for: record, library: Self.library, followsAnswer: true, fixed: .headTracking).profile == .headTracking)

            // A choice no longer in the library is every category, at the
            // answers' sizes.
            record.chooseRestBoard(UUID())
            #expect(ProfileChoice.request(for: record, library: Self.library, followsAnswer: true) == everyCategory)
        }
        #expect(ProfileChoice.requested(by: nil, restBoard: true) == .lateStage)
        #expect(ProfileChoice.requestedForHome(by: [.touch], restBoard: true, followsAnswer: true) == .lateStage)
        #expect(ProfileChoice.requestedForHome(by: [.touch], restBoard: true, followsAnswer: false) == .touch)
        #expect(ProfileChoice.Request.touch == .init(profile: .touch, restBoard: nil))
    }

    /// Fails if a request's layout is not `ProfileChoice.layout` for its
    /// profile and phrase area: Home and Settings both lay Home out from
    /// it, and Settings' places come from Home's frames.
    @Test func aRequestLaysHomeOutAsProfileChoiceDoes() throws {
        let space = HomeLayout.Space(size: CGSize(width: 1032, height: 1376), safeArea: SettingsRowPlaceTests.padSafeArea)
        let text = HomeLayoutEngineTests.defaultText
        let board = try #require(RestBoard(choice: Self.conversation.id, in: Self.library))
        for request in [ProfileChoice.Request.touch, .init(profile: .lateStage, restBoard: board), .init(profile: .eyeTracking, restBoard: nil)] {
            #expect(request.layout(space: space, text: text, modes: .phrasesAndTyping)
                == ProfileChoice.layout(requested: request.profile, space: space, text: text, modes: .phrasesAndTyping, phraseArea: request.phraseArea))
        }
    }
}
