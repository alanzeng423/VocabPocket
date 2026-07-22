import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var model: AppModel
    @EnvironmentObject private var store: VocabularyStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("VocabPocket")
                        .font(.headline)
                    Text("快捷取词 · 自动积累")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(model.settings.hotKey.title)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            }

            HStack(spacing: 8) {
                Button {
                    model.beginCapture()
                } label: {
                    Label("智能翻译", systemImage: "text.cursor")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    model.beginCapture(mode: .ocr)
                } label: {
                    Label("截图", systemImage: "viewfinder")
                }
                .buttonStyle(.bordered)
            }

            Divider()

            HStack {
                Text("最近生词")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(store.entries.count) 个")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            if store.entries.isEmpty {
                Text("选中文字后按 \(model.settings.hotKey.title) 开始")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 54)
            } else {
                ForEach(store.entries.prefix(4)) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.sourceText)
                            .font(.callout.weight(.medium))
                            .lineLimit(1)
                        Text(entry.translatedText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Divider()

            HStack {
                Button("打开生词本") {
                    openWindow(id: "library")
                    NSApp.activate(ignoringOtherApps: true)
                }
                SettingsLink {
                    Image(systemName: "gearshape")
                }
                .help("设置")
                Spacer()
                Button("退出") {
                    NSApp.terminate(nil)
                }
            }
        }
        .padding(14)
        .frame(width: 330)
    }
}
