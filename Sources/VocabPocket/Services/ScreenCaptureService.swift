import CoreGraphics
import Foundation

enum ScreenCaptureError: LocalizedError {
    case launchFailed(String)
    case captureFailed(Int32)

    var errorDescription: String? {
        switch self {
        case .launchFailed(let message): "无法启动系统截图：\(message)"
        case .captureFailed(let status): "系统截图失败（状态码 \(status)）"
        }
    }
}

@MainActor
final class ScreenCaptureService {
    static var hasScreenCaptureAccess: Bool {
        CGPreflightScreenCaptureAccess()
    }

    @discardableResult
    static func requestScreenCaptureAccess() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    /// Opens the native macOS crosshair UI. A nil result means the user pressed Escape.
    func captureSelection() async throws -> Data? {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("VocabPocket", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let destination = directory.appendingPathComponent("\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: destination) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", "-s", "-x", destination.path]

        let status: Int32 = try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { completedProcess in
                continuation.resume(returning: completedProcess.terminationStatus)
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: ScreenCaptureError.launchFailed(error.localizedDescription))
            }
        }

        if status != 0 && status != 1 {
            throw ScreenCaptureError.captureFailed(status)
        }

        guard FileManager.default.fileExists(atPath: destination.path) else { return nil }
        return try Data(contentsOf: destination)
    }
}
