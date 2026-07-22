import SwiftUI

enum TranscriptRowLayout {
    static let hoverBackgroundHorizontalInset: CGFloat = 0
    static let hoverBackgroundVerticalInset: CGFloat = 0
    static let hoverBackgroundFixedHeight: CGFloat? = nil
    static let reservesActionButtonsDuringIdle = true

    static func actionButtonsOpacity(isHovered: Bool) -> Double {
        isHovered ? 1 : 0
    }

    static func textOverflows(
        collapsedHeight: CGFloat,
        fullHeight: CGFloat,
        tolerance: CGFloat = 0.5
    ) -> Bool {
        fullHeight > collapsedHeight + tolerance
    }
}

enum TranscriptRowMotion {
    static let expandControlDuration: TimeInterval = 0.12
    static let feedbackFadeDuration: TimeInterval = 0.12
    static let animatesTextLayout = false

    static func animatesExpandControl(reduceMotion: Bool) -> Bool {
        !reduceMotion
    }

    static func retryUsesPositionalMotion(reduceMotion: Bool) -> Bool {
        !reduceMotion
    }
}

private struct TranscriptCollapsedTextHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct TranscriptFullTextHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct TranscriptTextOverflowReader: View {
    let text: String

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                measuredText(lineLimit: 4)
                    .background {
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: TranscriptCollapsedTextHeightKey.self,
                                value: proxy.size.height
                            )
                        }
                    }

                measuredText(lineLimit: nil)
                    .background {
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: TranscriptFullTextHeightKey.self,
                                value: proxy.size.height
                            )
                        }
                    }
            }
            .frame(width: geometry.size.width, alignment: .topLeading)
            .hidden()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func measuredText(lineLimit: Int?) -> some View {
        Text(text)
            .lineLimit(lineLimit)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TranscriptRowHoverBackgroundSizing: ViewModifier {
    let fixedHeight: CGFloat?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let fixedHeight {
            content.frame(height: fixedHeight)
        } else {
            content
        }
    }
}

struct TranscriptRowView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let item: TranscriptHistoryItem
    let timestampWidth: CGFloat
    let copy: AppCopy.Texts
    let actions: MainWindowActions
    private let copySuccessColor = Color(red: 0.18, green: 0.78, blue: 0.55)
    private let retryFailureColor = Color(red: 0.92, green: 0.32, blue: 0.28)
    @State private var isHovered = false
    @State private var isExpanded = false
    @State private var collapsedTextHeight: CGFloat = 0
    @State private var fullTextHeight: CGFloat = 0
    @State private var isCopyConfirmed = false
    @State private var isRetrying = false
    @State private var retryFeedback: RetryFeedbackState?
    @State private var retryFeedbackID = UUID()

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(Self.timeFormatter.string(from: item.createdAt))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(theme.secondaryInk)
                .frame(width: timestampWidth, alignment: .trailing)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                Text(presentation.primaryText)
                    .lineLimit(isExpanded ? nil : 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(theme.ink)
                    .background {
                        TranscriptTextOverflowReader(text: presentation.primaryText)
                    }
                    .onPreferenceChange(TranscriptCollapsedTextHeightKey.self) {
                        collapsedTextHeight = $0
                    }
                    .onPreferenceChange(TranscriptFullTextHeightKey.self) {
                        fullTextHeight = $0
                    }

                if let secondaryText = presentation.secondaryText {
                    Text(secondaryText)
                        .font(.caption)
                        .foregroundStyle(theme.secondaryInk)
                }

                if let recoveryMarkerText = presentation.recoveryMarkerText {
                    Label(recoveryMarkerText, systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(theme.success)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(theme.success.opacity(0.12), in: Capsule())
                }

                if item.transcriptionIssue == .possibleTruncation {
                    Label(copy.rowPossibleTruncation, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if let retryFeedback {
                    retryFeedbackLabel(retryFeedback)
                        .transition(retryFeedbackTransition)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(feedbackAnimation, value: item.transcriptionIssue)
            .animation(feedbackAnimation, value: retryFeedback)

            HStack(spacing: 6) {
                if shouldReserveActions {
                    if showsExpandControl {
                        rowActionButton(
                            systemImage: "chevron.down",
                            help: isExpanded ? copy.rowCollapse : copy.rowExpand,
                            accessibilityLabel: isExpanded ? copy.rowCollapse : copy.rowExpand,
                            rotation: isExpanded ? .degrees(180) : .zero,
                            rotationAnimation: expandControlAnimation,
                            action: { isExpanded.toggle() }
                        )
                    }
                    if presentation.canRetry {
                        let retryHelp = isRetrying
                            ? copy.rowRetryingSegmented
                            : (presentation.retryButtonTitle ?? copy.rowRetrySegmented)
                        rowActionButton(
                            systemImage: isRetrying ? "hourglass" : "arrow.clockwise",
                            help: retryHelp,
                            accessibilityLabel: presentation.retryButtonTitle ?? copy.rowRetrySegmented,
                            isDisabled: isRetrying,
                            action: { retrySegmentedTranscription() }
                        )
                    }
                    if presentation.canCopyAndPaste {
                        rowActionButton(
                            systemImage: isCopyConfirmed ? "checkmark" : "doc.on.doc",
                            help: isCopyConfirmed ? copy.rowCopied : copy.rowCopy,
                            accessibilityLabel: isCopyConfirmed ? copy.rowCopied : copy.rowCopyTranscript,
                            isConfirmed: isCopyConfirmed,
                            action: {
                                actions.copyTranscript(presentation.primaryText)
                                showCopyFeedback()
                            }
                        )
                        rowActionButton(
                            systemImage: "arrow.turn.down.right",
                            help: copy.rowPaste,
                            accessibilityLabel: copy.rowPasteAgain,
                            action: { actions.pasteTranscript(presentation.primaryText) }
                        )
                    }
                }
            }
            .opacity(actionsAreVisible ? 1 : 0)
            .allowsHitTesting(actionsAreVisible)
            .frame(width: actionButtonsWidth, alignment: .trailing)
            .animation(.easeOut(duration: 0.12), value: isHovered)
            .animation(feedbackAnimation, value: presentation.canRetry)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(alignment: .top) {
            if isHovered {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(theme.hoverSurface)
                    .modifier(TranscriptRowHoverBackgroundSizing(fixedHeight: TranscriptRowLayout.hoverBackgroundFixedHeight))
                    .padding(.horizontal, TranscriptRowLayout.hoverBackgroundHorizontalInset)
                    .padding(.vertical, TranscriptRowLayout.hoverBackgroundVerticalInset)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onHover {
            isHovered = $0
        }
        .onChange(of: showsExpandControl) {
            if !showsExpandControl {
                isExpanded = false
            }
        }
        .contextMenu {
            if presentation.canCopyAndPaste {
                Button(copy.rowCopy) {
                    actions.copyTranscript(presentation.primaryText)
                    showCopyFeedback()
                }
                Button(copy.rowPaste) {
                    actions.pasteTranscript(presentation.primaryText)
                }
            }
            if presentation.canRetry {
                Button(presentation.retryButtonTitle ?? copy.rowRetrySegmented) {
                    retrySegmentedTranscription()
                }
            }
            if showsExpandControl {
                Button(isExpanded ? copy.rowCollapse : copy.rowExpand) {
                    isExpanded.toggle()
                }
            }
        }
    }

    private func rowActionButton(
        systemImage: String,
        help: String,
        accessibilityLabel: String,
        isConfirmed: Bool = false,
        isDisabled: Bool = false,
        rotation: Angle = .zero,
        rotationAnimation: Animation? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .medium))
                .rotationEffect(rotation)
                .animation(rotationAnimation, value: rotation)
                .frame(width: 24, height: 24)
                .background {
                    if isConfirmed {
                        Circle()
                            .fill(copySuccessColor.opacity(0.20))
                    }
                }
        }
        .buttonStyle(.borderless)
        .disabled(isDisabled)
        .foregroundStyle(isConfirmed ? theme.success : theme.secondaryInk)
        .help(help)
        .accessibilityLabel(accessibilityLabel)
    }

    private var presentation: TranscriptRowPresentation {
        TranscriptRowPresentation.make(item: item, copy: copy)
    }

    private var feedbackAnimation: Animation? {
        if reduceMotion {
            return .easeOut(duration: TranscriptRowMotion.feedbackFadeDuration)
        }
        return .spring(response: 0.28, dampingFraction: 0.86)
    }

    private var expandControlAnimation: Animation? {
        guard TranscriptRowMotion.animatesExpandControl(reduceMotion: reduceMotion) else {
            return nil
        }
        return .easeOut(duration: TranscriptRowMotion.expandControlDuration)
    }

    private var retryFeedbackTransition: AnyTransition {
        guard TranscriptRowMotion.retryUsesPositionalMotion(reduceMotion: reduceMotion) else {
            return .opacity
        }
        return .asymmetric(
            insertion: .opacity
                .combined(with: .move(edge: .top))
                .combined(with: .scale(scale: 0.98, anchor: .leading)),
            removal: .opacity
                .combined(with: .move(edge: .top))
                .combined(with: .scale(scale: 0.98, anchor: .leading))
        )
    }

    private var shouldReserveActions: Bool {
        TranscriptRowLayout.reservesActionButtonsDuringIdle || actionsAreVisible
    }

    private var actionsAreVisible: Bool {
        isHovered || presentation.showsRetryAtRest
    }

    private var showsExpandControl: Bool {
        presentation.canCopyAndPaste && TranscriptRowLayout.textOverflows(
            collapsedHeight: collapsedTextHeight,
            fullHeight: fullTextHeight
        )
    }

    private var actionButtonsWidth: CGFloat {
        let buttonCount = (presentation.canCopyAndPaste ? 3 : 0) + (presentation.canRetry ? 1 : 0)
        guard buttonCount > 0 else { return 0 }
        return CGFloat(buttonCount * 30 - 6)
    }

    private func retrySegmentedTranscription() {
        guard !isRetrying else { return }
        isRetrying = true
        setRetryFeedback(.retrying, clearsAutomatically: false)
        Task {
            let result = await actions.retrySegmentedTranscription(item)
            await MainActor.run {
                isRetrying = false
                setRetryFeedback(retryFeedbackState(for: result), clearsAutomatically: true)
            }
        }
    }

    private func retryFeedbackState(for result: SegmentedRetryResult) -> RetryFeedbackState {
        switch result {
        case .succeeded:
            .succeeded
        case .failed:
            .failed
        case .expiredRecording:
            .expiredRecording
        }
    }

    private func retryFeedbackLabel(_ state: RetryFeedbackState) -> some View {
        Label(retryFeedbackText(for: state), systemImage: retryFeedbackImage(for: state))
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(retryFeedbackColor(for: state))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(retryFeedbackColor(for: state).opacity(0.13), in: Capsule())
    }

    private func retryFeedbackText(for state: RetryFeedbackState) -> String {
        switch state {
        case .retrying:
            copy.rowRetryingSegmented
        case .succeeded:
            copy.rowRetrySegmentedSucceeded
        case .failed:
            copy.rowRetrySegmentedFailed
        case .expiredRecording:
            copy.rowRecordingExpired
        }
    }

    private func retryFeedbackImage(for state: RetryFeedbackState) -> String {
        switch state {
        case .retrying:
            "hourglass"
        case .succeeded:
            "checkmark.circle.fill"
        case .failed:
            "exclamationmark.circle.fill"
        case .expiredRecording:
            "clock.badge.exclamationmark"
        }
    }

    private func retryFeedbackColor(for state: RetryFeedbackState) -> Color {
        switch state {
        case .retrying:
            .orange
        case .succeeded:
            copySuccessColor
        case .failed:
            retryFailureColor
        case .expiredRecording:
            retryFailureColor
        }
    }

    private func setRetryFeedback(_ state: RetryFeedbackState, clearsAutomatically: Bool) {
        withAnimation(feedbackAnimation) {
            retryFeedback = state
        }
        let feedbackID = UUID()
        retryFeedbackID = feedbackID

        guard clearsAutomatically else { return }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            guard retryFeedbackID == feedbackID else { return }
            withAnimation(feedbackAnimation) {
                retryFeedback = nil
            }
        }
    }

    private func showCopyFeedback() {
        isCopyConfirmed = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            isCopyConfirmed = false
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
}

private enum RetryFeedbackState: Equatable {
    case retrying
    case succeeded
    case failed
    case expiredRecording
}
