import AppKit
import SwiftUI

struct HomeView: View {
    @Environment(\.appTheme) private var theme

    @ObservedObject var state: MainWindowState
    let hotwordStore: HotwordStore
    let historyStore: TranscriptHistoryStore
    let usageStatsStore: UsageStatsStore?
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var readinessStore: MainWindowReadinessStore
    let actions: MainWindowActions

    @State private var historyItems: [TranscriptHistoryItem] = []
    @State private var usageStats: UsageStats = .empty
    @State private var isConfirmingClearHistory = false
    @State private var isShowingClearHistoryError = false
    @State private var clearHistoryErrorMessage = ""

    var body: some View {
        let copy = AppCopy.texts(for: settingsStore.uiLanguage)

        GeometryReader { geometry in
            ScrollView {
                content(isCompact: geometry.size.width < 900)
                    .padding(.horizontal, MainWindowDetailLayout.horizontalPadding(forWidth: geometry.size.width))
                    .padding(.top, MainWindowDetailLayout.topPadding)
                    .padding(.bottom, MainWindowDetailLayout.bottomPadding)
                    .frame(maxWidth: MainWindowDetailLayout.homeContentMaxWidth, alignment: .topLeading)
                    .frame(maxWidth: .infinity, alignment: .top)
            }
            .background(theme.surface)
        }
        .onAppear(perform: reload)
        .onChange(of: state.refreshID) {
            reload()
        }
        .confirmationDialog(
            copy.clearHistoryConfirmationTitle,
            isPresented: $isConfirmingClearHistory
        ) {
            Button(copy.clearHistoryTitle, role: .destructive) {
                clearHistory()
            }
            Button(copy.cancel, role: .cancel) {}
        } message: {
            Text(copy.clearHistoryConfirmationMessage)
        }
        .alert(copy.clearHistoryErrorTitle, isPresented: $isShowingClearHistoryError) {
            Button(copy.ok, role: .cancel) {}
        } message: {
            Text(clearHistoryErrorMessage)
        }
    }

    @ViewBuilder
    private func content(isCompact: Bool) -> some View {
        mainColumn(isCompact: isCompact)
    }

    private func mainColumn(isCompact: Bool) -> some View {
        let copy = AppCopy.texts(for: settingsStore.uiLanguage)
        let readinessPresentation = HomeReadinessPresentation.presentation(
            for: readinessStore.presentation
        )

        return VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text(copy.mainHeadline)
                    .font(.system(size: 34, weight: .semibold, design: .default))
                    .lineLimit(2)
                    .foregroundStyle(theme.ink)

                Text(copy.mainSubtitle)
                    .font(.callout)
                    .foregroundStyle(theme.secondaryInk)

                if !readinessPresentation.showsProminentCard {
                    Label(
                        readinessInlineTitle(for: readinessPresentation, copy: copy),
                        systemImage: readinessSymbol(for: readinessPresentation)
                    )
                    .font(.callout.weight(.medium))
                    .foregroundStyle(readinessColor(for: readinessPresentation))
                    .padding(.top, 4)
                }
            }

            if readinessPresentation.showsProminentCard {
                readinessCard(for: readinessPresentation)
            }

            UsageStatsOverviewView(
                stats: usageStats,
                isCompact: isCompact,
                copy: copy,
                theme: theme
            )

            if !isHistoryEnabled {
                historyDisabledView
            }

            historyControls

            if historyItems.isEmpty {
                emptyHistoryView
            } else {
                historySections
            }
        }
    }

    private func readinessCard(for presentation: HomeReadinessPresentation) -> some View {
        let copy = AppCopy.texts(for: settingsStore.uiLanguage)

        return HStack(spacing: 14) {
            Group {
                if presentation == .checking {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: readinessSymbol(for: presentation))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(readinessColor(for: presentation))
                }
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(readinessTitle(for: presentation, copy: copy))
                    .font(.headline)
                    .foregroundStyle(theme.ink)

                Text(readinessDetail(for: presentation, copy: copy))
                    .font(.callout)
                    .foregroundStyle(theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 16)

            Button {
                state.show(.readiness)
            } label: {
                Label(copy.readinessTitle, systemImage: "chevron.right")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard(theme, cornerRadius: 14)
    }

    private func readinessTitle(
        for presentation: HomeReadinessPresentation,
        copy: AppCopy.Texts
    ) -> String {
        switch presentation {
        case .checking:
            return copy.readinessCheckingTitle
        case .preparing:
            return copy.readinessStatusPreparingTitle
        case .ready:
            return copy.readinessSetupCompleteTitle
        case .needsSetup:
            return copy.readinessTaskSummaryTitle(count: readinessStore.presentation.requiredTaskCount)
        case .repairRequired:
            return copy.readinessRepairRequiredTitle
        }
    }

    private func readinessDetail(
        for presentation: HomeReadinessPresentation,
        copy: AppCopy.Texts
    ) -> String {
        switch presentation {
        case .checking:
            return copy.readinessCheckingDetail
        case .preparing:
            return copy.readinessPreparingDetail
        case .ready:
            return copy.readinessReadyDetail(for: readinessStore.snapshot.context)
        case .needsSetup:
            return copy.readinessTaskSummaryDetail(for: readinessStore.presentation.tasks)
        case .repairRequired:
            return copy.readinessRepairRequiredDetail
        }
    }

    private func readinessSymbol(for presentation: HomeReadinessPresentation) -> String {
        switch presentation {
        case .checking, .preparing: return "clock.fill"
        case .ready: return "checkmark.circle.fill"
        case .needsSetup: return "exclamationmark.triangle.fill"
        case .repairRequired: return "exclamationmark.triangle.fill"
        }
    }

    private func readinessColor(for presentation: HomeReadinessPresentation) -> Color {
        switch presentation {
        case .checking, .preparing: return theme.accent
        case .ready: return theme.success
        case .needsSetup: return .orange
        case .repairRequired: return theme.danger
        }
    }

    private func readinessInlineTitle(
        for presentation: HomeReadinessPresentation,
        copy: AppCopy.Texts
    ) -> String {
        switch presentation {
        case .checking: return copy.readinessCheckingTitle
        case .preparing: return copy.readinessStatusPreparingTitle
        case .ready: return copy.readinessReadyDetail(for: readinessStore.snapshot.context)
        case .needsSetup, .repairRequired: return ""
        }
    }

    private var historySections: some View {
        let copy = AppCopy.texts(for: settingsStore.uiLanguage)

        return VStack(alignment: .leading, spacing: 20) {
            TranscriptHistorySectionView(
                title: copy.todayTitle,
                items: groupedHistory.today,
                copy: copy,
                actions: actions
            )
            TranscriptHistorySectionView(
                title: copy.yesterdayTitle,
                items: groupedHistory.yesterday,
                copy: copy,
                actions: actions
            )
            TranscriptHistorySectionView(
                title: copy.olderTitle,
                items: groupedHistory.older,
                copy: copy,
                actions: actions
            )
        }
    }

    private var emptyHistoryView: some View {
        let copy = AppCopy.texts(for: settingsStore.uiLanguage)

        return Text(isHistoryEnabled ? copy.emptyHistoryEnabled : copy.emptyHistoryDisabled)
            .foregroundStyle(theme.secondaryInk)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 20)
    }

    private var historyDisabledView: some View {
        let copy = AppCopy.texts(for: settingsStore.uiLanguage)

        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "lock")
                .foregroundStyle(theme.secondaryInk)
            Text(copy.historyOffNotice)
                .foregroundStyle(theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.callout)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.controlSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var historyControls: some View {
        let copy = AppCopy.texts(for: settingsStore.uiLanguage)

        return HStack(spacing: 14) {
            Text(copy.historySectionTitle)
                .font(.headline)
                .foregroundStyle(theme.ink)

            Spacer()

            Button {
                state.show(.dictionary)
            } label: {
                Label(copy.dictionaryTitle, systemImage: "text.book.closed")
            }
            .buttonStyle(.borderless)
            .help(copy.openDictionaryHelp)

            Menu {
                Button(role: .destructive) {
                    isConfirmingClearHistory = true
                } label: {
                    Label(copy.clearHistoryTitle, systemImage: "trash")
                }
                .disabled(historyItems.isEmpty)
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .buttonStyle(.borderless)
            .help(copy.moreActionsTitle)
            .accessibilityLabel(copy.moreActionsTitle)
        }
        .padding(.vertical, 4)
    }

    private var groupedHistory: (
        today: [TranscriptHistoryItem],
        yesterday: [TranscriptHistoryItem],
        older: [TranscriptHistoryItem]
    ) {
        let calendar = Calendar.current
        let now = Date()
        return historyItems.reduce(into: (today: [], yesterday: [], older: [])) { groups, item in
            if calendar.isDateInToday(item.createdAt) {
                groups.today.append(item)
            } else if calendar.isDate(item.createdAt, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: now) ?? now) {
                groups.yesterday.append(item)
            } else {
                groups.older.append(item)
            }
        }
    }

    /// Read live from the observed store so the Settings window's history
    /// toggle updates Home immediately.
    private var isHistoryEnabled: Bool {
        settingsStore.isHistoryEnabled
    }

    private func reload() {
        historyItems = (try? historyStore.load()) ?? []
        if let usageStatsStore {
            usageStats = (try? usageStatsStore.load()) ?? .empty
        } else {
            usageStats = .empty
        }
    }

    private func clearHistory() {
        do {
            try actions.clearHistory()
            reload()
            state.refresh()
        } catch {
            clearHistoryErrorMessage = error.localizedDescription
            isShowingClearHistoryError = true
        }
    }
}

enum HomeReadinessPresentation: Equatable {
    case checking
    case ready
    case needsSetup(Int)
    case preparing
    case repairRequired(Int)

    var showsProminentCard: Bool {
        switch self {
        case .needsSetup, .repairRequired:
            return true
        case .checking, .ready, .preparing:
            return false
        }
    }

    static func presentation(
        for presentation: ReadinessPresentation
    ) -> HomeReadinessPresentation {
        switch presentation.phase {
        case .checking: return .checking
        case .ready: return .ready
        case .needsSetup: return .needsSetup(presentation.requiredTaskCount)
        case .preparing: return .preparing
        case .repairRequired: return .repairRequired(presentation.requiredTaskCount)
        }
    }
}

private struct UsageStatsOverviewView: View {
    let stats: UsageStats
    let isCompact: Bool
    let copy: AppCopy.Texts
    let theme: AppTheme

    private var columns: [GridItem] {
        let count = isCompact ? 2 : 4
        return Array(repeating: GridItem(.flexible(), spacing: 14), count: count)
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
            UsageMetricCard(
                title: copy.dictationCountTitle,
                segments: copy.dictationCountSegments(stats.successfulDictations),
                infoHelp: nil,
                symbolName: "mic.fill",
                tint: Color(red: 0.93, green: 0.38, blue: 0.22),
                theme: theme,
                illustration: .dictation
            )
            UsageMetricCard(
                title: copy.recordingDurationTitle,
                segments: copy.durationSegments(stats.cumulativeRecordingSeconds),
                infoHelp: nil,
                symbolName: "waveform",
                tint: Color(red: 0.93, green: 0.67, blue: 0.22),
                theme: theme,
                illustration: .duration
            )
            UsageMetricCard(
                title: copy.dictatedUnitsTitle,
                segments: copy.dictatedUnitsSegments(stats.dictatedUnitCount),
                infoHelp: nil,
                symbolName: "doc.text.fill",
                tint: Color(red: 0.53, green: 0.47, blue: 0.95),
                theme: theme,
                illustration: .words
            )
            UsageMetricCard(
                title: copy.savedTimeTitle,
                segments: copy.durationSegments(stats.estimatedSavedSeconds),
                infoHelp: copy.localEstimateNote,
                symbolName: "bolt.fill",
                tint: Color(red: 0.96, green: 0.73, blue: 0.23),
                theme: theme,
                illustration: .savedTime
            )
        }
    }
}

private struct UsageMetricCard: View {
    enum Illustration {
        case dictation
        case duration
        case words
        case savedTime
    }

    let title: String
    let segments: [AppCopy.MetricValueSegment]
    let infoHelp: String?
    let symbolName: String
    let tint: Color
    let theme: AppTheme
    let illustration: Illustration

    var body: some View {
        ZStack(alignment: .bottom) {
            MetricCardSurface(tint: tint, theme: theme)

            UsageCardIllustration(kind: illustration, tint: tint)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, -18)
                .padding(.bottom, -18)
                .opacity(0.92)
                .mask(alignment: .bottom) {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black.opacity(0.35), location: 0.24),
                            .init(color: .black, location: 0.58),
                            .init(color: .black.opacity(0.86), location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 5) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(theme.ink)
                        .lineLimit(1)

                    if let infoHelp {
                        Image(systemName: "info.circle")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(theme.tertiaryInk)
                            .help(infoHelp)
                            .accessibilityLabel(infoHelp)
                    }
                }

                metricValue

                Spacer(minLength: 20)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
        .frame(minHeight: 132)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(theme.border.opacity(0.8), lineWidth: 1)
        }
    }

    /// Numbers large, units small, aligned on a shared text baseline.
    private var metricValue: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                if segment.isUnit {
                    Text(segment.text)
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(theme.ink)
                } else {
                    Text(segment.text)
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct MetricCardSurface: View {
    let tint: Color
    let theme: AppTheme

    var body: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        theme.elevatedSurface.opacity(0.96),
                        theme.elevatedSurface.opacity(0.76),
                        tint.opacity(0.11)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(alignment: .topLeading) {
                Circle()
                    .fill(.white.opacity(0.07))
                    .frame(width: 168, height: 168)
                    .blur(radius: 34)
                    .offset(x: -88, y: -104)
            }
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(tint.opacity(0.10))
                    .frame(width: 190, height: 190)
                    .blur(radius: 46)
                    .offset(x: 76, y: 72)
            }
    }
}

private struct UsageCardIllustration: View {
    let kind: UsageMetricCard.Illustration
    let tint: Color

    var body: some View {
        if let image = HomeCardArtworkResource.image(named: kind.artworkResourceName) {
            GeometryReader { geometry in
                let artworkSize = kind.artworkSize(in: geometry.size)

                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .scaledToFit()
                    .frame(width: artworkSize.width, height: artworkSize.height)
                    .position(kind.artworkPosition(in: geometry.size, artworkSize: artworkSize))
                    .shadow(color: tint.opacity(0.16), radius: 18, x: 0, y: 8)
                    .shadow(color: .black.opacity(0.28), radius: 16, x: 0, y: 10)
            }
        } else {
            fallbackArtwork
        }
    }

    @ViewBuilder
    private var fallbackArtwork: some View {
        switch kind {
        case .dictation:
            DictationCardArtwork(tint: tint)
        case .duration:
            DurationCardArtwork(tint: tint)
        case .words:
            WordsCardArtwork(tint: tint)
        case .savedTime:
            SavedTimeCardArtwork(tint: tint)
        }
    }
}

private enum HomeCardArtworkResource {
    static func image(named name: String) -> NSImage? {
        if let url = Bundle.main.url(forResource: name, withExtension: "png") {
            return NSImage(contentsOf: url)
        }
        return NSImage(contentsOfFile: "Resources/\(name).png")
    }
}

private extension UsageMetricCard.Illustration {
    var artworkResourceName: String {
        switch self {
        case .dictation:
            return "HomeCardArtwork-mic"
        case .duration:
            return "HomeCardArtwork-wave"
        case .words:
            return "HomeCardArtwork-docs"
        case .savedTime:
            return "HomeCardArtwork-clock"
        }
    }

    var artworkAspectRatio: CGFloat {
        switch self {
        case .dictation:
            return 360 / 380
        case .duration:
            return 420 / 290
        case .words:
            return 380 / 370
        case .savedTime:
            return 390 / 360
        }
    }

    var preferredArtworkWidth: CGFloat {
        switch self {
        case .dictation:
            return 182
        case .duration:
            return 214
        case .words, .savedTime:
            return 188
        }
    }

    var maxWidthRatio: CGFloat {
        switch self {
        case .dictation, .savedTime:
            return 0.80
        case .duration:
            return 0.90
        case .words:
            return 0.78
        }
    }

    var maxHeightRatio: CGFloat {
        switch self {
        case .dictation:
            return 1.04
        case .duration:
            return 0.84
        case .words, .savedTime:
            return 1.02
        }
    }

    var artworkInset: CGFloat {
        switch self {
        case .duration:
            return 8
        case .dictation, .words, .savedTime:
            return 10
        }
    }

    var verticalBleed: CGFloat {
        switch self {
        case .duration:
            return 12
        case .dictation, .words, .savedTime:
            return 18
        }
    }

    func artworkSize(in containerSize: CGSize) -> CGSize {
        let maxWidth = min(preferredArtworkWidth, containerSize.width * maxWidthRatio)
        let maxHeight = containerSize.height * maxHeightRatio

        let widthFromHeight = maxHeight * artworkAspectRatio
        if widthFromHeight <= maxWidth {
            return CGSize(width: widthFromHeight, height: maxHeight)
        }

        return CGSize(width: maxWidth, height: maxWidth / artworkAspectRatio)
    }

    func artworkPosition(in containerSize: CGSize, artworkSize: CGSize) -> CGPoint {
        CGPoint(
            x: containerSize.width - artworkSize.width / 2 - artworkInset,
            y: containerSize.height - artworkSize.height / 2 + verticalBleed
        )
    }
}

private struct GlassDocument: View {
    let tint: Color
    var width: CGFloat = 148
    var height: CGFloat = 112
    var rotation: Angle = .degrees(5)

    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        .white.opacity(0.94),
                        .white.opacity(0.76),
                        tint.opacity(0.20)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: width, height: height)
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.white.opacity(0.62), lineWidth: 1.15)
            }
            .rotationEffect(rotation)
            .shadow(color: .black.opacity(0.14), radius: 12, x: 0, y: 7)
    }
}

private struct DictationCardArtwork: View {
    let tint: Color

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            GlassDocument(tint: tint, width: 154, height: 108, rotation: .degrees(6))
                .overlay(alignment: .topLeading) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(tint.opacity(1.0))
                        .padding(.leading, 24)
                        .padding(.top, 22)
                }
                .overlay(alignment: .topTrailing) {
                    Capsule()
                        .fill(tint.opacity(0.38))
                        .frame(width: 46, height: 13)
                        .padding(.trailing, 22)
                        .padding(.top, 34)
                }
                .overlay(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(tint.opacity(0.25))
                        .frame(width: 96, height: 54)
                        .padding(.leading, 28)
                        .padding(.bottom, 12)
                }
        }
        .frame(width: 216, height: 138)
    }
}

private struct DurationCardArtwork: View {
    let tint: Color

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Capsule()
                .fill(.white.opacity(0.72))
                .frame(width: 172, height: 62)
                .overlay(alignment: .leading) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                        .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(tint)
                        HStack(spacing: 7) {
                            ForEach([22, 38, 48, 34, 42, 28, 36], id: \.self) { height in
                                Capsule()
                                    .fill(tint.opacity(0.92))
                                    .frame(width: 7, height: CGFloat(height))
                            }
                        }
                    }
                    .padding(.leading, 22)
                }
                .shadow(color: tint.opacity(0.14), radius: 16, x: 0, y: 8)
                .offset(x: 20, y: -10)
        }
        .frame(width: 224, height: 138)
    }
}

private struct WordsCardArtwork: View {
    let tint: Color

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            GlassDocument(tint: tint, width: 152, height: 112, rotation: .degrees(6))
                .overlay(alignment: .topLeading) {
                    Capsule()
                        .fill(tint.opacity(0.58))
                        .frame(width: 74, height: 12)
                        .padding(.leading, 25)
                        .padding(.top, 22)
                }
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 9) {
                        Capsule()
                            .fill(tint.opacity(0.34))
                            .frame(width: 110, height: 12)
                        Capsule()
                            .fill(tint.opacity(0.30))
                            .frame(width: 94, height: 12)
                    }
                    .padding(.leading, 26)
                    .padding(.bottom, 24)
                }
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(tint.opacity(0.82))
                        .frame(width: 28, height: 28)
                        .overlay {
                            Text("文")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.92))
                        }
                        .padding(.trailing, 22)
                        .padding(.top, 28)
                }
        }
        .frame(width: 220, height: 138)
    }
}

private struct SavedTimeCardArtwork: View {
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.86),
                            .white.opacity(0.62),
                            tint.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 116, height: 116)
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.38), lineWidth: 1)
                }
                .overlay {
                    ClockTicks(tint: tint)
                        .frame(width: 92, height: 92)
                }
                .overlay {
                    ClockHands(tint: tint)
                        .frame(width: 74, height: 74)
                }
                .shadow(color: .black.opacity(0.08), radius: 9, x: 0, y: 6)
                .offset(x: -8, y: -2)

            Circle()
                .fill(tint.opacity(0.18))
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 23, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [tint.opacity(0.98), tint.opacity(0.64)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.22), lineWidth: 1)
                }
                .offset(x: 46, y: 36)
        }
        .frame(width: 220, height: 138)
    }
}

private struct ClockTicks: View {
    let tint: Color

    var body: some View {
        ZStack {
            ForEach(0..<12, id: \.self) { index in
                Capsule()
                    .fill(index % 3 == 0 ? tint.opacity(0.38) : tint.opacity(0.18))
                    .frame(width: index % 3 == 0 ? 4 : 3, height: index % 3 == 0 ? 10 : 7)
                    .offset(y: -40)
                    .rotationEffect(.degrees(Double(index) * 30))
            }
        }
    }
}

private struct ClockHands: View {
    let tint: Color

    var body: some View {
        ZStack {
            Capsule()
                .fill(tint.opacity(0.72))
                .frame(width: 7, height: 30)
                .offset(y: -11)
                .rotationEffect(.degrees(42))

            Capsule()
                .fill(tint.opacity(0.56))
                .frame(width: 6, height: 23)
                .offset(y: -8)
                .rotationEffect(.degrees(-58))

            Circle()
                .fill(tint.opacity(0.92))
                .frame(width: 11, height: 11)
        }
    }
}
