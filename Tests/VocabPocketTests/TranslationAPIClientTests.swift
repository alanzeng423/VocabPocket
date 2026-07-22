import Foundation
import XCTest

@testable import VocabPocket

final class TranslationAPIClientTests: XCTestCase {
    private var session: URLSession!
    private var client: TranslationAPIClient!

    override func setUp() {
        super.setUp()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: configuration)
        client = TranslationAPIClient(session: session)
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        session.invalidateAndCancel()
        client = nil
        session = nil
        super.tearDown()
    }

    func testDeepLUsesAuthorizationHeaderAndLanguageMapping() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "DeepL-Auth-Key secret")
            let body = try Self.bodyData(from: request)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(json["target_lang"] as? String, "ZH-HANS")
            XCTAssertEqual(json["text"] as? [String], ["hello"])
            return try Self.response(
                for: request,
                json: #"{"translations":[{"detected_source_language":"EN","text":"你好"}]}"#
            )
        }

        let result = try await client.translate(
            text: "hello",
            targetLanguageIdentifier: "zh-Hans",
            configuration: configuration(provider: .deepL)
        )

        XCTAssertEqual(result.translatedText, "你好")
        XCTAssertEqual(result.sourceLanguageIdentifier, "en")
    }

    func testGooglePlacesKeyInQueryAndDecodesEntities() async throws {
        MockURLProtocol.requestHandler = { request in
            let components = try XCTUnwrap(
                URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
            XCTAssertEqual(components.queryItems?.first(where: { $0.name == "key" })?.value, "secret")
            let body = try Self.bodyData(from: request)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(json["target"] as? String, "zh-TW")
            return try Self.response(
                for: request,
                json: #"{"data":{"translations":[{"translatedText":"Tom &amp; Jerry","detectedSourceLanguage":"en"}]}}"#
            )
        }

        let result = try await client.translate(
            text: "Tom and Jerry",
            targetLanguageIdentifier: "zh-Hant",
            configuration: configuration(provider: .googleCloud)
        )

        XCTAssertEqual(result.translatedText, "Tom & Jerry")
    }

    func testMicrosoftSendsRegionAndVersion() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Ocp-Apim-Subscription-Key"), "secret")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Ocp-Apim-Subscription-Region"), "eastasia")
            let components = try XCTUnwrap(
                URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
            XCTAssertEqual(components.queryItems?.first(where: { $0.name == "api-version" })?.value, "3.0")
            XCTAssertEqual(components.queryItems?.first(where: { $0.name == "to" })?.value, "ja")
            return try Self.response(
                for: request,
                json: #"[{"detectedLanguage":{"language":"en"},"translations":[{"text":"こんにちは","to":"ja"}]}]"#
            )
        }

        var configuration = configuration(provider: .microsoft)
        configuration = TranslationProviderConfiguration(
            provider: configuration.provider,
            endpoint: configuration.endpoint,
            apiKey: configuration.apiKey,
            model: configuration.model,
            systemPrompt: configuration.systemPrompt,
            region: "eastasia"
        )
        let result = try await client.translate(
            text: "hello",
            targetLanguageIdentifier: "ja",
            configuration: configuration
        )

        XCTAssertEqual(result.translatedText, "こんにちは")
        XCTAssertEqual(result.sourceLanguageIdentifier, "en")
    }

    func testOpenAICompatibleAppendsPathAndAllowsLocalServerWithoutKey() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/v1/chat/completions")
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            let body = try Self.bodyData(from: request)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(json["model"] as? String, "local-model")
            let messages = try XCTUnwrap(json["messages"] as? [[String: Any]])
            XCTAssertTrue((messages.first?["content"] as? String)?.contains("简体中文") == true)
            return try Self.response(
                for: request,
                json: #"{"choices":[{"message":{"content":"本地译文"}}]}"#
            )
        }

        let configuration = TranslationProviderConfiguration(
            provider: .openAICompatible,
            endpoint: "http://localhost:11434/v1",
            apiKey: "",
            model: "local-model",
            systemPrompt: TranslationProviderPreferences.defaultLLMPrompt,
            region: ""
        )
        let result = try await client.translate(
            text: "local translation",
            targetLanguageIdentifier: "zh-Hans",
            configuration: configuration
        )

        XCTAssertEqual(result.translatedText, "本地译文")
    }

    func testAnthropicRequestAndResponse() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), "secret")
            XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
            return try Self.response(
                for: request,
                json: #"{"content":[{"type":"text","text":"Claude 译文"}]}"#
            )
        }

        let result = try await client.translate(
            text: "translation",
            targetLanguageIdentifier: "zh-Hans",
            configuration: configuration(provider: .anthropic)
        )

        XCTAssertEqual(result.translatedText, "Claude 译文")
    }

    func testEveryRemoteProviderHasAValidDefaultEndpoint() throws {
        XCTAssertEqual(TranslationProviderKind.allCases.count, 29)
        for provider in TranslationProviderKind.allCases where provider.usesRemoteService {
            let preferences = TranslationProviderPreferences.defaults(for: provider)
            let url = try XCTUnwrap(URL(string: preferences.endpoint), provider.title)
            XCTAssertNotNil(url.scheme, provider.title)
            XCTAssertNotNil(url.host, provider.title)
            if provider.requiresModel {
                XCTAssertFalse(preferences.model.isEmpty, provider.title)
            }
        }
    }

    func testGoogleFreeParsesSegmentedResponse() async throws {
        MockURLProtocol.requestHandler = { request in
            let components = try XCTUnwrap(
                URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
            XCTAssertEqual(components.queryItems?.first(where: { $0.name == "client" })?.value, "gtx")
            XCTAssertEqual(components.queryItems?.first(where: { $0.name == "sl" })?.value, "auto")
            XCTAssertEqual(components.queryItems?.first(where: { $0.name == "tl" })?.value, "zh-CN")
            return try Self.response(
                for: request,
                json: #"[[["你","you",null,null],["好","good",null,null]],null,"en"]"#
            )
        }

        let result = try await client.translate(
            text: "you good",
            targetLanguageIdentifier: "zh-Hans",
            configuration: configuration(provider: .googleFree)
        )

        XCTAssertEqual(result.translatedText, "你好")
        XCTAssertEqual(result.sourceLanguageIdentifier, "en")
    }

    func testLibreTranslateAppendsPathAndAllowsOptionalKey() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/translate")
            let body = try Self.bodyData(from: request)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(json["source"] as? String, "auto")
            XCTAssertEqual(json["target"] as? String, "ja")
            XCTAssertEqual(json["api_key"] as? String, "secret")
            return try Self.response(
                for: request,
                json: #"{"translatedText":"こんにちは","detectedLanguage":{"language":"en"}}"#
            )
        }

        var configuration = configuration(provider: .libreTranslate)
        configuration = TranslationProviderConfiguration(
            provider: .libreTranslate,
            endpoint: "http://localhost:5000",
            apiKey: "secret",
            model: configuration.model,
            systemPrompt: configuration.systemPrompt,
            region: configuration.region
        )
        let result = try await client.translate(
            text: "hello",
            targetLanguageIdentifier: "ja",
            configuration: configuration
        )

        XCTAssertEqual(result.translatedText, "こんにちは")
        XCTAssertEqual(result.sourceLanguageIdentifier, "en")
    }

    func testGeminiBuildsGenerateContentRequest() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/v1beta/models/gemini-test:generateContent")
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-goog-api-key"), "secret")
            let body = try Self.bodyData(from: request)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertNotNil(json["system_instruction"])
            return try Self.response(
                for: request,
                json: #"{"candidates":[{"content":{"parts":[{"text":"Gemini 译文"}]}}]}"#
            )
        }

        let configuration = TranslationProviderConfiguration(
            provider: .gemini,
            endpoint: "https://generativelanguage.googleapis.com/v1beta",
            apiKey: "secret",
            model: "gemini-test",
            systemPrompt: TranslationProviderPreferences.defaultLLMPrompt,
            region: ""
        )
        let result = try await client.translate(
            text: "hello",
            targetLanguageIdentifier: "zh-Hans",
            configuration: configuration
        )

        XCTAssertEqual(result.translatedText, "Gemini 译文")
    }

    func testQwenMTSendsTranslationOptions() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer secret")
            let body = try Self.bodyData(from: request)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let options = try XCTUnwrap(json["translation_options"] as? [String: Any])
            XCTAssertEqual(options["source_lang"] as? String, "auto")
            XCTAssertEqual(options["target_lang"] as? String, "Traditional Chinese")
            XCTAssertEqual(options["domains"] as? String, "software")
            return try Self.response(
                for: request,
                json: #"{"choices":[{"message":{"content":"千问译文"}}]}"#
            )
        }

        let configuration = TranslationProviderConfiguration(
            provider: .qwenMT,
            endpoint: "https://dashscope.aliyuncs.com/compatible-mode",
            apiKey: "secret",
            model: "qwen-mt-plus",
            systemPrompt: "software",
            region: ""
        )
        let result = try await client.translate(
            text: "hello",
            targetLanguageIdentifier: "zh-Hant",
            configuration: configuration
        )

        XCTAssertEqual(result.translatedText, "千问译文")
    }

    func testBaiduSignsFormRequest() async throws {
        MockURLProtocol.requestHandler = { request in
            let parameters = try Self.formParameters(from: request)
            XCTAssertEqual(parameters["appid"], "app-id")
            XCTAssertEqual(parameters["from"], "auto")
            XCTAssertEqual(parameters["to"], "cht")
            XCTAssertEqual(parameters["q"], "hello")
            XCTAssertEqual(parameters["sign"]?.count, 32)
            return try Self.response(
                for: request,
                json: #"{"from":"en","to":"cht","trans_result":[{"src":"hello","dst":"您好"}]}"#
            )
        }

        var configuration = configuration(provider: .baidu)
        configuration = TranslationProviderConfiguration(
            provider: .baidu,
            endpoint: configuration.endpoint,
            apiKey: "app-id#app-secret",
            model: "",
            systemPrompt: "",
            region: ""
        )
        let result = try await client.translate(
            text: "hello",
            targetLanguageIdentifier: "zh-Hant",
            configuration: configuration
        )

        XCTAssertEqual(result.translatedText, "您好")
        XCTAssertEqual(result.sourceLanguageIdentifier, "en")
    }

    func testTencentCloudUsesV3SignatureHeaders() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-TC-Action"), "TextTranslate")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-TC-Version"), "2018-03-21")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-TC-Region"), "ap-shanghai")
            XCTAssertTrue(
                request.value(forHTTPHeaderField: "Authorization")?.hasPrefix("TC3-HMAC-SHA256 ") == true
            )
            return try Self.response(
                for: request,
                json: #"{"Response":{"TargetText":"腾讯译文","Source":"en","RequestId":"id"}}"#
            )
        }

        var configuration = configuration(provider: .tencentCloud)
        configuration = TranslationProviderConfiguration(
            provider: .tencentCloud,
            endpoint: configuration.endpoint,
            apiKey: "secret-id#secret-key",
            model: "",
            systemPrompt: "0",
            region: "ap-shanghai"
        )
        let result = try await client.translate(
            text: "hello",
            targetLanguageIdentifier: "zh-Hans",
            configuration: configuration
        )

        XCTAssertEqual(result.translatedText, "腾讯译文")
    }

    func testVolcanoEngineUsesSignedRequest() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertNotNil(request.value(forHTTPHeaderField: "X-Date"))
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Content-Sha256")?.count, 64)
            XCTAssertTrue(
                request.value(forHTTPHeaderField: "Authorization")?.hasPrefix("HMAC-SHA256 ") == true
            )
            return try Self.response(
                for: request,
                json: #"{"Result":{"TranslationList":[{"DetectedSourceLanguage":"en","Translation":"火山译文"}]}}"#
            )
        }

        var configuration = configuration(provider: .volcanoEngine)
        configuration = TranslationProviderConfiguration(
            provider: .volcanoEngine,
            endpoint: configuration.endpoint,
            apiKey: "access-key#secret-key",
            model: "",
            systemPrompt: "",
            region: "cn-beijing"
        )
        let result = try await client.translate(
            text: "hello",
            targetLanguageIdentifier: "zh-Hans",
            configuration: configuration
        )

        XCTAssertEqual(result.translatedText, "火山译文")
    }

    func testServerErrorUsesProviderMessage() async {
        MockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(
                HTTPURLResponse(
                    url: url,
                    statusCode: 401,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )
            )
            return (response, Data(#"{"error":{"message":"invalid credential"}}"#.utf8))
        }

        do {
            _ = try await client.translate(
                text: "hello",
                targetLanguageIdentifier: "zh-Hans",
                configuration: configuration(provider: .deepL)
            )
            XCTFail("Expected a server error")
        } catch let error as TranslationProviderError {
            XCTAssertEqual(error, .server(statusCode: 401, message: "invalid credential"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func configuration(provider: TranslationProviderKind) -> TranslationProviderConfiguration {
        let preferences = TranslationProviderPreferences.defaults(for: provider)
        return TranslationProviderConfiguration(
            provider: provider,
            endpoint: preferences.endpoint,
            apiKey: "secret",
            model: preferences.model,
            systemPrompt: preferences.systemPrompt,
            region: preferences.region
        )
    }

    private static func response(
        for request: URLRequest,
        json: String
    ) throws -> (HTTPURLResponse, Data) {
        let response = try XCTUnwrap(
            HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )
        )
        return (response, Data(json.utf8))
    }

    private static func bodyData(from request: URLRequest) throws -> Data {
        if let body = request.httpBody { return body }
        let stream = try XCTUnwrap(request.httpBodyStream)
        stream.open()
        defer { stream.close() }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4_096)
        while true {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count == 0 { break }
            if count < 0 {
                throw stream.streamError ?? URLError(.cannotDecodeRawData)
            }
            data.append(contentsOf: buffer.prefix(count))
        }
        return data
    }

    private static func formParameters(from request: URLRequest) throws -> [String: String] {
        let body = try bodyData(from: request)
        let value = try XCTUnwrap(String(data: body, encoding: .utf8))
        let components = try XCTUnwrap(URLComponents(string: "https://example.invalid/?\(value)"))
        return Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") }
        )
    }
}

private final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
