import Foundation
import SwiftUI
import Translation

/// SwiftUI is the owner of TranslationSession because this lets macOS download
/// a missing language model with the system permission UI when needed.
struct TranslationBridge: View {
    @ObservedObject var model: AppModel
    @State private var configuration: TranslationSession.Configuration?

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .onChange(of: model.pendingTranslation?.id) { _, requestID in
                guard requestID != nil, let request = model.pendingTranslation else { return }
                let target = Locale.Language(identifier: request.targetLanguageIdentifier)

                if var current = configuration, current.target == target {
                    current.invalidate()
                    configuration = current
                } else {
                    configuration = TranslationSession.Configuration(source: nil, target: target)
                }
            }
            .translationTask(configuration) { session in
                guard let request = model.pendingTranslation else { return }
                do {
                    let response = try await session.translate(request.sourceText)
                    await model.completeTranslation(
                        requestID: request.id,
                        translatedText: response.targetText,
                        sourceLanguageIdentifier: response.sourceLanguage.minimalIdentifier,
                        targetLanguageIdentifier: response.targetLanguage.minimalIdentifier
                    )
                } catch {
                    await model.translationFailed(requestID: request.id, error: error)
                }
            }
    }
}
