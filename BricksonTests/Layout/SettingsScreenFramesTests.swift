import Foundation
import Testing
@testable import Brickson

/// Where a Settings screen sits in the window (`SettingsScreenFrames`),
/// from CI's iPhone 17 on PR #53: Back to Talking ends at 134, so the
/// navigation stack starts 8 points under it, at 142, and ends above the
/// 40-point sound line, at 800; the navigation bar keeps 64 points, and the
/// content starts at 222, as CI's captures show.
struct SettingsScreenFramesTests {
    private static let phoneStack = CGRect(x: 0, y: 142, width: 402, height: 658)

    /// Fails if the content stops starting the bar's height and a gutter
    /// under the top of the stack, or stops ending a gutter above its foot:
    /// the root's row would then be placed from the wrong frames.
    @Test func theContentStartsUnderTheBarAndAGutter() {
        let frames = SettingsScreenFrames(
            stack: Self.phoneStack, safeArea: HomeLayout.Insets(top: 64, leading: 0, bottom: 0, trailing: 0), gutter: 16
        )
        #expect(frames.navigationBar == CGRect(x: 0, y: 142, width: 402, height: 64))
        #expect(frames.content == CGRect(x: 16, y: 222, width: 370, height: 562))
    }

    /// Fails if the safe area at the stack's sides or foot stops narrowing
    /// or shortening the content, or the content's size can go below zero.
    @Test func theSafeAreaAtEachEdgeNarrowsTheContent() {
        let frames = SettingsScreenFrames(
            stack: CGRect(x: 62, y: 100, width: 750, height: 200),
            safeArea: HomeLayout.Insets(top: 50, leading: 10, bottom: 20, trailing: 30), gutter: 16
        )
        #expect(frames.navigationBar == CGRect(x: 62, y: 100, width: 750, height: 50))
        #expect(frames.content == CGRect(x: 88, y: 166, width: 678, height: 98))
        let tiny = SettingsScreenFrames(
            stack: CGRect(x: 0, y: 0, width: 20, height: 20), safeArea: HomeLayout.Insets(top: 64, leading: 0, bottom: 0, trailing: 0),
            gutter: 16
        )
        #expect(tiny.content.width == 0)
        #expect(tiny.content.height == 0)
    }
}
