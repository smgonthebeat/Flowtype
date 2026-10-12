import AppKit
import SwiftUI

/// Result of the Help page's "check and copy diagnostics" button.
struct HelpDiagnosticsResult: Equatable {
    let summary: ReadinessSummary
    let fileURL: URL
}

struct HelpActions {
    var openSection: (MainWindowSection) -> Void = { _ in }
    var showOnboarding: () -> Void = {}
    /// Copies the last transcript to the clipboard; false when there is none.
    var copyLastTranscript: () -> Bool = { false }
    /// Runs a fresh readiness check, writes the diagnostics file and copies it.
    var checkAndCopyDiagnostics: () async throws -> HelpDiagnosticsResult = { throw CancellationError() }
    var revealFile: (URL) -> Void = { _ in }
    /// Opens a contact link (mail compose window or the GitHub issues page).
    var openURL: (URL) -> Void = { _ in }
}

@MainActor
final class HelpWindowController: NSWindowController {
    private let settingsStore: SettingsStore
    private let actions: HelpActions

    init(settingsStore: SettingsStore, actions: HelpActions = HelpActions()) {
        self.settingsStore = settingsStore
        self.actions = actions

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.minSize = NSSize(width: 560, height: 460)
        window.isReleasedWhenClosed = false
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        loadContent()
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Builds the themed window content without presenting the window.
    /// `show()` calls this first; the offscreen UI snapshot harness calls it
    /// directly so it can render the window without ordering it front.
    func loadContent(expandedProblemID: String? = nil) {
        let copy = HelpCopy.texts(for: settingsStore.uiLanguage)
        let theme = AppTheme.theme(for: settingsStore.appThemeID)

        window?.title = copy.windowTitle
        if let window { WindowChrome.applyBackdropLayout(theme, to: window) }
        window?.backgroundColor = theme.usesSystemMaterials ? .windowBackgroundColor : NSColor(theme.surface)
        window?.appearance = theme.windowAppearance
        window?.contentView = NSHostingView(
            rootView: HelpWindowView(copy: copy, actions: actions, initialExpandedID: expandedProblemID)
                .flowtypeTheme(theme)
        )
    }
}

private struct HelpWindowView: View {
    @Environment(\.appTheme) private var theme

    let copy: HelpCopy.Texts
    let actions: HelpActions

    @State private var expandedID: String?
    @State private var actionFeedback: (id: String, text: String)?
    @State private var diagnostics: DiagnosticsState = .idle

    private enum DiagnosticsState {
        case idle
        case running
        case done(HelpDiagnosticsResult)
        case failed(String)
    }

    init(copy: HelpCopy.Texts, actions: HelpActions, initialExpandedID: String?) {
        self.copy = copy
        self.actions = actions
        _expandedID = State(initialValue: initialExpandedID)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(copy.title)
                        .scaledFont(size: 30, weight: .semibold)
                        .foregroundStyle(theme.ink)
                    Text(copy.subtitle)
                        .scaledFont(.callout)
                        .foregroundStyle(theme.secondaryInk)
                }

                basicsCard

                Text(copy.problemsTitle)
                    .scaledFont(.headline)
                    .foregroundStyle(theme.ink)
                    .padding(.top, 4)

                problemsCard

                diagnosticsCard
            }
            .padding(28)
            .frame(maxWidth: 720, alignment: .topLeading)
        }
        .backdropTitlebarFade(theme)
        .background(ThemeBackdropView(theme: theme))
    }

    // MARK: Basics

    private var basicsCard: some View {
        HStack(alignment: .center, spacing: 20) {
            MacKeycap(legend: .function, width: 62, height: 58, pressAmount: 1)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(LinearGradient(colors: [Color(white: 0.19), Color(white: 0.145)], startPoint: .top, endPoint: .bottom))
                )

            VStack(alignment: .leading, spacing: 8) {
                Text(copy.basicsTitle)
                    .scaledFont(.headline)
                    .foregroundStyle(theme.ink)
                ForEach(Array(copy.basicsRules.enumerated()), id: \.offset) { index, rule in
                    HStack(spacing: 8) {
                        Text("\(index + 1)")
                            .scaledFont(size: 11, weight: .semibold)
                            .foregroundStyle(theme.onAccent)
                            .frame(width: 18, height: 18)
                            .background { AccentSurface(theme: theme, shape: Circle()) }
                        Text(rule)
                            .scaledFont(.callout)
                            .foregroundStyle(theme.ink)
                    }
                }
            }

            Spacer(minLength: 12)

            Button(copy.replayOnboarding, action: actions.showOnboarding)
                .buttonStyle(FlowtypeNeutralButtonStyle(theme: theme))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard(theme, cornerRadius: 12)
    }

    // MARK: Problems

    private var problemsCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(copy.problems.enumerated()), id: \.element.id) { index, problem in
                if index > 0 {
                    Divider().padding(.leading, 52)
                }
                problemRow(problem)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard(theme, cornerRadius: 12)
    }

    private func problemRow(_ problem: HelpProblem) -> some View {
        let isExpanded = expandedID == problem.id
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    expandedID = isExpanded ? nil : problem.id
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: problem.symbol)
                        .scaledFont(size: 14, weight: .semibold)
                        .foregroundStyle(theme.accent)
                        .frame(width: 26, height: 26)
                        .background(theme.controlSurface, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    Text(problem.question)
                        .scaledFont(size: 13, weight: .medium)
                        .foregroundStyle(theme.ink)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .scaledFont(size: 11, weight: .semibold)
                        .foregroundStyle(theme.tertiaryInk)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    Text(problem.answer)
                        .scaledFont(.callout)
                        .foregroundStyle(theme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 10) {
                        Button(problem.actionTitle) {
                            perform(problem)
                        }
                        .buttonStyle(FlowtypeNeutralButtonStyle(theme: theme))
                        if let feedback = actionFeedback, feedback.id == problem.id {
                            Text(feedback.text)
                                .scaledFont(.caption)
                                .foregroundStyle(theme.secondaryInk)
                        }
                    }
                }
                .padding(.leading, 52)
                .padding(.trailing, 14)
                .padding(.bottom, 14)
            }
        }
    }

    private func perform(_ problem: HelpProblem) {
        switch problem.action {
        case let .openSection(section):
            actions.openSection(section)
        case .copyLastTranscript:
            let copied = actions.copyLastTranscript()
            actionFeedback = (problem.id, copied ? copy.copiedLastTranscript : copy.noLastTranscript)
        }
    }

    // MARK: Diagnostics

    private var diagnosticsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(copy.diagnosticsTitle, systemImage: "stethoscope")
                .scaledFont(.headline)
                .foregroundStyle(theme.ink)
            Text(copy.diagnosticsBody)
                .scaledFont(.callout)
                .foregroundStyle(theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button(isRunning ? copy.diagnosticsRunning : copy.diagnosticsButton) {
                    runDiagnostics()
                }
                .buttonStyle(FlowtypeProminentButtonStyle(theme: theme))
                .disabled(isRunning)
                if isRunning {
                    ProgressView().controlSize(.small)
                }
            }
            .padding(.top, 2)

            diagnosticsResult

            contactRow
                .padding(.top, 2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard(theme, cornerRadius: 12)
    }

    @ViewBuilder
    private var diagnosticsResult: some View {
        switch diagnostics {
        case .idle, .running:
            EmptyView()
        case let .failed(message):
            Text(message)
                .scaledFont(.callout)
                .foregroundStyle(theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        case let .done(result):
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(dotColor(for: result.summary.tone))
                        .frame(width: 8, height: 8)
                    Text(copy.diagnosticsResultPrefix + result.summary.text)
                        .scaledFont(.callout)
                        .foregroundStyle(theme.ink)
                    if result.summary.tone == .attention {
                        Button(copy.openSetupStatus) {
                            actions.openSection(.readiness)
                        }
                        .buttonStyle(.link)
                    }
                }
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(theme.accent)
                    Text(copy.diagnosticsCopied)
                        .scaledFont(.callout)
                        .foregroundStyle(theme.ink)
                    Button(copy.revealInFinder) {
                        actions.revealFile(result.fileURL)
                    }
                    .buttonStyle(.link)
                }
            }
        }
    }

    private var contactRow: some View {
        HStack(spacing: 8) {
            Text(copy.contactLabel)
                .scaledFont(.callout)
                .foregroundStyle(theme.secondaryInk)
            if let mailURL = HelpContact.mailURL(subject: copy.contactEmailSubject, body: copy.contactEmailBody) {
                Button(HelpContact.email) {
                    actions.openURL(mailURL)
                }
                .buttonStyle(.link)
                .help(HelpContact.email)
            }
            Text("·")
                .foregroundStyle(theme.secondaryInk)
            Button(copy.contactGitHub) {
                actions.openURL(HelpContact.issuesURL)
            }
            .buttonStyle(.link)
            .help(HelpContact.issuesURL.absoluteString)
        }
        .scaledFont(.callout)
    }

    private var isRunning: Bool {
        if case .running = diagnostics { return true }
        return false
    }

    private func dotColor(for tone: ReadinessSummary.Tone) -> Color {
        switch tone {
        case .ready: return Color(nsColor: .systemGreen)
        case .working: return Color(nsColor: .systemGray)
        case .attention: return Color(nsColor: .systemOrange)
        }
    }

    private func runDiagnostics() {
        diagnostics = .running
        Task { @MainActor in
            do {
                diagnostics = .done(try await actions.checkAndCopyDiagnostics())
            } catch {
                diagnostics = .failed(error.localizedDescription)
            }
        }
    }
}
