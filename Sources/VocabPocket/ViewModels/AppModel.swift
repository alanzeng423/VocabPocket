import AppKit
import Combine
import Foundation

struct PendingTranslation: Identifiable, Equatable {
    let id: UUID
    let sourceText: String
    let targetLanguageIdentifier: String
    let captureMethod: CaptureMethod
    let provider: TranslationProviderKind
}

struct TranslationPopupState: Equatable {
    enum Phase: Equatable {
        case idle
        case readingSelection
        case preparingScreenshot
        case recognizing
        case translating
        case success
        case error
    }

    var phase: Phase = .idle
    var message: String?
    var sourceText: String?
    var translatedText: String?
    var sourceLanguageIdentifier: String?
    var targetLanguageIdentifier: String?
    var captureMethod: CaptureMethod?
    var savedEntryID: UUID?

    static let idle = TranslationPopupState()

    static func progress(_ phase: Phase, message: String, sourceText: String? = nil) -> Self {
        Self(phase: phase, message: message, sourceText: sourceText)
    }

    static func failure(_ message: String) -> Self {
        Self(phase: .error, message: message)
    }
}

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    @Published private(set) var popup: TranslationPopupState = .idle
    @Published private(set) var pendingTranslation: PendingTranslation?
    @Published private(set) var hotKeyError: String?
    @Published private(set) var providerTestMessage: String?
    @Published private(set) var isTestingProvider = false

    let settings: AppSettings
    let store: VocabularyStore

    private let selectionReader: SelectionReader
    private let screenCaptureService: ScreenCaptureService
    private let ocrService: OCRService
    private let hotKeyManager: HotKeyManager
    private let translationClient: TranslationAPIClient
    private var captureTask: Task<Void, Never>?
    private var externalTranslationTask: Task<Void, Never>?
    private var dismissTask: Task<Void, Never>?
    private var hasStarted = false
    private var captureInProgress = false

    init(
        settings: AppSettings? = nil,
        store: VocabularyStore? = nil,
        selectionReader: SelectionReader? = nil,
        screenCaptureService: ScreenCaptureService? = nil,
        ocrService: OCRService = OCRService(),
        hotKeyManager: HotKeyManager? = nil,
        translationClient: TranslationAPIClient = TranslationAPIClient()
    ) {
        self.settings = settings ?? AppSettings()
        self.store = store ?? VocabularyStore()
        self.selectionReader = selectionReader ?? SelectionReader()
        self.screenCaptureService = screenCaptureService ?? ScreenCaptureService()
        self.ocrService = ocrService
        self.hotKeyManager = hotKeyManager ?? HotKeyManager()
        self.translationClient = translationClient
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        hotKeyManager.onPressed = { [weak self] in
            self?.beginCapture()
        }
        updateHotKey()

        if !settings.firstLaunchCompleted {
            SelectionReader.requestAccessibilityAccess()
            settings.firstLaunchCompleted = true
        }
    }

    func stop() {
        captureTask?.cancel()
        externalTranslationTask?.cancel()
        dismissTask?.cancel()
        hotKeyManager.unregister()
    }

    func updateHotKey() {
        do {
            try hotKeyManager.register(settings.hotKey)
            hotKeyError = nil
        } catch {
            hotKeyError = error.localizedDescription
            showFailure(error.localizedDescription)
        }
    }

    func beginCapture(mode: CaptureMode? = nil) {
        guard !captureInProgress, pendingTranslation == nil else { return }
        captureInProgress = true
        captureTask?.cancel()
        captureTask = Task { [weak self] in
            guard let self else { return }
            await self.performCapture(mode: mode ?? self.settings.captureMode)
            self.captureInProgress = false
        }
    }

    func translateManually(_ text: String) {
        guard !captureInProgress, pendingTranslation == nil else { return }
        submitForTranslation(text: text, captureMethod: .manual)
    }

    func completeTranslation(
        requestID: UUID,
        translatedText: String,
        sourceLanguageIdentifier: String,
        targetLanguageIdentifier: String
    ) {
        guard let request = pendingTranslation, request.id == requestID else { return }
        pendingTranslation = nil
        externalTranslationTask = nil

        let entry: VocabularyEntry?
        if settings.autoSave {
            entry = store.addOrUpdate(
                sourceText: request.sourceText,
                translatedText: translatedText,
                sourceLanguageIdentifier: sourceLanguageIdentifier,
                targetLanguageIdentifier: targetLanguageIdentifier,
                captureMethod: request.captureMethod
            )
        } else {
            entry = nil
        }

        popup = TranslationPopupState(
            phase: .success,
            message: entry == nil ? "翻译完成" : "已加入生词本",
            sourceText: request.sourceText,
            translatedText: translatedText,
            sourceLanguageIdentifier: sourceLanguageIdentifier,
            targetLanguageIdentifier: targetLanguageIdentifier,
            captureMethod: request.captureMethod,
            savedEntryID: entry?.id
        )
        scheduleDismiss(after: 12)
    }

    func translationFailed(requestID: UUID, error: Error) {
        guard pendingTranslation?.id == requestID else { return }
        pendingTranslation = nil
        externalTranslationTask = nil
        showFailure("翻译失败：\(error.localizedDescription)")
    }

    func saveCurrentTranslation() {
        guard
            popup.phase == .success,
            popup.savedEntryID == nil,
            let sourceText = popup.sourceText,
            let translatedText = popup.translatedText,
            let sourceLanguageIdentifier = popup.sourceLanguageIdentifier,
            let targetLanguageIdentifier = popup.targetLanguageIdentifier,
            let captureMethod = popup.captureMethod
        else {
            return
        }

        let entry = store.addOrUpdate(
            sourceText: sourceText,
            translatedText: translatedText,
            sourceLanguageIdentifier: sourceLanguageIdentifier,
            targetLanguageIdentifier: targetLanguageIdentifier,
            captureMethod: captureMethod
        )
        popup.savedEntryID = entry.id
        popup.message = "已加入生词本"
    }

    func copyTranslation() {
        guard let translatedText = popup.translatedText else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(translatedText, forType: .string)
        popup.message = "译文已复制"
        scheduleDismiss(after: 3)
    }

    func dismissPopup() {
        dismissTask?.cancel()
        if pendingTranslation != nil {
            externalTranslationTask?.cancel()
            externalTranslationTask = nil
            pendingTranslation = nil
        }
        popup = .idle
    }

    func testSelectedTranslationProvider() async {
        let provider = settings.translationProvider
        guard provider.usesRemoteService else {
            providerTestMessage = "Apple Translation 无需 API 配置，请直接使用快捷翻译测试。"
            return
        }

        isTestingProvider = true
        providerTestMessage = nil
        defer { isTestingProvider = false }

        do {
            let configuration = try settings.configuration(for: provider)
            let result = try await translationClient.translate(
                text: "Hello, world!",
                targetLanguageIdentifier: settings.targetLanguage.rawValue,
                configuration: configuration
            )
            providerTestMessage = "连接成功：\(result.translatedText)"
        } catch {
            providerTestMessage = "测试失败：\(error.localizedDescription)"
        }
    }

    func clearProviderTestMessage() {
        providerTestMessage = nil
    }

    private func performCapture(mode: CaptureMode) async {
        dismissTask?.cancel()
        var text: String?
        var captureMethod = CaptureMethod.selectedText

        if mode != .ocr {
            popup = .progress(.readingSelection, message: "正在读取选中文字…")
            text = await selectionReader.readSelectedText()
        }

        if text == nil {
            if mode == .selectedText {
                let permissionHint =
                    SelectionReader.isAccessibilityTrusted
                    ? "请先在其他应用中选中一段文字"
                    : "请先在系统设置中授予“辅助功能”权限"
                showFailure(permissionHint)
                return
            }

            captureMethod = .ocr
            popup = .progress(.preparingScreenshot, message: "请拖拽框选图片中的文字")
            try? await Task.sleep(nanoseconds: 550_000_000)
            guard !Task.isCancelled else { return }

            // Keep the floating translation panel out of the captured image.
            popup = .idle

            do {
                guard let imageData = try await screenCaptureService.captureSelection() else {
                    popup = .idle
                    return
                }
                popup = .progress(.recognizing, message: "正在识别图片文字…")
                text = try await ocrService.recognizeText(in: imageData)
            } catch {
                showFailure(error.localizedDescription)
                return
            }
        }

        guard let text else {
            showFailure("没有读取到可翻译的内容")
            return
        }
        submitForTranslation(text: text, captureMethod: captureMethod)
    }

    private func submitForTranslation(text: String, captureMethod: CaptureMethod) {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            showFailure("没有可翻译的文字")
            return
        }

        let request = PendingTranslation(
            id: UUID(),
            sourceText: String(cleaned.prefix(8_000)),
            targetLanguageIdentifier: settings.targetLanguage.rawValue,
            captureMethod: captureMethod,
            provider: settings.translationProvider
        )
        pendingTranslation = request
        popup = .progress(
            .translating,
            message: request.provider.progressMessage,
            sourceText: request.sourceText
        )

        if request.provider.usesRemoteService {
            translateUsingExternalProvider(request)
        }
    }

    private func translateUsingExternalProvider(_ request: PendingTranslation) {
        externalTranslationTask?.cancel()
        externalTranslationTask = Task { [weak self] in
            guard let self else { return }
            do {
                let configuration = try self.settings.configuration(for: request.provider)
                let result = try await self.translationClient.translate(
                    text: request.sourceText,
                    targetLanguageIdentifier: request.targetLanguageIdentifier,
                    configuration: configuration
                )
                guard !Task.isCancelled else { return }
                self.completeTranslation(
                    requestID: request.id,
                    translatedText: result.translatedText,
                    sourceLanguageIdentifier: result.sourceLanguageIdentifier,
                    targetLanguageIdentifier: result.targetLanguageIdentifier
                )
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                self.translationFailed(requestID: request.id, error: error)
            }
        }
    }

    private func showFailure(_ message: String) {
        externalTranslationTask?.cancel()
        externalTranslationTask = nil
        pendingTranslation = nil
        popup = .failure(message)
        scheduleDismiss(after: 10)
    }

    private func scheduleDismiss(after seconds: UInt64) {
        dismissTask?.cancel()
        let expectedPhase = popup.phase
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)
            guard !Task.isCancelled, self?.popup.phase == expectedPhase else { return }
            self?.popup = .idle
        }
    }
}
