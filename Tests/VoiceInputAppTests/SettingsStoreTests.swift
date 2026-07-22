import Combine
import XCTest
@testable import VoiceInputApp

final class SettingsStoreTests: XCTestCase {
    func testDefaultsPreferQwenAndMixedLanguage() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = SettingsStore(defaults: defaults)

        XCTAssertEqual(store.engine, .qwenLocal)
        XCTAssertEqual(store.languageMode, .mixedChineseEnglish)
        XCTAssertEqual(store.appleSpeechLocaleIdentifier, "zh-CN")
        XCTAssertEqual(store.maxRecordingDuration, 180)
        XCTAssertEqual(store.uiLanguage, .chinese)
        XCTAssertEqual(store.appThemeID, .oscurange)
        XCTAssertEqual(store.selectedModelID, "qwen3-asr-0.6b")
        XCTAssertTrue(store.isSmartNumericFormattingEnabled)
        XCTAssertTrue(store.isFillerCleanupEnabled)
        XCTAssertFalse(store.isMathNotationEnabled)
        XCTAssertEqual(store.mathNotationOutputFormat, .latex)
        XCTAssertFalse(store.hasSeenReadinessSetupPrompt)
        XCTAssertNil(store.modelDownloadConsent(for: VoiceInputModel.qwen3ASR06B.modelID))
        XCTAssertFalse(store.isDebugRecordingCaptureEnabled)
        XCTAssertFalse(store.forceNextTranscriptionIssue)
        XCTAssertNil(store.selectedMicrophoneUID)
    }

    func testReadinessPromptVisibilityDoesNotImplyModelDownloadConsent() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = SettingsStore(defaults: defaults)

        store.hasSeenReadinessSetupPrompt = true

        XCTAssertNil(store.modelDownloadConsent(for: VoiceInputModel.qwen3ASR06B.modelID))
    }

    func testPersistsVersionedModelDownloadConsentPerModel() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = SettingsStore(defaults: defaults)
        let acceptedAt = Date(timeIntervalSince1970: 1_783_872_000)

        store.recordModelDownloadConsent(
            modelID: VoiceInputModel.qwen3ASR06B.modelID,
            disclosureVersion: 1,
            acceptedAt: acceptedAt
        )

        XCTAssertEqual(
            SettingsStore(defaults: defaults).modelDownloadConsent(for: VoiceInputModel.qwen3ASR06B.modelID),
            ModelDownloadConsent(
                modelID: VoiceInputModel.qwen3ASR06B.modelID,
                acceptedAt: acceptedAt,
                disclosureVersion: 1
            )
        )
        XCTAssertNil(store.modelDownloadConsent(for: VoiceInputModel.qwen3ASR17B.modelID))
    }

    func testPersistsEngineAndLocale() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = SettingsStore(defaults: defaults)

        store.engine = .appleSpeech
        store.languageMode = .english
        store.appleSpeechLocaleIdentifier = "en-US"

        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertEqual(reloaded.engine, .appleSpeech)
        XCTAssertEqual(reloaded.languageMode, .english)
        XCTAssertEqual(reloaded.appleSpeechLocaleIdentifier, "en-US")
    }

    func testEnginePostsChangeNotificationOnlyWhenValueChanges() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = SettingsStore(defaults: defaults)
        var observedEngines: [TranscriptionEngineKind] = []
        let observer = NotificationCenter.default.addObserver(
            forName: SettingsStore.engineDidChangeNotification,
            object: store,
            queue: nil
        ) { notification in
            guard let rawValue = notification.userInfo?[SettingsStore.engineUserInfoKey] as? String,
                  let engine = TranscriptionEngineKind(rawValue: rawValue) else {
                return
            }
            observedEngines.append(engine)
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        store.engine = .qwenLocal
        store.engine = .appleSpeech
        store.engine = .appleSpeech
        store.engine = .qwenLocal

        XCTAssertEqual(observedEngines, [.appleSpeech, .qwenLocal])
    }

    func testPersistsUILanguage() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = SettingsStore(defaults: defaults)

        store.uiLanguage = .english

        XCTAssertEqual(SettingsStore(defaults: defaults).uiLanguage, .english)
    }

    func testPersistsAppThemeIDAndFallsBackForInvalidValues() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = SettingsStore(defaults: defaults)

        store.appThemeID = .codex

        XCTAssertEqual(SettingsStore(defaults: defaults).appThemeID, .codex)

        defaults.set("missing-theme", forKey: "appThemeID")

        XCTAssertEqual(SettingsStore(defaults: defaults).appThemeID, .oscurange)
    }

    func testRemovedThemeValuesFallBackToOscurange() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!

        defaults.set("tokyo-night", forKey: "appThemeID")
        XCTAssertEqual(SettingsStore(defaults: defaults).appThemeID, .oscurange)

        defaults.set("catppuccin", forKey: "appThemeID")
        XCTAssertEqual(SettingsStore(defaults: defaults).appThemeID, .oscurange)
    }

    func testAppThemeIDPostsChangeNotificationOnlyWhenValueChanges() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = SettingsStore(defaults: defaults)
        var observedThemes: [AppThemeID] = []
        let observer = NotificationCenter.default.addObserver(
            forName: SettingsStore.appThemeDidChangeNotification,
            object: store,
            queue: nil
        ) { notification in
            guard let rawValue = notification.userInfo?[SettingsStore.appThemeIDUserInfoKey] as? String,
                  let themeID = AppThemeID(rawValue: rawValue) else {
                return
            }
            observedThemes.append(themeID)
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        store.appThemeID = .codex
        store.appThemeID = .codex
        store.appThemeID = .default

        XCTAssertEqual(observedThemes, [.codex, .default])
    }

    func testAppThemeIDPublishesObjectChangeForSwiftUIRefresh() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = SettingsStore(defaults: defaults)
        var changeCount = 0
        let cancellable = store.objectWillChange.sink {
            changeCount += 1
        }

        store.appThemeID = .codex
        store.appThemeID = .codex
        store.appThemeID = .default

        XCTAssertEqual(changeCount, 2)
        cancellable.cancel()
    }

    func testPersistsSelectedModelID() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = SettingsStore(defaults: defaults)

        store.selectedModelID = "qwen3-asr-1.7b"

        XCTAssertEqual(SettingsStore(defaults: defaults).selectedModelID, "qwen3-asr-1.7b")
    }

    func testSelectingQwenModelSwitchesEngineBackToLocalQwenEvenWhenModelIDIsUnchanged() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = SettingsStore(defaults: defaults)
        store.selectedModelID = "qwen3-asr-0.6b"
        store.engine = .appleSpeech

        store.selectedModelID = "qwen3-asr-0.6b"

        XCTAssertEqual(store.engine, .qwenLocal)
        XCTAssertEqual(SettingsStore(defaults: defaults).engine, .qwenLocal)
    }

    func testSelectedModelIDPostsChangeNotificationOnlyWhenValueChanges() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = SettingsStore(defaults: defaults)
        var observedModelIDs: [String] = []
        let observer = NotificationCenter.default.addObserver(
            forName: SettingsStore.selectedModelDidChangeNotification,
            object: store,
            queue: nil
        ) { notification in
            guard let modelID = notification.userInfo?[SettingsStore.selectedModelIDUserInfoKey] as? String else {
                return
            }
            observedModelIDs.append(modelID)
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        store.selectedModelID = "qwen3-asr-1.7b"
        store.selectedModelID = "qwen3-asr-1.7b"
        store.selectedModelID = "qwen3-asr-0.6b"

        XCTAssertEqual(observedModelIDs, ["qwen3-asr-1.7b", "qwen3-asr-0.6b"])
    }

    func testPersistsTranscriptionPreferences() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = SettingsStore(defaults: defaults)

        store.isSmartNumericFormattingEnabled = false
        store.isFillerCleanupEnabled = false
        store.isMathNotationEnabled = true
        store.mathNotationOutputFormat = .unicode
        store.hasSeenReadinessSetupPrompt = true

        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertFalse(reloaded.isSmartNumericFormattingEnabled)
        XCTAssertFalse(reloaded.isFillerCleanupEnabled)
        XCTAssertTrue(reloaded.isMathNotationEnabled)
        XCTAssertEqual(reloaded.mathNotationOutputFormat, .unicode)
        XCTAssertTrue(reloaded.hasSeenReadinessSetupPrompt)
    }

    func testHistoryDefaultsAndPersistence() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = SettingsStore(defaults: defaults)

        XCTAssertTrue(store.isHistoryEnabled)
        XCTAssertEqual(store.historyLimit, 100)

        store.isHistoryEnabled = false
        store.historyLimit = 25

        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertFalse(reloaded.isHistoryEnabled)
        XCTAssertEqual(reloaded.historyLimit, 25)
    }

    func testHistoryLimitClampsZeroAndNegativeValuesToOne() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = SettingsStore(defaults: defaults)

        store.historyLimit = 0
        XCTAssertEqual(store.historyLimit, 1)

        store.historyLimit = -10
        XCTAssertEqual(store.historyLimit, 1)
    }

    func testRecordingDurationClampsToSupportedRange() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = SettingsStore(defaults: defaults)

        store.maxRecordingDuration = 10
        XCTAssertEqual(store.maxRecordingDuration, 30)

        store.maxRecordingDuration = 900
        XCTAssertEqual(store.maxRecordingDuration, 600)

        store.maxRecordingDuration = 240
        XCTAssertEqual(SettingsStore(defaults: defaults).maxRecordingDuration, 240)
    }

    func testDebugRecordingCapturePersists() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = SettingsStore(defaults: defaults)

        store.isDebugRecordingCaptureEnabled = true

        XCTAssertTrue(SettingsStore(defaults: defaults).isDebugRecordingCaptureEnabled)
    }

    func testForceNextTranscriptionIssuePersists() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = SettingsStore(defaults: defaults)

        store.forceNextTranscriptionIssue = true

        XCTAssertTrue(SettingsStore(defaults: defaults).forceNextTranscriptionIssue)
    }

    func testMicrophoneSelectionPersistsAndClearsEmptyValue() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = SettingsStore(defaults: defaults)

        store.selectedMicrophoneUID = "mic-uid"
        XCTAssertEqual(SettingsStore(defaults: defaults).selectedMicrophoneUID, "mic-uid")

        store.selectedMicrophoneUID = ""
        XCTAssertNil(SettingsStore(defaults: defaults).selectedMicrophoneUID)
    }

    func testOnboardingCompletionFlagDefaultsFalseAndPersists() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = SettingsStore(defaults: defaults)

        XCTAssertFalse(store.hasCompletedOnboarding)

        store.hasCompletedOnboarding = true
        XCTAssertTrue(SettingsStore(defaults: defaults).hasCompletedOnboarding)
    }

    func testHistoryToggleNotifiesObserversOncePerChange() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = SettingsStore(defaults: defaults)

        var changeCount = 0
        let subscription = store.objectWillChange.sink { changeCount += 1 }
        defer { subscription.cancel() }

        store.isHistoryEnabled = false
        XCTAssertEqual(changeCount, 1)
        XCTAssertFalse(store.isHistoryEnabled)

        store.isHistoryEnabled = false
        XCTAssertEqual(changeCount, 1)

        store.isHistoryEnabled = true
        XCTAssertEqual(changeCount, 2)
        XCTAssertTrue(store.isHistoryEnabled)
    }
}
