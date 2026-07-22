import AppKit
import Combine
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var settings: AppSettings
    @State private var accessibilityGranted = SelectionReader.isAccessibilityTrusted
    @State private var screenCaptureGranted = ScreenCaptureService.hasScreenCaptureAccess

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
                Text("翻译使用 Apple Translation，OCR 使用 Vision，均在设备端处理。生词本以 JSON 文件保存在本机，不会上传到 VocabPocket 的服务器。")
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
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            accessibilityGranted = SelectionReader.isAccessibilityTrusted
            screenCaptureGranted = ScreenCaptureService.hasScreenCaptureAccess
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
