import Combine
import Foundation

enum CaptureMode: String, CaseIterable, Codable, Identifiable {
    case smart
    case selectedText
    case ocr

    var id: String { rawValue }

    var title: String {
        switch self {
        case .smart: "智能（文字优先，失败后截图）"
        case .selectedText: "只读取选中文字"
        case .ocr: "只使用截图 OCR"
        }
    }
}

enum HotKeyPreset: String, CaseIterable, Identifiable {
    case optionCommandD
    case optionCommandT
    case optionCommandV

    var id: String { rawValue }

    var title: String {
        switch self {
        case .optionCommandD: "⌥⌘D"
        case .optionCommandT: "⌥⌘T"
        case .optionCommandV: "⌥⌘V"
        }
    }

    /// Hardware-independent ANSI key code used by Carbon's hot-key API.
    var keyCode: UInt32 {
        switch self {
        case .optionCommandD: 2
        case .optionCommandT: 17
        case .optionCommandV: 9
        }
    }
}

enum TargetLanguage: String, CaseIterable, Identifiable {
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case english = "en"
    case japanese = "ja"
    case korean = "ko"
    case french = "fr"
    case german = "de"
    case spanish = "es"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .simplifiedChinese: "简体中文"
        case .traditionalChinese: "繁体中文"
        case .english: "English"
        case .japanese: "日本語"
        case .korean: "한국어"
        case .french: "Français"
        case .german: "Deutsch"
        case .spanish: "Español"
        }
    }
}

@MainActor
final class AppSettings: ObservableObject {
    private enum Key {
        static let targetLanguage = "targetLanguage"
        static let captureMode = "captureMode"
        static let shortcut = "hotKey"
        static let autoSave = "autoSave"
        static let firstLaunchCompleted = "firstLaunchCompleted"
    }

    private let defaults: UserDefaults

    @Published var targetLanguage: TargetLanguage {
        didSet { defaults.set(targetLanguage.rawValue, forKey: Key.targetLanguage) }
    }

    @Published var captureMode: CaptureMode {
        didSet { defaults.set(captureMode.rawValue, forKey: Key.captureMode) }
    }

    @Published var hotKey: HotKeyPreset {
        didSet { defaults.set(hotKey.rawValue, forKey: Key.shortcut) }
    }

    @Published var autoSave: Bool {
        didSet { defaults.set(autoSave, forKey: Key.autoSave) }
    }

    var firstLaunchCompleted: Bool {
        get { defaults.bool(forKey: Key.firstLaunchCompleted) }
        set { defaults.set(newValue, forKey: Key.firstLaunchCompleted) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        targetLanguage =
            TargetLanguage(
                rawValue: defaults.string(forKey: Key.targetLanguage) ?? ""
            ) ?? .simplifiedChinese
        captureMode =
            CaptureMode(
                rawValue: defaults.string(forKey: Key.captureMode) ?? ""
            ) ?? .smart
        hotKey =
            HotKeyPreset(
                rawValue: defaults.string(forKey: Key.shortcut) ?? ""
            ) ?? .optionCommandD
        autoSave = defaults.object(forKey: Key.autoSave) as? Bool ?? true
    }
}
