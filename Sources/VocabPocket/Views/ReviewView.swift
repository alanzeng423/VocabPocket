import SwiftUI

struct ReviewView: View {
    @EnvironmentObject private var store: VocabularyStore
    @State private var isRevealed = false
    @State private var reviewedThisSession = 0

    private var currentEntry: VocabularyEntry? {
        store.dueEntries.first
    }

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("间隔复习")
                        .font(.largeTitle.bold())
                    Text("根据记忆程度自动安排下次复习")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("本次已复习 \(reviewedThisSession)")
                    .foregroundStyle(.secondary)
            }

            if let entry = currentEntry {
                reviewCard(entry)
            } else {
                ContentUnavailableView {
                    Label("今天的复习完成了", systemImage: "checkmark.seal.fill")
                } description: {
                    Text(reviewedThisSession == 0 ? "新收集的生词会出现在这里。" : "做得不错，稍后再来看看。")
                }
                .frame(maxHeight: .infinity)
            }
        }
        .padding(28)
        .navigationTitle("复习")
    }

    private func reviewCard(_ entry: VocabularyEntry) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 20) {
                Text(entry.sourceText)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)

                if isRevealed {
                    Divider()
                        .frame(maxWidth: 440)
                    Text(entry.translatedText)
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .textSelection(.enabled)
                    if !entry.note.isEmpty {
                        Text(entry.note)
                            .font(.callout)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    Button("显示答案") {
                        withAnimation(.easeInOut(duration: 0.2)) { isRevealed = true }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 300)
            .padding(32)

            if isRevealed {
                Divider()
                HStack(spacing: 12) {
                    ratingButton(.again, color: .red)
                    ratingButton(.hard, color: .orange)
                    ratingButton(.good, color: .green)
                }
                .padding(18)
            }
        }
        .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.08), radius: 18, y: 8)
        .frame(maxWidth: 680, maxHeight: .infinity)
    }

    private func ratingButton(_ rating: ReviewRating, color: Color) -> some View {
        Button(rating.title) {
            guard let id = currentEntry?.id else { return }
            store.recordReview(id: id, rating: rating)
            reviewedThisSession += 1
            isRevealed = false
        }
        .buttonStyle(.bordered)
        .tint(color)
        .controlSize(.large)
        .frame(maxWidth: .infinity)
    }
}
