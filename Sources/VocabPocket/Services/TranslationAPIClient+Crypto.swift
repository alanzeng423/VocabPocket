import CryptoKit
import Foundation

extension TranslationAPIClient {
    func credentialParts(
        _ value: String,
        count: Int,
        provider: TranslationProviderKind
    ) throws -> [String] {
        let parts = value.split(separator: "#", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == count, parts.allSatisfy({ !$0.isEmpty }) else {
            throw TranslationProviderError.invalidResponse(
                "\(provider.title) 的凭证格式应为 \(provider.credentialLabel)"
            )
        }
        return parts
    }

    func sha256Data(_ data: Data) -> Data {
        Data(SHA256.hash(data: data))
    }

    func sha256Hex(_ data: Data) -> String {
        hex(sha256Data(data))
    }

    func sha256Hex(_ value: String) -> String {
        sha256Hex(Data(value.utf8))
    }

    func md5Hex(_ value: String) -> String {
        hex(Data(Insecure.MD5.hash(data: Data(value.utf8))))
    }

    func hmacSHA256(key: Data, message: Data) -> Data {
        let authentication = HMAC<SHA256>.authenticationCode(
            for: message,
            using: SymmetricKey(data: key)
        )
        return Data(authentication)
    }

    func hmacSHA256(key: Data, message: String) -> Data {
        hmacSHA256(key: key, message: Data(message.utf8))
    }

    func hmacSHA256(key: String, message: String) -> Data {
        hmacSHA256(key: Data(key.utf8), message: Data(message.utf8))
    }

    func hmacSHA1(key: String, message: String) -> Data {
        let authentication = HMAC<Insecure.SHA1>.authenticationCode(
            for: Data(message.utf8),
            using: SymmetricKey(data: Data(key.utf8))
        )
        return Data(authentication)
    }

    func hex(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    func rfc3986Encode(_ value: String) -> String {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    func formEncoded(_ parameters: [String: String], sorted: Bool = false) -> Data {
        let keys = sorted ? parameters.keys.sorted() : Array(parameters.keys)
        let body = keys.map { "\(rfc3986Encode($0))=\(rfc3986Encode(parameters[$0] ?? ""))" }
            .joined(separator: "&")
        return Data(body.utf8)
    }

    func queryString(_ items: [URLQueryItem]) -> String {
        items.sorted { lhs, rhs in
            lhs.name == rhs.name ? (lhs.value ?? "") < (rhs.value ?? "") : lhs.name < rhs.name
        }.map { "\(rfc3986Encode($0.name))=\(rfc3986Encode($0.value ?? ""))" }
            .joined(separator: "&")
    }

    func iso8601BasicUTC(_ date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return formatter.string(from: date)
    }

    func rfc1123UTC(_ date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        return formatter.string(from: date)
    }
}
