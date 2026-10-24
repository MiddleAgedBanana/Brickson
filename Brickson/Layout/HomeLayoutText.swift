import SwiftUI

extension HomeLayout.Text {
    /// One line of each of Home's label styles at `size`, measured with the
    /// fonts Home draws them in (`LabelFont`), heavier with Bold Text on.
    /// Kept apart from the engine so the engine never measures text and its
    /// tests run without a screen.
    static func measured(at size: DynamicTypeSize, boldText: Bool) -> HomeLayout.Text {
        let weight: LegibilityWeight = boldText ? .bold : .regular
        return HomeLayout.Text(
            quickControlLine: LabelFont.quickControl.legible(weight).lineHeight(at: size),
            categoryLine: LabelFont.category.legible(weight).lineHeight(at: size),
            messageLine: LabelFont.message.legible(weight).lineHeight(at: size),
            statusLine: LabelFont.status.legible(weight).lineHeight(at: size),
            boldText: boldText
        )
    }
}
