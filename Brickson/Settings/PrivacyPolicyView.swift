import SafariServices
import SwiftUI

/// The privacy policy, inside the app.
///
/// App Review Guideline 5.1.1(i) asks for the policy inside the app "in an
/// easily accessible manner". Brickson shows the bundled copy of the public
/// page natively, so it reads at the person's text size and needs no
/// network, and offers the web version in an in-app Safari sheet rather than
/// sending the family out of the app (docs/DECISIONS.md, "The privacy policy
/// ships inside the app").
struct PrivacyPolicyView: View {
    @State private var showsWebVersion = false

    /// Read once: the bundled page never changes while the app runs.
    private static let policy = Result { try PrivacyPolicyDocument.bundled() }

    var body: some View {
        SettingsScreen(title: "Privacy Policy") {
            Button {
                showsWebVersion = true
            } label: {
                SettingsRowLabel(title: "Open the Web Version", systemImage: "safari.fill")
            }
            .settingsRowStyle()

            switch Self.policy {
            case .success(let document):
                ForEach(Array(document.blocks.enumerated()), id: \.offset) { _, block in
                    PolicyBlockView(block: block)
                }
            case .failure:
                SettingsParagraph("The privacy policy could not be shown here. Open the web version above to read it.")
            }
        }
        .sheet(isPresented: $showsWebVersion) {
            SafariView(url: PrivacyPolicyView.webURL)
                .ignoresSafeArea()
        }
        .holdsSettingsIdleReset(showsWebVersion)
    }

    /// The public page App Store Connect also links to.
    static let webURL = URL(string: "https://middleagedbanana.github.io/Brickson/privacy/")!
}

private struct PolicyBlockView: View {
    let block: PrivacyPolicyDocument.Block

    var body: some View {
        switch block.kind {
        case .title:
            styled.font(.title.weight(.bold)).accessibilityAddTraits(.isHeader)
        case .heading:
            styled.font(.title2.weight(.bold)).accessibilityAddTraits(.isHeader).padding(.top, 8)
        case .paragraph:
            styled.font(.body)
        case .listItem:
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: "•").accessibilityHidden(true)
                styled
            }
            .font(.body)
        }
    }

    /// The policy's own words: shown verbatim, with its bold runs.
    private var styled: some View {
        var attributed = AttributedString()
        for run in block.runs {
            var part = AttributedString(run.text)
            if run.isBold {
                part.inlinePresentationIntent = .stronglyEmphasized
            }
            attributed += part
        }
        return Text(attributed)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Safari's in-app browser, for the policy's web version. It is Apple's own
/// view: Brickson sees nothing of what happens inside it.
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
