import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct VocabularyView: View {
    @ObservedObject var model: AppModel
    @EnvironmentObject private var store: VocabularyStore
    @State private var query = ""
    @State private var selectedID: UUID?
    @State private var manualText = ""

    private var visibleEntries: [VocabularyEntry] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return store.entries
        }
        return store.entries.filter {
            $0.sourceText.localizedCaseInsensitiveContains(query)
                || $0.translatedText.localizedCaseInsensitiveContains(query)
                || $0.note.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            manualTranslationBar
            Divider()

            if store.entries.isEmpty {
                ContentUnavailableView {
                    Label("生词本还是空的", systemImage: "character.book.closed")
                } description: {
                    Text("在任意应用中选中文字并按 \(model.settings.hotKey.title)，译文会自动保存到这里。")
                } actions: {
                    Button("截图取词") {
                        model.beginCapture(mode: .ocr)
                    }
                }
            } else {
                HSplitView {
                    entryList
                        .frame(minWidth: 300, idealWidth: 370)
                    EntryDetailView(entryID: selectedID)
                        .frame(minWidth: 340)
                }
            }
        }
        .navigationTitle("生词本")
        .searchable(text: $query, prompt: "搜索原文、译文或笔记")
        .toolbar {
            ToolbarItemGroup {
                Text("\(store.entries.count) 个生词 · \(store.dueEntries.count) 个待复习")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Menu {
                    Button("导出 JSON…") { export(format: .json) }
                    Button("导出 CSV…") { export(format: .csv) }
                } label: {
                    Label("导出", systemImage: "square.and.arrow.up")
                }
            }
        }
        .onAppear {
            if selectedID == nil { selectedID = visibleEntries.first?.id }
        }
        .onChange(of: store.entries) { _, entries in
            if let selectedID, entries.contains(where: { $0.id == selectedID }) { return }
            self.selectedID = entries.first?.id
        }
    }

    private var manualTranslationBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "keyboard")
                .foregroundStyle(.secondary)
            TextField("也可以直接输入要翻译的文字", text: $manualText)
                .textFieldStyle(.plain)
                .onSubmit(submitManualTranslation)
            Button("翻译") { submitManualTranslation() }
                .buttonStyle(.borderedProminent)
                .disabled(manualText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var entryList: some View {
        List(selection: $selectedID) {
            ForEach(visibleEntries) { entry in
                VocabularyRow(entry: entry)
                    .tag(entry.id)
                    .contextMenu {
                        Button(entry.isFavorite ? "取消收藏" : "收藏") {
                            store.toggleFavorite(id: entry.id)
                        }
                        Divider()
                        Button("删除", role: .destructive) {
                            store.remove(id: entry.id)
                        }
                    }
            }
            .onDelete { offsets in
                store.remove(at: offsets, from: visibleEntries)
            }
        }
        .listStyle(.inset)
    }

    private func submitManualTranslation() {
        let value = manualText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        model.translateManually(value)
        manualText = ""
    }

    private enum ExportFormat {
        case json
        case csv
    }

    private func export(format: ExportFormat) {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true

        switch format {
        case .json:
            panel.nameFieldStringValue = "VocabPocket-生词本.json"
            panel.allowedContentTypes = [.json]
        case .csv:
            panel.nameFieldStringValue = "VocabPocket-生词本.csv"
            panel.allowedContentTypes = [.commaSeparatedText]
        }

        guard panel.runModal() == .OK, let destination = panel.url else { return }
        do {
            switch format {
            case .json: try store.exportJSON(to: destination)
            case .csv: try store.exportCSV(to: destination)
            }
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }
}

private struct VocabularyRow: View {
    let entry: VocabularyEntry

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: entry.isFavorite ? "star.fill" : entry.captureMethod.systemImage)
                .foregroundStyle(entry.isFavorite ? Color.yellow : Color.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.sourceText)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                Text(entry.translatedText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if entry.encounterCount > 1 {
                    Text("遇见 \(entry.encounterCount) 次")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct EntryDetailView: View {
    let entryID: UUID?
    @EnvironmentObject private var store: VocabularyStore
    @State private var note = ""
    @State private var showingDeleteConfirmation = false

    private var entry: VocabularyEntry? {
        store.entry(id: entryID)
    }

    var body: some View {
        if let entry {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(entry.sourceText)
                                .font(.largeTitle.weight(.semibold))
                                .textSelection(.enabled)
                            Text(entry.translatedText)
                                .font(.title2)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        Spacer()
                        Button {
                            store.toggleFavorite(id: entry.id)
                        } label: {
                            Image(systemName: entry.isFavorite ? "star.fill" : "star")
                                .font(.title2)
                                .foregroundStyle(entry.isFavorite ? Color.yellow : Color.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Divider()

                    Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 10) {
                        metadataRow("来源", value: entry.captureMethod.title)
                        metadataRow(
                            "语言", value: "\(entry.sourceLanguageIdentifier) → \(entry.targetLanguageIdentifier)")
                        metadataRow("遇见次数", value: "\(entry.encounterCount)")
                        metadataRow("复习次数", value: "\(entry.reviewCount)")
                        metadataRow("掌握等级", value: "\(entry.masteryLevel) / 5")
                        metadataRow("下次复习", value: entry.nextReviewAt.formatted(date: .abbreviated, time: .shortened))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("笔记")
                            .font(.headline)
                        TextEditor(text: $note)
                            .font(.body)
                            .frame(minHeight: 100)
                            .padding(6)
                            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                        HStack {
                            Button("保存笔记") {
                                store.updateNote(id: entry.id, note: note)
                            }
                            .disabled(note == entry.note)
                            Spacer()
                            Button("删除生词", role: .destructive) {
                                showingDeleteConfirmation = true
                            }
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .id(entry.id)
            .onAppear { note = entry.note }
            .confirmationDialog("确定删除这个生词吗？", isPresented: $showingDeleteConfirmation) {
                Button("删除", role: .destructive) { store.remove(id: entry.id) }
            }
        } else {
            ContentUnavailableView("选择一个生词", systemImage: "text.book.closed")
        }
    }

    private func metadataRow(_ label: String, value: String) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
                .textSelection(.enabled)
        }
    }
}
