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
        static let textSize = "textSize"
        static let appleSpeechLocaleIdentifier = "appleSpeechLocaleIdentifier"
        static let isHistoryEnabled = "isHistoryEnabled"
        static let historyLimit = "historyLimit"
        static let maxRecordingDuration = "maxRecordingDuration"
        static let selectedMicrophoneUID = "selectedMicrophoneUID"
        static let selectedModelID = "selectedModelID"
        static let isSmartNumericFormattingEnabled = "isSmartNumericFormattingEnabled"
        static let isAcademicReferenceFormattingEnabled = "isAcademicReferenceFormattingEnabled"
        static let isFillerCleanupEnabled = "isFillerCleanupEnabled"
        static let isMathNotationEnabled = "isMathNotationEnabled"
        static let mathNotationOutputFormat = "mathNotationOutputFormat"
        static let hasSeenReadinessSetupPrompt = "hasSeenReadinessSetupPrompt"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let modelDownloadConsents = "modelDownloadConsents"
        static let isDebugRecordingCaptureEnabled = "isDebugRecordingCaptureEnabled"
        static let forceNextTranscriptionIssue = "forceNextTranscriptionIssue"
        static let hasMigratedLegacyDefaults = "hasMigratedVoiceInputDefaultsToFlowtype"
        static let fillerCleanupSafetyMigrationVersion = "fillerCleanupSafetyMigrationVersion"
        static let fillerCleanupSafetyNoticePending = "fillerCleanupSafetyNoticePending"

        static let persistedKeys = [
            engine,
            languageMode,
            uiLanguage,
            appThemeID,
            textSize,
            appleSpeechLocaleIdentifier,
            isHistoryEnabled,
            historyLimit,
            maxRecordingDuration,
            selectedMicrophoneUID,
            selectedModelID,
            isSmartNumericFormattingEnabled,
            isAcademicReferenceFormattingEnabled,
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
    private static let currentFillerCleanupSafetyMigrationVersion = 1
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        let legacyDefaults = defaults === UserDefaults.standard
            ? UserDefaults(suiteName: Self.legacyBundleIdentifier)
            : nil
        self.defaults = defaults
        Self.runMigrations(current: defaults, legacy: legacyDefaults)
    }

    init(defaults: UserDefaults, legacyDefaults: UserDefaults?) {
        self.defaults = defaults
        Self.runMigrations(current: defaults, legacy: legacyDefaults)
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
                return Self.defaultUILanguage(preferredLanguages: Self.preferredLanguagesProvider())
            }
            return value
        }
        set { defaults.set(newValue.rawValue, forKey: Key.uiLanguage) }
    }

    var appThemeID: AppThemeID {
        get { Self.storedAppThemeID(defaults: defaults) }
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

    /// The stored theme, for surfaces that hold no SettingsStore of their own (the recording capsule).
    static func storedAppThemeID(defaults: UserDefaults = .standard) -> AppThemeID {
        guard let raw = defaults.string(forKey: Key.appThemeID),
              let value = AppThemeID(rawValue: raw) else {
            return .oscurange
        }
        return value
    }

    /// Interface text size. Writing it also updates the shared model every window reads.
    var textSize: AppTextSize {
        get { Self.storedTextSize(defaults: defaults) }
        set {
            guard textSize != newValue else { return }
            objectWillChange.send()
            defaults.set(newValue.rawValue, forKey: Key.textSize)
            if defaults === UserDefaults.standard {
                AppTextSizeModel.shared.size = newValue
            }
        }
    }

    static func storedTextSize(defaults: UserDefaults = .standard) -> AppTextSize {
        guard let raw = defaults.string(forKey: Key.textSize),
              let value = AppTextSize(rawValue: raw) else {
            return .defaultSize
        }
        return value
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

    var isAcademicReferenceFormattingEnabled: Bool {
        get { defaults.bool(forKey: Key.isAcademicReferenceFormattingEnabled) }
        set { defaults.set(newValue, forKey: Key.isAcademicReferenceFormattingEnabled) }
    }

    var isFillerCleanupEnabled: Bool {
        get { defaults.bool(forKey: Key.isFillerCleanupEnabled) }
        set {
            let oldValue = isFillerCleanupEnabled
            let hadPendingNotice = isFillerCleanupSafetyNoticePending
            defaults.set(newValue, forKey: Key.isFillerCleanupEnabled)
            if newValue {
                defaults.set(false, forKey: Key.fillerCleanupSafetyNoticePending)
            }
            if oldValue != newValue || (newValue && hadPendingNotice) {
                objectWillChange.send()
            }
        }
    }

    var isFillerCleanupSafetyNoticePending: Bool {
        defaults.bool(forKey: Key.fillerCleanupSafetyNoticePending)
    }

    func dismissFillerCleanupSafetyNotice() {
        guard isFillerCleanupSafetyNoticePending else { return }
        objectWillChange.send()
        defaults.set(false, forKey: Key.fillerCleanupSafetyNoticePending)
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

    private struct PreMigrationSnapshot {
        let hasExistingInstallEvidence: Bool
        let effectiveOldFillerState: Bool
    }

    private static func runMigrations(current: UserDefaults, legacy: UserDefaults?) {
        let snapshot = capturePreMigrationSnapshot(current: current, legacy: legacy)
        migrateLegacyDefaultsIfNeeded(into: current, from: legacy)
        migrateFillerCleanupSafetyIfNeeded(into: current, snapshot: snapshot)
        resolveInitialUILanguageIfNeeded(into: current, snapshot: snapshot)
    }

    /// The Mac's preferred languages, replaceable in tests.
    static var preferredLanguagesProvider: () -> [String] = { Locale.preferredLanguages }

    /// First launch follows the Mac: any Chinese system language gives the Chinese
    /// interface, everything else English (owner decision, 2026-10-11).
    static func defaultUILanguage(preferredLanguages: [String]) -> UILanguage {
        guard let first = preferredLanguages.first?.lowercased() else { return .chinese }
        return first.hasPrefix("zh") ? .chinese : .english
    }

    /// Stores the interface language once. Installs from before this setting followed the
    /// system keep the Chinese interface they already had; new installs take the system language.
    private static func resolveInitialUILanguageIfNeeded(
        into defaults: UserDefaults,
        snapshot: PreMigrationSnapshot
    ) {
        guard defaults.string(forKey: Key.uiLanguage) == nil else { return }
        let language: UILanguage = snapshot.hasExistingInstallEvidence
            ? .chinese
            : defaultUILanguage(preferredLanguages: preferredLanguagesProvider())
        defaults.set(language.rawValue, forKey: Key.uiLanguage)
    }

    private static func capturePreMigrationSnapshot(
        current: UserDefaults,
        legacy: UserDefaults?
    ) -> PreMigrationSnapshot {
        let currentHasPersistedKey = Key.persistedKeys.contains {
            current.object(forKey: $0) != nil
        }
        let legacyHasPersistedKey = legacy.map { legacyDefaults in
            Key.persistedKeys.contains { legacyDefaults.object(forKey: $0) != nil }
        } ?? false
        let hasExistingInstallEvidence =
            current.object(forKey: Key.hasMigratedLegacyDefaults) != nil ||
            currentHasPersistedKey ||
            legacyHasPersistedKey

        let currentExplicitFiller = current.object(forKey: Key.isFillerCleanupEnabled) as? Bool
        let legacyExplicitFiller = legacy?.object(forKey: Key.isFillerCleanupEnabled) as? Bool

        return PreMigrationSnapshot(
            hasExistingInstallEvidence: hasExistingInstallEvidence,
            effectiveOldFillerState:
                currentExplicitFiller ??
                legacyExplicitFiller ??
                hasExistingInstallEvidence
        )
    }

    private static func migrateLegacyDefaultsIfNeeded(
        into defaults: UserDefaults,
        from legacyDefaults: UserDefaults?
    ) {
        guard defaults.object(forKey: Key.hasMigratedLegacyDefaults) == nil else { return }

        if let legacyDefaults {
            for key in Key.persistedKeys where defaults.object(forKey: key) == nil {
                if let value = legacyDefaults.object(forKey: key) {
                    defaults.set(value, forKey: key)
                }
            }
        }
        defaults.set(true, forKey: Key.hasMigratedLegacyDefaults)
    }

    private static func migrateFillerCleanupSafetyIfNeeded(
        into defaults: UserDefaults,
        snapshot: PreMigrationSnapshot
    ) {
        guard defaults.integer(forKey: Key.fillerCleanupSafetyMigrationVersion) <
                currentFillerCleanupSafetyMigrationVersion else {
            return
        }

        // Existing installs are switched off by this safety migration. New installs start with
        // filler cleanup on (owner decision, 2026-10-11): the revised rules only remove
        // standalone pauses such as 嗯 / 呃 / um.
        defaults.set(!snapshot.hasExistingInstallEvidence, forKey: Key.isFillerCleanupEnabled)
        defaults.set(
            snapshot.hasExistingInstallEvidence && snapshot.effectiveOldFillerState,
            forKey: Key.fillerCleanupSafetyNoticePending
        )
        defaults.set(
            currentFillerCleanupSafetyMigrationVersion,
            forKey: Key.fillerCleanupSafetyMigrationVersion
        )
    }
}
