import Foundation

enum ReviewRating: String, CaseIterable {
    case again
    case hard
    case good

    var title: String {
        switch self {
        case .again: "忘记了"
        case .hard: "有点难"
        case .good: "记住了"
        }
    }
}

enum ReviewScheduler {
    private static let goodIntervalsInDays = [0, 1, 3, 7, 14, 30]

    static func apply(
        _ rating: ReviewRating,
        to entry: inout VocabularyEntry,
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        entry.reviewCount += 1
        entry.lastReviewedAt = now
        entry.updatedAt = now

        switch rating {
        case .again:
            entry.masteryLevel = 0
            entry.nextReviewAt = calendar.date(byAdding: .minute, value: 10, to: now) ?? now

        case .hard:
            entry.masteryLevel = max(0, entry.masteryLevel - 1)
            entry.nextReviewAt = calendar.date(byAdding: .day, value: 1, to: now) ?? now

        case .good:
            entry.masteryLevel = min(goodIntervalsInDays.count - 1, entry.masteryLevel + 1)
            let days = goodIntervalsInDays[entry.masteryLevel]
            entry.nextReviewAt = calendar.date(byAdding: .day, value: days, to: now) ?? now
        }
    }
}
