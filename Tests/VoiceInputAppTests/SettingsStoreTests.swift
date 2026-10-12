import Combine
import XCTest
@testable import VoiceInputApp

final class SettingsStoreTests: XCTestCase {
    func testDefaultsPreferQwenAndMixedLanguage() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        // The interface language now follows the Mac on first launch; pin a Chinese system so
        // the remaining defaults are checked as before.
        let previousProvider = SettingsStore.preferredLanguagesProvider
        SettingsStore.preferredLanguagesProvider = { ["zh-Hans-GB"] }
        defer { SettingsStore.preferredLanguagesProvider = previousProvider }
        let store = SettingsStore(defaults: defaults)

        XCTAssertEqual(store.engine, .qwenLocal)
        XCTAssertEqual(store.languageMode, .mixedChineseEnglish)
        XCTAssertEqual(store.appleSpeechLocaleIdentifier, "zh-CN")
        XCTAssertEqual(store.maxRecordingDuration, 180)
        XCTAssertEqual(store.uiLanguage, .chinese)
        XCTAssertEqual(store.appThemeID, .flowtype)
        XCTAssertEqual(store.selectedModelID, "qwen3-asr-0.6b")
        XCTAssertTrue(store.isSmartNumericFormattingEnabled)
        XCTAssertFalse(store.isAcademicReferenceFormattingEnabled)
        // Was off for every install. Owner decision (2026-10-11): a fresh install starts with
        // filler cleanup on; existing installs keep the safety migration's off state (tests below).
        XCTAssertTrue(store.isFillerCleanupEnabled)
        XCTAssertFalse(store.isFillerCleanupSafetyNoticePending)
        XCTAssertEqual(defaults.integer(forKey: "fillerCleanupSafetyMigrationVersion"), 1)
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

        XCTAssertEqual(SettingsStore(defaults: defaults).appThemeID, .flowtype)
    }

    func testPersistsFlowtypeThemeAndReloadsIt() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = SettingsStore(defaults: defaults)

        // Flowtype is the default, so pick another theme first to make the write observable.
        store.appThemeID = .oscurange
        store.appThemeID = .flowtype

        XCTAssertEqual(SettingsStore(defaults: defaults).appThemeID, .flowtype)
        XCTAssertEqual(defaults.string(forKey: "appThemeID"), "flowtype")
    }

    func testRemovedThemeValuesFallBackToFlowtype() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!

        defaults.set("tokyo-night", forKey: "appThemeID")
        XCTAssertEqual(SettingsStore(defaults: defaults).appThemeID, .flowtype)

        defaults.set("catppuccin", forKey: "appThemeID")
        XCTAssertEqual(SettingsStore(defaults: defaults).appThemeID, .flowtype)
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
        store.isAcademicReferenceFormattingEnabled = true
        store.isFillerCleanupEnabled = false
        store.isMathNotationEnabled = true
        store.mathNotationOutputFormat = .unicode
        store.hasSeenReadinessSetupPrompt = true

        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertFalse(reloaded.isSmartNumericFormattingEnabled)
        XCTAssertTrue(reloaded.isAcademicReferenceFormattingEnabled)
        XCTAssertFalse(reloaded.isFillerCleanupEnabled)
        XCTAssertTrue(reloaded.isMathNotationEnabled)
        XCTAssertEqual(reloaded.mathNotationOutputFormat, .unicode)
        XCTAssertTrue(reloaded.hasSeenReadinessSetupPrompt)
    }

    func testExistingImplicitOnStateIsResetOffWithPendingNotice() {
        let defaults = isolatedDefaults(prefix: "current")
        defer { defaults.cleanup() }
        defaults.store.set(UILanguage.english.rawValue, forKey: "uiLanguage")

        let store = SettingsStore(defaults: defaults.store, legacyDefaults: nil)

        XCTAssertFalse(store.isFillerCleanupEnabled)
        XCTAssertTrue(store.isFillerCleanupSafetyNoticePending)
        XCTAssertEqual(defaults.store.integer(forKey: "fillerCleanupSafetyMigrationVersion"), 1)
    }

    func testPreV1StoredOffRemainsOffWithoutNotice() {
        let defaults = isolatedDefaults(prefix: "current")
        defer { defaults.cleanup() }
        defaults.store.set(false, forKey: "isFillerCleanupEnabled")

        let store = SettingsStore(defaults: defaults.store, legacyDefaults: nil)

        XCTAssertFalse(store.isFillerCleanupEnabled)
        XCTAssertFalse(store.isFillerCleanupSafetyNoticePending)
    }

    func testPreV1StoredOnIsResetOffWithPendingNotice() {
        let defaults = isolatedDefaults(prefix: "current")
        defer { defaults.cleanup() }
        defaults.store.set(true, forKey: "isFillerCleanupEnabled")

        let store = SettingsStore(defaults: defaults.store, legacyDefaults: nil)

        XCTAssertFalse(store.isFillerCleanupEnabled)
        XCTAssertTrue(store.isFillerCleanupSafetyNoticePending)
    }

    func testLegacyOnImportsBeforeSafetyReset() {
        let current = isolatedDefaults(prefix: "current")
        let legacy = isolatedDefaults(prefix: "legacy")
        defer {
            current.cleanup()
            legacy.cleanup()
        }
        legacy.store.set(true, forKey: "isFillerCleanupEnabled")
        legacy.store.set("qwen3-asr-1.7b", forKey: "selectedModelID")

        let store = SettingsStore(defaults: current.store, legacyDefaults: legacy.store)

        XCTAssertFalse(store.isFillerCleanupEnabled)
        XCTAssertTrue(store.isFillerCleanupSafetyNoticePending)
        XCTAssertEqual(store.selectedModelID, "qwen3-asr-1.7b")
    }

    func testLegacyOffImportsWithoutNotice() {
        let current = isolatedDefaults(prefix: "current")
        let legacy = isolatedDefaults(prefix: "legacy")
        defer {
            current.cleanup()
            legacy.cleanup()
        }
        legacy.store.set(false, forKey: "isFillerCleanupEnabled")

        let store = SettingsStore(defaults: current.store, legacyDefaults: legacy.store)

        XCTAssertFalse(store.isFillerCleanupEnabled)
        XCTAssertFalse(store.isFillerCleanupSafetyNoticePending)
    }

    func testCurrentExplicitOffWinsOverLegacyOn() {
        let current = isolatedDefaults(prefix: "current")
        let legacy = isolatedDefaults(prefix: "legacy")
        defer {
            current.cleanup()
            legacy.cleanup()
        }
        current.store.set(false, forKey: "isFillerCleanupEnabled")
        legacy.store.set(true, forKey: "isFillerCleanupEnabled")

        let store = SettingsStore(defaults: current.store, legacyDefaults: legacy.store)

        XCTAssertFalse(store.isFillerCleanupEnabled)
        XCTAssertFalse(store.isFillerCleanupSafetyNoticePending)
    }

    func testPendingNoticeSurvivesRepeatedInitializationUntilAcknowledged() {
        let defaults = isolatedDefaults(prefix: "current")
        defer { defaults.cleanup() }
        defaults.store.set(true, forKey: "isFillerCleanupEnabled")

        let first = SettingsStore(defaults: defaults.store, legacyDefaults: nil)
        let second = SettingsStore(defaults: defaults.store, legacyDefaults: nil)

        XCTAssertFalse(first.isFillerCleanupEnabled)
        XCTAssertTrue(second.isFillerCleanupSafetyNoticePending)
    }

    func testReEnablingAcknowledgesNoticeAndPersistsChoice() {
        let defaults = isolatedDefaults(prefix: "current")
        defer { defaults.cleanup() }
        defaults.store.set(true, forKey: "isFillerCleanupEnabled")
        let store = SettingsStore(defaults: defaults.store, legacyDefaults: nil)

        store.isFillerCleanupEnabled = true
        let reloaded = SettingsStore(defaults: defaults.store, legacyDefaults: nil)

        XCTAssertTrue(reloaded.isFillerCleanupEnabled)
        XCTAssertFalse(reloaded.isFillerCleanupSafetyNoticePending)
    }

    func testDismissingNoticeKeepsFeatureOffAndNeverReopensNotice() {
        let defaults = isolatedDefaults(prefix: "current")
        defer { defaults.cleanup() }
        defaults.store.set(true, forKey: "isFillerCleanupEnabled")
        let store = SettingsStore(defaults: defaults.store, legacyDefaults: nil)

        store.dismissFillerCleanupSafetyNotice()
        let reloaded = SettingsStore(defaults: defaults.store, legacyDefaults: nil)

        XCTAssertFalse(reloaded.isFillerCleanupEnabled)
        XCTAssertFalse(reloaded.isFillerCleanupSafetyNoticePending)
    }

    func testLegacyMigrationMarkerCountsAsExistingImplicitOnEvidence() {
        let defaults = isolatedDefaults(prefix: "current")
        defer { defaults.cleanup() }
        defaults.store.set(true, forKey: "hasMigratedVoiceInputDefaultsToFlowtype")

        let store = SettingsStore(defaults: defaults.store, legacyDefaults: nil)

        XCTAssertFalse(store.isFillerCleanupEnabled)
        XCTAssertTrue(store.isFillerCleanupSafetyNoticePending)
    }

    func testSmartNumericDoesNotImplicitlyEnableAcademicReferenceFormatting() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = SettingsStore(defaults: defaults)

        store.isSmartNumericFormattingEnabled = true

        XCTAssertFalse(store.isAcademicReferenceFormattingEnabled)
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

    private func isolatedDefaults(prefix: String) -> (
        store: UserDefaults,
        cleanup: () -> Void
    ) {
        let suiteName = "SettingsStoreTests.\(prefix).\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (
            defaults,
            { defaults.removePersistentDomain(forName: suiteName) }
        )
    }

    func testFirstLaunchInterfaceLanguageFollowsTheMac() {
        XCTAssertEqual(SettingsStore.defaultUILanguage(preferredLanguages: ["zh-Hans-CN", "en-GB"]), .chinese)
        XCTAssertEqual(SettingsStore.defaultUILanguage(preferredLanguages: ["zh-Hant-TW"]), .chinese)
        XCTAssertEqual(SettingsStore.defaultUILanguage(preferredLanguages: ["zh-HK"]), .chinese)
        XCTAssertEqual(SettingsStore.defaultUILanguage(preferredLanguages: ["en-GB", "zh-Hans"]), .english)
        XCTAssertEqual(SettingsStore.defaultUILanguage(preferredLanguages: ["ja-JP"]), .english)

        let previousProvider = SettingsStore.preferredLanguagesProvider
        SettingsStore.preferredLanguagesProvider = { ["en-US"] }
        defer { SettingsStore.preferredLanguagesProvider = previousProvider }

        let fresh = isolatedDefaults(prefix: "fresh")
        defer { fresh.cleanup() }
        XCTAssertEqual(SettingsStore(defaults: fresh.store, legacyDefaults: nil).uiLanguage, .english)

        // An install from before the setting existed keeps the Chinese interface it showed.
        let existing = isolatedDefaults(prefix: "existing")
        defer { existing.cleanup() }
        existing.store.set("qwenLocal", forKey: "engine")
        XCTAssertEqual(SettingsStore(defaults: existing.store, legacyDefaults: nil).uiLanguage, .chinese)

        // A stored choice always wins.
        let chosen = isolatedDefaults(prefix: "chosen")
        defer { chosen.cleanup() }
        chosen.store.set(UILanguage.chinese.rawValue, forKey: "uiLanguage")
        XCTAssertEqual(SettingsStore(defaults: chosen.store, legacyDefaults: nil).uiLanguage, .chinese)
    }
}
