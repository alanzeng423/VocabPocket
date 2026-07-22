import Foundation
import Vision

enum OCRError: LocalizedError {
    case noTextFound

    var errorDescription: String? {
        switch self {
        case .noTextFound: "没有在截图中识别到文字"
        }
    }
}

struct OCRService {
    func recognizeText(in imageData: Data) async throws -> String {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.automaticallyDetectsLanguage = true
        request.usesLanguageCorrection = true

        let observations = try await request.perform(on: imageData)
        let lines =
            observations
            .compactMap { observation -> (x: CGFloat, y: CGFloat, text: String)? in
                guard let candidate = observation.topCandidates(1).first else { return nil }
                return (observation.topLeft.x, observation.topLeft.y, candidate.string)
            }
            .sorted { lhs, rhs in
                if abs(lhs.y - rhs.y) > 0.025 { return lhs.y > rhs.y }
                return lhs.x < rhs.x
            }
            .map { $0.text }

        let text = lines.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw OCRError.noTextFound }
        return String(text.prefix(8_000))
    }
}
