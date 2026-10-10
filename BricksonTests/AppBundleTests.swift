import Foundation
import Testing
@testable import Brickson

/// Settings that live in the built app's Info.plist and privacy manifest,
/// where a mistake shows up only on a device or in App Store review.
struct AppBundleTests {
    /// Reads the bundled Info.plist itself: `Bundle.object(forInfoDictionaryKey:)`
    /// resolves `~ipad` keys for the running device, so it cannot check both.
    private func infoPlist() throws -> [String: Any] {
        try plist(named: "Info", extension: "plist")
    }

    private func plist(named name: String, extension fileExtension: String) throws -> [String: Any] {
        let url = try #require(
            Bundle.main.url(forResource: name, withExtension: fileExtension),
            "\(name).\(fileExtension) is not in the app bundle"
        )
        let value = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil)
        return try #require(value as? [String: Any])
    }

    // MARK: Identity

    /// The name under the icon comes from `APP_DISPLAY_NAME` in project.yml.
    /// An unexpanded `$(…)` would mean the build setting is missing.
    @Test func theDisplayNameIsSet() throws {
        let name = try #require(try infoPlist()["CFBundleDisplayName"] as? String)
        #expect(!name.isEmpty)
        #expect(!name.contains("$("))
    }

    /// How text-to-speech says the name comes from `APP_SPOKEN_NAME`.
    @Test func theSpokenNameIsSet() throws {
        let name = try #require(try infoPlist()["CFBundleSpokenName"] as? String)
        #expect(!name.isEmpty)
        #expect(!name.contains("$("))
    }

    /// Siri accepts at most three alternative names, each a dictionary with
    /// a non-empty `INAlternativeAppName`.
    @Test func theAlternativeNamesAreWellFormed() throws {
        let names = try #require(try infoPlist()["INAlternativeAppNames"] as? [[String: Any]])
        #expect((1...3).contains(names.count))
        for entry in names {
            let name = try #require(entry["INAlternativeAppName"] as? String)
            #expect(!name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    @Test func theVersionNumbersAreSet() throws {
        let info = try infoPlist()
        for key in ["CFBundleShortVersionString", "CFBundleVersion"] {
            let value = try #require(info[key] as? String, "missing \(key)")
            #expect(!value.isEmpty && !value.contains("$("), "\(key) is \"\(value)\"")
        }
    }

    // MARK: Behaviour

    /// Speech must keep playing when the screen dims or another app comes
    /// forward (invariant 4).
    @Test func speechCanPlayInTheBackground() throws {
        let modes = try #require(try infoPlist()["UIBackgroundModes"] as? [String])
        #expect(modes.contains("audio"))
    }

    /// docs/DECISIONS.md, "Orientations".
    @Test func theIPhoneIsPortraitOnly() throws {
        #expect(try infoPlist()["UISupportedInterfaceOrientations"] as? [String]
            == ["UIInterfaceOrientationPortrait"])
    }

    /// iPad multitasking requires all four.
    @Test func theIPadKeepsAllFourOrientations() throws {
        let orientations = try #require(try infoPlist()["UISupportedInterfaceOrientations~ipad"] as? [String])
        #expect(Set(orientations) == [
            "UIInterfaceOrientationPortrait",
            "UIInterfaceOrientationPortraitUpsideDown",
            "UIInterfaceOrientationLandscapeLeft",
            "UIInterfaceOrientationLandscapeRight",
        ])
    }

    // MARK: App Store

    /// Without this, App Store Connect asks the export-compliance question
    /// on every upload. True only while the app uses no encryption of its own.
    @Test func noNonExemptEncryptionIsDeclared() throws {
        #expect(try infoPlist()["ITSAppUsesNonExemptEncryption"] as? Bool == false)
    }

    /// The privacy manifest says the app tracks nothing and collects nothing
    /// (invariant 9), and gives Apple's approved reason for each
    /// "required reason" API it uses. Today that is UserDefaults, read and
    /// written only by the app itself (reason CA92.1).
    @Test func thePrivacyManifestDeclaresNoTrackingAndNoCollection() throws {
        let manifest = try plist(named: "PrivacyInfo", extension: "xcprivacy")
        #expect(manifest["NSPrivacyTracking"] as? Bool == false)
        #expect((manifest["NSPrivacyTrackingDomains"] as? [String])?.isEmpty == true)
        #expect((manifest["NSPrivacyCollectedDataTypes"] as? [Any])?.isEmpty == true)

        let apis = try #require(manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        let userDefaults = try #require(apis.first {
            $0["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryUserDefaults"
        })
        #expect(userDefaults["NSPrivacyAccessedAPITypeReasons"] as? [String] == ["CA92.1"])
    }
}
