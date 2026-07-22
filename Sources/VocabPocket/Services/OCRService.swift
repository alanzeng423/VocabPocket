import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import Vision

enum OCRError: LocalizedError {
    case invalidImage
    case noTextFound
    case recognitionFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            "截图文件无效，请重新框选文字区域"
        case .noTextFound:
            "没有在截图中识别到文字；请尽量贴近文字框选，并避免范围过大"
        case .recognitionFailed(let reason):
            "OCR 识别失败：\(reason)"
        }
    }
}

struct OCRService {
    func recognizeText(in imageData: Data) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            try Self.recognizeSynchronously(in: imageData)
        }.value
    }

    private static func recognizeSynchronously(in imageData: Data) throws -> String {
        guard
            !imageData.isEmpty,
            let source = CGImageSourceCreateWithData(imageData as CFData, nil),
            let originalImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw OCRError.invalidImage
        }

        var results: [OCRPassResult] = []
        var errors: [Error] = []

        runPass(
            image: originalImage,
            usesLanguageCorrection: true,
            minimumTextHeight: 0.004,
            results: &results,
            errors: &errors
        )

        if let enhancedImage = enhancedImage(from: originalImage, inverted: false) {
            runPass(
                image: enhancedImage,
                usesLanguageCorrection: false,
                minimumTextHeight: 0.002,
                results: &results,
                errors: &errors
            )
        }

        if results.max(by: { $0.score < $1.score })?.isReliable != true,
            let invertedImage = enhancedImage(from: originalImage, inverted: true)
        {
            runPass(
                image: invertedImage,
                usesLanguageCorrection: false,
                minimumTextHeight: 0.002,
                results: &results,
                errors: &errors
            )
        }

        if let best = results.max(by: { $0.score < $1.score }), !best.text.isEmpty {
            return String(best.text.prefix(8_000))
        }
        if let error = errors.last, errors.count >= 2 {
            throw OCRError.recognitionFailed(error.localizedDescription)
        }
        throw OCRError.noTextFound
    }

    private static func runPass(
        image: CGImage,
        usesLanguageCorrection: Bool,
        minimumTextHeight: Float,
        results: inout [OCRPassResult],
        errors: inout [Error]
    ) {
        do {
            let result = try recognize(
                image: image,
                usesLanguageCorrection: usesLanguageCorrection,
                minimumTextHeight: minimumTextHeight
            )
            if !result.text.isEmpty { results.append(result) }
        } catch {
            errors.append(error)
        }
    }

    private static func recognize(
        image: CGImage,
        usesLanguageCorrection: Bool,
        minimumTextHeight: Float
    ) throws -> OCRPassResult {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = usesLanguageCorrection
        request.automaticallyDetectsLanguage = true
        request.minimumTextHeight = minimumTextHeight
        let languageHints = supportedLanguageHints(for: request)
        if !languageHints.isEmpty {
            request.recognitionLanguages = languageHints
        }

        let handler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
        try handler.perform([request])

        let lines = (request.results ?? []).compactMap { observation -> OCRLine? in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return OCRLine(
                text: text,
                confidence: candidate.confidence,
                boundingBox: observation.boundingBox
            )
        }
        return OCRPassResult(lines: lines)
    }

    private static func supportedLanguageHints(for request: VNRecognizeTextRequest) -> [String] {
        let supported = (try? request.supportedRecognitionLanguages()) ?? []
        guard !supported.isEmpty else { return [] }

        let desired =
            Locale.preferredLanguages + [
                "zh-Hans", "zh-Hant", "en-US", "ja-JP", "ko-KR", "fr-FR", "de-DE", "es-ES",
            ]
        var selected: [String] = []
        for desiredCode in desired {
            let normalized = desiredCode.lowercased()
            let language = normalized.split(separator: "-").first.map(String.init) ?? normalized
            guard
                let match = supported.first(where: {
                    let candidate = $0.lowercased()
                    return candidate == normalized || candidate == language
                        || candidate.hasPrefix("\(language)-")
                }),
                !selected.contains(match)
            else { continue }
            selected.append(match)
        }
        return Array(selected.prefix(8))
    }

    private static func enhancedImage(from image: CGImage, inverted: Bool) -> CGImage? {
        let originalWidth = CGFloat(image.width)
        let originalHeight = CGFloat(image.height)
        guard originalWidth > 0, originalHeight > 0 else { return nil }

        let longestSide = max(originalWidth, originalHeight)
        let scale = min(3.0, max(1.5, 2_400 / longestSide))
        var output = CIImage(cgImage: image)
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .applyingFilter(
                "CIColorControls",
                parameters: [
                    kCIInputSaturationKey: 0,
                    kCIInputContrastKey: 1.45,
                    kCIInputBrightnessKey: 0.02,
                ]
            )
            .applyingFilter("CISharpenLuminance", parameters: [kCIInputSharpnessKey: 0.65])
        if inverted {
            output = output.applyingFilter("CIColorInvert")
        }

        let context = CIContext(options: [.cacheIntermediates: false])
        return context.createCGImage(output, from: output.extent.integral)
    }
}

private struct OCRLine {
    let text: String
    let confidence: Float
    let boundingBox: CGRect
}

private struct OCRPassResult {
    let text: String
    let averageConfidence: Double
    let characterCount: Int
    let lineCount: Int

    init(lines: [OCRLine]) {
        let sorted = lines.sorted { lhs, rhs in
            let lhsY = lhs.boundingBox.midY
            let rhsY = rhs.boundingBox.midY
            if abs(lhsY - rhsY) > 0.018 { return lhsY > rhsY }
            return lhs.boundingBox.minX < rhs.boundingBox.minX
        }

        var uniqueLines: [OCRLine] = []
        for line in sorted where uniqueLines.last?.text != line.text {
            uniqueLines.append(line)
        }

        let recognizedText = uniqueLines.map(\.text).joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let confidence =
            uniqueLines.isEmpty
            ? 0
            : uniqueLines.reduce(0) { $0 + Double($1.confidence) } / Double(uniqueLines.count)
        let characters =
            recognizedText.unicodeScalars.filter {
                !CharacterSet.whitespacesAndNewlines.contains($0)
            }.count

        text = recognizedText
        averageConfidence = confidence
        characterCount = characters
        lineCount = uniqueLines.count
    }

    var score: Double {
        averageConfidence * 100
            + log(Double(max(characterCount, 1))) * 9
            + Double(min(lineCount, 20)) * 0.4
    }

    var isReliable: Bool {
        characterCount >= 2 && averageConfidence >= 0.52
    }
}
