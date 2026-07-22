import Foundation
import NaturalLanguage

extension TranslationAPIClient {
    func translateWithFreeProvider(
        text: String,
        target: String,
        configuration: TranslationProviderConfiguration
    ) async throws -> ProviderTranslationResult {
        switch configuration.provider {
        case .googleFree:
            return try await translateWithGoogleFree(text: text, target: target, configuration: configuration)
        case .bingFree:
            return try await translateWithBingFree(text: text, target: target, configuration: configuration)
        case .youdaoFree:
            return try await translateWithYoudaoFree(text: text, target: target, configuration: configuration)
        case .volcanoWeb:
            return try await translateWithVolcanoWeb(text: text, target: target, configuration: configuration)
        case .tencentTransmart:
            return try await translateWithTencentTransmart(text: text, target: target, configuration: configuration)
        default:
            throw TranslationProviderError.unsupportedProvider
        }
    }

    private func translateWithGoogleFree(
        text: String,
        target: String,
        configuration: TranslationProviderConfiguration
    ) async throws -> ProviderTranslationResult {
        let endpoint = try endpointURL(configuration.endpoint)
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw TranslationProviderError.invalidEndpoint
        }
        components.queryItems = [
            URLQueryItem(name: "client", value: "gtx"),
            URLQueryItem(name: "sl", value: "auto"),
            URLQueryItem(name: "tl", value: googleCode(for: target)),
            URLQueryItem(name: "dt", value: "t"),
            URLQueryItem(name: "q", value: text),
        ]
        guard let url = components.url else { throw TranslationProviderError.invalidEndpoint }
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data = try await send(request)
        guard
            let payload = try JSONSerialization.jsonObject(with: data) as? [Any],
            let segments = payload.first as? [Any]
        else {
            throw TranslationProviderError.invalidResponse("Google 免费接口格式已变化")
        }
        let translated = segments.compactMap { segment -> String? in
            guard let values = segment as? [Any], let value = values.first as? String else { return nil }
            return value
        }.joined()
        let source = payload.count > 2 ? (payload[2] as? String ?? "und") : "und"
        return try result(text: translated, source: source, target: target)
    }

    private func translateWithBingFree(
        text: String,
        target: String,
        configuration: TranslationProviderConfiguration
    ) async throws -> ProviderTranslationResult {
        guard let tokenURL = URL(string: "https://edge.microsoft.com/translate/auth") else {
            throw TranslationProviderError.invalidEndpoint
        }
        var tokenRequest = URLRequest(url: tokenURL)
        tokenRequest.timeoutInterval = 30
        tokenRequest.setValue(Self.browserUserAgent, forHTTPHeaderField: "User-Agent")
        let tokenData = try await send(tokenRequest)
        guard
            let token = String(data: tokenData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            !token.isEmpty
        else {
            throw TranslationProviderError.invalidResponse("未取得 Bing 临时令牌")
        }

        let endpoint = try endpointURL(configuration.endpoint)
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw TranslationProviderError.invalidEndpoint
        }
        components.queryItems = [
            URLQueryItem(name: "api-version", value: "3.0"),
            URLQueryItem(name: "to", value: microsoftCode(for: target)),
        ]
        guard let url = components.url else { throw TranslationProviderError.invalidEndpoint }
        var request = baseRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(Self.browserUserAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONSerialization.data(withJSONObject: [["text": text]])

        let data = try await send(request)
        guard
            let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
            let first = array.first,
            let translations = first["translations"] as? [[String: Any]],
            let translated = translations.first?["text"] as? String
        else {
            throw TranslationProviderError.invalidResponse("Bing 免费接口格式已变化")
        }
        let detected = (first["detectedLanguage"] as? [String: Any])?["language"] as? String ?? "und"
        return try result(text: translated, source: detected, target: target)
    }

    private func translateWithYoudaoFree(
        text: String,
        target: String,
        configuration: TranslationProviderConfiguration
    ) async throws -> ProviderTranslationResult {
        let endpoint = try endpointURL(configuration.endpoint)
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw TranslationProviderError.invalidEndpoint
        }
        components.queryItems = [
            URLQueryItem(name: "doctype", value: "json"),
            URLQueryItem(name: "type", value: "AUTO2\(youdaoFreeCode(for: target))"),
            URLQueryItem(name: "i", value: text),
        ]
        guard let url = components.url else { throw TranslationProviderError.invalidEndpoint }
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue(Self.browserUserAgent, forHTTPHeaderField: "User-Agent")

        let data = try await send(request)
        guard
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let groups = object["translateResult"] as? [Any]
        else {
            throw TranslationProviderError.invalidResponse("有道免费接口格式已变化")
        }
        let translated = groups.flatMap { ($0 as? [Any]) ?? [] }.compactMap { item in
            (item as? [String: Any])?["tgt"] as? String
        }.joined()
        return try result(
            text: translated,
            source: detectedLanguageIdentifier(for: text),
            target: target
        )
    }

    private func translateWithVolcanoWeb(
        text: String,
        target: String,
        configuration: TranslationProviderConfiguration
    ) async throws -> ProviderTranslationResult {
        let url = try endpointURL(configuration.endpoint)
        let detected = baseLanguageCode(detectedLanguageIdentifier(for: text))
        let source = detected == "und" ? "auto" : detected
        var request = baseRequest(url: url)
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "source_language": detected == "und" ? "" : detected,
            "target_language": baseLanguageCode(target),
            "text": text,
        ])
        let data = try await send(request)
        guard
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let translated = object["translation"] as? String
        else {
            throw TranslationProviderError.invalidResponse("火山网页接口格式已变化")
        }
        return try result(text: translated, source: source, target: target)
    }

    private func translateWithTencentTransmart(
        text: String,
        target: String,
        configuration: TranslationProviderConfiguration
    ) async throws -> ProviderTranslationResult {
        let url = try endpointURL(configuration.endpoint)
        let detected = baseLanguageCode(detectedLanguageIdentifier(for: text))
        let source = detected == "und" ? "auto" : detected
        var request = baseRequest(url: url)
        request.setValue(Self.browserUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("https://transmart.qq.com/zh-CN/index", forHTTPHeaderField: "Referer")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "header": [
                "fn": "auto_translation",
                "client_key":
                    "browser-chrome-127.0.0-Mac OS-\(UUID().uuidString.lowercased())-\(Int(Date().timeIntervalSince1970 * 1_000))",
            ],
            "type": "plain",
            "model_category": "normal",
            "source": ["lang": source, "text_list": [text]],
            "target": ["lang": baseLanguageCode(target)],
        ])
        let data = try await send(request)
        guard
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let translations = object["auto_translation"] as? [String]
        else {
            throw TranslationProviderError.invalidResponse("腾讯交互翻译接口格式已变化")
        }
        return try result(text: translations.joined(separator: "\n"), source: source, target: target)
    }

    func detectedLanguageIdentifier(for text: String) -> String {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.dominantLanguage?.rawValue ?? "und"
    }

    func baseLanguageCode(_ identifier: String) -> String {
        switch identifier {
        case "zh-Hans", "zh-CN", "zh-SG": "zh"
        case "zh-Hant", "zh-TW", "zh-HK", "zh-MO": "zh"
        default: identifier.split(separator: "-").first.map(String.init) ?? identifier
        }
    }

    private func youdaoFreeCode(for target: String) -> String {
        switch target {
        case "zh-Hans": "ZH_CN"
        case "zh-Hant": "ZH_TW"
        default: target.uppercased().replacingOccurrences(of: "-", with: "_")
        }
    }

    static let browserUserAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 VocabPocket/0.3"
}
