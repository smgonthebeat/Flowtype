import Combine
import Foundation

enum TranscriptionEngineKind: String, CaseIterable, Codable {
    case qwenLocal
    case appleSpeech
}

enum LanguageMode: String, CaseIterable, Codable {
    case mixedChineseEnglish
    case chinese
    case english
}

enum UILanguage: String, CaseIterable, Codable {
    case chinese
    case english
}

struct ModelDownloadConsent: Codable, Equatable {
    static let currentDisclosureVersion = 1

    let modelID: String
    let acceptedAt: Date
    let disclosureVersion: Int
}

final class SettingsStore: ObservableObject {
    static let appThemeDidChangeNotification = Notification.Name("SettingsStoreAppThemeDidChange")
    static let appThemeIDUserInfoKey = "appThemeID"
    static let selectedModelDidChangeNotification = Notification.Name("SettingsStoreSelectedModelDidChange")
    static let selectedModelIDUserInfoKey = "selectedModelID"
    static let engineDidChangeNotification = Notification.Name("SettingsStoreEngineDidChange")
    static let engineUserInfoKey = "engine"

    private enum Key {
        static let engine = "engine"
        static let languageMode = "languageMode"
        static let uiLanguage = "uiLanguage"
        static let appThemeID = "appThemeID"
        static let appleSpeechLocaleIdentifier = "appleSpeechLocaleIdentifier"
        static let isHistoryEnabled = "isHistoryEnabled"
        static let historyLimit = "historyLimit"
        static let maxRecordingDuration = "maxRecordingDuration"
        static let selectedMicrophoneUID = "selectedMicrophoneUID"
        static let selectedModelID = "selectedModelID"
        static let isSmartNumericFormattingEnabled = "isSmartNumericFormattingEnabled"
        static let isFillerCleanupEnabled = "isFillerCleanupEnabled"
        static let isMathNotationEnabled = "isMathNotationEnabled"
        static let mathNotationOutputFormat = "mathNotationOutputFormat"
        static let hasSeenReadinessSetupPrompt = "hasSeenReadinessSetupPrompt"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let modelDownloadConsents = "modelDownloadConsents"
        static let isDebugRecordingCaptureEnabled = "isDebugRecordingCaptureEnabled"
        static let forceNextTranscriptionIssue = "forceNextTranscriptionIssue"
        static let hasMigratedLegacyDefaults = "hasMigratedVoiceInputDefaultsToFlowtype"

        static let persistedKeys = [
            engine,
            languageMode,
            uiLanguage,
            appThemeID,
            appleSpeechLocaleIdentifier,
            isHistoryEnabled,
            historyLimit,
            maxRecordingDuration,
            selectedMicrophoneUID,
            selectedModelID,
            isSmartNumericFormattingEnabled,
            isFillerCleanupEnabled,
            isMathNotationEnabled,
            mathNotationOutputFormat,
            hasSeenReadinessSetupPrompt,
            hasCompletedOnboarding,
            modelDownloadConsents,
            isDebugRecordingCaptureEnabled
        ]
    }

    private static let legacyBundleIdentifier = "com.smg.voiceinput"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults === UserDefaults.standard {
            Self.migrateLegacyDefaultsIfNeeded(into: defaults)
        }
    }

    var engine: TranscriptionEngineKind {
        get {
            guard let raw = defaults.string(forKey: Key.engine),
                  let value = TranscriptionEngineKind(rawValue: raw) else {
                return .qwenLocal
            }
            return value
        }
        set {
            let oldValue = engine
            defaults.set(newValue.rawValue, forKey: Key.engine)
            guard oldValue != newValue else { return }
            NotificationCenter.default.post(
                name: Self.engineDidChangeNotification,
                object: self,
                userInfo: [Self.engineUserInfoKey: newValue.rawValue]
            )
        }
    }

    var languageMode: LanguageMode {
        get {
            guard let raw = defaults.string(forKey: Key.languageMode),
                  let value = LanguageMode(rawValue: raw) else {
                return .mixedChineseEnglish
            }
            return value
        }
        set { defaults.set(newValue.rawValue, forKey: Key.languageMode) }
    }

    var uiLanguage: UILanguage {
        get {
            guard let raw = defaults.string(forKey: Key.uiLanguage),
                  let value = UILanguage(rawValue: raw) else {
                return .chinese
            }
            return value
        }
        set { defaults.set(newValue.rawValue, forKey: Key.uiLanguage) }
    }

    var appThemeID: AppThemeID {
        get {
            guard let raw = defaults.string(forKey: Key.appThemeID),
                  let value = AppThemeID(rawValue: raw) else {
                return .oscurange
            }
            return value
        }
        set {
            let oldValue = appThemeID
            guard oldValue != newValue else { return }
            objectWillChange.send()
            defaults.set(newValue.rawValue, forKey: Key.appThemeID)
            NotificationCenter.default.post(
                name: Self.appThemeDidChangeNotification,
                object: self,
                userInfo: [Self.appThemeIDUserInfoKey: newValue.rawValue]
            )
        }
    }

    var appleSpeechLocaleIdentifier: String {
        get { defaults.string(forKey: Key.appleSpeechLocaleIdentifier) ?? "zh-CN" }
        set { defaults.set(newValue, forKey: Key.appleSpeechLocaleIdentifier) }
    }

    var selectedModelID: String {
        get {
            let value = defaults.string(forKey: Key.selectedModelID) ?? VoiceInputModel.qwen3ASR06B.id
            return VoiceInputModel.model(for: value).id
        }
        set {
            let oldValue = selectedModelID
            let resolvedValue = VoiceInputModel.model(for: newValue).id
            defaults.set(resolvedValue, forKey: Key.selectedModelID)
            engine = .qwenLocal
            guard oldValue != resolvedValue else { return }
            NotificationCenter.default.post(
                name: Self.selectedModelDidChangeNotification,
                object: self,
                userInfo: [Self.selectedModelIDUserInfoKey: resolvedValue]
            )
        }
    }

    var isSmartNumericFormattingEnabled: Bool {
        get {
            if defaults.object(forKey: Key.isSmartNumericFormattingEnabled) == nil {
                return true
            }
            return defaults.bool(forKey: Key.isSmartNumericFormattingEnabled)
        }
        set { defaults.set(newValue, forKey: Key.isSmartNumericFormattingEnabled) }
    }

    var isFillerCleanupEnabled: Bool {
        get {
            if defaults.object(forKey: Key.isFillerCleanupEnabled) == nil {
                return true
            }
            return defaults.bool(forKey: Key.isFillerCleanupEnabled)
        }
        set { defaults.set(newValue, forKey: Key.isFillerCleanupEnabled) }
    }

    var isMathNotationEnabled: Bool {
        get { defaults.bool(forKey: Key.isMathNotationEnabled) }
        set { defaults.set(newValue, forKey: Key.isMathNotationEnabled) }
    }

    var mathNotationOutputFormat: MathNotationOutputFormat {
        get {
            guard let raw = defaults.string(forKey: Key.mathNotationOutputFormat),
                  let value = MathNotationOutputFormat(rawValue: raw) else {
                return .latex
            }
            return value
        }
        set { defaults.set(newValue.rawValue, forKey: Key.mathNotationOutputFormat) }
    }

    var hasSeenReadinessSetupPrompt: Bool {
        get { defaults.bool(forKey: Key.hasSeenReadinessSetupPrompt) }
        set { defaults.set(newValue, forKey: Key.hasSeenReadinessSetupPrompt) }
    }

    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Key.hasCompletedOnboarding) }
        set { defaults.set(newValue, forKey: Key.hasCompletedOnboarding) }
    }

    func modelDownloadConsent(for modelID: String) -> ModelDownloadConsent? {
        modelDownloadConsents()[modelID]
    }

    func recordModelDownloadConsent(
        modelID: String,
        disclosureVersion: Int,
        acceptedAt: Date = Date()
    ) {
        var consents = modelDownloadConsents()
        consents[modelID] = ModelDownloadConsent(
            modelID: modelID,
            acceptedAt: acceptedAt,
            disclosureVersion: disclosureVersion
        )
        guard let data = try? JSONEncoder().encode(consents) else { return }
        defaults.set(data, forKey: Key.modelDownloadConsents)
    }

    private func modelDownloadConsents() -> [String: ModelDownloadConsent] {
        guard let data = defaults.data(forKey: Key.modelDownloadConsents),
              let consents = try? JSONDecoder().decode([String: ModelDownloadConsent].self, from: data)
        else {
            return [:]
        }
        return consents
    }

    var isDebugRecordingCaptureEnabled: Bool {
        get { defaults.bool(forKey: Key.isDebugRecordingCaptureEnabled) }
        set { defaults.set(newValue, forKey: Key.isDebugRecordingCaptureEnabled) }
    }

    var forceNextTranscriptionIssue: Bool {
        get { defaults.bool(forKey: Key.forceNextTranscriptionIssue) }
        set { defaults.set(newValue, forKey: Key.forceNextTranscriptionIssue) }
    }

    var isHistoryEnabled: Bool {
        get {
            if defaults.object(forKey: Key.isHistoryEnabled) == nil {
                return true
            }
            return defaults.bool(forKey: Key.isHistoryEnabled)
        }
        set {
            guard isHistoryEnabled != newValue else { return }
            // Published so views observing the store (e.g. Home's history
            // notice) update when the Settings window flips this.
            objectWillChange.send()
            defaults.set(newValue, forKey: Key.isHistoryEnabled)
        }
    }

    var historyLimit: Int {
        get {
            let value = defaults.integer(forKey: Key.historyLimit)
            return value > 0 ? value : 100
        }
        set { defaults.set(max(1, newValue), forKey: Key.historyLimit) }
    }

    var maxRecordingDuration: Int {
        get {
            let value = defaults.integer(forKey: Key.maxRecordingDuration)
            return value > 0 ? Self.clampRecordingDuration(value) : 180
        }
        set { defaults.set(Self.clampRecordingDuration(newValue), forKey: Key.maxRecordingDuration) }
    }

    var selectedMicrophoneUID: String? {
        get {
            guard let value = defaults.string(forKey: Key.selectedMicrophoneUID),
                  !value.isEmpty else {
                return nil
            }
            return value
        }
        set {
            if let newValue, !newValue.isEmpty {
                defaults.set(newValue, forKey: Key.selectedMicrophoneUID)
            } else {
                defaults.removeObject(forKey: Key.selectedMicrophoneUID)
            }
        }
    }

    private static func clampRecordingDuration(_ value: Int) -> Int {
        min(600, max(30, value))
    }

    private static func migrateLegacyDefaultsIfNeeded(into defaults: UserDefaults) {
        guard defaults.object(forKey: Key.hasMigratedLegacyDefaults) == nil else { return }
        guard let legacyDefaults = UserDefaults(suiteName: legacyBundleIdentifier) else {
            defaults.set(true, forKey: Key.hasMigratedLegacyDefaults)
            return
        }

        for key in Key.persistedKeys where defaults.object(forKey: key) == nil {
            if let value = legacyDefaults.object(forKey: key) {
                defaults.set(value, forKey: key)
            }
        }
        defaults.set(true, forKey: Key.hasMigratedLegacyDefaults)
    }
}
