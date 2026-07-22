import SwiftUI

private enum MainSection: String, CaseIterable, Identifiable {
    case vocabulary
    case review
    case guide

    var id: String { rawValue }

    var title: String {
        switch self {
        case .vocabulary: "生词本"
        case .review: "复习"
        case .guide: "使用指南"
        }
    }

    var systemImage: String {
        switch self {
        case .vocabulary: "character.book.closed"
        case .review: "rectangle.on.rectangle.angled"
        case .guide: "questionmark.circle"
        }
    }
}

struct MainView: View {
    @ObservedObject var model: AppModel
    @EnvironmentObject private var store: VocabularyStore
    @State private var selectedSection: MainSection = .vocabulary

    var body: some View {
        NavigationSplitView {
            List(MainSection.allCases, selection: $selectedSection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationTitle("VocabPocket")
            .navigationSplitViewColumnWidth(min: 160, ideal: 190, max: 230)
        } detail: {
            switch selectedSection {
            case .vocabulary:
                VocabularyView(model: model)
            case .review:
                ReviewView()
            case .guide:
                GuideView(model: model)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    model.beginCapture()
                } label: {
                    Label("快捷翻译", systemImage: "sparkles")
                }
                .help("使用 \(model.settings.hotKey.title) 也可以随时翻译")
            }
        }
    }
}
