import Foundation

struct PasteTelemetryEvent: Equatable, Sendable {
    let attemptID: UUID
    let source: PasteSource
    let targetProcessIdentifier: pid_t?
    let targetBundleIdentifier: String?
    let outcome: PasteOutcome
    let pasteboardChangeCountBefore: Int
    let pasteboardChangeCountAfter: Int
    let eventPairCount: Int
    let frontmostMatch: Bool?
    let elapsedMilliseconds: Int
}

protocol PasteTelemetryRecording: AnyObject {
    func record(_ event: PasteTelemetryEvent)
}

final class PasteLoggerTelemetry: PasteTelemetryRecording {
    func record(_ event: PasteTelemetryEvent) {
        let targetPID = event.targetProcessIdentifier ?? -1
        let targetBundleIdentifier = event.targetBundleIdentifier ?? "missing"
        let frontmostMatch = event.frontmostMatch.map(String.init) ?? "unknown"
        AppLogger.paste.info(
            "paste_attempt_result attempt_id=\(event.attemptID.uuidString, privacy: .public) source=\(event.source.rawValue, privacy: .public) target_pid=\(targetPID, privacy: .public) target_bundle=\(targetBundleIdentifier, privacy: .public) frontmost_match=\(frontmostMatch, privacy: .public) outcome=\(event.outcome.diagnosticName, privacy: .public) change_before=\(event.pasteboardChangeCountBefore, privacy: .public) change_after=\(event.pasteboardChangeCountAfter, privacy: .public) event_pair_count=\(event.eventPairCount, privacy: .public) elapsed_ms=\(event.elapsedMilliseconds, privacy: .public)"
        )
    }
}
