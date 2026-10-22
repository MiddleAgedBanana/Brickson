import Foundation
import Testing
@testable import Brickson

/// App Review Guideline 5.1.1(i) asks for the privacy policy inside the app
/// "in an easily accessible manner". Brickson shows the public page's own
/// words, so the in-app copy can never say something the page does not.
struct PrivacyPolicyDocumentTests {
    @Test func theBundledPolicyIsThePublicPage() throws {
        let policy = try PrivacyPolicyDocument.bundled()

        #expect(policy.blocks.first?.kind == .title)
        #expect(policy.blocks.first?.text.hasSuffix("Privacy Policy") == true)
        #expect(policy.blocks.contains { $0.kind == .heading })
        #expect(policy.blocks.contains { $0.kind == .listItem })
    }

    /// If the page gains an element the parser does not read (a table, a
    /// definition list), its words would silently vanish from the app. This
    /// fails instead.
    @Test func noWordOfTheBundledPageIsLost() throws {
        let url = try #require(PrivacyPolicyDocument.bundledURL())
        let html = try String(contentsOf: url, encoding: .utf8)
        let policy = try PrivacyPolicyDocument.parse(html: html)

        #expect(policy.visibleCharacters == PrivacyPolicyDocument.visibleCharacters(ofPage: html))
    }

    @Test func blocksKeepTheirKindAndOrder() throws {
        let html = """
        <header><p>Navigation is not policy text.</p></header>
        <main class="policy-copy" id="policy">
        <h1>Title</h1>
        <p class="effective">Effective today</p>
        <h2 id="a">A heading</h2>
        <ul>
        <li>First item.</li>
        <li>Second item.</li>
        </ul>
        </main>
        <footer><p>Footer text.</p></footer>
        """
        let policy = try PrivacyPolicyDocument.parse(html: html)

        #expect(policy.blocks.map(\.kind) == [.title, .paragraph, .heading, .listItem, .listItem])
        #expect(policy.blocks.map(\.text) == ["Title", "Effective today", "A heading", "First item.", "Second item."])
    }

    @Test func boldRunsAndLinksKeepTheirWords() throws {
        let html = """
        <main><p><strong>The short version:</strong> read <a href="https://example.com">this page</a> &amp; that one &gt; here.</p></main>
        """
        let block = try #require(try PrivacyPolicyDocument.parse(html: html).blocks.first)

        #expect(block.runs == [
            .init(text: "The short version:", isBold: true),
            .init(text: " read this page & that one > here.", isBold: false),
        ])
    }

    @Test func numericEntitiesAreDecoded() {
        #expect(PrivacyPolicyDocument.decodeEntities("it&#8217;s &#x2014; &rsquo;") == "it\u{2019}s \u{2014} \u{2019}")
        #expect(PrivacyPolicyDocument.decodeEntities("&unknown;") == "&unknown;")
    }

    @Test func aPageWithoutMainIsAnError() {
        #expect(throws: PrivacyPolicyDocument.ParseError.noMainElement) {
            try PrivacyPolicyDocument.parse(html: "<p>No main here.</p>")
        }
        #expect(throws: PrivacyPolicyDocument.ParseError.empty) {
            try PrivacyPolicyDocument.parse(html: "<main></main>")
        }
    }

    /// The check above must be able to fail: text in an element the parser
    /// does not read shows up as a difference.
    @Test func textOutsideAnyBlockIsDetected() throws {
        let html = "<main><p>Kept.</p><table><tr><td>Lost.</td></tr></table></main>"
        let policy = try PrivacyPolicyDocument.parse(html: html)

        #expect(policy.visibleCharacters != PrivacyPolicyDocument.visibleCharacters(ofPage: html))
    }
}
