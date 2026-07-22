import Foundation
import XCTest

@testable import VocabPocket

final class VocabularyStoreTests: XCTestCase {
    private var directory: URL!
    private var fileURL: URL!

    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("VocabPocketTests-\(UUID().uuidString)", isDirectory: true)
        fileURL = directory.appendingPathComponent("vocabulary.json")
    }

    override func tearDown() {
        if let directory {
            try? FileManager.default.removeItem(at: directory)
        }
        super.tearDown()
    }

    @MainActor
    func testAddingEntryPersistsAndCanBeReloaded() {
        let store = VocabularyStore(fileURL: fileURL)
        store.addOrUpdate(
            sourceText: "ephemeral",
            translatedText: "短暂的",
            sourceLanguageIdentifier: "en",
            targetLanguageIdentifier: "zh-Hans",
            captureMethod: .selectedText
        )

        let reloaded = VocabularyStore(fileURL: fileURL)
        XCTAssertEqual(reloaded.entries.count, 1)
        XCTAssertEqual(reloaded.entries.first?.sourceText, "ephemeral")
        XCTAssertEqual(reloaded.entries.first?.translatedText, "短暂的")
    }

    @MainActor
    func testDuplicateSourceUpdatesInsteadOfCreatingAnotherEntry() {
        let store = VocabularyStore(fileURL: fileURL)
        store.addOrUpdate(
            sourceText: "  Hello   World ",
            translatedText: "你好，世界",
            sourceLanguageIdentifier: "en",
            targetLanguageIdentifier: "zh-Hans",
            captureMethod: .selectedText
        )
        store.addOrUpdate(
            sourceText: "hello world",
            translatedText: "世界你好",
            sourceLanguageIdentifier: "en",
            targetLanguageIdentifier: "zh-Hans",
            captureMethod: .ocr
        )

        XCTAssertEqual(store.entries.count, 1)
        XCTAssertEqual(store.entries[0].encounterCount, 2)
        XCTAssertEqual(store.entries[0].translatedText, "世界你好")
        XCTAssertEqual(store.entries[0].captureMethod, .ocr)
    }

    @MainActor
    func testSameSourceCanExistForDifferentTargetLanguages() {
        let store = VocabularyStore(fileURL: fileURL)
        for target in ["zh-Hans", "ja"] {
            store.addOrUpdate(
                sourceText: "hello",
                translatedText: target,
                sourceLanguageIdentifier: "en",
                targetLanguageIdentifier: target,
                captureMethod: .manual
            )
        }

        XCTAssertEqual(store.entries.count, 2)
    }

    @MainActor
    func testCSVExportEscapesQuotesAndCommas() throws {
        let store = VocabularyStore(fileURL: fileURL)
        store.addOrUpdate(
            sourceText: "hello, \"friend\"",
            translatedText: "你好，朋友",
            sourceLanguageIdentifier: "en",
            targetLanguageIdentifier: "zh-Hans",
            captureMethod: .manual
        )
        let csvURL = directory.appendingPathComponent("export.csv")

        try store.exportCSV(to: csvURL)

        let csv = try String(contentsOf: csvURL, encoding: .utf8)
        XCTAssertTrue(csv.contains("\"hello, \"\"friend\"\"\""))
    }
}
