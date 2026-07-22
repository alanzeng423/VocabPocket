import XCTest

@testable import VocabPocket

final class ReviewSchedulerTests: XCTestCase {
    func testGoodReviewAdvancesMasteryAndSchedulesTomorrow() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        var entry = makeEntry(createdAt: now)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        ReviewScheduler.apply(.good, to: &entry, now: now, calendar: calendar)

        XCTAssertEqual(entry.masteryLevel, 1)
        XCTAssertEqual(entry.reviewCount, 1)
        XCTAssertEqual(entry.lastReviewedAt, now)
        XCTAssertEqual(entry.nextReviewAt.timeIntervalSince(now), 86_400, accuracy: 0.1)
    }

    func testAgainReviewResetsMasteryAndReturnsInTenMinutes() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        var entry = makeEntry(createdAt: now)
        entry.masteryLevel = 4

        ReviewScheduler.apply(.again, to: &entry, now: now)

        XCTAssertEqual(entry.masteryLevel, 0)
        XCTAssertEqual(entry.nextReviewAt.timeIntervalSince(now), 600, accuracy: 0.1)
    }

    func testMasteryNeverExceedsMaximum() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        var entry = makeEntry(createdAt: now)
        entry.masteryLevel = 5

        ReviewScheduler.apply(.good, to: &entry, now: now)

        XCTAssertEqual(entry.masteryLevel, 5)
    }

    private func makeEntry(createdAt: Date) -> VocabularyEntry {
        VocabularyEntry(
            sourceText: "serendipity",
            translatedText: "意外发现美好事物的运气",
            sourceLanguageIdentifier: "en",
            targetLanguageIdentifier: "zh-Hans",
            captureMethod: .selectedText,
            createdAt: createdAt
        )
    }
}
