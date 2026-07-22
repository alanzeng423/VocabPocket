import Foundation

enum TranslationProviderGroup: String, CaseIterable, Identifiable {
    case onDevice
    case officialAPI
    case llm
    case selfHosted
    case experimental

    var id: String { rawValue }

    var title: String {
        switch self {
        case .onDevice: "设备端"
        case .officialAPI: "官方翻译 API"
        case .llm: "LLM 翻译"
        case .selfHosted: "自托管"
        case .experimental: "免费网页接口（实验性）"
        }
    }
}

enum TranslationProviderKind: String, CaseIterable, Codable, Identifiable {
    case apple

    case deepL
    case googleCloud
    case microsoft
    case baidu
    case baiduField
    case youdaoCloud
    case youdaoLLM
    case niuTrans
    case caiyun
    case aliyun
    case tencentCloud
    case volcanoEngine
    case iFlytek
    case openL

    case openAICompatible
    case anthropic
    case azureOpenAI
    case gemini
    case qwenMT

    case deepLX
    case libreTranslate
    case mTranServer
    case nllb

    case googleFree
    case bingFree
    case youdaoFree
    case volcanoWeb
    case tencentTransmart

    var id: String { rawValue }

    var group: TranslationProviderGroup {
        switch self {
        case .apple:
            .onDevice
        case .deepL, .googleCloud, .microsoft, .baidu, .baiduField, .youdaoCloud,
            .youdaoLLM, .niuTrans, .caiyun, .aliyun, .tencentCloud, .volcanoEngine,
            .iFlytek, .openL:
            .officialAPI
        case .openAICompatible, .anthropic, .azureOpenAI, .gemini, .qwenMT:
            .llm
        case .deepLX, .libreTranslate, .mTranServer, .nllb:
            .selfHosted
        case .googleFree, .bingFree, .youdaoFree, .volcanoWeb, .tencentTransmart:
            .experimental
        }
    }

    var title: String {
        switch self {
        case .apple: "Apple Translation"
        case .deepL: "DeepL"
        case .googleCloud: "Google Cloud Translation"
        case .microsoft: "Microsoft Translator"
        case .baidu: "百度通用翻译"
        case .baiduField: "百度领域翻译"
        case .youdaoCloud: "有道智云"
        case .youdaoLLM: "有道翻译大模型"
        case .niuTrans: "小牛翻译 NiuTrans"
        case .caiyun: "彩云小译"
        case .aliyun: "阿里云机器翻译"
        case .tencentCloud: "腾讯云机器翻译"
        case .volcanoEngine: "火山引擎机器翻译"
        case .iFlytek: "讯飞机器翻译"
        case .openL: "OpenL 聚合翻译"
        case .openAICompatible: "OpenAI 兼容 LLM"
        case .anthropic: "Anthropic Claude"
        case .azureOpenAI: "Azure OpenAI"
        case .gemini: "Google Gemini"
        case .qwenMT: "通义千问 Qwen-MT"
        case .deepLX: "DeepLX"
        case .libreTranslate: "LibreTranslate"
        case .mTranServer: "MTranServer"
        case .nllb: "NLLB"
        case .googleFree: "Google Translate 免费接口"
        case .bingFree: "Bing 免费接口"
        case .youdaoFree: "有道免费接口"
        case .volcanoWeb: "火山翻译网页接口"
        case .tencentTransmart: "腾讯交互翻译 Transmart"
        }
    }

    var detail: String {
        switch self {
        case .apple:
            "使用 macOS 系统翻译模型，文字不会离开设备。"
        case .deepL:
            "调用 DeepL Text Translation API，支持 Free、Pro 与自定义接口。"
        case .googleCloud:
            "调用 Google Cloud Translation Basic (v2)。"
        case .microsoft:
            "调用 Azure AI Translator Text API (v3)。"
        case .baidu:
            "调用百度通用文本翻译 API。"
        case .baiduField:
            "调用百度垂直领域翻译 API，可选择领域模型。"
        case .youdaoCloud:
            "调用有道智云文本翻译 API，支持领域与术语表。"
        case .youdaoLLM:
            "调用有道翻译大模型接口。"
        case .niuTrans:
            "调用小牛翻译文本 API。"
        case .caiyun:
            "调用彩云小译翻译 API。"
        case .aliyun:
            "调用阿里云机器翻译 TranslateGeneral API。"
        case .tencentCloud:
            "调用腾讯云机器翻译 TextTranslate API。"
        case .volcanoEngine:
            "调用火山引擎 TranslateText API。"
        case .iFlytek:
            "调用讯飞 niutrans 机器翻译 API。"
        case .openL:
            "通过 OpenL 同时调用一个或多个翻译服务。"
        case .openAICompatible:
            "支持 OpenAI、Ollama、LM Studio 及兼容 Chat Completions 的服务。"
        case .anthropic:
            "调用 Anthropic Messages API，使用 Claude 按提示词翻译。"
        case .azureOpenAI:
            "调用 Azure OpenAI Chat Completions，需要部署名称与 API 版本。"
        case .gemini:
            "调用 Gemini generateContent API，使用可配置提示词翻译。"
        case .qwenMT:
            "调用阿里云百炼 OpenAI 兼容接口中的 Qwen-MT 专用模型。"
        case .deepLX:
            "连接你自行部署的 DeepLX 兼容 /translate 接口。"
        case .libreTranslate:
            "连接 LibreTranslate 实例；公开实例可能要求 API Key。"
        case .mTranServer:
            "连接本机或局域网内的 MTranServer。"
        case .nllb:
            "连接 nllb-serve 或 nllb-api 自托管服务。"
        case .googleFree, .bingFree, .youdaoFree, .volcanoWeb, .tencentTransmart:
            "使用未承诺稳定性的网页接口，无需密钥，可能随时限流、变更或停用。"
        }
    }

    var usesRemoteService: Bool { self != .apple }

    var isExperimental: Bool { group == .experimental }

    var requiresAPIKey: Bool {
        switch self {
        case .apple, .openAICompatible, .deepLX, .libreTranslate, .mTranServer, .nllb,
            .googleFree, .bingFree, .youdaoFree, .volcanoWeb, .tencentTransmart:
            false
        default:
            true
        }
    }

    var supportsCredential: Bool {
        switch self {
        case .apple, .googleFree, .bingFree, .youdaoFree, .volcanoWeb, .tencentTransmart:
            false
        default:
            true
        }
    }

    var modelLabel: String? {
        switch self {
        case .openAICompatible, .anthropic, .gemini, .qwenMT:
            "模型名称"
        case .azureOpenAI:
            "Azure 部署名称"
        case .nllb:
            "后端类型（nllb-serve 或 nllb-api）"
        case .youdaoLLM:
            "模型档位（pro 或 lite）"
        case .iFlytek:
            "接口类型（niutrans）"
        default:
            nil
        }
    }

    var requiresModel: Bool {
        switch self {
        case .openAICompatible, .anthropic, .azureOpenAI, .gemini, .qwenMT, .nllb:
            true
        default:
            false
        }
    }

    var regionLabel: String? {
        switch self {
        case .microsoft: "Azure Region（部分资源必填）"
        case .baiduField: "领域（如 electronics、medicine）"
        case .youdaoCloud: "领域（general / computers / medicine / finance / game）"
        case .aliyun: "地域（默认 cn-hangzhou）"
        case .tencentCloud: "地域（默认 ap-shanghai）"
        case .volcanoEngine: "地域（默认 cn-beijing）"
        case .azureOpenAI: "API 版本"
        case .mTranServer: "语言代码模式（base 或 bcp47）"
        default: nil
        }
    }

    var promptLabel: String? {
        switch self {
        case .openAICompatible, .anthropic, .azureOpenAI, .gemini:
            "系统提示词"
        case .qwenMT:
            "领域提示（可选）"
        case .youdaoCloud:
            "术语表 ID（可选）"
        case .youdaoLLM:
            "翻译要求（可选）"
        case .openL:
            "服务列表（逗号分隔）"
        case .tencentCloud:
            "项目 ID（默认 0）"
        default:
            nil
        }
    }

    var credentialLabel: String {
        switch self {
        case .baidu, .baiduField: "AppID#密钥"
        case .youdaoCloud, .youdaoLLM: "应用 ID#应用密钥"
        case .aliyun: "AccessKey ID#AccessKey Secret"
        case .tencentCloud: "Secret ID#Secret Key"
        case .volcanoEngine: "AccessKey ID#Secret AccessKey"
        case .iFlytek: "AppID#APISecret#APIKey"
        case .openL: "OpenL API Key"
        case .openAICompatible, .deepLX, .libreTranslate, .mTranServer, .nllb:
            "API Key / Token（可留空）"
        default:
            "API Key"
        }
    }

    var credentialHint: String? {
        switch self {
        case .baidu, .baiduField:
            "按 AppID#密钥 保存，例如 2026xxxx#your-secret。"
        case .youdaoCloud, .youdaoLLM:
            "按 应用ID#应用密钥 保存。"
        case .aliyun:
            "按 AccessKeyID#AccessKeySecret 保存。"
        case .tencentCloud:
            "按 SecretId#SecretKey 保存。"
        case .volcanoEngine:
            "按 AccessKeyID#SecretAccessKey 保存。"
        case .iFlytek:
            "按 AppID#APISecret#APIKey 保存。"
        case .openL:
            "服务列表在上方单独填写，钥匙串中只保存 API Key。"
        default:
            nil
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
        case .baidu, .baiduField:
            value = "https://fanyi-api.baidu.com/doc/21"
        case .youdaoCloud:
            value = "https://ai.youdao.com/DOCSIRMA/html/trans/api/wbfy/index.html"
        case .youdaoLLM:
            value = "https://ai.youdao.com/DOCSIRMA/html/trans/api/dmxfy/index.html"
        case .niuTrans:
            value = "https://niutrans.com/documents/contents/trans_text"
        case .caiyun:
            value = "https://docs.caiyunapp.com/lingocloud-app/lingocloud-web/trans-api.html"
        case .aliyun:
            value =
                "https://help.aliyun.com/zh/machine-translation/developer-reference/api-reference-machine-translation-universal-version-call-guide"
        case .tencentCloud:
            value = "https://cloud.tencent.com/document/product/551/15619"
        case .volcanoEngine:
            value =
                "https://api.volcengine.com/api-explorer/debug?action=TranslateText&groupName=机器翻译&serviceCode=translate&version=2020-06-01"
        case .iFlytek:
            value = "https://www.xfyun.cn/doc/nlp/niutrans/API.html"
        case .openL:
            value = "https://openl.club"
        case .openAICompatible:
            value = "https://platform.openai.com/docs/api-reference/chat/create"
        case .anthropic:
            value = "https://docs.anthropic.com/en/api/messages"
        case .azureOpenAI:
            value = "https://learn.microsoft.com/azure/ai-foundry/openai/reference"
        case .gemini:
            value = "https://ai.google.dev/api/generate-content"
        case .qwenMT:
            value = "https://help.aliyun.com/en/model-studio/machine-translation"
        case .deepLX:
            value = "https://github.com/OwO-Network/DeepLX"
        case .libreTranslate:
            value = "https://docs.libretranslate.com"
        case .mTranServer:
            value = "https://github.com/xxnuo/MTranServer"
        case .nllb:
            value = "https://github.com/thammegowda/nllb-serve"
        case .googleFree, .bingFree, .youdaoFree, .volcanoWeb, .tencentTransmart:
            value = "https://github.com/windingwind/zotero-pdf-translate#readme"
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
            Self(endpoint: "https://api-free.deepl.com/v2/translate", model: "", systemPrompt: "", region: "")
        case .googleCloud:
            Self(
                endpoint: "https://translation.googleapis.com/language/translate/v2", model: "", systemPrompt: "",
                region: "")
        case .microsoft:
            Self(
                endpoint: "https://api.cognitive.microsofttranslator.com/translate", model: "", systemPrompt: "",
                region: "")
        case .baidu:
            Self(
                endpoint: "https://fanyi-api.baidu.com/api/trans/vip/translate", model: "", systemPrompt: "", region: ""
            )
        case .baiduField:
            Self(
                endpoint: "https://fanyi-api.baidu.com/api/trans/vip/fieldtranslate", model: "", systemPrompt: "",
                region: "electronics")
        case .youdaoCloud:
            Self(endpoint: "https://openapi.youdao.com/api", model: "", systemPrompt: "", region: "general")
        case .youdaoLLM:
            Self(endpoint: "https://openapi.youdao.com/llm_trans", model: "pro", systemPrompt: "", region: "")
        case .niuTrans:
            Self(
                endpoint: "https://api.niutrans.com/NiuTransServer/translation", model: "", systemPrompt: "", region: ""
            )
        case .caiyun:
            Self(
                endpoint: "https://api.interpreter.caiyunai.com/v1/translator", model: "", systemPrompt: "", region: "")
        case .aliyun:
            Self(endpoint: "https://mt.cn-hangzhou.aliyuncs.com/", model: "", systemPrompt: "", region: "cn-hangzhou")
        case .tencentCloud:
            Self(endpoint: "https://tmt.tencentcloudapi.com/", model: "", systemPrompt: "0", region: "ap-shanghai")
        case .volcanoEngine:
            Self(
                endpoint: "https://open.volcengineapi.com/?Action=TranslateText&Version=2020-06-01", model: "",
                systemPrompt: "", region: "cn-beijing")
        case .iFlytek:
            Self(endpoint: "https://ntrans.xfyun.cn/v2/ots", model: "niutrans", systemPrompt: "", region: "")
        case .openL:
            Self(endpoint: "https://api.openl.club/group/translate", model: "", systemPrompt: "google", region: "")
        case .openAICompatible:
            Self(
                endpoint: "https://api.openai.com/v1/chat/completions", model: "gpt-4o-mini",
                systemPrompt: defaultLLMPrompt, region: "")
        case .anthropic:
            Self(
                endpoint: "https://api.anthropic.com/v1/messages", model: "claude-sonnet-4-20250514",
                systemPrompt: defaultLLMPrompt, region: "")
        case .azureOpenAI:
            Self(
                endpoint: "https://YOUR-RESOURCE.openai.azure.com", model: "YOUR-DEPLOYMENT",
                systemPrompt: defaultLLMPrompt, region: "2024-10-21")
        case .gemini:
            Self(
                endpoint: "https://generativelanguage.googleapis.com/v1beta", model: "gemini-3.5-flash",
                systemPrompt: defaultLLMPrompt, region: "")
        case .qwenMT:
            Self(
                endpoint: "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions", model: "qwen-mt-plus",
                systemPrompt: "", region: "")
        case .deepLX:
            Self(endpoint: "http://localhost:1188/translate", model: "", systemPrompt: "", region: "")
        case .libreTranslate:
            Self(endpoint: "http://localhost:5000/translate", model: "", systemPrompt: "", region: "")
        case .mTranServer:
            Self(endpoint: "http://localhost:8989/translate", model: "", systemPrompt: "", region: "base")
        case .nllb:
            Self(endpoint: "http://localhost:6060", model: "nllb-serve", systemPrompt: "", region: "")
        case .googleFree:
            Self(
                endpoint: "https://translate.googleapis.com/translate_a/single", model: "", systemPrompt: "", region: ""
            )
        case .bingFree:
            Self(
                endpoint: "https://api-edge.cognitive.microsofttranslator.com/translate", model: "", systemPrompt: "",
                region: "")
        case .youdaoFree:
            Self(endpoint: "https://fanyi.youdao.com/translate", model: "", systemPrompt: "", region: "")
        case .volcanoWeb:
            Self(endpoint: "https://translate.volcengine.com/crx/translate/v1", model: "", systemPrompt: "", region: "")
        case .tencentTransmart:
            Self(endpoint: "https://transmart.qq.com/api/imt", model: "", systemPrompt: "", region: "")
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
