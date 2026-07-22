import Foundation

enum TranslationProviderKind: String, CaseIterable, Codable, Identifiable {
    case apple
    case deepL
    case googleCloud
    case microsoft
    case openAICompatible
    case anthropic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .apple: "Apple Translation"
        case .deepL: "DeepL"
        case .googleCloud: "Google Cloud Translation"
        case .microsoft: "Microsoft Translator"
        case .openAICompatible: "OpenAI 兼容 LLM"
        case .anthropic: "Anthropic Claude"
        }
    }

    var detail: String {
        switch self {
        case .apple:
            "使用 macOS 系统翻译模型，文字不会离开设备。"
        case .deepL:
            "调用 DeepL Text Translation API，支持 Free 与 Pro 接口。"
        case .googleCloud:
            "调用 Google Cloud Translation Basic (v2)。"
        case .microsoft:
            "调用 Azure AI Translator Text API (v3)。"
        case .openAICompatible:
            "支持 OpenAI、Ollama、LM Studio 及兼容 Chat Completions 的服务。"
        case .anthropic:
            "调用 Anthropic Messages API，使用 Claude 按提示词翻译。"
        }
    }

    var isLLM: Bool {
        self == .openAICompatible || self == .anthropic
    }

    var usesRemoteService: Bool {
        self != .apple
    }

    var requiresAPIKey: Bool {
        switch self {
        case .apple, .openAICompatible: false
        default: true
        }
    }

    var progressMessage: String {
        switch self {
        case .apple: "正在使用 Apple Translation 翻译…"
        default: "正在使用 \(title) 翻译…"
        }
    }

    var documentationURL: URL? {
        let value: String
        switch self {
        case .apple:
            return nil
        case .deepL:
            value = "https://developers.deepl.com/api-reference/translate"
        case .googleCloud:
            value = "https://cloud.google.com/translate/docs/reference/rest/v2/translate"
        case .microsoft:
            value = "https://learn.microsoft.com/azure/ai-services/translator/text-translation/reference/v3/translate"
        case .openAICompatible:
            value = "https://platform.openai.com/docs/api-reference/chat/create"
        case .anthropic:
            value = "https://docs.anthropic.com/en/api/messages"
        }
        return URL(string: value)
    }
}

struct TranslationProviderPreferences: Codable, Equatable {
    var endpoint: String
    var model: String
    var systemPrompt: String
    var region: String

    static let defaultLLMPrompt = """
        You are a professional translator. Translate the user's text into {target_language} ({target_language_code}). Preserve meaning, tone, names, punctuation, and line breaks. Return only the translation, without explanations or quotation marks.
        """

    static func defaults(for provider: TranslationProviderKind) -> Self {
        switch provider {
        case .apple:
            Self(endpoint: "", model: "", systemPrompt: "", region: "")
        case .deepL:
            Self(
                endpoint: "https://api-free.deepl.com/v2/translate",
                model: "",
                systemPrompt: "",
                region: ""
            )
        case .googleCloud:
            Self(
                endpoint: "https://translation.googleapis.com/language/translate/v2",
                model: "",
                systemPrompt: "",
                region: ""
            )
        case .microsoft:
            Self(
                endpoint: "https://api.cognitive.microsofttranslator.com/translate",
                model: "",
                systemPrompt: "",
                region: ""
            )
        case .openAICompatible:
            Self(
                endpoint: "https://api.openai.com/v1/chat/completions",
                model: "gpt-4o-mini",
                systemPrompt: defaultLLMPrompt,
                region: ""
            )
        case .anthropic:
            Self(
                endpoint: "https://api.anthropic.com/v1/messages",
                model: "claude-sonnet-4-20250514",
                systemPrompt: defaultLLMPrompt,
                region: ""
            )
        }
    }
}

struct TranslationProviderConfiguration: Equatable {
    let provider: TranslationProviderKind
    let endpoint: String
    let apiKey: String
    let model: String
    let systemPrompt: String
    let region: String
}

struct ProviderTranslationResult: Equatable {
    let translatedText: String
    let sourceLanguageIdentifier: String
    let targetLanguageIdentifier: String
}
