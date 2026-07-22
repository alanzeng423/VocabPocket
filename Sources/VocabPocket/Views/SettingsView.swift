import AppKit
import Combine
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var settings: AppSettings
    @State private var accessibilityGranted = SelectionReader.isAccessibilityTrusted
    @State private var screenCaptureGranted = ScreenCaptureService.hasScreenCaptureAccess
    @State private var apiKeyDraft = ""
    @State private var credentialMessage: String?

    init(model: AppModel) {
        self.model = model
        _settings = ObservedObject(wrappedValue: model.settings)
    }

    var body: some View {
        Form {
            Section("快捷翻译") {
                Picker("全局快捷键", selection: $settings.hotKey) {
                    ForEach(HotKeyPreset.allCases) { preset in
                        Text(preset.title).tag(preset)
                    }
                }
                .onChange(of: settings.hotKey) { _, _ in model.updateHotKey() }

                Picker("取词方式", selection: $settings.captureMode) {
                    ForEach(CaptureMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }

                Picker("翻译为", selection: $settings.targetLanguage) {
                    ForEach(TargetLanguage.allCases) { language in
                        Text(language.title).tag(language)
                    }
                }

                Toggle("翻译成功后自动加入生词本", isOn: $settings.autoSave)
            }

            Section("翻译引擎") {
                Picker("Provider", selection: $settings.translationProvider) {
                    ForEach(TranslationProviderKind.allCases) { provider in
                        Text(provider.title).tag(provider)
                    }
                }

                Text(settings.translationProvider.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if settings.translationProvider.usesRemoteService {
                    providerConfiguration
                } else {
                    Label("无需 API Key 或网络请求", systemImage: "lock.shield.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            Section("系统权限") {
                HStack {
                    Label("辅助功能", systemImage: "cursorarrow.motionlines")
                    Spacer()
                    permissionStatus(accessibilityGranted)
                    Button(accessibilityGranted ? "打开设置" : "授权") {
                        if accessibilityGranted {
                            openPrivacySettings("Privacy_Accessibility")
                        } else {
                            accessibilityGranted = SelectionReader.requestAccessibilityAccess()
                        }
                    }
                }

                HStack {
                    Label("屏幕录制", systemImage: "rectangle.dashed.badge.record")
                    Spacer()
                    permissionStatus(screenCaptureGranted)
                    Button(screenCaptureGranted ? "打开设置" : "授权") {
                        if screenCaptureGranted {
                            openPrivacySettings("Privacy_ScreenCapture")
                        } else {
                            screenCaptureGranted = ScreenCaptureService.requestScreenCaptureAccess()
                        }
                    }
                }
            }

            Section("隐私") {
                privacyDescription
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if let hotKeyError = model.hotKeyError {
                Text(hotKeyError)
                    .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .padding(12)
        .onChange(of: settings.translationProvider) { _, _ in
            apiKeyDraft = ""
            credentialMessage = nil
            model.clearProviderTestMessage()
        }
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            accessibilityGranted = SelectionReader.isAccessibilityTrusted
            screenCaptureGranted = ScreenCaptureService.hasScreenCaptureAccess
        }
    }

    @ViewBuilder
    private var providerConfiguration: some View {
        let provider = settings.translationProvider

        TextField("接口地址", text: preferenceBinding(\.endpoint, provider: provider))
            .textFieldStyle(.roundedBorder)

        if provider == .microsoft {
            TextField("Azure Region（部分资源必填）", text: preferenceBinding(\.region, provider: provider))
                .textFieldStyle(.roundedBorder)
        }

        if provider.isLLM {
            TextField("模型名称", text: preferenceBinding(\.model, provider: provider))
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 6) {
                Text("系统提示词")
                    .font(.caption.weight(.semibold))
                TextEditor(text: preferenceBinding(\.systemPrompt, provider: provider))
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 82)
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    }
                Text("可使用 {target_language} 和 {target_language_code} 占位符。")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }

        VStack(alignment: .leading, spacing: 7) {
            SecureField(
                provider == .openAICompatible ? "API Key（本地服务可留空）" : "API Key",
                text: $apiKeyDraft
            )
            .textFieldStyle(.roundedBorder)

            HStack(spacing: 10) {
                Label(
                    apiKeyStatus(provider),
                    systemImage: settings.hasAPIKey(for: provider) ? "key.fill" : "key"
                )
                .font(.caption)
                .foregroundStyle(settings.hasAPIKey(for: provider) ? .green : .secondary)

                Spacer()

                if settings.hasAPIKey(for: provider) {
                    Button("删除密钥", role: .destructive) {
                        removeAPIKey(for: provider)
                    }
                }
                Button("保存密钥") {
                    saveAPIKey(for: provider)
                }
                .disabled(apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }

        HStack {
            if let documentationURL = provider.documentationURL {
                Link("查看接口文档", destination: documentationURL)
                    .font(.caption)
            }
            Spacer()
            Button("恢复默认配置") {
                settings.resetPreferences(for: provider)
                model.clearProviderTestMessage()
            }
            Button {
                Task { await model.testSelectedTranslationProvider() }
            } label: {
                if model.isTestingProvider {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("测试配置")
                }
            }
            .disabled(model.isTestingProvider)
        }

        if let credentialMessage {
            Text(credentialMessage)
                .font(.caption)
                .foregroundStyle(credentialMessage.hasPrefix("已") ? .green : .red)
        }
        if let message = model.providerTestMessage {
            Text(message)
                .font(.caption)
                .foregroundStyle(message.hasPrefix("连接成功") ? .green : .red)
                .textSelection(.enabled)
        }
    }

    private var privacyDescription: Text {
        if settings.translationProvider == .apple {
            return Text("翻译使用 Apple Translation，OCR 使用 Vision，均在设备端处理。生词本以 JSON 文件保存在本机。")
        }
        return Text(
            "OCR 始终由 Vision 在设备端完成；只会把识别后的文字发送到你配置的 \(settings.translationProvider.title) 接口。API Key 保存在 macOS 钥匙串，VocabPocket 没有中转服务器。"
        )
    }

    private func preferenceBinding(
        _ keyPath: WritableKeyPath<TranslationProviderPreferences, String>,
        provider: TranslationProviderKind
    ) -> Binding<String> {
        Binding(
            get: { settings.preferences(for: provider)[keyPath: keyPath] },
            set: {
                settings.updatePreference(for: provider, keyPath, to: $0)
                model.clearProviderTestMessage()
            }
        )
    }

    private func apiKeyStatus(_ provider: TranslationProviderKind) -> String {
        if settings.hasAPIKey(for: provider) { return "密钥已安全保存在钥匙串" }
        if provider.requiresAPIKey { return "尚未保存密钥" }
        return "未保存密钥；本地兼容服务可直接使用"
    }

    private func saveAPIKey(for provider: TranslationProviderKind) {
        do {
            try settings.saveAPIKey(apiKeyDraft, for: provider)
            apiKeyDraft = ""
            credentialMessage = "已保存到 macOS 钥匙串"
            model.clearProviderTestMessage()
        } catch {
            credentialMessage = error.localizedDescription
        }
    }

    private func removeAPIKey(for provider: TranslationProviderKind) {
        do {
            try settings.removeAPIKey(for: provider)
            apiKeyDraft = ""
            credentialMessage = "已从 macOS 钥匙串删除"
            model.clearProviderTestMessage()
        } catch {
            credentialMessage = error.localizedDescription
        }
    }

    private func permissionStatus(_ granted: Bool) -> some View {
        Text(granted ? "已授权" : "未授权")
            .font(.caption.weight(.semibold))
            .foregroundStyle(granted ? .green : .orange)
    }

    private func openPrivacySettings(_ pane: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") else { return }
        NSWorkspace.shared.open(url)
    }
}
