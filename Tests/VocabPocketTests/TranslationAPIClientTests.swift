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
            let body = try XCTUnwrap(request.httpBody)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(json["target_lang"] as? String, "ZH-HANS")
            XCTAssertEqual(json["text"] as? [String], ["hello"])
            return Self.response(
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
            let body = try XCTUnwrap(request.httpBody)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(json["target"] as? String, "zh-TW")
            return Self.response(
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
            return Self.response(
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
            let body = try XCTUnwrap(request.httpBody)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(json["model"] as? String, "local-model")
            let messages = try XCTUnwrap(json["messages"] as? [[String: Any]])
            XCTAssertTrue((messages.first?["content"] as? String)?.contains("简体中文") == true)
            return Self.response(
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
            return Self.response(
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
