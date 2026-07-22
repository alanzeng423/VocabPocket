import Foundation

extension TranslationAPIClient {
    func translateWithCloudProvider(
        text: String,
        target: String,
        configuration: TranslationProviderConfiguration
    ) async throws -> ProviderTranslationResult {
        switch configuration.provider {
        case .baidu, .baiduField:
            return try await translateWithBaidu(text: text, target: target, configuration: configuration)
        case .youdaoCloud:
            return try await translateWithYoudaoCloud(text: text, target: target, configuration: configuration)
        case .youdaoLLM:
            return try await translateWithYoudaoLLM(text: text, target: target, configuration: configuration)
        case .niuTrans:
            return try await translateWithNiuTrans(text: text, target: target, configuration: configuration)
        case .caiyun:
            return try await translateWithCaiyun(text: text, target: target, configuration: configuration)
        case .openL:
            return try await translateWithOpenL(text: text, target: target, configuration: configuration)
        case .aliyun:
            return try await translateWithAliyun(text: text, target: target, configuration: configuration)
        case .tencentCloud:
            return try await translateWithTencentCloud(text: text, target: target, configuration: configuration)
        case .volcanoEngine:
            return try await translateWithVolcanoEngine(text: text, target: target, configuration: configuration)
        case .iFlytek:
            return try await translateWithIFlytek(text: text, target: target, configuration: configuration)
        default:
            throw TranslationProviderError.unsupportedProvider
        }
    }

    private func translateWithBaidu(
        text: String,
        target: String,
        configuration: TranslationProviderConfiguration
    ) async throws -> ProviderTranslationResult {
        let parts = try credentialParts(configuration.apiKey, count: 2, provider: configuration.provider)
        let appID = parts[0]
        let secret = parts[1]
        let salt = String(Int(Date().timeIntervalSince1970 * 1_000))
        let isField = configuration.provider == .baiduField
        let domainValue = configuration.region.trimmingCharacters(in: .whitespacesAndNewlines)
        let domain = domainValue.isEmpty ? "electronics" : domainValue
        let signInput =
            isField
            ? appID + text + salt + domain + secret
            : appID + text + salt + secret
        var parameters = [
            "q": text,
            "appid": appID,
            "from": "auto",
            "to": baiduLanguageCode(for: target),
            "salt": salt,
            "sign": md5Hex(signInput),
        ]
        if isField { parameters["domain"] = domain }

        let url = try endpointURL(configuration.endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = formEncoded(parameters)
        let data = try await send(request)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TranslationProviderError.invalidResponse("百度接口未返回 JSON 对象")
        }
        if let code = object["error_code"] {
            throw TranslationProviderError.invalidResponse(
                "百度错误 \(code)：\(object["error_msg"] as? String ?? "未知错误")"
            )
        }
        guard let translations = object["trans_result"] as? [[String: Any]] else {
            throw TranslationProviderError.invalidResponse("百度响应中没有 trans_result")
        }
        let translated = translations.compactMap { $0["dst"] as? String }.joined(separator: "\n")
        return try result(text: translated, source: object["from"] as? String ?? "und", target: target)
    }

    private func translateWithYoudaoCloud(
        text: String,
        target: String,
        configuration: TranslationProviderConfiguration
    ) async throws -> ProviderTranslationResult {
        let parts = try credentialParts(configuration.apiKey, count: 2, provider: .youdaoCloud)
        let signed = youdaoSignedParameters(text: text, appID: parts[0], secret: parts[1])
        var parameters = signed
        parameters["q"] = text
        parameters["from"] = "auto"
        parameters["to"] = youdaoLanguageCode(for: target)
        let domain = configuration.region.trimmingCharacters(in: .whitespacesAndNewlines)
        if !domain.isEmpty { parameters["domain"] = domain }
        let vocabularyID = configuration.systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !vocabularyID.isEmpty { parameters["vocabId"] = vocabularyID }

        let url = try endpointURL(configuration.endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = formEncoded(parameters)
        let data = try await send(request)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TranslationProviderError.invalidResponse("有道智云未返回 JSON 对象")
        }
        let errorCode = String(describing: object["errorCode"] ?? "")
        guard errorCode == "0" else {
            throw TranslationProviderError.invalidResponse("有道智云错误码 \(errorCode)")
        }
        guard let translations = object["translation"] as? [String] else {
            throw TranslationProviderError.invalidResponse("有道智云响应中没有 translation")
        }
        let languagePair = object["l"] as? String
        let source = languagePair?.components(separatedBy: "2").first ?? "und"
        return try result(text: translations.joined(), source: source, target: target)
    }

    private func translateWithYoudaoLLM(
        text: String,
        target: String,
        configuration: TranslationProviderConfiguration
    ) async throws -> ProviderTranslationResult {
        let parts = try credentialParts(configuration.apiKey, count: 2, provider: .youdaoLLM)
        var parameters = youdaoSignedParameters(text: text, appID: parts[0], secret: parts[1])
        parameters["i"] = text
        parameters["from"] = "auto"
        parameters["to"] = youdaoLanguageCode(for: target)
        parameters["handleOption"] = configuration.model.lowercased() == "lite" ? "3" : "0"
        parameters["streamType"] = "full"
        let requirement = configuration.systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !requirement.isEmpty { parameters["prompt"] = requirement }

        let endpoint = try endpointURL(configuration.endpoint)
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw TranslationProviderError.invalidEndpoint
        }
        components.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components.url else { throw TranslationProviderError.invalidEndpoint }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("text/event-stream, application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data()
        let data = try await send(request)
        let responseText = String(data: data, encoding: .utf8) ?? ""
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let code = json["errorCode"]
        {
            throw TranslationProviderError.invalidResponse("有道大模型错误码 \(code)")
        }
        var translated = ""
        for line in responseText.components(separatedBy: .newlines) where line.hasPrefix("data:") {
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            guard
                let eventData = payload.data(using: .utf8),
                let event = try? JSONSerialization.jsonObject(with: eventData) as? [String: Any]
            else { continue }
            if let full = event["transFull"] as? String {
                translated = full
            } else if let incremental = event["transIncre"] as? String {
                translated += incremental
            }
        }
        return try result(text: translated, source: "und", target: target)
    }

    private func translateWithNiuTrans(
        text: String,
        target: String,
        configuration: TranslationProviderConfiguration
    ) async throws -> ProviderTranslationResult {
        let url = try endpointURL(configuration.endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = formEncoded([
            "from": "auto",
            "to": niuTransLanguageCode(for: target),
            "apikey": configuration.apiKey,
            "src_text": text,
        ])
        let data = try await send(request)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TranslationProviderError.invalidResponse("小牛翻译未返回 JSON 对象")
        }
        if let errorCode = object["error_code"] ?? object["code"],
            String(describing: errorCode) != "200"
        {
            throw TranslationProviderError.invalidResponse(
                "小牛翻译错误 \(errorCode)：\(object["error_msg"] as? String ?? object["msg"] as? String ?? "未知错误")"
            )
        }
        let translated =
            object["tgt_text"] as? String
            ?? (object["data"] as? [String: Any])?["tgt_text"] as? String
        guard let translated else {
            throw TranslationProviderError.invalidResponse("小牛翻译响应中没有 tgt_text")
        }
        return try result(text: translated, source: "und", target: target)
    }

    private func translateWithCaiyun(
        text: String,
        target: String,
        configuration: TranslationProviderConfiguration
    ) async throws -> ProviderTranslationResult {
        let url = try endpointURL(configuration.endpoint)
        let detected = detectedLanguageIdentifier(for: text)
        let source = detected == "und" ? "auto" : caiyunLanguageCode(for: detected)
        let targetCode = caiyunLanguageCode(for: target)
        var request = baseRequest(url: url)
        request.setValue("token \(configuration.apiKey)", forHTTPHeaderField: "x-authorization")
        let body: [String: Any] = [
            "source": [text],
            "trans_type": "\(source)2\(targetCode)",
            "request_id": UUID().uuidString,
            "detect": true,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let data = try await send(request)
        guard
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let translations = object["target"] as? [String]
        else {
            throw TranslationProviderError.invalidResponse("彩云响应中没有 target")
        }
        return try result(text: translations.joined(separator: "\n"), source: source, target: target)
    }

    private func translateWithOpenL(
        text: String,
        target: String,
        configuration: TranslationProviderConfiguration
    ) async throws -> ProviderTranslationResult {
        let services = configuration.systemPrompt.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !services.isEmpty else {
            throw TranslationProviderError.invalidResponse("请至少填写一个 OpenL 服务名称")
        }
        let url = try endpointURL(configuration.endpoint)
        var request = baseRequest(url: url)
        let body: [String: Any] = [
            "apikey": configuration.apiKey,
            "services": services,
            "text": text,
            "source_lang": baseLanguageCode(detectedLanguageIdentifier(for: text)),
            "target_lang": baseLanguageCode(target),
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let data = try await send(request)
        guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TranslationProviderError.invalidResponse("OpenL 未返回 JSON 对象")
        }
        guard (object.removeValue(forKey: "status") as? Bool) != false else {
            throw TranslationProviderError.invalidResponse("OpenL 请求失败")
        }
        let translations = object.keys.sorted().compactMap { service -> String? in
            guard
                let response = object[service] as? [String: Any],
                response["status"] as? Bool == true,
                let translated = response["result"] as? String
            else { return nil }
            return object.count == 1 ? translated : "[\(service)] \(translated)"
        }
        return try result(text: translations.joined(separator: "\n"), source: "und", target: target)
    }

    private func youdaoSignedParameters(text: String, appID: String, secret: String) -> [String: String] {
        let salt = UUID().uuidString
        let currentTime = String(Int(Date().timeIntervalSince1970))
        let input = truncatedYoudaoInput(text)
        return [
            "appKey": appID,
            "salt": salt,
            "curtime": currentTime,
            "signType": "v3",
            "sign": sha256Hex(appID + input + salt + currentTime + secret),
        ]
    }

    private func truncatedYoudaoInput(_ value: String) -> String {
        let utf16Value = value as NSString
        guard utf16Value.length > 20 else { return value }
        return
            utf16Value.substring(to: 10) + String(utf16Value.length)
            + utf16Value.substring(from: utf16Value.length - 10)
    }

    private func baiduLanguageCode(for identifier: String) -> String {
        switch identifier {
        case "zh-Hans": "zh"
        case "zh-Hant": "cht"
        default: baseLanguageCode(identifier)
        }
    }

    private func youdaoLanguageCode(for identifier: String) -> String {
        switch identifier {
        case "zh-Hans": "zh-CHS"
        case "zh-Hant": "zh-CHT"
        case "en": "en"
        default: baseLanguageCode(identifier)
        }
    }

    private func niuTransLanguageCode(for identifier: String) -> String {
        switch identifier {
        case "zh-Hans": "zh"
        case "zh-Hant": "cht"
        default: baseLanguageCode(identifier)
        }
    }

    private func caiyunLanguageCode(for identifier: String) -> String {
        switch identifier {
        case "zh-Hant", "zh-TW", "zh-HK", "zh-MO": "zh-Hant"
        case "zh-Hans", "zh-CN", "zh-SG", "zh": "zh"
        default: baseLanguageCode(identifier)
        }
    }
}
