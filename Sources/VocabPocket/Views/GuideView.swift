import AppKit
import Combine
import SwiftUI

struct GuideView: View {
    @ObservedObject var model: AppModel
    @State private var accessibilityGranted = SelectionReader.isAccessibilityTrusted
    @State private var screenCaptureGranted = ScreenCaptureService.hasScreenCaptureAccess

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("三步开始积累生词")
                        .font(.largeTitle.bold())
                    Text("翻译和 OCR 均由 macOS 在设备端完成。")
                        .foregroundStyle(.secondary)
                }

                HStack(alignment: .top, spacing: 14) {
                    stepCard(number: 1, title: "选中内容", detail: "可选中文字；图片或不可选文字会进入截图模式。", icon: "text.cursor")
                    stepCard(
                        number: 2, title: "按下快捷键", detail: "默认是 \(model.settings.hotKey.title)，可在设置中切换。",
                        icon: "command")
                    stepCard(
                        number: 3, title: "自动保存", detail: "译文弹出后，生词会进入生词本和复习队列。", icon: "character.book.closed.fill")
                }

                GroupBox("系统权限") {
                    VStack(spacing: 14) {
                        permissionRow(
                            title: "辅助功能",
                            detail: "读取当前选中的文字，并兼容不直接暴露选区的应用。",
                            granted: accessibilityGranted,
                            actionTitle: "请求权限"
                        ) {
                            accessibilityGranted = SelectionReader.requestAccessibilityAccess()
                        }
                        Divider()
                        permissionRow(
                            title: "屏幕录制",
                            detail: "仅用于你主动框选的区域；截图识别完成后会立即删除临时文件。",
                            granted: screenCaptureGranted,
                            actionTitle: "请求权限"
                        ) {
                            screenCaptureGranted = ScreenCaptureService.requestScreenCaptureAccess()
                        }
                    }
                    .padding(8)
                }

                HStack {
                    Button("试试选中文字") {
                        model.beginCapture(mode: .selectedText)
                    }
                    .buttonStyle(.borderedProminent)
                    Button("试试截图 OCR") {
                        model.beginCapture(mode: .ocr)
                    }
                    Button("打开隐私设置") {
                        openPrivacySettings()
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: 900, alignment: .leading)
        }
        .navigationTitle("使用指南")
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            accessibilityGranted = SelectionReader.isAccessibilityTrusted
            screenCaptureGranted = ScreenCaptureService.hasScreenCaptureAccess
        }
    }

    private func stepCard(number: Int, title: String, detail: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                Spacer()
                Text("\(number)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .padding(7)
                    .background(.quaternary, in: Circle())
            }
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
    }

    private func permissionRow(
        title: String,
        detail: String,
        granted: Bool,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(granted ? .green : .orange)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(granted ? "已授权" : "未授权")
                .font(.caption.weight(.semibold))
                .foregroundStyle(granted ? .green : .orange)
            if !granted {
                Button(actionTitle, action: action)
            }
        }
    }

    private func openPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        else { return }
        NSWorkspace.shared.open(url)
    }
}
