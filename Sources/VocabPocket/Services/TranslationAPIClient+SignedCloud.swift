import Foundation

extension TranslationAPIClient {
    func translateWithAliyun(
        text: String,
        target: String,
        configuration: TranslationProviderConfiguration
    ) async throws -> ProviderTranslationResult {
        let credentials = try credentialParts(configuration.apiKey, count: 2, provider: .aliyun)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        var parameters = [
            "AccessKeyId": credentials[0],
            "Action": "TranslateGeneral",
            "Format": "JSON",
            "FormatType": "text",
            "Scene": "general",
            "SignatureMethod": "HMAC-SHA1",
            "SignatureNonce": UUID().uuidString,
            "SignatureVersion": "1.0",
            "SourceLanguage": "auto",
            "SourceText": text,
            "TargetLanguage": aliyunLanguageCode(for: target),
            "Timestamp": formatter.string(from: Date()),
            "Version": "2018-10-12",
        ]
        let canonical = String(data: formEncoded(parameters, sorted: true), encoding: .utf8) ?? ""
        let stringToSign = "POST&%2F&\(rfc3986Encode(canonical))"
        parameters["Signature"] = hmacSHA1(key: credentials[1] + "&", message: stringToSign).base64EncodedString()

        let url = try endpointURL(configuration.endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = formEncoded(parameters, sorted: true)
        let data = try await send(request)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TranslationProviderError.invalidResponse("阿里云未返回 JSON 对象")
        }
        let code = String(describing: object["Code"] ?? "")
        guard code == "200" else {
            throw TranslationProviderError.invalidResponse(
                "阿里云错误 \(code)：\(object["Message"] as? String ?? "未知错误")"
            )
        }
        guard
            let responseData = object["Data"] as? [String: Any],
            let translated = responseData["Translated"] as? String
        else {
            throw TranslationProviderError.invalidResponse("阿里云响应中没有 Data.Translated")
        }
        return try result(text: translated, source: "und", target: target)
    }

    func translateWithTencentCloud(
        text: String,
        target: String,
        configuration: TranslationProviderConfiguration
    ) async throws -> ProviderTranslationResult {
        let credentials = try credentialParts(configuration.apiKey, count: 2, provider: .tencentCloud)
        let url = try endpointURL(configuration.endpoint)
        guard let host = url.host else { throw TranslationProviderError.invalidEndpoint }
        let region = configuration.region.trimmingCharacters(in: .whitespacesAndNewlines)
        let projectID = Int(configuration.systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        let bodyObject: [String: Any] = [
            "SourceText": text,
            "Source": "auto",
            "Target": tencentLanguageCode(for: target),
            "ProjectId": projectID,
        ]
        let body = try JSONSerialization.data(withJSONObject: bodyObject)
        let timestamp = Int(Date().timeIntervalSince1970)
        let date = utcShortDate(fromUnixTimestamp: timestamp)
        let contentType = "application/json; charset=utf-8"
        let signedHeaders = "content-type;host"
        let canonicalHeaders = "content-type:\(contentType)\nhost:\(host)\n"
        let canonicalRequest = [
            "POST",
            "/",
            "",
            canonicalHeaders,
            signedHeaders,
            sha256Hex(body),
        ].joined(separator: "\n")
        let credentialScope = "\(date)/tmt/tc3_request"
        let stringToSign = [
            "TC3-HMAC-SHA256",
            String(timestamp),
            credentialScope,
            sha256Hex(canonicalRequest),
        ].joined(separator: "\n")
        let secretDate = hmacSHA256(key: Data(("TC3" + credentials[1]).utf8), message: date)
        let secretService = hmacSHA256(key: secretDate, message: "tmt")
        let secretSigning = hmacSHA256(key: secretService, message: "tc3_request")
        let signature = hex(hmacSHA256(key: secretSigning, message: stringToSign))
        let authorization =
            "TC3-HMAC-SHA256 Credential=\(credentials[0])/\(credentialScope), "
            + "SignedHeaders=\(signedHeaders), Signature=\(signature)"

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("TextTranslate", forHTTPHeaderField: "X-TC-Action")
        request.setValue("2018-03-21", forHTTPHeaderField: "X-TC-Version")
        request.setValue(String(timestamp), forHTTPHeaderField: "X-TC-Timestamp")
        request.setValue(region.isEmpty ? "ap-shanghai" : region, forHTTPHeaderField: "X-TC-Region")
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        request.httpBody = body
        let data = try await send(request)
        guard
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let response = object["Response"] as? [String: Any]
        else {
            throw TranslationProviderError.invalidResponse("腾讯云未返回 Response")
        }
        if let error = response["Error"] as? [String: Any] {
            throw TranslationProviderError.invalidResponse(
                "腾讯云错误 \(error["Code"] as? String ?? "")：\(error["Message"] as? String ?? "未知错误")"
            )
        }
        guard let translated = response["TargetText"] as? String else {
            throw TranslationProviderError.invalidResponse("腾讯云响应中没有 TargetText")
        }
        return try result(
            text: translated,
            source: response["Source"] as? String ?? "und",
            target: target
        )
    }

    func translateWithVolcanoEngine(
        text: String,
        target: String,
        configuration: TranslationProviderConfiguration
    ) async throws -> ProviderTranslationResult {
        let credentials = try credentialParts(configuration.apiKey, count: 2, provider: .volcanoEngine)
        let url = try endpointURL(configuration.endpoint)
        guard
            let host = url.host,
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else {
            throw TranslationProviderError.invalidEndpoint
        }
        let bodyObject: [String: Any] = [
            "SourceLanguage": "",
            "TargetLanguage": volcanoLanguageCode(for: target),
            "TextList": [text],
        ]
        let body = try JSONSerialization.data(withJSONObject: bodyObject)
        let payloadHash = sha256Hex(body)
        let requestDate = iso8601BasicUTC()
        let shortDate = String(requestDate.prefix(8))
        let regionValue = configuration.region.trimmingCharacters(in: .whitespacesAndNewlines)
        let region = regionValue.isEmpty ? "cn-beijing" : regionValue
        let service = "translate"
        let contentType = "application/json"
        let signedHeaders = "content-type;host;x-content-sha256;x-date"
        let canonicalHeaders = [
            "content-type:\(contentType)",
            "host:\(host)",
            "x-content-sha256:\(payloadHash)",
            "x-date:\(requestDate)",
            "",
        ].joined(separator: "\n")
        let canonicalURI = components.percentEncodedPath.isEmpty ? "/" : components.percentEncodedPath
        let canonicalQuery = queryString(components.queryItems ?? [])
        let canonicalRequest = [
            "POST",
            canonicalURI,
            canonicalQuery,
            canonicalHeaders,
            signedHeaders,
            payloadHash,
        ].joined(separator: "\n")
        let credentialScope = "\(shortDate)/\(region)/\(service)/request"
        let stringToSign = [
            "HMAC-SHA256",
            requestDate,
            credentialScope,
            sha256Hex(canonicalRequest),
        ].joined(separator: "\n")
        let dateKey = hmacSHA256(key: credentials[1], message: shortDate)
        let regionKey = hmacSHA256(key: dateKey, message: region)
        let serviceKey = hmacSHA256(key: regionKey, message: service)
        let signingKey = hmacSHA256(key: serviceKey, message: "request")
        let signature = hex(hmacSHA256(key: signingKey, message: stringToSign))
        let authorization =
            "HMAC-SHA256 Credential=\(credentials[0])/\(credentialScope), "
            + "SignedHeaders=\(signedHeaders), Signature=\(signature)"

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(payloadHash, forHTTPHeaderField: "X-Content-Sha256")
        request.setValue(requestDate, forHTTPHeaderField: "X-Date")
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        request.httpBody = body
        let data = try await send(request)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TranslationProviderError.invalidResponse("火山引擎未返回 JSON 对象")
        }
        let resultObject = object["Result"] as? [String: Any] ?? object
        guard
            let list = resultObject["TranslationList"] as? [[String: Any]],
            let first = list.first,
            let translated = first["Translation"] as? String
        else {
            let metadata = object["ResponseMetadata"] as? [String: Any]
            let error = metadata?["Error"] as? [String: Any]
            throw TranslationProviderError.invalidResponse(
                "火山引擎响应中没有译文：\(error?["Message"] as? String ?? "未知错误")"
            )
        }
        return try result(
            text: translated,
            source: first["DetectedSourceLanguage"] as? String ?? "und",
            target: target
        )
    }

    func translateWithIFlytek(
        text: String,
        target: String,
        configuration: TranslationProviderConfiguration
    ) async throws -> ProviderTranslationResult {
        let credentials = try credentialParts(configuration.apiKey, count: 3, provider: .iFlytek)
        let url = try endpointURL(configuration.endpoint)
        guard let host = url.host else { throw TranslationProviderError.invalidEndpoint }
        let source = iFlytekLanguageCode(for: detectedLanguageIdentifier(for: text))
        let targetCode = iFlytekLanguageCode(for: target)
        let bodyObject: [String: Any] = [
            "common": ["app_id": credentials[0]],
            "business": ["from": source, "to": targetCode],
            "data": ["text": Data(text.utf8).base64EncodedString()],
        ]
        let body = try JSONSerialization.data(withJSONObject: bodyObject)
        let date = rfc1123UTC()
        let digest = "SHA-256=\(sha256Data(body).base64EncodedString())"
        let path = url.path.isEmpty ? "/" : url.path
        let signatureOrigin =
            "host: \(host)\ndate: \(date)\nPOST \(path) HTTP/1.1\ndigest: \(digest)"
        let signature = hmacSHA256(key: credentials[1], message: signatureOrigin).base64EncodedString()
        let authorization =
            "api_key=\"\(credentials[2])\", algorithm=\"hmac-sha256\", "
            + "headers=\"host date request-line digest\", signature=\"\(signature)\""

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json,version=1.0", forHTTPHeaderField: "Accept")
        request.setValue(host, forHTTPHeaderField: "Host")
        request.setValue(date, forHTTPHeaderField: "Date")
        request.setValue(digest, forHTTPHeaderField: "Digest")
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        request.httpBody = body
        let data = try await send(request)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TranslationProviderError.invalidResponse("讯飞未返回 JSON 对象")
        }
        let code = (object["code"] as? NSNumber)?.intValue ?? (object["code"] as? Int) ?? -1
        guard code == 0 else {
            throw TranslationProviderError.invalidResponse(
                "讯飞错误 \(code)：\(object["message"] as? String ?? "未知错误")"
            )
        }
        guard
            let responseData = object["data"] as? [String: Any],
            let translationResult = responseData["result"] as? [String: Any],
            let transResult = translationResult["trans_result"] as? [String: Any],
            let translated = transResult["dst"] as? String
        else {
            throw TranslationProviderError.invalidResponse("讯飞响应中没有 trans_result.dst")
        }
        return try result(
            text: translated,
            source: translationResult["from"] as? String ?? source,
            target: target
        )
    }

    private func utcShortDate(fromUnixTimestamp timestamp: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(timestamp)))
    }

    private func aliyunLanguageCode(for identifier: String) -> String {
        switch identifier {
        case "zh-Hans": "zh"
        case "zh-Hant": "zh-tw"
        default: baseLanguageCode(identifier)
        }
    }

    private func tencentLanguageCode(for identifier: String) -> String {
        switch identifier {
        case "zh-Hans": "zh"
        case "zh-Hant": "zh-TW"
        default: baseLanguageCode(identifier)
        }
    }

    private func volcanoLanguageCode(for identifier: String) -> String {
        switch identifier {
        case "zh-Hans": "zh"
        case "zh-Hant": "zh-Hant"
        default: baseLanguageCode(identifier)
        }
    }

    private func iFlytekLanguageCode(for identifier: String) -> String {
        switch identifier {
        case "zh", "zh-Hans", "zh-CN", "zh-SG": "cn"
        case "zh-Hant", "zh-TW", "zh-HK", "zh-MO": "cht"
        default: baseLanguageCode(identifier)
        }
    }
}
