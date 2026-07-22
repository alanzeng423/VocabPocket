import Foundation

extension TranslationAPIClient {
    func translateWithSelfHostedProvider(
        text: String,
        target: String,
        configuration: TranslationProviderConfiguration
    ) async throws -> ProviderTranslationResult {
        switch configuration.provider {
        case .deepLX:
            return try await translateWithDeepLX(text: text, target: target, configuration: configuration)
        case .libreTranslate:
            return try await translateWithLibreTranslate(text: text, target: target, configuration: configuration)
        case .mTranServer:
            return try await translateWithMTranServer(text: text, target: target, configuration: configuration)
        case .nllb:
            return try await translateWithNLLB(text: text, target: target, configuration: configuration)
        default:
            throw TranslationProviderError.unsupportedProvider
        }
    }

    private func translateWithDeepLX(
        text: String,
        target: String,
        configuration: TranslationProviderConfiguration
    ) async throws -> ProviderTranslationResult {
        let url = try endpointURL(
            configuration.endpoint,
            appendingIfNeeded: ["translate"],
            acceptedSuffix: "/translate"
        )
        var request = baseRequest(url: url)
        setOptionalBearer(configuration.apiKey, on: &request)
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "text": text,
            "source_lang": "auto",
            "target_lang": deepLCode(for: target),
        ])

        let data = try await send(request)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TranslationProviderError.invalidResponse("DeepLX 未返回 JSON 对象")
        }
        let translated =
            object["data"] as? String
            ?? object["translation"] as? String
            ?? object["translated_text"] as? String
            ?? (object["translations"] as? [[String: Any]])?.first?["text"] as? String
        guard let translated else {
            throw TranslationProviderError.invalidResponse("DeepLX 响应中没有译文")
        }
        let source = object["source_lang"] as? String ?? object["sourceLanguage"] as? String ?? "und"
        return try result(text: translated, source: source.lowercased(), target: target)
    }

    private func translateWithLibreTranslate(
        text: String,
        target: String,
        configuration: TranslationProviderConfiguration
    ) async throws -> ProviderTranslationResult {
        let url = try endpointURL(
            configuration.endpoint,
            appendingIfNeeded: ["translate"],
            acceptedSuffix: "/translate"
        )
        var body: [String: Any] = [
            "q": text,
            "source": "auto",
            "target": baseLanguageCode(target),
            "format": "text",
        ]
        let key = configuration.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !key.isEmpty { body["api_key"] = key }
        var request = baseRequest(url: url)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data = try await send(request)
        guard
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let translated = object["translatedText"] as? String
        else {
            throw TranslationProviderError.invalidResponse("LibreTranslate 响应中没有 translatedText")
        }
        let detected = (object["detectedLanguage"] as? [String: Any])?["language"] as? String ?? "und"
        return try result(text: translated, source: detected, target: target)
    }

    private func translateWithMTranServer(
        text: String,
        target: String,
        configuration: TranslationProviderConfiguration
    ) async throws -> ProviderTranslationResult {
        let url = try endpointURL(configuration.endpoint)
        let detected = detectedLanguageIdentifier(for: text)
        let useBCP47 = configuration.region.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "bcp47"
        let sourceCode = mTranCode(for: detected, useBCP47: useBCP47)
        let targetCode = mTranCode(for: target, useBCP47: useBCP47)
        var request = baseRequest(url: url)
        let token = configuration.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !token.isEmpty { request.setValue(token, forHTTPHeaderField: "Authorization") }
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "text": text,
            "from": sourceCode,
            "to": targetCode,
        ])
        let data = try await send(request)
        guard
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let translated = object["result"] as? String
        else {
            throw TranslationProviderError.invalidResponse("MTranServer 响应中没有 result")
        }
        return try result(text: translated, source: detected, target: target)
    }

    private func translateWithNLLB(
        text: String,
        target: String,
        configuration: TranslationProviderConfiguration
    ) async throws -> ProviderTranslationResult {
        let backend = configuration.model.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let source = detectedLanguageIdentifier(for: text)
        if backend == "nllb-api" {
            let base = try endpointURL(configuration.endpoint)
            let url = try endpointURL(
                base.absoluteString,
                appendingIfNeeded: ["api", "v4", "translator"],
                acceptedSuffix: "/api/v4/translator"
            )
            guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                throw TranslationProviderError.invalidEndpoint
            }
            components.queryItems = [
                URLQueryItem(name: "text", value: text),
                URLQueryItem(name: "source", value: nllbCode(for: source)),
                URLQueryItem(name: "target", value: nllbCode(for: target)),
            ]
            guard let requestURL = components.url else { throw TranslationProviderError.invalidEndpoint }
            var request = URLRequest(url: requestURL)
            request.timeoutInterval = 45
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            setOptionalBearer(configuration.apiKey, on: &request)
            let data = try await send(request)
            guard
                let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let translated = object["result"] as? String
            else {
                throw TranslationProviderError.invalidResponse("nllb-api 响应中没有 result")
            }
            return try result(text: translated, source: source, target: target)
        }

        guard backend == "nllb-serve" else {
            throw TranslationProviderError.invalidResponse("NLLB 后端类型只能是 nllb-serve 或 nllb-api")
        }
        let url = try endpointURL(
            configuration.endpoint,
            appendingIfNeeded: ["translate"],
            acceptedSuffix: "/translate"
        )
        var request = baseRequest(url: url)
        setOptionalBearer(configuration.apiKey, on: &request)
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "source": text,
            "src_lang": nllbCode(for: source),
            "tgt_lang": nllbCode(for: target),
        ])
        let data = try await send(request)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TranslationProviderError.invalidResponse("nllb-serve 未返回 JSON 对象")
        }
        let translated =
            (object["translation"] as? [String])?.first
            ?? object["translation"] as? String
            ?? object["result"] as? String
        guard let translated else {
            throw TranslationProviderError.invalidResponse("nllb-serve 响应中没有 translation")
        }
        return try result(text: translated, source: source, target: target)
    }

    private func setOptionalBearer(_ value: String, on request: inout URLRequest) {
        let token = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if !token.isEmpty { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
    }

    private func mTranCode(for identifier: String, useBCP47: Bool) -> String {
        guard useBCP47 else { return baseLanguageCode(identifier) }
        switch identifier {
        case "zh", "zh-Hans", "zh-CN", "zh-SG": "zh-Hans"
        case "zh-Hant", "zh-TW", "zh-HK", "zh-MO": "zh-Hant"
        default: identifier
        }
    }

    private func nllbCode(for identifier: String) -> String {
        if ["zh-Hant", "zh-TW", "zh-HK", "zh-MO"].contains(identifier) { return "zho_Hant" }
        switch baseLanguageCode(identifier) {
        case "en": "eng_Latn"
        case "zh": "zho_Hans"
        case "ja": "jpn_Jpan"
        case "ko": "kor_Hang"
        case "fr": "fra_Latn"
        case "es": "spa_Latn"
        case "de": "deu_Latn"
        case "it": "ita_Latn"
        case "nl": "nld_Latn"
        case "pt": "por_Latn"
        case "ru": "rus_Cyrl"
        case "ar": "arb_Arab"
        case "tr": "tur_Latn"
        case "vi": "vie_Latn"
        case "th": "tha_Thai"
        case "id": "ind_Latn"
        case "ms": "zsm_Latn"
        case "hi": "hin_Deva"
        case "bn": "ben_Beng"
        case "ur": "urd_Arab"
        case "he": "heb_Hebr"
        case "pl": "pol_Latn"
        case "ro": "ron_Latn"
        case "cs": "ces_Latn"
        case "hu": "hun_Latn"
        case "sv": "swe_Latn"
        case "da": "dan_Latn"
        case "fi": "fin_Latn"
        case "el": "ell_Grek"
        case "uk": "ukr_Cyrl"
        case "km": "khm_Khmr"
        default: identifier
        }
    }
}
