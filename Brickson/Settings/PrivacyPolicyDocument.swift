import Foundation

/// The public privacy policy, read from the copy of `site/privacy/index.html`
/// bundled into the app, so the words in the app are the words on the web
/// page: there is one source, and nothing to keep in step by hand
/// (docs/DECISIONS.md, "The privacy policy ships inside the app").
///
/// Only the page's `<main>` is read. The parser understands exactly what
/// that page uses: headings, paragraphs and list items, with bold runs and
/// links inside them. A link keeps its words as plain text; the web version
/// is one button away for anyone who wants to follow it. A test checks that
/// every character of the page reaches exactly one block, so a new kind of element on the
/// page fails the build instead of quietly disappearing from the app.
nonisolated struct PrivacyPolicyDocument: Equatable, Sendable {
    struct Run: Equatable, Sendable {
        let text: String
        let isBold: Bool
    }

    enum Kind: Equatable, Sendable {
        case title
        case heading
        case paragraph
        case listItem
    }

    struct Block: Equatable, Sendable {
        let kind: Kind
        let runs: [Run]

        var text: String { runs.map(\.text).joined() }
    }

    enum ParseError: Error, Equatable {
        case noMainElement
        case empty
    }

    let blocks: [Block]

    /// Where the bundled page is: project.yml copies the `site/privacy`
    /// folder into the app.
    static func bundledURL(in bundle: Bundle = .main) -> URL? {
        bundle.url(forResource: "index", withExtension: "html", subdirectory: "privacy")
    }

    static func bundled(in bundle: Bundle = .main) throws -> PrivacyPolicyDocument {
        guard let url = bundledURL(in: bundle) else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try parse(html: String(contentsOf: url, encoding: .utf8))
    }

    static func parse(html: String) throws -> PrivacyPolicyDocument {
        guard let main = mainContent(of: html) else { throw ParseError.noMainElement }

        var blocks: [Block] = []
        let pattern = /<(h1|h2|h3|p|li)\b[^>]*>(.*?)<\/\1>/.dotMatchesNewlines()
        for match in main.matches(of: pattern) {
            let kind: Kind = switch match.output.1 {
            case "h1": .title
            case "h2", "h3": .heading
            case "li": .listItem
            default: .paragraph
            }
            let runs = inlineRuns(of: String(match.output.2))
            if !runs.isEmpty {
                blocks.append(Block(kind: kind, runs: runs))
            }
        }
        guard !blocks.isEmpty else { throw ParseError.empty }
        return PrivacyPolicyDocument(blocks: blocks)
    }

    /// Everything between `<main ...>` and `</main>`.
    static func mainContent(of html: String) -> Substring? {
        guard let open = html.firstMatch(of: /<main\b[^>]*>/),
              let close = html[open.range.upperBound...].firstMatch(of: /<\/main>/)
        else { return nil }
        return html[open.range.upperBound..<close.range.lowerBound]
    }

    /// Every visible character inside `<main>`, with markup and whitespace
    /// removed: what the blocks must add up to (`visibleCharacters`).
    static func visibleCharacters(ofPage html: String) -> String {
        guard let main = mainContent(of: html) else { return "" }
        return visibleCharacters(of: decodeEntities(String(main).replacing(/<[^>]*>/, with: "")))
    }

    /// The blocks' text with whitespace removed, for comparing with the page.
    var visibleCharacters: String {
        Self.visibleCharacters(of: blocks.map(\.text).joined())
    }

    private static func visibleCharacters(of text: String) -> String {
        String(text.filter { !$0.isWhitespace })
    }

    /// Splits an element's contents into bold and plain runs, dropping the
    /// tags of links and anything else but keeping their words.
    private static func inlineRuns(of html: String) -> [Run] {
        var runs: [Run] = []
        var isBold = false
        var rest = Substring(html)
        func append(_ raw: Substring) {
            let text = decodeEntities(String(raw).replacing(/\s+/, with: " "))
            guard !text.isEmpty else { return }
            if let last = runs.last, last.isBold == isBold {
                runs[runs.count - 1] = Run(text: last.text + text, isBold: isBold)
            } else {
                runs.append(Run(text: text, isBold: isBold))
            }
        }
        while let tag = rest.firstMatch(of: /<(\/?)([a-zA-Z0-9]+)\b[^>]*>/) {
            append(rest[..<tag.range.lowerBound])
            let name = tag.output.2.lowercased()
            if name == "strong" || name == "b" {
                isBold = tag.output.1.isEmpty
            } else if name == "br" {
                append(" ")
            }
            rest = rest[tag.range.upperBound...]
        }
        append(rest)

        // Trim the outer edges only; spaces between runs are meaningful.
        if let first = runs.first {
            runs[0] = Run(text: String(first.text.drop(while: \.isWhitespace)), isBold: first.isBold)
        }
        if let last = runs.last {
            let trimmed = String(last.text.reversed().drop(while: \.isWhitespace).reversed())
            runs[runs.count - 1] = Run(text: trimmed, isBold: last.isBold)
        }
        return runs.filter { !$0.text.isEmpty }
    }

    private static let namedEntities: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": "\u{00A0}",
        "rsquo": "\u{2019}", "lsquo": "\u{2018}", "rdquo": "\u{201D}", "ldquo": "\u{201C}",
        "ndash": "\u{2013}", "mdash": "\u{2014}", "hellip": "\u{2026}",
    ]

    static func decodeEntities(_ text: String) -> String {
        text.replacing(/&(#x[0-9a-fA-F]+|#[0-9]+|[a-zA-Z]+);/) { match in
            let name = String(match.output.1)
            if name.hasPrefix("#x"), let value = UInt32(name.dropFirst(2), radix: 16), let scalar = Unicode.Scalar(value) {
                return String(Character(scalar))
            }
            if name.hasPrefix("#"), let value = UInt32(name.dropFirst()), let scalar = Unicode.Scalar(value) {
                return String(Character(scalar))
            }
            return namedEntities[name] ?? String(match.output.0)
        }
    }
}
