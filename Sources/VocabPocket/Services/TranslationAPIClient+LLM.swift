import Foundation

extension TranslationAPIClient {
    func translateWithAdditionalLLM(
        text: String,
        target: String,
        configuration: TranslationProviderConfiguration
    ) async throws -> ProviderTranslationResult {
        switch configuration.provider {
        case .azureOpenAI:
            return try await translateWithAzureOpenAI(text: text, target: target, configuration: configuration)
        case .gemini:
            return try await translateWithGemini(text: text, target: target, configuration: configuration)
        case .qwenMT:
            return try await translateWithQwenMT(text: text, target: target, configuration: configuration)
        default:
            throw TranslationProviderError.unsupportedProvider
        }
    }

    private func translateWithAzureOpenAI(
        text: String,
        target: String,
        configuration: TranslationProviderConfiguration
    ) async throws -> ProviderTranslationResult {
        let endpoint = try endpointURL(configuration.endpoint)
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw TranslationProviderError.invalidEndpoint
        }
        if !components.path.contains("/openai/deployments/") {
            var path = components.path
            if !path.hasSuffix("/") { path += "/" }
            path += "openai/deployments/\(configuration.model)/chat/completions"
            components.path = path
        }
        var queryItems = components.queryItems ?? []
        queryItems.removeAll { $0.name == "api-version" }
        let version = configuration.region.trimmingCharacters(in: .whitespacesAndNewlines)
        queryItems.append(URLQueryItem(name: "api-version", value: version.isEmpty ? "2024-10-21" : version))
        components.queryItems = queryItems
        guard let url = components.url else { throw TranslationProviderError.invalidEndpoint }

        var request = baseRequest(url: url)
        request.setValue(configuration.apiKey, forHTTPHeaderField: "api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "messages": [
                ["role": "system", "content": prompt(configuration, target: target)],
                ["role": "user", "content": text],
            ]
        ])
        let data = try await send(request)
        let translated = try openAIText(from: data)
        return try result(text: translated, source: "und", target: target)
    }

    private func translateWithGemini(
        text: String,
        target: String,
        configuration: TranslationProviderConfiguration
    ) async throws -> ProviderTranslationResult {
        let base = try endpointURL(configuration.endpoint)
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            throw TranslationProviderError.invalidEndpoint
        }
        if !components.path.contains(":generateContent") {
            var path = components.path
            if !path.hasSuffix("/") { path += "/" }
            path += "models/\(configuration.model):generateContent"
            components.path = path
        }
        guard let url = components.url else { throw TranslationProviderError.invalidEndpoint }
        var request = baseRequest(url: url)
        request.setValue(configuration.apiKey, forHTTPHeaderField: "x-goog-api-key")
        let body: [String: Any] = [
            "system_instruction": ["parts": [["text": prompt(configuration, target: target)]]],
            "contents": [
                [
                    "role": "user",
                    "parts": [["text": text]],
                ]
            ],
            "generationConfig": ["temperature": 0.1],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data = try await send(request)
        guard
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let candidates = object["candidates"] as? [[String: Any]],
            let content = candidates.first?["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]]
        else {
            throw TranslationProviderError.invalidResponse("Gemini 没有返回候选文本")
        }
        let translated = parts.compactMap { $0["text"] as? String }.joined()
        return try result(text: translated, source: "und", target: target)
    }

    private func translateWithQwenMT(
        text: String,
        target: String,
        configuration: TranslationProviderConfiguration
    ) async throws -> ProviderTranslationResult {
        let url = try endpointURL(
            configuration.endpoint,
            appendingIfNeeded: ["v1", "chat", "completions"],
            acceptedSuffix: "/v1/chat/completions"
        )
        var request = baseRequest(url: url)
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        var options: [String: Any] = [
            "source_lang": "auto",
            "target_lang": qwenLanguageName(for: target),
        ]
        let domains = configuration.systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !domains.isEmpty { options["domains"] = domains }
        let body: [String: Any] = [
            "model": configuration.model,
            "messages": [["role": "user", "content": text]],
            "translation_options": options,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let data = try await send(request)
        let translated = try openAIText(from: data)
        return try result(text: translated, source: "und", target: target)
    }

    private func openAIText(from data: Data) throws -> String {
        guard
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = object["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any]
        else {
            throw TranslationProviderError.invalidResponse("模型没有返回 choices")
        }
        if let value = message["content"] as? String { return value }
        if let parts = message["content"] as? [[String: Any]] {
            return parts.compactMap { $0["text"] as? String }.joined()
        }
        throw TranslationProviderError.invalidResponse("模型没有返回文本")
    }

    private func qwenLanguageName(for identifier: String) -> String {
        switch identifier {
        case "zh-Hans": "Chinese"
        case "zh-Hant": "Traditional Chinese"
        case "en": "English"
        case "ja": "Japanese"
        case "ko": "Korean"
        case "fr": "French"
        case "de": "German"
        case "es": "Spanish"
        default: TargetLanguage(rawValue: identifier)?.title ?? identifier
        }
    }
}
