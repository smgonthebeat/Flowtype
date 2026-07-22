import Foundation

struct TranscriptRowPresentation: Equatable {
    let primaryText: String
    let secondaryText: String?
    let recoveryMarkerText: String?
    let canCopyAndPaste: Bool
    let canRetry: Bool
    let showsRetryAtRest: Bool
    let retryButtonTitle: String?

    static func make(item: TranscriptHistoryItem, copy: AppCopy.Texts) -> TranscriptRowPresentation {
        switch item.status {
        case .failed:
            let isExpired = item.failureCategory == .expiredRecording
            let canRetry = item.failureCategory == .transcriptionFailed && item.recordingFileName != nil
            return TranscriptRowPresentation(
                primaryText: copy.rowTranscriptionFailed,
                secondaryText: canRetry && !isExpired ? copy.rowRecoverableFailureDetail : copy.rowRecordingExpired,
                recoveryMarkerText: nil,
                canCopyAndPaste: false,
                canRetry: canRetry,
                showsRetryAtRest: true,
                retryButtonTitle: copy.rowRetryTranscription
            )
        case .recovered:
            let canRetry = item.transcriptionIssue == .possibleTruncation && item.recordingFileName != nil
            return TranscriptRowPresentation(
                primaryText: item.text,
                secondaryText: nil,
                recoveryMarkerText: copy.rowRetrySegmentedSucceeded,
                canCopyAndPaste: Self.hasTranscriptText(item.text),
                canRetry: canRetry,
                showsRetryAtRest: false,
                retryButtonTitle: canRetry ? copy.rowRetrySegmented : nil
            )
        case .succeeded:
            let canRetry = item.transcriptionIssue == .possibleTruncation && item.recordingFileName != nil
            return TranscriptRowPresentation(
                primaryText: item.text,
                secondaryText: nil,
                recoveryMarkerText: nil,
                canCopyAndPaste: Self.hasTranscriptText(item.text),
                canRetry: canRetry,
                showsRetryAtRest: false,
                retryButtonTitle: canRetry ? copy.rowRetrySegmented : nil
            )
        }
    }

    private static func hasTranscriptText(_ text: String) -> Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
