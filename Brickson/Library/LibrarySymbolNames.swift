import Foundation

/// The words for each picture a category can have (`LibraryRules.symbolChoices`),
/// so VoiceOver reads them and Voice Control can say them ("Tap Heart"):
/// a picture is a button, and every button has a name in words
/// (AGENTS.md, invariant 1).
nonisolated enum LibrarySymbolNames {
    /// The picture's name, or a plain word for one Brickson does not offer
    /// (a backup keeps a category's picture as it was written).
    static func name(of symbolName: String) -> String {
        switch symbolName {
        case "square.grid.2x2.fill": String(localized: "Grid")
        case "bubble.left.and.bubble.right.fill": String(localized: "Speech Bubbles")
        case "text.bubble.fill": String(localized: "Text Bubble")
        case "exclamationmark.triangle.fill": String(localized: "Warning Sign")
        case "hand.raised.fill": String(localized: "Raised Hand")
        case "hand.thumbsup.fill": String(localized: "Thumbs Up")
        case "heart.fill": String(localized: "Heart")
        case "star.fill": String(localized: "Star")
        case "face.smiling": String(localized: "Smiling Face")
        case "person.fill": String(localized: "Person")
        case "person.2.fill": String(localized: "Two People")
        case "house.fill": String(localized: "House")
        case "bed.double.fill": String(localized: "Bed")
        case "fork.knife": String(localized: "Fork and Knife")
        case "cup.and.saucer.fill": String(localized: "Cup and Saucer")
        case "drop.fill": String(localized: "Water Drop")
        case "pills.fill": String(localized: "Pills")
        case "cross.case.fill": String(localized: "First Aid Kit")
        case "figure.walk": String(localized: "Walking")
        case "car.fill": String(localized: "Car")
        case "phone.fill": String(localized: "Phone")
        case "tv.fill": String(localized: "Television")
        case "music.note": String(localized: "Music Note")
        case "book.fill": String(localized: "Book")
        case "gamecontroller.fill": String(localized: "Game Controller")
        case "sun.max.fill": String(localized: "Sun")
        case "leaf.fill": String(localized: "Leaf")
        case "pawprint.fill": String(localized: "Paw Print")
        case "gift.fill": String(localized: "Gift")
        case "calendar": String(localized: "Calendar")
        case "clock.fill": String(localized: "Clock")
        case "questionmark.circle.fill": String(localized: "Question Mark")
        default: String(localized: "Picture")
        }
    }
}
