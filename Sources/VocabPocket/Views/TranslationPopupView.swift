import SwiftUI

struct TranslationPopupView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            switch model.popup.phase {
            case .idle:
                EmptyView()
            case .readingSelection, .preparingScreenshot, .recognizing, .translating:
                progressContent
            case .success:
                successContent
            case .error:
                errorContent
            }
        }
        .padding(16)
        .frame(width: 400, height: 250, alignment: .topLeading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: headerIcon)
                .foregroundStyle(headerColor)
            Text(headerTitle)
                .font(.headline)
            Spacer()
            Button {
                model.dismissPopup()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("关闭")
        }
    }

    private var progressContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ProgressView()
                    .controlSize(.small)
                Text(model.popup.message ?? "处理中…")
                    .foregroundStyle(.secondary)
            }

            if let source = model.popup.sourceText {
                Text(source)
                    .font(.body)
                    .lineLimit(4)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var successContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.popup.sourceText ?? "")
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .textSelection(.enabled)

            Divider()

            Text(model.popup.translatedText ?? "")
                .font(.title3.weight(.medium))
                .lineLimit(4)
                .textSelection(.enabled)

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                if let method = model.popup.captureMethod {
                    Label(method.title, systemImage: method.systemImage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if model.popup.savedEntryID == nil {
                    Button("存入生词本") {
                        model.saveCurrentTranslation()
                    }
                }
                Button("复制译文") {
                    model.copyTranslation()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var errorContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.popup.message ?? "发生未知错误")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Text("可在 VocabPocket 设置中检查系统权限与快捷键。")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var headerIcon: String {
        switch model.popup.phase {
        case .success: "checkmark.circle.fill"
        case .error: "exclamationmark.triangle.fill"
        case .idle: "character.book.closed.fill"
        default: "sparkles"
        }
    }

    private var headerColor: Color {
        switch model.popup.phase {
        case .success: .green
        case .error: .orange
        default: .accentColor
        }
    }

    private var headerTitle: String {
        switch model.popup.phase {
        case .success: model.popup.message ?? "翻译完成"
        case .error: "未能完成翻译"
        case .preparingScreenshot: "截图取词"
        case .recognizing: "OCR 识别"
        case .readingSelection: "读取选区"
        case .translating: "设备端翻译"
        case .idle: "VocabPocket"
        }
    }
}
