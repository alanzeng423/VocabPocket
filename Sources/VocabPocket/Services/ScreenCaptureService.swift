import CoreGraphics
import Foundation

enum ScreenCaptureError: LocalizedError {
    case launchFailed(String)
    case captureFailed(Int32)
    case permissionRequired
    case emptyCapture

    var errorDescription: String? {
        switch self {
        case .launchFailed(let message): "无法启动系统截图：\(message)"
        case .captureFailed(let status): "系统截图失败（状态码 \(status)）"
        case .permissionRequired:
            "截图 OCR 需要“屏幕录制”权限；请在系统设置中授权 VocabPocket 后再试"
        case .emptyCapture:
            "没有获得有效截图，请重新框选文字区域"
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
        if !Self.hasScreenCaptureAccess, !Self.requestScreenCaptureAccess() {
            throw ScreenCaptureError.permissionRequired
        }

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
        let data = try Data(contentsOf: destination)
        guard !data.isEmpty else { throw ScreenCaptureError.emptyCapture }
        return data
    }
}
