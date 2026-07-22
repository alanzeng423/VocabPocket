import Combine
import Foundation

@MainActor
final class VocabularyStore: ObservableObject {
    @Published private(set) var entries: [VocabularyEntry] = []
    @Published private(set) var lastError: String?

    private let fileURL: URL
    private let fileManager: FileManager

    init(
        fileURL: URL? = nil,
        fileManager: FileManager = .default,
        loadImmediately: Bool = true
    ) {
        self.fileManager = fileManager
        self.fileURL = fileURL ?? Self.defaultFileURL(fileManager: fileManager)
        if loadImmediately {
            load()
        }
    }

    static func defaultFileURL(fileManager: FileManager = .default) -> URL {
        let base =
            fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return
            base
            .appendingPathComponent("VocabPocket", isDirectory: true)
            .appendingPathComponent("vocabulary.json")
    }

    var dueEntries: [VocabularyEntry] {
        let now = Date()
        return
            entries
            .filter { $0.nextReviewAt <= now }
            .sorted { lhs, rhs in
                if lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite }
                return lhs.nextReviewAt < rhs.nextReviewAt
            }
    }

    var favoriteCount: Int {
        entries.lazy.filter(\.isFavorite).count
    }

    func load() {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            entries = []
            lastError = nil
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            entries = try Self.decoder.decode([VocabularyEntry].self, from: data)
                .sorted { $0.updatedAt > $1.updatedAt }
            lastError = nil
        } catch {
            lastError = "读取生词本失败：\(error.localizedDescription)"
        }
    }

    @discardableResult
    func addOrUpdate(
        sourceText: String,
        translatedText: String,
        sourceLanguageIdentifier: String,
        targetLanguageIdentifier: String,
        captureMethod: CaptureMethod,
        now: Date = Date()
    ) -> VocabularyEntry {
        let normalizedSource = Self.normalized(sourceText)

        if let index = entries.firstIndex(where: {
            Self.normalized($0.sourceText) == normalizedSource
                && $0.targetLanguageIdentifier == targetLanguageIdentifier
        }) {
            entries[index].sourceText = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
            entries[index].translatedText = translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
            entries[index].sourceLanguageIdentifier = sourceLanguageIdentifier
            entries[index].captureMethod = captureMethod
            entries[index].updatedAt = now
            entries[index].encounterCount += 1
            let updated = entries.remove(at: index)
            entries.insert(updated, at: 0)
            persist()
            return updated
        }

        let entry = VocabularyEntry(
            sourceText: sourceText.trimmingCharacters(in: .whitespacesAndNewlines),
            translatedText: translatedText.trimmingCharacters(in: .whitespacesAndNewlines),
            sourceLanguageIdentifier: sourceLanguageIdentifier,
            targetLanguageIdentifier: targetLanguageIdentifier,
            captureMethod: captureMethod,
            createdAt: now
        )
        entries.insert(entry, at: 0)
        persist()
        return entry
    }

    func remove(id: UUID) {
        entries.removeAll { $0.id == id }
        persist()
    }

    func remove(at offsets: IndexSet, from visibleEntries: [VocabularyEntry]) {
        let ids = Set(
            offsets.compactMap { index in
                visibleEntries.indices.contains(index) ? visibleEntries[index].id : nil
            })
        entries.removeAll { ids.contains($0.id) }
        persist()
    }

    func toggleFavorite(id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].isFavorite.toggle()
        entries[index].updatedAt = Date()
        persist()
    }

    func updateNote(id: UUID, note: String) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].note = note
        entries[index].updatedAt = Date()
        persist()
    }

    func recordReview(id: UUID, rating: ReviewRating, now: Date = Date()) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        ReviewScheduler.apply(rating, to: &entries[index], now: now)
        persist()
    }

    func entry(id: UUID?) -> VocabularyEntry? {
        guard let id else { return nil }
        return entries.first { $0.id == id }
    }

    func exportJSON(to destination: URL) throws {
        let data = try Self.encoder.encode(entries)
        try data.write(to: destination, options: .atomic)
    }

    func exportCSV(to destination: URL) throws {
        var lines = [
            "source,translation,source_language,target_language,capture_method,created_at,review_count,mastery_level,encounter_count,favorite,note"
        ]
        let formatter = ISO8601DateFormatter()
        lines += entries.map { entry in
            [
                entry.sourceText,
                entry.translatedText,
                entry.sourceLanguageIdentifier,
                entry.targetLanguageIdentifier,
                entry.captureMethod.rawValue,
                formatter.string(from: entry.createdAt),
                String(entry.reviewCount),
                String(entry.masteryLevel),
                String(entry.encounterCount),
                entry.isFavorite ? "true" : "false",
                entry.note,
            ].map(Self.csvEscaped).joined(separator: ",")
        }
        let data = Data(lines.joined(separator: "\n").utf8)
        try data.write(to: destination, options: .atomic)
    }

    private func persist() {
        do {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try Self.encoder.encode(entries)
            try data.write(to: fileURL, options: .atomic)
            lastError = nil
        } catch {
            lastError = "保存生词本失败：\(error.localizedDescription)"
        }
    }

    private static func normalized(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .lowercased()
    }

    private static func csvEscaped(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
