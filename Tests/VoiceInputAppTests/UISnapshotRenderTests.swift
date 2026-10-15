import AppKit
import SwiftUI
import XCTest
@testable import VoiceInputApp

/// Offscreen UI snapshot harness.
///
/// Renders every Flowtype screen to PNG from synthetic fixture data without
/// launching the app and without showing a window, so the real SwiftUI/AppKit
/// output can be reviewed before and after a UI change.
///
///     FLOWTYPE_UI_SNAPSHOT_DIR=<dir> swift test --filter UISnapshotRenderTests
///
/// Output layout: `<dir>/<theme>-<language>-<size>/<screen>.png` plus
/// `<dir>/INDEX.md`. The test is skipped unless `FLOWTYPE_UI_SNAPSHOT_DIR` is
/// set, so the normal suite is unaffected.
///
/// Optional: `FLOWTYPE_UI_SNAPSHOT_FILTER` is a comma-separated list of
/// substrings matched against `<theme>-<language>-<size>/<screen>`; only
/// matching snapshots are rendered and `INDEX.md` is left untouched.
///
/// Optional: `FLOWTYPE_UI_SNAPSHOT_TEXT_SIZE` is `small`, `standard` or `large`
/// (the interface text size); it defaults to the app's default size.
///
/// Optional: `FLOWTYPE_UI_SNAPSHOT_PLAN=asset-library` renders the set used by the
/// launch-video asset library instead of the review set: each Flowtype Dawn
/// page in Chinese and English (`public-release/marketing/flowtype-asset-library`).
///
/// Always pass `--filter UISnapshotRenderTests` when the variable is set: the
/// harness redirects the process home directory, which would leak into any
/// other test running later in the same process.
///
/// Safety properties the harness relies on and asserts:
/// - Windows are created but never ordered front; the app is never activated.
/// - `CFFIXED_USER_HOME` points at a temporary sandbox before anything
///   resolves Application Support, and every store is injected with a file
///   inside that sandbox. Settings live in an in-memory `UserDefaults`
///   subclass; `UserDefaults.standard` is never used.
@MainActor
final class UISnapshotRenderTests: XCTestCase {
    func testRenderUISnapshots() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let outputPath = environment["FLOWTYPE_UI_SNAPSHOT_DIR"], !outputPath.isEmpty else {
            throw XCTSkip("Set FLOWTYPE_UI_SNAPSHOT_DIR=<dir> to render UI snapshots.")
        }
        let filters = (environment["FLOWTYPE_UI_SNAPSHOT_FILTER"] ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let textSizeModel = AppTextSizeModel.shared
        let previousTextSize = textSizeModel.size
        let textSizeName = environment["FLOWTYPE_UI_SNAPSHOT_TEXT_SIZE"] ?? AppTextSize.defaultSize.rawValue
        guard let textSize = AppTextSize(rawValue: textSizeName) else {
            XCTFail("FLOWTYPE_UI_SNAPSHOT_TEXT_SIZE must be small, standard or large.")
            return
        }
        textSizeModel.size = textSize
        defer { textSizeModel.size = previousTextSize }

        let renderer = try SnapshotRenderer(
            outputRoot: URL(fileURLWithPath: outputPath, isDirectory: true).standardizedFileURL,
            filters: filters
        )
        defer { renderer.tearDown() }
        switch environment["FLOWTYPE_UI_SNAPSHOT_PLAN"] ?? "review" {
        case "review":
            try renderer.renderAll()
        case "asset-library":
            try renderer.renderAssetLibrary()
        default:
            XCTFail("FLOWTYPE_UI_SNAPSHOT_PLAN must be review or asset-library.")
            return
        }

        XCTAssertFalse(renderer.rendered.isEmpty, "No snapshot matched the filter.")
        XCTAssertTrue(renderer.problems.isEmpty, renderer.problems.joined(separator: "\n"))
        XCTAssertFalse(NSApp.isActive, "The snapshot harness must never activate the app.")
        XCTAssertTrue(
            NSApp.windows.allSatisfy { !$0.isVisible },
            "The snapshot harness must never show a window."
        )
        print("UI snapshots: wrote \(renderer.rendered.count) files to \(renderer.outputRoot.path)")
    }
}

// MARK: - Variants and screens

private struct SnapshotVariant {
    let theme: AppThemeID
    /// Only meaningful for the default theme, which follows the system
    /// appearance in the app; the harness pins it instead.
    let appearance: NSAppearance.Name?
    let language: UILanguage
    /// Main-window frame size; nil for surfaces that have their own fixed size.
    let size: NSSize?

    var directoryName: String {
        var parts = [theme.rawValue]
        if let appearance {
            parts.append(appearance == .aqua ? "light" : "dark")
        }
        parts.append(language == .chinese ? "zh" : "en")
        if let size {
            parts.append("\(Int(size.width))x\(Int(size.height))")
        } else {
            parts.append("natural")
        }
        return parts.joined(separator: "-")
    }

    static let minimumSize = NSSize(width: 1100, height: 680)
    static let comfortableSize = NSSize(width: 1440, height: 900)
}

private enum LargeModelFixture {
    case installed
    case downloading
    case notInstalled
}

private enum ReadinessFixture {
    case ready
    case needsAttention
}

private struct FixtureOptions {
    var hasHistory = true
    /// History with failed, possibly truncated and recovered rows (QA of those row styles).
    var historyShowsIssues = false
    var hasUsageStats = true
    var hasHotwords = true
    var largeModel: LargeModelFixture = .installed
    var readiness: ReadinessFixture = .ready
}

private enum MainScreen: CaseIterable {
    case home
    case homeEmpty
    case homeNeedsAttention
    case dictionary
    case dictionaryEmpty
    case dictionaryNoResults
    case models
    case modelsDownloading
    case modelsNotInstalled
    case readiness
    case readinessNeedsAttention
    case readinessExpanded
    case preferences

    var fileName: String {
        switch self {
        case .home: return "main-home"
        case .homeEmpty: return "main-home-empty"
        case .homeNeedsAttention: return "main-home-needs-attention"
        case .dictionary: return "main-dictionary"
        case .dictionaryEmpty: return "main-dictionary-empty"
        case .dictionaryNoResults: return "main-dictionary-no-results"
        case .models: return "main-models"
        case .modelsDownloading: return "main-models-downloading"
        case .modelsNotInstalled: return "main-models-not-installed"
        case .readiness: return "main-readiness"
        case .readinessNeedsAttention: return "main-readiness-needs-attention"
        case .readinessExpanded: return "main-readiness-expanded"
        case .preferences: return "main-preferences"
        }
    }

    var section: MainWindowSection {
        switch self {
        case .home, .homeEmpty, .homeNeedsAttention: return .home
        case .dictionary, .dictionaryEmpty, .dictionaryNoResults: return .dictionary
        case .models, .modelsDownloading, .modelsNotInstalled: return .models
        case .readiness, .readinessNeedsAttention, .readinessExpanded: return .readiness
        case .preferences: return .preferences
        }
    }

    var options: FixtureOptions {
        var options = FixtureOptions()
        switch self {
        case .homeEmpty:
            options.hasHistory = false
            options.hasUsageStats = false
        case .homeNeedsAttention:
            options.readiness = .needsAttention
            options.historyShowsIssues = true
        case .readinessNeedsAttention:
            options.readiness = .needsAttention
        case .dictionaryEmpty:
            options.hasHotwords = false
        case .modelsDownloading:
            options.largeModel = .downloading
        case .modelsNotInstalled:
            options.largeModel = .notInstalled
        case .home, .dictionary, .dictionaryNoResults, .models, .readiness, .readinessExpanded, .preferences:
            break
        }
        return options
    }

    var summary: String {
        switch self {
        case .home:
            return "Home: usage stat cards (19,289 dictations, 55 h 29 min, 880,000 characters, 219 h 47 min saved) and history across today, yesterday and earlier, including a long multi-line transcript, a recoverable failed attempt, a possibly truncated item, a recovered item and short items."
        case .homeEmpty:
            return "Home empty state: no history and zero usage stats."
        case .homeNeedsAttention:
            return "Home with the prominent readiness card (Microphone permission missing, selected model not installed)."
        case .dictionary:
            return "Dictionary with 30 hotwords: names, places and terms in several languages."
        case .dictionaryEmpty:
            return "Dictionary empty state: no hotwords."
        case .dictionaryNoResults:
            return "Dictionary with a search query that matches nothing."
        case .models:
            return "Models: daily model installed and in use, large model installed."
        case .modelsDownloading:
            return "Models: daily model in use, large model downloading (42%)."
        case .modelsNotInstalled:
            return "Models: daily model in use, large model not installed."
        case .readiness:
            return "Readiness in the all-ready state."
        case .readinessNeedsAttention:
            return "Readiness needs attention: Microphone permission missing and selected model not installed."
        case .readinessExpanded:
            return "Readiness in the all-ready state with the check-details and advanced-diagnostics disclosure groups expanded."
        case .preferences:
            return "Preferences (transcription and appearance)."
        }
    }

    /// Every screen is rendered for the primary (oscurange, Chinese) variants;
    /// secondary variants pick a subset in `renderAll`.
    static let primary = MainScreen.allCases
}

private struct RenderedSnapshot {
    let directory: String
    let file: String
    let pixelSize: NSSize
    let summary: String
}

// MARK: - Renderer

@MainActor
private final class SnapshotRenderer {
    let outputRoot: URL
    private let filters: [String]
    private let sandbox: URL
    private var fixtures: [FixtureEnvironment] = []
    /// Keeps every controller alive until the run finishes so no window is
    /// closed mid-run (closing would run the app's close handlers).
    private var retained: [AnyObject] = []
    private(set) var rendered: [RenderedSnapshot] = []
    private(set) var problems: [String] = []

    init(outputRoot: URL, filters: [String]) throws {
        self.outputRoot = outputRoot
        self.filters = filters

        // Resource lookups in the app fall back to "Resources/<name>" relative
        // to the working directory when Bundle.main (the test runner here)
        // does not contain them, so run from the package root.
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        FileManager.default.changeCurrentDirectoryPath(packageRoot.path)
        for resource in [
            "Resources/HomeCardArtwork-mic.png",
            "Resources/HomeCardArtwork-wave.png",
            "Resources/HomeCardArtwork-docs.png",
            "Resources/HomeCardArtwork-clock.png",
            "Resources/HomeCardArtwork-mic-light.png",
            "Resources/HomeCardArtwork-wave-light.png",
            "Resources/HomeCardArtwork-docs-light.png",
            "Resources/HomeCardArtwork-clock-light.png",
            "Resources/FlowtypeBackdrop-topLeading.png",
            "Resources/FlowtypeBackdrop-bottomTrailing.png",
            "Resources/Flowtype-logo.svg",
            "Resources/Qwen-logo.svg"
        ] {
            guard NSImage(contentsOfFile: resource) != nil else {
                throw SnapshotError("Missing bundled image \(resource); snapshots would use fallback artwork.")
            }
        }

        // Redirect the home directory so nothing can touch the real
        // Application Support folder, then prove the redirect took effect.
        sandbox = FileManager.default.temporaryDirectory
            .appendingPathComponent("flowtype-ui-snapshots-\(UUID().uuidString)", isDirectory: true)
            .standardizedFileURL
        try FileManager.default.createDirectory(at: sandbox, withIntermediateDirectories: true)
        setenv("CFFIXED_USER_HOME", sandbox.path, 1)
        guard let applicationSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .standardizedFileURL,
            applicationSupport.path.hasPrefix(sandbox.path)
        else {
            throw SnapshotError("Could not sandbox Application Support; refusing to render.")
        }

        try FileManager.default.createDirectory(at: outputRoot, withIntermediateDirectories: true)
    }

    func tearDown() {
        KeyWindowEmulation.uninstall()
    }

    // MARK: Plan

    func renderAll() throws {
        let primaryVariants = [SnapshotVariant.minimumSize, SnapshotVariant.comfortableSize].map {
            SnapshotVariant(theme: .oscurange, appearance: nil, language: .chinese, size: $0)
        }
        for variant in primaryVariants {
            for screen in MainScreen.primary {
                try renderMainWindow(screen, variant: variant, includeFullHeight: true)
            }
        }

        let natural = SnapshotVariant(theme: .oscurange, appearance: nil, language: .chinese, size: nil)
        try renderSettingsWindow(variant: natural)
        try renderHelpWindow(variant: natural)
        try renderOnboarding(variant: natural)
        try renderCapsule(variant: natural)

        let flowtypeVariants = [SnapshotVariant.minimumSize, SnapshotVariant.comfortableSize].map {
            SnapshotVariant(theme: .flowtype, appearance: nil, language: .chinese, size: $0)
        }
        for variant in flowtypeVariants {
            for screen in MainScreen.primary {
                try renderMainWindow(screen, variant: variant, includeFullHeight: true)
            }
        }

        let flowtypeNatural = SnapshotVariant(theme: .flowtype, appearance: nil, language: .chinese, size: nil)
        try renderSettingsWindow(variant: flowtypeNatural)
        try renderHelpWindow(variant: flowtypeNatural)
        try renderOnboarding(variant: flowtypeNatural)
        try renderCapsule(variant: flowtypeNatural)
        try renderAccentStrip(variant: flowtypeNatural)

        let secondary: [(SnapshotVariant, [MainScreen])] = [
            (
                SnapshotVariant(theme: .codex, appearance: nil, language: .chinese, size: SnapshotVariant.comfortableSize),
                [.home, .models]
            ),
            (
                SnapshotVariant(theme: .default, appearance: .darkAqua, language: .chinese, size: SnapshotVariant.comfortableSize),
                [.home, .preferences]
            ),
            (
                SnapshotVariant(theme: .default, appearance: .aqua, language: .chinese, size: SnapshotVariant.comfortableSize),
                [.home, .preferences]
            ),
            (
                SnapshotVariant(theme: .oscurange, appearance: nil, language: .english, size: SnapshotVariant.comfortableSize),
                [.home, .preferences]
            ),
            (
                SnapshotVariant(theme: .flowtype, appearance: nil, language: .english, size: SnapshotVariant.comfortableSize),
                [.home, .preferences]
            )
        ]
        for (variant, screens) in secondary {
            for screen in screens {
                try renderMainWindow(screen, variant: variant, includeFullHeight: false)
            }
        }

        if filters.isEmpty {
            try writeIndex()
        }
    }

    /// Launch-video asset library: each Flowtype Dawn page as it first opens, Chinese and English,
    /// at the comfortable window size. Curated and renamed afterwards by the library's build script.
    func renderAssetLibrary() throws {
        let pages: [MainScreen] = [.home, .dictionary, .models, .readiness, .preferences]
        for language in [UILanguage.chinese, .english] {
            let window = SnapshotVariant(theme: .flowtype, appearance: nil, language: language, size: SnapshotVariant.comfortableSize)
            for screen in pages {
                try renderMainWindow(screen, variant: window, includeFullHeight: false)
            }
            let natural = SnapshotVariant(theme: .flowtype, appearance: nil, language: language, size: nil)
            try renderSettingsWindow(variant: natural)
            try renderHelpWindow(variant: natural)
            try renderOnboarding(variant: natural)
            try renderCapsule(variant: natural)
        }
        if filters.isEmpty {
            try writeIndex()
        }
    }

    private func wants(_ variant: SnapshotVariant, _ names: String...) -> Bool {
        guard !filters.isEmpty else { return true }
        return names.contains { name in
            let path = "\(variant.directoryName)/\(name)"
            return filters.contains { path.contains($0) }
        }
    }

    // MARK: Main window

    private func renderMainWindow(
        _ screen: MainScreen,
        variant: SnapshotVariant,
        includeFullHeight: Bool
    ) throws {
        let name = screen.fileName
        let closeUpName = "sidebar-closeup"
        let wantsCloseUp = screen == .home && includeFullHeight && wants(variant, closeUpName)
        guard wants(variant, name, "\(name)-full") || wantsCloseUp else { return }
        guard let size = variant.size else { return }

        let fixture = try makeFixture(variant: variant, options: screen.options)
        let controller = MainWindowController(
            hotwordStore: fixture.hotwordStore,
            historyStore: fixture.historyStore,
            usageStatsStore: fixture.usageStatsStore,
            settingsStore: fixture.settingsStore,
            modelManager: fixture.modelManager,
            initialReadinessSnapshot: fixture.readinessSnapshot,
            actions: fixture.mainWindowActions
        )
        retained.append(controller)
        guard let window = controller.window else {
            throw SnapshotError("MainWindowController has no window.")
        }
        prepare(window, variant: variant)
        window.setFrame(NSRect(origin: .zero, size: size), display: false)
        controller.state.show(screen.section)
        settle()

        if screen == .dictionaryNoResults {
            let placeholder = AppCopy.texts(for: variant.language).searchHotwordsPlaceholder
            if !typeText("zzzz", intoFieldWithPlaceholder: placeholder, in: window) {
                problems.append("\(variant.directoryName)/\(name): could not drive the search field offscreen.")
            }
            settle(0.3)
        }
        if screen == .readinessExpanded {
            if pressAll(role: .disclosureTriangle, in: window) == 0 {
                problems.append("\(variant.directoryName)/\(name): could not expand the disclosure groups offscreen.")
            }
            settle(0.4)
        }

        let frameView = try frameView(of: window)
        let bitmap = try capture(frameView)
        if wants(variant, name) {
            try write(bitmap, variant: variant, name: name, summary: screen.summary)
        }
        if wantsCloseUp {
            let closeUp = try crop(bitmap, toLeadingPoints: 232)
            try write(
                closeUp,
                variant: variant,
                name: closeUpName,
                summary: "Sidebar close-up cropped from main-home (window chrome, brand row, five sections with Home selected, Settings and Help rows)."
            )
        }
        if includeFullHeight, wants(variant, "\(name)-full"), expandToFullContentHeight(window) {
            let fullBitmap = try capture(frameView)
            try write(
                fullBitmap,
                variant: variant,
                name: "\(name)-full",
                summary: "Same as \(name) with the window stretched vertically so the whole scrolling page is visible (review aid; not a real window size)."
            )
        }
    }

    // MARK: Secondary windows

    private func renderSettingsWindow(variant: SnapshotVariant) throws {
        let name = "settings-window"
        guard wants(variant, name, "\(name)-full") else { return }
        let fixture = try makeFixture(variant: variant, options: FixtureOptions())
        let controller = SettingsWindowController(
            settingsStore: fixture.settingsStore,
            usageStatsStore: fixture.usageStatsStore
        )
        retained.append(controller)
        guard let window = controller.window else {
            throw SnapshotError("SettingsWindowController has no window.")
        }
        prepare(window, variant: variant)
        settle()
        try captureWindow(
            window,
            variant: variant,
            name: name,
            summary: "Settings window (devices, storage and privacy) at its fixed 720x560 content size, with window chrome."
        )

        // Onboarding can switch the language while this window already exists; it must
        // follow instead of keeping the language it was built with (owner report, 2026-10-11).
        let externalName = "settings-window-after-onboarding-switch"
        guard wants(variant, externalName) else { return }
        fixture.settingsStore.uiLanguage = variant.language == .chinese ? .english : .chinese
        controller.reloadFromStore()
        settle()
        try captureWindow(
            window,
            variant: variant,
            name: externalName,
            summary: "Same Settings window after the interface language was switched elsewhere (as on the onboarding welcome page) and the window reloaded."
        )
    }

    private func renderHelpWindow(variant: SnapshotVariant) throws {
        let name = "help-window"
        guard wants(variant, name, "\(name)-full", "\(name)-english") else { return }
        let fixture = try makeFixture(variant: variant, options: FixtureOptions())
        let controller = HelpWindowController(settingsStore: fixture.settingsStore)
        retained.append(controller)
        // One problem open, as a user would see it after clicking it.
        controller.loadContent(expandedProblemID: "paste")
        guard let window = controller.window else {
            throw SnapshotError("HelpWindowController has no window.")
        }
        prepare(window, variant: variant)
        settle()
        try captureWindow(
            window,
            variant: variant,
            name: name,
            summary: "Help window at its default 680x680 content size: basics, common problems with the paste entry expanded, diagnostics."
        )

        guard wants(variant, "\(name)-english") else { return }
        fixture.settingsStore.uiLanguage = variant.language == .chinese ? .english : .chinese
        controller.loadContent(expandedProblemID: "paste")
        settle()
        try captureWindow(
            window,
            variant: variant,
            name: "\(name)-english",
            summary: "Same Help window in the other interface language."
        )
    }

    private func captureWindow(
        _ window: NSWindow,
        variant: SnapshotVariant,
        name: String,
        summary: String
    ) throws {
        let frameView = try frameView(of: window)
        if wants(variant, name) {
            try write(try capture(frameView), variant: variant, name: name, summary: summary)
        }
        if wants(variant, "\(name)-full"), expandToFullContentHeight(window) {
            try write(
                try capture(frameView),
                variant: variant,
                name: "\(name)-full",
                summary: "Same as \(name) with the window stretched vertically so the whole scrolling page is visible (review aid; not a real window size)."
            )
        }
    }

    private func renderOnboarding(variant: SnapshotVariant) throws {
        let names = [
            "onboarding-1-welcome",
            // Index 1 onward is unchanged; the English welcome shot is taken inline.
            "onboarding-2-prepare",
            "onboarding-2-prepare-downloading",
            "onboarding-2-prepare-ready",
            "onboarding-3-hold-fn",
            "onboarding-4-practice",
            "onboarding-4-practice-listening",
            "onboarding-4-practice-too-short",
            "onboarding-4-practice-success",
            "onboarding-5-features",
            "onboarding-5-features-math-on"
        ]
        guard names.contains(where: { wants(variant, $0) }) else { return }

        let fixture = try makeFixture(variant: variant, options: FixtureOptions())
        let copy = AppCopy.texts(for: variant.language)
        let model = VoiceInputModel.model(for: fixture.settingsStore.selectedModelID)
        let permissions = PermissionBox()
        let gate = PreparationGate()
        let readyReport = fixture.readinessSnapshot.report
        let readyContext = fixture.readinessSnapshot.context

        let practice = PracticeListenerBox()
        var actions = OnboardingActions()
        actions.permissionSnapshot = { permissions.snapshot }
        actions.setPracticeListener = { practice.listener = $0 }
        actions.prepareFlowtype = { _, _, report in
            await MainActor.run {
                permissions.snapshot = PermissionSnapshot(
                    microphone: .granted,
                    accessibility: .granted,
                    speechRecognition: .unknown
                )
                report(PreparationSnapshot(
                    runID: UUID(),
                    operationID: nil,
                    configuration: PreparationConfiguration(
                        engine: .qwenLocal,
                        modelID: model.modelID,
                        runtimeRevision: "ui-snapshot-fixture",
                        generation: 1
                    ),
                    stage: .downloadingModel,
                    progress: 0.42,
                    transfer: DownloadTransferSnapshot(
                        operationID: "ui-snapshot-fixture",
                        downloadedBytes: 798_000_000,
                        totalBytes: 1_900_000_000,
                        updatedAt: Date().timeIntervalSince1970,
                        source: "modelscope"
                    )
                ))
            }
            await gate.wait()
            return ReadinessSetupResult(outcome: .prepared, report: readyReport, verifiedContext: readyContext)
        }

        let controller = OnboardingWindowController(settingsStore: fixture.settingsStore, actions: actions)
        // Freeze the hold-Fn loop mid-press (key down 1.5 s, capsule listening, ring part filled).
        controller.illustrationStillTime = 2.9
        retained.append(controller)
        controller.loadContent()
        guard let window = controller.window else {
            throw SnapshotError("OnboardingWindowController has no window.")
        }
        prepare(window, variant: variant)
        settle()
        let frameView = try frameView(of: window)

        func shoot(_ name: String, _ summary: String) throws {
            guard wants(variant, name) else { return }
            try write(try capture(frameView), variant: variant, name: name, summary: summary)
        }
        func press(_ title: String, before name: String) -> Bool {
            if pressButton(titled: title, in: window) {
                settle(0.4)
                return true
            }
            problems.append("\(variant.directoryName)/\(name): could not press \"\(title)\" offscreen.")
            return false
        }

        func send(_ event: OnboardingPracticeEvent, before name: String) -> Bool {
            guard let listener = practice.listener else {
                problems.append("\(variant.directoryName)/\(name): the practice page did not register a listener.")
                return false
            }
            listener(event)
            settle(0.3)
            return true
        }

        try shoot(names[0], "Onboarding step 1 of 5: welcome with the speak, recognise, paste pictures.")
        if wants(variant, "onboarding-1-welcome-english") {
            // The language switch is a custom-drawn picker the offscreen button search can't press;
            // set the stored language the way the picker does.
            fixture.settingsStore.uiLanguage = .english
            fixture.settingsStore.objectWillChange.send()
            settle(0.3)
            try shoot("onboarding-1-welcome-english", "Onboarding step 1 of 5 with the language switched to English.")
            fixture.settingsStore.uiLanguage = variant.language
            fixture.settingsStore.objectWillChange.send()
            settle(0.3)
        }
        guard press(copy.onboardingContinueTitle, before: names[1]) else { return }
        try shoot(names[1], "Onboarding step 2 of 5: prepare, before starting (permissions not yet granted).")
        guard press(copy.readinessPrepareFlowtypeTitle, before: names[2]) else { return }
        try shoot(names[2], "Onboarding step 2 of 5: prepare, model download in progress (42%) with the download route and VPN hint.")
        gate.open()
        settle(0.4)
        try shoot(names[3], "Onboarding step 2 of 5: prepare finished, ready to continue.")
        guard press(copy.onboardingContinueTitle, before: names[4]) else { return }
        try shoot(names[4], "Onboarding step 3 of 5: hold Fn, animation frozen mid-press, right and wrong press timelines.")
        guard press(copy.onboardingContinueTitle, before: names[5]) else { return }
        try shoot(names[5], "Onboarding step 4 of 5: practice, waiting for Fn.")
        guard send(.listening, before: names[6]) else { return }
        try shoot(names[6], "Onboarding step 4 of 5: practice while Fn is held.")
        guard send(.tooShort, before: names[7]) else { return }
        try shoot(names[7], "Onboarding step 4 of 5: practice after a tap that was too short.")
        let sample = variant.language == .chinese ? "今天天气不错。" : "The weather is nice today."
        guard send(.result(sample), before: names[8]) else { return }
        try shoot(names[8], "Onboarding step 4 of 5: practice succeeded, text shown in the window.")
        guard press(copy.onboardingContinueTitle, before: names[9]) else { return }
        try shoot(names[9], "Onboarding step 5 of 5: feature switches with their defaults.")
        fixture.settingsStore.isMathNotationEnabled = true
        fixture.settingsStore.objectWillChange.send()
        settle(0.3)
        try shoot(names[10], "Onboarding step 5 of 5: math notation switched on, output format picker shown.")
        fixture.settingsStore.isMathNotationEnabled = false
    }

    // MARK: Capsule

    private func renderCapsule(variant: SnapshotVariant) throws {
        let copy = AppCopy.texts(for: variant.language)
        // Strings mirror what AppDelegate passes to the capsule today.
        let shots: [(String, CapsulePresentation, Double?, String)] = [
            ("capsule-listening", .listening(copy.capsuleListening), 0.62, "Recording capsule while listening (waveform at a mid audio level)."),
            ("capsule-countdown", .listeningCountdown(copy.capsuleSecondsLeft(15)), 0.62, "Recording capsule near the time limit (live waveform in the warning colour)."),
            ("capsule-transcribing", .transcribing(copy.capsuleTranscribing), nil, "Recording capsule while transcribing (three dots at rest; the bounce is not visible in a still)."),
            ("capsule-status", .status(copy.noTranscriptYet), nil, "Recording capsule showing a status message."),
            ("capsule-no-speech", .noSpeech(copy.capsuleNoSpeechDetected), nil, "Recording capsule when the recording held no speech (muted-microphone chip)."),
            ("capsule-failure", .failure(copy.capsuleRecoverableTranscriptionFailed), nil, "Recording capsule showing a recoverable failure."),
            ("capsule-failure-permission", .failure(copy.capsuleMicrophonePermissionRequired), nil, "Recording capsule showing a permission failure.")
        ]
        guard shots.contains(where: { wants(variant, $0.0) }) else { return }

        let capsule = FloatingCapsulePanel()
        // Pin the theme so the capsule never reads the test process's user defaults.
        capsule.themeProvider = { AppTheme.theme(for: variant.theme) }
        retained.append(capsule)
        for (name, presentation, level, summary) in shots where wants(variant, name) {
            guard let contentView = capsule.layoutOffscreen(presentation) else {
                throw SnapshotError("The capsule panel has no content view.")
            }
            if let level {
                capsule.updateAudioLevel(level)
            }
            settle(0.25)
            let bitmap = try capture(contentView)
            try write(
                try compositeCapsule(bitmap),
                variant: variant,
                name: name,
                summary: summary + " Placed on a flat dark backdrop. The body shows AppKit's flat grey fallback because the live HUD blur material needs an on-screen window; the real capsule is darker and translucent."
            )
        }
    }

    /// The accent-painted controls side by side on a white card, for comparing accent variants.
    private func renderAccentStrip(variant: SnapshotVariant) throws {
        let name = "accent-strip"
        guard wants(variant, name) else { return }
        let size = NSSize(width: 760, height: 150)
        let host = NSHostingView(rootView: AccentStripView(theme: AppTheme.theme(for: variant.theme)))
        host.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        window.appearance = NSAppearance(named: .aqua)
        retained.append(window)
        KeyWindowEmulation.apply(to: window)
        settle(0.3)
        try write(
            try capture(host),
            variant: variant,
            name: name,
            summary: "The accent-painted controls on a white card: prominent and neutral buttons, segmented picker, progress bar, switches on and off, and the in-use badge."
        )
    }

    /// The capsule is a borderless, transparent panel. Place the capture on a
    /// padded dark backdrop so its outline is visible in the PNG.
    private func compositeCapsule(_ capsule: NSBitmapImageRep) throws -> NSBitmapImageRep {
        let padding: CGFloat = 24
        let size = NSSize(width: capsule.size.width + padding * 2, height: capsule.size.height + padding * 2)
        let canvas = try makeBitmap(pointSize: size)
        guard let context = NSGraphicsContext(bitmapImageRep: canvas) else {
            throw SnapshotError("Could not create a drawing context.")
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        NSColor(calibratedWhite: 0.08, alpha: 1).setFill()
        NSRect(origin: .zero, size: size).fill()
        capsule.draw(
            in: NSRect(x: padding, y: padding, width: capsule.size.width, height: capsule.size.height),
            from: .zero,
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: false,
            hints: nil
        )
        NSGraphicsContext.restoreGraphicsState()
        return canvas
    }

    // MARK: Window helpers

    private func makeFixture(variant: SnapshotVariant, options: FixtureOptions) throws -> FixtureEnvironment {
        let fixture = try FixtureEnvironment(
            directory: sandbox.appendingPathComponent("fixture-\(fixtures.count)", isDirectory: true),
            variant: variant,
            options: options
        )
        fixtures.append(fixture)
        return fixture
    }

    private func prepare(_ window: NSWindow, variant: SnapshotVariant) {
        if let appearance = variant.appearance {
            // The default theme leaves `window.appearance` nil so the app
            // follows the system; pin it to render both appearances.
            window.appearance = NSAppearance(named: appearance)
        }
        KeyWindowEmulation.apply(to: window)
    }

    private func frameView(of window: NSWindow) throws -> NSView {
        guard let frameView = window.contentView?.superview else {
            throw SnapshotError("Window has no frame view.")
        }
        return frameView
    }

    /// Grows the window so the tallest scroll view shows its whole document.
    /// Returns false when nothing scrolls.
    private func expandToFullContentHeight(_ window: NSWindow) -> Bool {
        var didExpand = false
        for _ in 0..<4 {
            guard let contentView = window.contentView else { break }
            contentView.layoutSubtreeIfNeeded()
            let overflow = verticalOverflow(in: contentView)
            guard overflow > 1 else { break }
            var frame = window.frame
            frame.size.height = min(frame.height + ceil(overflow), 6000)
            guard frame.height > window.frame.height else { break }
            window.setFrame(frame, display: false)
            didExpand = true
            settle(0.35)
        }
        return didExpand
    }

    private func verticalOverflow(in view: NSView) -> CGFloat {
        var overflow: CGFloat = 0
        if let scrollView = view as? NSScrollView, let document = scrollView.documentView {
            overflow = document.frame.height - scrollView.contentView.bounds.height
        }
        for subview in view.subviews {
            overflow = max(overflow, verticalOverflow(in: subview))
        }
        return overflow
    }

    private func settle(_ seconds: TimeInterval = 0.6) {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
        }
    }

    // MARK: Offscreen interaction

    /// Presses a SwiftUI button through the accessibility tree, which works
    /// without the window being on screen.
    private func pressButton(titled title: String, in window: NSWindow) -> Bool {
        enableAccessibilityTree()
        guard let contentView = window.contentView,
              let button = findAccessibilityElement(in: contentView, where: { element in
                  let role = element.accessibilityRole?()
                  let label = element.accessibilityLabel?()
                  let elementTitle = element.accessibilityTitle?()
                  return role == .button && (label == title || elementTitle == title)
              })
        else { return false }
        return button.accessibilityPerformPress?() ?? false
    }

    /// Presses every accessibility element with `role`; returns how many
    /// accepted the press.
    private func pressAll(role: NSAccessibility.Role, in window: NSWindow) -> Int {
        enableAccessibilityTree()
        guard let contentView = window.contentView else { return 0 }
        var matches: [AnyObject] = []
        _ = findAccessibilityElement(in: contentView, where: { element in
            if element.accessibilityRole?() == role {
                matches.append(element)
            }
            return false
        })
        return matches.filter { $0.accessibilityPerformPress?() ?? false }.count
    }

    /// SwiftUI only builds its accessibility tree once an assistive client is
    /// present, so announce one for this test process.
    private func enableAccessibilityTree() {
        NSApp.accessibilitySetValue(
            true,
            forAttribute: NSAccessibility.Attribute(rawValue: "AXEnhancedUserInterface")
        )
        settle(0.2)
    }

    /// SwiftUI's accessibility nodes are plain Objective-C objects that do not
    /// formally adopt `NSAccessibilityProtocol`, so message them dynamically.
    private func findAccessibilityElement(
        in root: Any,
        depth: Int = 0,
        where predicate: (AnyObject) -> Bool
    ) -> AnyObject? {
        guard depth < 80 else { return nil }
        let element = root as AnyObject
        if predicate(element) { return element }
        for child in element.accessibilityChildren?() ?? [] {
            if let match = findAccessibilityElement(in: child, depth: depth + 1, where: predicate) {
                return match
            }
        }
        return nil
    }

    /// Sets the text of the AppKit field backing a SwiftUI `TextField` and
    /// notifies its delegate the way the field editor would.
    private func typeText(_ text: String, intoFieldWithPlaceholder placeholder: String, in window: NSWindow) -> Bool {
        guard let contentView = window.contentView,
              let field = findTextField(in: contentView, placeholder: placeholder)
        else { return false }
        field.stringValue = text
        let notification = Notification(name: NSControl.textDidChangeNotification, object: field)
        field.delegate?.controlTextDidChange?(notification)
        NotificationCenter.default.post(notification)
        return true
    }

    private func findTextField(in view: NSView, placeholder: String) -> NSTextField? {
        if let field = view as? NSTextField,
           field.isEditable,
           field.placeholderString == placeholder || field.placeholderAttributedString?.string == placeholder {
            return field
        }
        for subview in view.subviews {
            if let match = findTextField(in: subview, placeholder: placeholder) {
                return match
            }
        }
        return nil
    }

    // MARK: Capture and output

    private func makeBitmap(pointSize: NSSize) throws -> NSBitmapImageRep {
        let scale: CGFloat = 2
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int((pointSize.width * scale).rounded()),
            pixelsHigh: Int((pointSize.height * scale).rounded()),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw SnapshotError("Could not allocate a \(pointSize) bitmap.")
        }
        bitmap.size = pointSize
        return bitmap
    }

    private func capture(_ view: NSView) throws -> NSBitmapImageRep {
        view.layoutSubtreeIfNeeded()
        let bitmap = try makeBitmap(pointSize: view.bounds.size)
        view.cacheDisplay(in: view.bounds, to: bitmap)
        return bitmap
    }

    private func crop(_ bitmap: NSBitmapImageRep, toLeadingPoints width: CGFloat) throws -> NSBitmapImageRep {
        let scale = CGFloat(bitmap.pixelsWide) / bitmap.size.width
        guard let image = bitmap.cgImage?.cropping(to: CGRect(
            x: 0,
            y: 0,
            width: Int(width * scale),
            height: bitmap.pixelsHigh
        )) else {
            throw SnapshotError("Could not crop the bitmap.")
        }
        let cropped = NSBitmapImageRep(cgImage: image)
        cropped.size = NSSize(width: width, height: bitmap.size.height)
        return cropped
    }

    private func write(
        _ bitmap: NSBitmapImageRep,
        variant: SnapshotVariant,
        name: String,
        summary: String
    ) throws {
        let directory = outputRoot.appendingPathComponent(variant.directoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw SnapshotError("Could not encode \(name).png.")
        }
        try data.write(to: directory.appendingPathComponent("\(name).png"), options: .atomic)
        if isBlank(bitmap) {
            problems.append("\(variant.directoryName)/\(name).png looks blank (a single flat colour).")
        }
        rendered.append(RenderedSnapshot(
            directory: variant.directoryName,
            file: "\(name).png",
            pixelSize: NSSize(width: bitmap.pixelsWide, height: bitmap.pixelsHigh),
            summary: summary
        ))
    }

    /// Cheap sanity check: a rendered screen has many distinct colours.
    private func isBlank(_ bitmap: NSBitmapImageRep) -> Bool {
        var colours = Set<UInt32>()
        let columns = 48
        let rows = 32
        for row in 0..<rows {
            for column in 0..<columns {
                let x = bitmap.pixelsWide * column / columns
                let y = bitmap.pixelsHigh * row / rows
                var pixel = [Int](repeating: 0, count: 4)
                bitmap.getPixel(&pixel, atX: x, y: y)
                colours.insert(UInt32(pixel[0] << 16 | pixel[1] << 8 | pixel[2]))
                if colours.count > 8 { return false }
            }
        }
        return true
    }

    private func writeIndex() throws {
        var lines: [String] = [
            "# Flowtype UI snapshots",
            "",
            "Generated by `Tests/VoiceInputAppTests/UISnapshotRenderTests.swift` from synthetic fixture data.",
            "The app was not launched and no window was shown; each PNG is the real SwiftUI/AppKit view tree rendered offscreen at 2x.",
            "",
            "Regenerate (from the package root):",
            "",
            "```bash",
            "FLOWTYPE_UI_SNAPSHOT_DIR=<dir> swift test --filter UISnapshotRenderTests",
            "```",
            "",
            "Directory names are `<theme>-<language>-<size>`. `natural` holds surfaces with their own fixed size (Settings, Help, onboarding, capsule). `default-dark` and `default-light` are the default (Apple) theme pinned to each system appearance.",
            "`*-full.png` files stretch the window vertically so a whole scrolling page is visible; they are a review aid, not a real window size.",
            "",
            "Known differences from the running app: square window corners and no window shadow; no hover, focus or pressed states; no behind-window blur (the capsule body is AppKit's flat grey fallback on a flat backdrop); the microphone picker and model-suitability hints reflect the machine that ran the harness. Windows are drawn with key (active) appearance.",
            ""
        ]

        var directories: [String] = []
        for snapshot in rendered where !directories.contains(snapshot.directory) {
            directories.append(snapshot.directory)
        }
        for directory in directories {
            lines.append("## \(directory)")
            lines.append("")
            lines.append("| File | Pixels | Shows |")
            lines.append("| --- | --- | --- |")
            for snapshot in rendered where snapshot.directory == directory {
                let pixels = "\(Int(snapshot.pixelSize.width))x\(Int(snapshot.pixelSize.height))"
                lines.append("| `\(directory)/\(snapshot.file)` | \(pixels) | \(snapshot.summary) |")
            }
            lines.append("")
        }
        try lines.joined(separator: "\n")
            .write(to: outputRoot.appendingPathComponent("INDEX.md"), atomically: true, encoding: .utf8)
    }
}

// MARK: - Key-window emulation

/// Title-bar buttons and prominent controls render in their inactive (grey)
/// style unless their window has key appearance, and these windows are never
/// ordered front. While installed, the key/main getters answer true for the
/// windows registered here and fall through to AppKit for every other window.
/// Swapping the implementations (instead of re-classing the window) keeps
/// the key-value observers SwiftUI attaches to the window intact.
@MainActor
private enum KeyWindowEmulation {
    private typealias Getter = @convention(c) (AnyObject, Selector) -> Bool

    private static let windows = NSHashTable<NSWindow>.weakObjects()
    private static var originals: [(Method, IMP)] = []

    static func apply(to window: NSWindow) {
        install()
        windows.add(window)
        NotificationCenter.default.post(name: NSWindow.didBecomeKeyNotification, object: window)
        NotificationCenter.default.post(name: NSWindow.didBecomeMainNotification, object: window)
    }

    static func uninstall() {
        for (method, implementation) in originals {
            method_setImplementation(method, implementation)
        }
        originals.removeAll()
        windows.removeAllObjects()
    }

    private static func install() {
        guard originals.isEmpty else { return }
        // The AppKit-internal appearance getters are what the title-bar
        // buttons and prominent controls consult. They are swapped only when
        // present with the expected `BOOL (id, SEL)` signature, and only in
        // this test process.
        let selectors = [
            #selector(getter: NSWindow.isKeyWindow),
            #selector(getter: NSWindow.isMainWindow),
            NSSelectorFromString("hasKeyAppearance"),
            NSSelectorFromString("hasMainAppearance"),
            NSSelectorFromString("_hasKeyAppearance"),
            NSSelectorFromString("_hasMainAppearance")
        ]
        let boolGetterEncoding = "B16@0:8"
        for selector in selectors {
            guard let method = class_getInstanceMethod(NSWindow.self, selector),
                  let encoding = method_getTypeEncoding(method),
                  String(cString: encoding) == boolGetterEncoding
            else { continue }
            let original = method_getImplementation(method)
            let callOriginal = unsafeBitCast(original, to: Getter.self)
            let table = windows
            let block: @convention(block) (AnyObject) -> Bool = { object in
                if let window = object as? NSWindow, table.contains(window) {
                    return true
                }
                return callOriginal(object, selector)
            }
            originals.append((method, original))
            method_setImplementation(method, imp_implementationWithBlock(block))
        }
    }
}

// MARK: - Fixtures

private struct SnapshotError: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}

/// Settings backing store that lives only in memory. A suite-named
/// `UserDefaults` would leave a preference file in the real home directory
/// (the preferences daemon ignores `CFFIXED_USER_HOME`), so every accessor
/// `SettingsStore` uses is answered from a dictionary instead.
private final class InMemoryDefaults: UserDefaults {
    private var storage: [String: Any] = [:]

    init() {
        // The suite is never read or written: all accessors are overridden.
        super.init(suiteName: "flowtype-ui-snapshots-in-memory")!
    }

    override func object(forKey defaultName: String) -> Any? {
        storage[defaultName]
    }

    override func set(_ value: Any?, forKey defaultName: String) {
        storage[defaultName] = value
    }

    override func set(_ value: Bool, forKey defaultName: String) {
        storage[defaultName] = value
    }

    override func set(_ value: Int, forKey defaultName: String) {
        storage[defaultName] = value
    }

    override func removeObject(forKey defaultName: String) {
        storage[defaultName] = nil
    }

    override func string(forKey defaultName: String) -> String? {
        storage[defaultName] as? String
    }

    override func bool(forKey defaultName: String) -> Bool {
        storage[defaultName] as? Bool ?? false
    }

    override func integer(forKey defaultName: String) -> Int {
        storage[defaultName] as? Int ?? 0
    }

    override func data(forKey defaultName: String) -> Data? {
        storage[defaultName] as? Data
    }
}

@MainActor
private final class PermissionBox {
    var snapshot = PermissionSnapshot(
        microphone: .notDetermined,
        accessibility: .notDetermined,
        speechRecognition: .unknown
    )
}

/// Captures the listener the practice page registers so the harness can feed it events.
@MainActor
private final class PracticeListenerBox {
    var listener: ((OnboardingPracticeEvent) -> Void)?
}

/// Holds the fake onboarding preparation open until the harness has captured
/// the in-progress state.
@MainActor
private final class PreparationGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var isOpen = false

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { continuation = $0 }
    }

    func open() {
        isOpen = true
        continuation?.resume()
        continuation = nil
    }
}

@MainActor
private final class FixtureEnvironment {
    let settingsStore: SettingsStore
    let historyStore: TranscriptHistoryStore
    let usageStatsStore: UsageStatsStore
    let hotwordStore: HotwordStore
    let modelManager: ModelManager
    let readinessSnapshot: ReadinessSnapshot
    let mainWindowActions: MainWindowActions

    init(directory: URL, variant: SnapshotVariant, options: FixtureOptions) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        settingsStore = SettingsStore(defaults: InMemoryDefaults(), legacyDefaults: nil)
        settingsStore.appThemeID = variant.theme
        settingsStore.uiLanguage = variant.language
        settingsStore.selectedModelID = VoiceInputModel.qwen3ASR06B.id

        historyStore = TranscriptHistoryStore(
            fileURL: directory.appendingPathComponent("history.json"),
            limit: 100
        )
        if options.hasHistory {
            try historyStore.save(Self.historyItems(language: variant.language, showsIssues: options.historyShowsIssues))
        }

        let usageStatsURL = directory.appendingPathComponent("usage-stats.json")
        usageStatsStore = UsageStatsStore(fileURL: usageStatsURL)
        if options.hasUsageStats {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(UsageStats(
                firstUsedAt: Date(timeIntervalSince1970: 1_750_000_000),
                successfulDictations: 19_289,
                cumulativeRecordingSeconds: 55 * 3600 + 29 * 60,
                dictatedUnitCount: 880_000,
                estimatedSavedSeconds: 219 * 3600 + 47 * 60,
                updatedAt: Date()
            )).write(to: usageStatsURL)
        }

        hotwordStore = HotwordStore(fileURL: directory.appendingPathComponent("hotwords.json"))
        if options.hasHotwords {
            try hotwordStore.save(Self.hotwords.map { Hotword(text: $0) })
        }

        modelManager = ModelManager(applicationSupportRoot: directory)
        let readinessNeedsModel = options.readiness == .needsAttention
        if !readinessNeedsModel {
            try Self.installModel(.qwen3ASR06B, sizeBytes: 1_880_000_000, root: directory)
        }
        if options.largeModel == .installed {
            try Self.installModel(.qwen3ASR17B, sizeBytes: 4_690_000_000, root: directory)
        }

        let report = Self.readinessReport(options.readiness)
        readinessSnapshot = ReadinessSnapshot(
            report: report,
            context: ReadinessContext(engine: .qwenLocal, selectedModelID: VoiceInputModel.qwen3ASR06B.id),
            coverage: .live
        )

        var actions = MainWindowActions()
        actions.refreshReadiness = { report }
        actions.refreshReadinessLive = { report }
        let largeModel = options.largeModel
        actions.refreshModelStatus = { modelID in
            if modelID == VoiceInputModel.qwen3ASR17B.modelID, largeModel == .downloading {
                return QwenModelStatus(
                    installed: false,
                    loaded: false,
                    loading: false,
                    downloading: true,
                    progress: 0.42,
                    modelId: modelID,
                    modelPath: nil,
                    phase: .downloading,
                    downloadedBytes: 1_970_000_000,
                    totalBytes: 4_690_000_000,
                    downloadSource: "modelscope"
                )
            }
            // Installed state is decided by the fixture files on disk, as in
            // the app when the helper has nothing newer to report.
            return QwenModelStatus(
                installed: true,
                loaded: modelID == VoiceInputModel.qwen3ASR06B.modelID,
                loading: false,
                downloading: false,
                progress: nil,
                modelId: modelID,
                modelPath: nil
            )
        }
        mainWindowActions = actions
    }

    // MARK: Fixture data

    /// Writes the minimal on-disk layout `ModelManager` treats as an installed
    /// Hugging Face snapshot. The weights file is sparse, so it reports a
    /// realistic size without using disk space.
    private static func installModel(_ model: VoiceInputModel, sizeBytes: UInt64, root: URL) throws {
        let manager = ModelManager(model: model, applicationSupportRoot: root)
        let snapshot = manager.huggingFaceHubModelDirectory
            .appendingPathComponent("snapshots", isDirectory: true)
            .appendingPathComponent("ui-snapshot-fixture", isDirectory: true)
        try FileManager.default.createDirectory(at: snapshot, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: snapshot.appendingPathComponent("config.json"))
        let weights = snapshot.appendingPathComponent("model.safetensors")
        FileManager.default.createFile(atPath: weights.path, contents: nil)
        let handle = try FileHandle(forWritingTo: weights)
        try handle.truncate(atOffset: sizeBytes)
        try handle.close()
    }

    /// Fixed times of day keep the rendered timestamps identical across runs.
    private static func date(daysAgo: Int, hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: Date())) ?? Date()
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }

    private static func historyItems(language: UILanguage, showsIssues: Bool) -> [TranscriptHistoryItem] {
        func item(
            _ text: String,
            daysAgo: Int,
            _ hour: Int,
            _ minute: Int,
            app: String,
            duration: TimeInterval,
            recording: String? = nil,
            issue: TranscriptHistoryIssue? = nil,
            status: TranscriptHistoryStatus = .succeeded,
            failure: TranscriptFailureCategory? = nil
        ) -> TranscriptHistoryItem {
            TranscriptHistoryItem(
                text: text,
                createdAt: date(daysAgo: daysAgo, hour: hour, minute: minute),
                engine: .qwenLocal,
                languageMode: .mixedChineseEnglish,
                targetAppName: app,
                recordingFileName: recording,
                recordingDuration: duration,
                transcriptionIssue: issue,
                status: status,
                failureCategory: failure
            )
        }

        // The launch films open on Home and then explain spoken math, so the default history has math
        // entries and no status rows: all English for the English interface, mixed Chinese-English
        // for the Chinese one. The rows with issues are kept for the needs-attention snapshot.
        if !showsIssues && language == .chinese {
            return [
                item("vlog 开头先放 highlight，再慢慢讲故事。", daysAgo: 0, 14, 32, app: "Final Cut Pro", duration: 3.4),
                item("在最优点，偏导数 ∂f/∂x 等于零。", daysAgo: 0, 14, 18, app: "备忘录", duration: 3.9),
                item(
                    "帮我把这个 PR 的 description 改一下，重点写清楚 breaking change 和 migration 步骤。",
                    daysAgo: 0, 13, 47, app: "GitHub", duration: 7.8
                ),
                item("回归模型是 E[Y | X] = β₀ + β₁x，记得报告 slope。", daysAgo: 0, 11, 5, app: "Overleaf", duration: 5.6),
                item("根据贝叶斯公式，P(A | B) = P(B | A)·P(A)/P(B)。", daysAgo: 0, 10, 26, app: "Obsidian", duration: 4.8),
                item("先把 hotfix 发出去，refactor 放到下个 sprint 再说。", daysAgo: 0, 9, 41, app: "Linear", duration: 4.6),
                item("好的，明天十点见。", daysAgo: 1, 21, 16, app: "微信", duration: 1.8),
                item(
                    "明天上午十点和设计同步一下首页卡片的方案，顺便确认 dark mode 下的对比度。",
                    daysAgo: 1, 18, 3, app: "日历", duration: 6.9
                ),
                item(
                    "这个 bug 的 root cause 是 token 在 refresh 之后没有写回 Keychain。",
                    daysAgo: 3, 16, 40, app: "GitHub", duration: 7.1
                )
            ]
        }
        if !showsIssues {
            return [
                item("Open the vlog with the highlight, then tell the story.", daysAgo: 0, 14, 32, app: "Final Cut Pro", duration: 3.6),
                item("The partial derivative ∂f/∂x is zero at the optimum.", daysAgo: 0, 14, 18, app: "Notes", duration: 4.2),
                item(
                    "Update the PR description: list the breaking changes and the migration steps.",
                    daysAgo: 0, 13, 47, app: "GitHub", duration: 5.9
                ),
                item("Fit the model E[Y | X] = β₀ + β₁x and report the slope.", daysAgo: 0, 11, 5, app: "Overleaf", duration: 5.1),
                item("By Bayes, P(A | B) = P(B | A)·P(A)/P(B).", daysAgo: 0, 10, 26, app: "Obsidian", duration: 4.4),
                item(
                    "Let's ship the hotfix first, then circle back to the refactor next sprint.",
                    daysAgo: 0, 9, 41, app: "Linear", duration: 5.2
                ),
                item("Sounds good, see you at ten tomorrow.", daysAgo: 1, 21, 16, app: "Slack", duration: 2.3),
                item("Move the design sync to Thursday morning.", daysAgo: 1, 18, 3, app: "Calendar", duration: 2.8),
                item(
                    "The root cause is that the refreshed token never gets written back to the Keychain.",
                    daysAgo: 3, 16, 40, app: "GitHub", duration: 6.2
                )
            ]
        }

        return [
            item("好的，收到。", daysAgo: 0, 14, 32, app: "Slack", duration: 1.4),
            item(
                "帮我把这个 PR 的 description 改一下，重点写清楚 breaking change 和 migration 步骤。",
                daysAgo: 0, 14, 27, app: "Xcode", duration: 7.8
            ),
            item(
                "",
                daysAgo: 0, 14, 21, app: "Notion", duration: 42,
                recording: "ui-snapshot-fixture-failed.wav",
                status: .failed,
                failure: .transcriptionFailed
            ),
            item(
                "今天的周会我想先同步三件事。第一，Flowtype 的本地模型已经切到 Qwen3-ASR 0.6B，冷启动从 9 秒降到了 3 秒左右，warm-up 之后基本感觉不到延迟。第二，后处理这边新增了 English percentage normalization，像 twenty five percent 会直接输出成 25%，但是版本号、IP 地址和代码标识符都会被保护起来，不会被误改。第三，UI 这一轮我们不改信息架构，只做 type scale、spacing 和 surface 的统一，目标是让内容本身成为屏幕上最亮的东西，导航和装饰都往后退。大家如果有想补充的，可以直接在 thread 里回复，或者会后单独找我。",
                daysAgo: 0, 11, 5, app: "Notion", duration: 58.3
            ),
            item(
                "接下来我们看一下 onboarding 的转化漏斗，从下载到完成首次听写，中间最大的流失点在",
                daysAgo: 0, 10, 48, app: "Keynote", duration: 181,
                recording: "ui-snapshot-fixture-truncated.wav",
                issue: .possibleTruncation
            ),
            item(
                "Let's ship the hotfix first, then circle back to the refactor next sprint.",
                daysAgo: 0, 9, 41, app: "Linear", duration: 5.2
            ),
            item(
                "把 retry 的 backoff 改成 exponential，上限 30 秒，另外加一个 jitter。",
                daysAgo: 1, 21, 16, app: "Cursor", duration: 6.1,
                status: .recovered
            ),
            item(
                "明天上午十点和设计同步一下首页卡片的方案，顺便确认 dark mode 下的对比度。",
                daysAgo: 1, 18, 3, app: "微信", duration: 6.9
            ),
            item(
                "",
                daysAgo: 1, 10, 22, app: "Safari", duration: 12,
                status: .failed,
                failure: .expiredRecording
            ),
            item(
                "这个 bug 的 root cause 是 token 在 refresh 之后没有写回 Keychain，所以下一次冷启动又会走一遍登录。",
                daysAgo: 3, 16, 40, app: "GitHub", duration: 9.4
            )
        ]
    }

    private static let hotwords = [
        "Flowtype", "Obsidian", "Figma", "Notion", "Keynote", "Logic Pro",
        "Siobhán", "François", "Nguyễn Minh", "Søren", "Zoë", "贝叶斯推断",
        "费曼学习法", "横纵分析", "麦肯锡", "小红书", "Reykjavík", "Kraków",
        "Shoreditch", "陆家嘴", "Québec", "EBITDA", "OKR", "GDPR",
        "CRISPR", "p-value", "Q3 roadmap", "Lightroom", "Airbnb",
        "Department of Statistical Science"
    ]

    /// Mirrors the ids, titles and details the app's readiness inspectors
    /// produce so the page renders the same rows as a real report.
    private static func readinessReport(_ fixture: ReadinessFixture) -> ReadinessReport {
        let needsAttention = fixture == .needsAttention
        let daily = VoiceInputModel.qwen3ASR06B
        let large = VoiceInputModel.qwen3ASR17B

        var checks: [ReadinessCheck] = [
            ReadinessCheck(id: "app-binary", group: .appBundle, title: "Flowtype app binary", detail: "The Flowtype executable is present.", status: .ready, locationTarget: .appBundle),
            ReadinessCheck(id: "bundled-uv", group: .appBundle, title: "Bundled uv", detail: "Bundled uv is present and executable.", status: .ready, locationTarget: .appResources),
            ReadinessCheck(id: "bundled-qwen-helper", group: .appBundle, title: "Bundled Qwen helper", detail: "The bundled helper source is present.", status: .ready, locationTarget: .appResources),
            ReadinessCheck(id: "helper-manifest", group: .appBundle, title: "Helper version manifest", detail: "The bundled helper manifest is present.", status: .ready, locationTarget: .appResources),
            ReadinessCheck(id: "flowtype-icon", group: .appBundle, title: "Flowtype icon", detail: "The app icon resource is present.", status: .ready, locationTarget: .appResources),
            ReadinessCheck(id: "qwen-logo", group: .appBundle, title: "Qwen logo", detail: "The Qwen logo resource is present.", status: .ready, locationTarget: .appResources),
            ReadinessCheck(id: "application-support-root", group: .localRuntime, title: "Application Support folder", detail: "Flowtype can use its Application Support folder.", status: .ready, locationTarget: .applicationSupportRoot),
            ReadinessCheck(id: "local-helper-copy", group: .localRuntime, title: "Local Qwen helper copy", detail: "The local helper copy is ready at ~/Library/Application Support/Flowtype/qwen-asr-helper.", status: .ready, locationTarget: .localHelper),
            ReadinessCheck(id: "local-bundled-uv", group: .localRuntime, title: "Bundled uv runtime", detail: "Flowtype can launch the helper with bundled uv.", status: .ready, locationTarget: .appResources),
            ReadinessCheck(id: "selected-model", group: .models, title: "Selected model", detail: "\(daily.displayName) is selected for local dictation.", status: .ready, locationTarget: .selectedModel)
        ]

        if needsAttention {
            checks += [
                ReadinessCheck(id: "model-\(daily.id)", group: .models, title: daily.displayName, detail: "Download this model before using local Qwen dictation.", status: .notReady, primaryAction: .downloadDefaultModel, locationTarget: .selectedModel),
                ReadinessCheck(id: "model-\(daily.id)-warm", group: .models, title: "\(daily.displayName) preload status", detail: "Flowtype prepares the selected model automatically after download and app launch. The first dictation may be slower if preparation has not finished.", status: .optional, locationTarget: .selectedModel),
                ReadinessCheck(id: "microphone-permission", group: .permissions, title: "Microphone", detail: "Flowtype needs Microphone permission to record dictation audio.", status: .notReady, primaryAction: .requestMicrophone)
            ]
        } else {
            checks += [
                ReadinessCheck(id: "model-\(daily.id)", group: .models, title: daily.displayName, detail: "The model cache is present in Flowtype's Application Support folder.", status: .ready, locationTarget: .selectedModel),
                ReadinessCheck(id: "model-\(daily.id)-warm", group: .models, title: "\(daily.displayName) preload status", detail: "The selected Qwen model is loaded and ready for lower-latency dictation.", status: .ready, locationTarget: .selectedModel),
                ReadinessCheck(id: "microphone-permission", group: .permissions, title: "Microphone", detail: "Flowtype can record audio.", status: .ready)
            ]
        }

        checks += [
            ReadinessCheck(id: "model-\(large.id)", group: .models, title: large.displayName, detail: "The model cache is present in Flowtype's Application Support folder.", status: .ready, locationTarget: .modelsRoot),
            ReadinessCheck(id: "model-\(large.id)-warm", group: .models, title: "\(large.displayName) preload status", detail: "Only the selected model is prepared for lower-latency dictation.", status: .optional, locationTarget: .modelsRoot),
            ReadinessCheck(id: "accessibility-permission", group: .permissions, title: "Accessibility", detail: "Flowtype can listen for Fn and paste transcripts.", status: .ready),
            ReadinessCheck(id: "apple-silicon", group: .performance, title: "Apple Silicon", detail: "Apple M3 Pro is supported.", status: .ready),
            ReadinessCheck(id: "memory-tier", group: .performance, title: "Memory tier", detail: "36 GB unified memory detected.", status: .ready),
            ReadinessCheck(id: "selected-model-recommendation", group: .performance, title: "Model recommendation", detail: "\(daily.displayName) matches this Mac's memory tier.", status: .ready),
            ReadinessCheck(id: "helper-memory", group: .performance, title: "Helper memory", detail: "Flowtype helper processes are using 2184 MB RSS.", status: .ready),
            ReadinessCheck(id: "last-transcription-timing", group: .performance, title: "Last transcription timing", detail: "Last run: helper 12 ms, status probe 8 ms, decode 640 ms, post 21 ms.", status: .ready)
        ]

        return ReadinessReport(generatedAt: Date(), checks: checks)
    }
}


private struct AccentStripView: View {
    let theme: AppTheme
    @State private var selection = 1
    @State private var isOn = true
    @State private var isOff = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Button("使用此模型") {}
                    .buttonStyle(FlowtypeProminentButtonStyle(theme: theme))
                Button("打开文件夹") {}
                    .buttonStyle(FlowtypeNeutralButtonStyle(theme: theme))
                FlowtypeSegmentedPicker(
                    theme: theme,
                    selection: $selection,
                    options: [(0, "小"), (1, "标准"), (2, "大")]
                )
                HStack(spacing: 4) {
                    Image(systemName: "checkmark").font(.system(size: 9, weight: .bold))
                    Text("正在使用").font(.caption).fontWeight(.semibold)
                }
                .foregroundStyle(theme.onAccent)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background { AccentSurface(theme: theme, shape: Capsule()) }
            }
            HStack(spacing: 24) {
                FlowtypeProgressBar(theme: theme, value: 0.6).frame(width: 200)
                Toggle("", isOn: $isOn).toggleStyle(FlowtypeSwitchToggleStyle(theme: theme)).labelsHidden()
                Toggle("", isOn: $isOff).toggleStyle(FlowtypeSwitchToggleStyle(theme: theme)).labelsHidden()
                Label("词典热词", systemImage: "book")
                    .foregroundStyle(theme.accent)
            }
        }
        .padding(20)
        .frame(width: 760, height: 150, alignment: .leading)
        .background(theme.elevatedSurface)
        .flowtypeTheme(theme)
    }
}
