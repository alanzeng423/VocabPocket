import Foundation

enum TranslationProviderError: LocalizedError, Equatable {
    case unsupportedProvider
    case invalidEndpoint
    case missingAPIKey(String)
    case missingModel(String)
    case invalidResponse(String)
    case server(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .unsupportedProvider:
            "该翻译引擎不能通过网络客户端调用"
        case .invalidEndpoint:
            "接口地址无效，请填写完整的 http:// 或 https:// 地址"
        case .missingAPIKey(let provider):
            "尚未保存 \(provider) API Key"
        case .missingModel(let provider):
            "请为 \(provider) 填写模型名称"
        case .invalidResponse(let reason):
            "翻译服务返回了无法解析的结果：\(reason)"
        case .server(let statusCode, let message):
            "翻译服务请求失败（HTTP \(statusCode)）：\(message)"
        }
    }
}

final class TranslationAPIClient: @unchecked Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func translate(
        text: String,
        targetLanguageIdentifier: String,
        configuration: TranslationProviderConfiguration
    ) async throws -> ProviderTranslationResult {
        try validate(configuration)

        switch configuration.provider {
        case .apple:
            throw TranslationProviderError.unsupportedProvider
        case .deepL:
            return try await translateWithDeepL(
                text: text,
                target: targetLanguageIdentifier,
                configuration: configuration
            )
        case .googleCloud:
            return try await translateWithGoogle(
                text: text,
                target: targetLanguageIdentifier,
                configuration: configuration
            )
        case .microsoft:
            return try await translateWithMicrosoft(
                text: text,
                target: targetLanguageIdentifier,
                configuration: configuration
            )
        case .openAICompatible:
            return try await translateWithOpenAICompatible(
                text: text,
                target: targetLanguageIdentifier,
                configuration: configuration
            )
        case .anthropic:
            return try await translateWithAnthropic(
                text: text,
                target: targetLanguageIdentifier,
                configuration: configuration
            )
        }
    }

    private func translateWithDeepL(
        text: String,
        target: String,
        configuration: TranslationProviderConfiguration
    ) async throws -> ProviderTranslationResult {
        let url = try endpointURL(configuration.endpoint)
        var request = baseRequest(url: url)
        request.setValue("DeepL-Auth-Key \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(
            DeepLRequest(text: [text], targetLanguage: deepLCode(for: target))
        )

        let data = try await send(request)
        let response = try JSONDecoder().decode(DeepLResponse.self, from: data)
        guard let translation = response.translations.first else {
            throw TranslationProviderError.invalidResponse("没有译文")
        }
        return try result(
            text: translation.text,
            source: translation.detectedSourceLanguage.lowercased(),
            target: target
        )
    }

    private func translateWithGoogle(
        text: String,
        target: String,
        configuration: TranslationProviderConfiguration
    ) async throws -> ProviderTranslationResult {
        let endpoint = try endpointURL(configuration.endpoint)
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw TranslationProviderError.invalidEndpoint
        }
        var queryItems = components.queryItems ?? []
        queryItems.removeAll { $0.name == "key" }
        queryItems.append(URLQueryItem(name: "key", value: configuration.apiKey))
        components.queryItems = queryItems
        guard let url = components.url else { throw TranslationProviderError.invalidEndpoint }

        var request = baseRequest(url: url)
        request.httpBody = try JSONEncoder().encode(
            GoogleRequest(query: text, target: googleCode(for: target), format: "text")
        )

        let data = try await send(request)
        let response = try JSONDecoder().decode(GoogleResponse.self, from: data)
        guard let translation = response.data.translations.first else {
            throw TranslationProviderError.invalidResponse("没有译文")
        }
        return try result(
            text: decodeHTMLEntities(translation.translatedText),
            source: translation.detectedSourceLanguage ?? "und",
            target: target
        )
    }

    private func translateWithMicrosoft(
        text: String,
        target: String,
        configuration: TranslationProviderConfiguration
    ) async throws -> ProviderTranslationResult {
        let endpoint = try endpointURL(configuration.endpoint)
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw TranslationProviderError.invalidEndpoint
        }
        var queryItems = components.queryItems ?? []
        queryItems.removeAll { $0.name == "api-version" || $0.name == "to" }
        queryItems.append(URLQueryItem(name: "api-version", value: "3.0"))
        queryItems.append(URLQueryItem(name: "to", value: microsoftCode(for: target)))
        components.queryItems = queryItems
        guard let url = components.url else { throw TranslationProviderError.invalidEndpoint }

        var request = baseRequest(url: url)
        request.setValue(configuration.apiKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        let region = configuration.region.trimmingCharacters(in: .whitespacesAndNewlines)
        if !region.isEmpty {
            request.setValue(region, forHTTPHeaderField: "Ocp-Apim-Subscription-Region")
        }
        request.httpBody = try JSONEncoder().encode([MicrosoftRequest(text: text)])

        let data = try await send(request)
        let response = try JSONDecoder().decode([MicrosoftResponse].self, from: data)
        guard
            let item = response.first,
            let translation = item.translations.first
        else {
            throw TranslationProviderError.invalidResponse("没有译文")
        }
        return try result(
            text: translation.text,
            source: item.detectedLanguage?.language ?? "und",
            target: target
        )
    }

    private func translateWithOpenAICompatible(
        text: String,
        target: String,
        configuration: TranslationProviderConfiguration
    ) async throws -> ProviderTranslationResult {
        let url = try endpointURL(
            configuration.endpoint,
            appendingIfNeeded: ["chat", "completions"],
            acceptedSuffix: "/chat/completions"
        )
        var request = baseRequest(url: url)
        if !configuration.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(
            OpenAIRequest(
                model: configuration.model,
                messages: [
                    LLMMessage(role: "system", content: prompt(configuration, target: target)),
                    LLMMessage(role: "user", content: text),
                ]
            )
        )

        let data = try await send(request)
        let response = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        guard let text = response.choices.first?.message.content.text else {
            throw TranslationProviderError.invalidResponse("模型没有返回文本")
        }
        return try result(text: text, source: "und", target: target)
    }

    private func translateWithAnthropic(
        text: String,
        target: String,
        configuration: TranslationProviderConfiguration
    ) async throws -> ProviderTranslationResult {
        let url = try endpointURL(
            configuration.endpoint,
            appendingIfNeeded: ["v1", "messages"],
            acceptedSuffix: "/v1/messages"
        )
        var request = baseRequest(url: url)
        request.setValue(configuration.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONEncoder().encode(
            AnthropicRequest(
                model: configuration.model,
                maxTokens: 2_048,
                system: prompt(configuration, target: target),
                messages: [LLMMessage(role: "user", content: text)]
            )
        )

        let data = try await send(request)
        let response = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        let translated = response.content
            .filter { $0.type == "text" }
            .compactMap(\.text)
            .joined()
        return try result(text: translated, source: "und", target: target)
    }

    private func validate(_ configuration: TranslationProviderConfiguration) throws {
        guard configuration.provider != .apple else {
            throw TranslationProviderError.unsupportedProvider
        }
        _ = try endpointURL(configuration.endpoint)
        if configuration.provider.requiresAPIKey,
            configuration.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            throw TranslationProviderError.missingAPIKey(configuration.provider.title)
        }
        if configuration.provider.isLLM,
            configuration.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            throw TranslationProviderError.missingModel(configuration.provider.title)
        }
    }

    private func baseRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslationProviderError.invalidResponse("不是 HTTP 响应")
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw TranslationProviderError.server(
                statusCode: httpResponse.statusCode,
                message: serverErrorMessage(from: data)
            )
        }
        return data
    }

    private func endpointURL(
        _ value: String,
        appendingIfNeeded components: [String] = [],
        acceptedSuffix: String? = nil
    ) throws -> URL {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            var urlComponents = URLComponents(string: trimmed),
            let scheme = urlComponents.scheme?.lowercased(),
            scheme == "https" || scheme == "http",
            urlComponents.host != nil
        else {
            throw TranslationProviderError.invalidEndpoint
        }

        if let acceptedSuffix,
            !urlComponents.path.lowercased().hasSuffix(acceptedSuffix.lowercased())
        {
            var path = urlComponents.path
            var missingComponents = components
            if let existingLast = path.split(separator: "/").last,
                let desiredFirst = missingComponents.first,
                existingLast.lowercased() == desiredFirst.lowercased()
            {
                missingComponents.removeFirst()
            }
            for component in missingComponents {
                if !path.hasSuffix("/") { path += "/" }
                path += component
            }
            urlComponents.path = path
        }
        guard let url = urlComponents.url else { throw TranslationProviderError.invalidEndpoint }
        return url
    }

    private func result(text: String, source: String, target: String) throws -> ProviderTranslationResult {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            throw TranslationProviderError.invalidResponse("译文为空")
        }
        return ProviderTranslationResult(
            translatedText: cleaned,
            sourceLanguageIdentifier: source,
            targetLanguageIdentifier: target
        )
    }

    private func prompt(_ configuration: TranslationProviderConfiguration, target: String) -> String {
        let languageName = TargetLanguage(rawValue: target)?.title ?? target
        let value = configuration.systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let template = value.isEmpty ? TranslationProviderPreferences.defaultLLMPrompt : value
        return
            template
            .replacingOccurrences(of: "{target_language}", with: languageName)
            .replacingOccurrences(of: "{target_language_code}", with: target)
    }

    private func deepLCode(for target: String) -> String {
        switch target {
        case "zh-Hans": "ZH-HANS"
        case "zh-Hant": "ZH-HANT"
        case "en": "EN-US"
        default: target.uppercased()
        }
    }

    private func googleCode(for target: String) -> String {
        switch target {
        case "zh-Hans": "zh-CN"
        case "zh-Hant": "zh-TW"
        default: target
        }
    }

    private func microsoftCode(for target: String) -> String {
        switch target {
        case "zh-Hans": "zh-Hans"
        case "zh-Hant": "zh-Hant"
        default: target
        }
    }

    private func decodeHTMLEntities(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
    }

    private func serverErrorMessage(from data: Data) -> String {
        guard !data.isEmpty else { return "服务未返回错误详情" }
        if let object = try? JSONSerialization.jsonObject(with: data),
            let message = findMessage(in: object)
        {
            return String(message.prefix(500))
        }
        let text = String(data: data, encoding: .utf8) ?? "无法读取错误详情"
        return String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500))
    }

    private func findMessage(in value: Any) -> String? {
        if let dictionary = value as? [String: Any] {
            for key in ["message", "detail", "error_description"] {
                if let message = dictionary[key] as? String, !message.isEmpty { return message }
            }
            for nested in dictionary.values {
                if let message = findMessage(in: nested) { return message }
            }
        } else if let array = value as? [Any] {
            for nested in array {
                if let message = findMessage(in: nested) { return message }
            }
        }
        return nil
    }
}

private struct DeepLRequest: Encodable {
    let text: [String]
    let targetLanguage: String

    enum CodingKeys: String, CodingKey {
        case text
        case targetLanguage = "target_lang"
    }
}

private struct DeepLResponse: Decodable {
    struct Translation: Decodable {
        let detectedSourceLanguage: String
        let text: String

        enum CodingKeys: String, CodingKey {
            case detectedSourceLanguage = "detected_source_language"
            case text
        }
    }

    let translations: [Translation]
}

private struct GoogleRequest: Encodable {
    let query: String
    let target: String
    let format: String

    enum CodingKeys: String, CodingKey {
        case query = "q"
        case target
        case format
    }
}

private struct GoogleResponse: Decodable {
    struct Payload: Decodable {
        struct Translation: Decodable {
            let translatedText: String
            let detectedSourceLanguage: String?
        }

        let translations: [Translation]
    }

    let data: Payload
}

private struct MicrosoftRequest: Encodable {
    let text: String

    enum CodingKeys: String, CodingKey {
        case text = "Text"
    }
}

private struct MicrosoftResponse: Decodable {
    struct DetectedLanguage: Decodable {
        let language: String
    }

    struct Translation: Decodable {
        let text: String
        let to: String
    }

    let detectedLanguage: DetectedLanguage?
    let translations: [Translation]
}

private struct LLMMessage: Codable {
    let role: String
    let content: String
}

private struct OpenAIRequest: Encodable {
    let model: String
    let messages: [LLMMessage]
}

private struct OpenAIResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: FlexibleLLMContent
        }

        let message: Message
    }

    let choices: [Choice]
}

private enum FlexibleLLMContent: Decodable {
    struct Part: Decodable {
        let text: String?
    }

    case string(String)
    case parts([Part])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self = .string(value)
        } else {
            self = .parts(try container.decode([Part].self))
        }
    }

    var text: String {
        switch self {
        case .string(let value): value
        case .parts(let parts): parts.compactMap(\.text).joined()
        }
    }
}

private struct AnthropicRequest: Encodable {
    let model: String
    let maxTokens: Int
    let system: String
    let messages: [LLMMessage]

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case system
        case messages
    }
}

private struct AnthropicResponse: Decodable {
    struct Content: Decodable {
        let type: String
        let text: String?
    }

    let content: [Content]
}
