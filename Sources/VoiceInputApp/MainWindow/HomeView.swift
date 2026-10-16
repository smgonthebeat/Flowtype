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
            .themedPageBackground(theme)
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
                    .scaledFont(size: 34, weight: .semibold, design: .default)
                    .lineLimit(2)
                    .foregroundStyle(theme.ink)

                if readinessPresentation.showsInlineStatus {
                    Label(
                        readinessInlineTitle(for: readinessPresentation, copy: copy),
                        systemImage: readinessSymbol(for: readinessPresentation)
                    )
                    .scaledFont(.callout, weight: .medium)
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
                        .scaledFont(size: 20, weight: .semibold)
                        .foregroundStyle(readinessColor(for: presentation))
                }
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(readinessTitle(for: presentation, copy: copy))
                    .scaledFont(.headline)
                    .foregroundStyle(theme.ink)

                Text(readinessDetail(for: presentation, copy: copy))
                    .scaledFont(.callout)
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
            .buttonStyle(FlowtypeNeutralButtonStyle(theme: theme))
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
        .scaledFont(.callout)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedPageStrip(theme, cornerRadius: 8)
    }

    private var historyControls: some View {
        let copy = AppCopy.texts(for: settingsStore.uiLanguage)

        return HStack(spacing: 14) {
            Text(copy.historySectionTitle)
                .scaledFont(.headline)
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
            clearHistoryErrorMessage = UserFacingErrorMessage.message(for: error, language: settingsStore.uiLanguage)
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

    /// Owner feedback (2026-10-03): the green "ready" line under the headline was noise once
    /// everything works. Only model preparation, which can take minutes, keeps an inline line;
    /// the launch check is too brief to show without making the header jump when it ends.
    var showsInlineStatus: Bool {
        self == .preparing
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

    @Environment(\.colorScheme) private var colorScheme

    private var usesLightArtwork: Bool {
        theme.usesLightCardArtwork(in: colorScheme)
    }

    /// Light themes use the Dawn artwork, whose colours run peach, rose, violet and blue across
    /// the row; the glow and the artwork shadow follow that colour instead of the dark-theme tint.
    private var cardTint: Color {
        usesLightArtwork ? illustration.dawnTint : tint
    }

    /// The artwork fades out towards the top so the title and number stay clean. The Dawn cards
    /// fade less (0.65 of the full fade, owner's pick in the HTML tuner, task 19).
    private var topFadeStops: [Gradient.Stop] {
        let fade: Double = usesLightArtwork ? 0.65 : 1
        return [
            .init(color: .black.opacity(1 - fade), location: 0),
            .init(color: .black.opacity(1 - fade * 0.65), location: 0.24),
            .init(color: .black, location: 0.58),
            .init(color: .black.opacity(1 - fade * 0.14), location: 1)
        ]
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            MetricCardSurface(tint: cardTint, theme: theme)

            UsageCardIllustration(kind: illustration, tint: cardTint, theme: theme)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, -UsageArtworkPlacement.framePadding)
                .padding(.bottom, -UsageArtworkPlacement.framePadding)
                .opacity(0.92)
                .mask(alignment: .bottom) {
                    LinearGradient(stops: topFadeStops, startPoint: .top, endPoint: .bottom)
                }

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 5) {
                    Text(title)
                        .scaledFont(size: 15, weight: .medium)
                        .foregroundStyle(theme.ink)
                        .lineLimit(1)

                    if let infoHelp {
                        Image(systemName: "info.circle")
                            .scaledFont(size: 11, weight: .medium)
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
                .stroke(theme.backdrop == nil ? theme.border.opacity(0.8) : theme.cardEdge, lineWidth: 1)
        }
        // The same Dawn-violet lift as `themedCard`; a no-op for themes without a backdrop.
        .themedCardShadow(theme)
    }

    /// Numbers large, units small, aligned on a shared text baseline.
    private var metricValue: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                if segment.isUnit {
                    Text(segment.text)
                        .scaledFont(size: 18, weight: .medium, design: .rounded)
                        .foregroundStyle(theme.ink)
                } else {
                    Text(segment.text)
                        .scaledFont(size: 30, weight: .semibold, design: .rounded)
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

/// A soft round glow: full strength in the middle, fading to clear at `radius`.
struct MetricCardGlow: View {
    static let radius: CGFloat = 150

    enum Corner {
        case topLeading
        case bottomTrailing
    }

    let tint: Color
    let opacity: Double
    let corner: Corner
    /// Distance of the glow's centre from that corner, inward (negative = outside the card).
    let inset: CGSize

    var body: some View {
        // Fill the whole card and place the gradient's centre from the card's measured size.
        // The earlier version drew a 300 pt gradient inside a 190 pt frame and offset it from a
        // corner overlay; that overflow layout put the glow near the middle of the card on other
        // macOS versions (seen on a downloaded Preview 10), so nothing here relies on overflow.
        GeometryReader { geometry in
            let size = geometry.size
            let x = corner == .bottomTrailing ? size.width - inset.width : inset.width
            let y = corner == .bottomTrailing ? size.height - inset.height : inset.height
            RadialGradient(
                stops: [
                    .init(color: tint.opacity(opacity), location: 0),
                    .init(color: tint.opacity(opacity * 0.6), location: 0.4),
                    .init(color: tint.opacity(0), location: 1)
                ],
                center: UnitPoint(
                    x: size.width > 0 ? x / size.width : 1,
                    y: size.height > 0 ? y / size.height : 1
                ),
                startRadius: 0,
                endRadius: Self.radius
            )
        }
        .allowsHitTesting(false)
    }
}

private struct MetricCardSurface: View {
    let tint: Color
    let theme: AppTheme

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if theme.backdrop != nil {
            // Opaque white, with only the faint tint glow in the bottom-trailing corner (a little
            // stronger behind the Dawn artwork: 0.20, owner's pick in the HTML tuner, task 19). The glow
            // is a radial gradient rather than a blurred circle: the blurred circle rendered with a
            // visible disc edge, and the gradient is what the HTML tuner draws.
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(theme.elevatedSurface)
                .overlay {
                    MetricCardGlow(
                        tint: tint,
                        opacity: theme.usesLightCardArtwork(in: colorScheme) ? 0.20 : 0.10,
                        corner: .bottomTrailing,
                        inset: CGSize(width: 19, height: 23)
                    )
                }
        } else {
            flatThemeSurface
        }
    }

    private var flatThemeSurface: some View {
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
            // Radial gradients, not blurred circles: a blurred circle leaves a visible disc edge,
            // which showed once the shared artwork frame stopped covering it (task 19). The
            // top-leading highlight keeps the centre of the earlier 168 pt circle.
            .overlay {
                MetricCardGlow(tint: .white, opacity: 0.07, corner: .topLeading, inset: CGSize(width: -4, height: -20))
            }
            .overlay {
                MetricCardGlow(tint: tint, opacity: 0.10, corner: .bottomTrailing, inset: CGSize(width: 19, height: 23))
            }
    }
}

private struct UsageCardIllustration: View {
    let kind: UsageMetricCard.Illustration
    let tint: Color
    let theme: AppTheme

    @Environment(\.colorScheme) private var colorScheme

    private var usesLightArtwork: Bool {
        theme.usesLightCardArtwork(in: colorScheme)
    }

    var body: some View {
        if let image = HomeCardArtworkResource.image(
            named: kind.artworkResourceName + (usesLightArtwork ? "-light" : "")
        ) {
            GeometryReader { geometry in
                let placement = kind.placement(in: geometry.size)

                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .scaledToFit()
                    .frame(width: placement.size.width, height: placement.size.height)
                    .mask {
                        LinearGradient(stops: leftFadeStops, startPoint: .leading, endPoint: .trailing)
                    }
                    .position(placement.center)
                    .shadow(color: tint.opacity(0.16), radius: 18, x: 0, y: 8)
                    .shadow(color: .black.opacity(usesLightArtwork ? 0.10 : 0.28), radius: 16, x: 0, y: 10)
            }
        } else {
            fallbackArtwork
        }
    }

    /// Fades the left part of the artwork so its heavy colour reads at the bottom right, like the
    /// microphone and document cards; only the Dawn waveform and clock need it (owner's pick in
    /// the HTML tuner, task 19). Stops follow the tuner: 1 - fade at 0, 1 - fade / 2 at 30 %,
    /// opaque from 62 %.
    private var leftFadeStops: [Gradient.Stop] {
        let fade = usesLightArtwork ? kind.dawnLeftFade : 0
        return [
            .init(color: .black.opacity(1 - fade), location: 0),
            .init(color: .black.opacity(1 - fade * 0.5), location: 0.30),
            .init(color: .black, location: 0.62)
        ]
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

    // MARK: Layout

    /// Pixel size of the artwork PNG (the dark original and its `-light` version share the canvas).
    var artworkPixelSize: CGSize {
        switch self {
        case .dictation:
            return CGSize(width: 360, height: 380)
        case .duration:
            return CGSize(width: 420, height: 290)
        case .words:
            return CGSize(width: 380, height: 370)
        case .savedTime:
            return CGSize(width: 390, height: 360)
        }
    }

    /// Bounds of the opaque artwork inside its canvas (alpha > 50%, measured on the original), in
    /// pixels, top-left origin. The canvases have different padding, so the layout works from
    /// these, not the canvas.
    var artworkContentPixelBounds: CGRect {
        switch self {
        case .dictation:
            return CGRect(x: 17, y: 16, width: 327, height: 314)
        case .duration:
            return CGRect(x: 20, y: 12, width: 383, height: 259)
        case .words:
            return CGRect(x: 31, y: 15, width: 327, height: 328)
        case .savedTime:
            return CGRect(x: 26, y: 15, width: 341, height: 321)
        }
    }

    /// The four artworks share one frame in every theme: the same visual size (the square root of
    /// the content area, so the wide waveform is not drawn bigger than the others) and the same
    /// overhang past the trailing and bottom card edges.
    func placement(in containerSize: CGSize) -> UsageArtworkPlacement {
        UsageArtworkPlacement.shared(
            in: containerSize,
            pixelSize: artworkPixelSize,
            contentPixelBounds: artworkContentPixelBounds
        )
    }

    /// Dawn colour per card, in logo order: peach, rose, violet, sky blue. The light artwork is
    /// recoloured with the same values (`docs/maintenance/artifacts/2026-10-14-home-cards-dawn/`).
    /// Left fade of the Dawn artwork (see `UsageCardIllustration.leftFadeStops`).
    var dawnLeftFade: Double {
        switch self {
        case .duration, .savedTime:
            return 0.3
        case .dictation, .words:
            return 0
        }
    }

    var dawnTint: Color {
        switch self {
        case .dictation:
            return Color(hex: "#F09A73")
        case .duration:
            return Color(hex: "#E68AAE")
        case .words:
            return Color(hex: "#9C86E2")
        case .savedTime:
            return Color(hex: "#6CA4EA")
        }
    }
}

struct UsageArtworkPlacement: Equatable {
    /// The artwork frame reaches this far past the card's trailing and bottom edges.
    static let framePadding: CGFloat = 18

    // Measured from the card edges (owner's pick in the HTML tuner for Flowtype Dawn, then used
    // for every theme, task 19): content size as a share of the card height, capped by a share of
    // the card width in narrow windows; negative insets let the artwork run past the edge and be
    // clipped by the card.
    static let heightShare: CGFloat = 0.86
    static let widthShare: CGFloat = 0.48
    static let trailingInset: CGFloat = -6
    static let bottomInset: CGFloat = -10

    let size: CGSize
    let center: CGPoint

    /// Places one artwork so that its opaque content (not its canvas) has the shared visual size
    /// and position; see `UsageMetricCard.Illustration.placement(in:)`. `containerSize` is
    /// the artwork frame, which extends `framePadding` past the card; the frame and the card share
    /// their top-leading corner, so the result is in the same coordinates for both.
    static func shared(in containerSize: CGSize, pixelSize: CGSize, contentPixelBounds content: CGRect) -> UsageArtworkPlacement {
        let card = CGSize(width: containerSize.width - framePadding, height: containerSize.height - framePadding)
        let visualSize = min(card.height * heightShare, card.width * widthShare)
        let scale = visualSize / (content.width * content.height).squareRoot()
        let size = CGSize(width: pixelSize.width * scale, height: pixelSize.height * scale)

        let contentMaxX = card.width - trailingInset
        let contentMaxY = card.height - bottomInset
        let origin = CGPoint(x: contentMaxX - content.maxX * scale, y: contentMaxY - content.maxY * scale)
        return UsageArtworkPlacement(
            size: size,
            center: CGPoint(x: origin.x + size.width / 2, y: origin.y + size.height / 2)
        )
    }
}

extension AppTheme {
    /// Light themes use the Dawn `-light` artwork (with its colours and fades) on light cards; the
    /// dark themes keep the original dark-glass artwork. The Apple theme follows the system
    /// appearance, so it takes the Dawn artwork in light mode and the original in dark mode.
    func usesLightCardArtwork(in colorScheme: ColorScheme) -> Bool {
        usesSystemMaterials ? colorScheme == .light : !isDark
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
                        .scaledFont(size: 26, weight: .semibold)
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
                        .scaledFont(size: 22, weight: .semibold)
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
                                .scaledFont(size: 15, weight: .bold, design: .rounded)
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
                        .scaledFont(size: 23, weight: .bold)
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
