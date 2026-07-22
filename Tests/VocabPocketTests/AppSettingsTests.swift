import Foundation
import XCTest

@testable import VocabPocket

final class AppSettingsTests: XCTestCase {
    @MainActor
    func testProviderPreferencesAndKeyArePersistedSeparately() throws {
        let suiteName = "VocabPocket.AppSettingsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let credentials = MemoryCredentialStore()

        var settings = AppSettings(defaults: defaults, credentialStore: credentials)
        settings.translationProvider = .openAICompatible
        settings.updatePreference(for: .openAICompatible, \.endpoint, to: "http://localhost:1234/v1")
        try settings.saveAPIKey("private-key", for: .openAICompatible)

        settings = AppSettings(defaults: defaults, credentialStore: credentials)
        XCTAssertEqual(settings.translationProvider, .openAICompatible)
        XCTAssertEqual(
            settings.preferences(for: .openAICompatible).endpoint,
            "http://localhost:1234/v1"
        )
        XCTAssertTrue(settings.hasAPIKey(for: .openAICompatible))
        XCTAssertFalse(
            defaults.dictionaryRepresentation().values.contains { value in
                String(describing: value).contains("private-key")
            })
    }
}

private final class MemoryCredentialStore: CredentialStoring {
    private var values: [String: String] = [:]

    func string(for account: String) throws -> String? {
        values[account]
    }

    func set(_ value: String, for account: String) throws {
        values[account] = value
    }

    func removeValue(for account: String) throws {
        values.removeValue(forKey: account)
    }
}
