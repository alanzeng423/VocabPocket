import Foundation

enum CaptureMethod: String, Codable, CaseIterable, Sendable {
    case selectedText
    case ocr
    case manual

    var title: String {
        switch self {
        case .selectedText: "选中文字"
        case .ocr: "图片 OCR"
        case .manual: "手动输入"
        }
    }

    var systemImage: String {
        switch self {
        case .selectedText: "text.cursor"
        case .ocr: "viewfinder"
        case .manual: "keyboard"
        }
    }
}

struct VocabularyEntry: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var sourceText: String
    var translatedText: String
    var sourceLanguageIdentifier: String
    var targetLanguageIdentifier: String
    var captureMethod: CaptureMethod
    let createdAt: Date
    var updatedAt: Date
    var lastReviewedAt: Date?
    var nextReviewAt: Date
    var reviewCount: Int
    var masteryLevel: Int
    var encounterCount: Int
    var isFavorite: Bool
    var note: String

    init(
        id: UUID = UUID(),
        sourceText: String,
        translatedText: String,
        sourceLanguageIdentifier: String,
        targetLanguageIdentifier: String,
        captureMethod: CaptureMethod,
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        lastReviewedAt: Date? = nil,
        nextReviewAt: Date? = nil,
        reviewCount: Int = 0,
        masteryLevel: Int = 0,
        encounterCount: Int = 1,
        isFavorite: Bool = false,
        note: String = ""
    ) {
        self.id = id
        self.sourceText = sourceText
        self.translatedText = translatedText
        self.sourceLanguageIdentifier = sourceLanguageIdentifier
        self.targetLanguageIdentifier = targetLanguageIdentifier
        self.captureMethod = captureMethod
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.lastReviewedAt = lastReviewedAt
        self.nextReviewAt = nextReviewAt ?? createdAt
        self.reviewCount = reviewCount
        self.masteryLevel = masteryLevel
        self.encounterCount = encounterCount
        self.isFavorite = isFavorite
        self.note = note
    }

    var isDueForReview: Bool {
        nextReviewAt <= Date()
    }
}
