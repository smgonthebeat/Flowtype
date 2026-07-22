import Foundation

@MainActor
final class PasteCoordinator {
    typealias TargetResolver = @MainActor (PasteTargetIdentity) async -> PasteTargetIdentity?
    typealias TargetValidator = @MainActor (PasteTargetIdentity) -> Bool

    private let injector: PasteInjector
    private let telemetry: PasteTelemetryRecording
    private var consumedAttemptIDs: Set<UUID> = []

    init(injector: PasteInjector, telemetry: PasteTelemetryRecording) {
        self.injector = injector
        self.telemetry = telemetry
    }

    func perform(
        _ attempt: PasteAttempt,
        resolveTarget: TargetResolver,
        validateTarget: TargetValidator
    ) async -> PasteOutcome {
        let startedAt = ProcessInfo.processInfo.systemUptime
        guard consumedAttemptIDs.insert(attempt.id).inserted else {
            let result = injector.noOpResult(.duplicateIgnored)
            log(attempt: attempt, resolvedTarget: nil, result: result, startedAt: startedAt)
            return result.outcome
        }

        guard PasteInjector.isPasteable(attempt.text) else {
            let result = injector.noOpResult(.invalidText)
            log(attempt: attempt, resolvedTarget: nil, result: result, startedAt: startedAt)
            return result.outcome
        }

        guard let capturedTarget = attempt.target else {
            let result = injector.copyOnly(attempt.text, reason: .missingTarget)
            log(attempt: attempt, resolvedTarget: nil, result: result, startedAt: startedAt)
            return result.outcome
        }

        guard let resolvedTarget = await resolveTarget(capturedTarget) else {
            let result = injector.copyOnly(
                attempt.text,
                reason: .targetRejected,
                frontmostMatch: false
            )
            log(attempt: attempt, resolvedTarget: nil, result: result, startedAt: startedAt)
            return result.outcome
        }

        let result = injector.dispatch(
            attempt.text,
            to: resolvedTarget.processIdentifier,
            validateTarget: { validateTarget(resolvedTarget) }
        )
        log(
            attempt: attempt,
            resolvedTarget: resolvedTarget,
            result: result,
            startedAt: startedAt
        )
        return result.outcome
    }

    private func log(
        attempt: PasteAttempt,
        resolvedTarget: PasteTargetIdentity?,
        result: PasteOperationResult,
        startedAt: TimeInterval
    ) {
        let target = resolvedTarget ?? attempt.target
        let elapsedMilliseconds = Int(
            max(0, ProcessInfo.processInfo.systemUptime - startedAt) * 1_000
        )

        telemetry.record(PasteTelemetryEvent(
            attemptID: attempt.id,
            source: attempt.source,
            targetProcessIdentifier: target?.processIdentifier,
            targetBundleIdentifier: target?.bundleIdentifier,
            outcome: result.outcome,
            pasteboardChangeCountBefore: result.pasteboardChangeCountBefore,
            pasteboardChangeCountAfter: result.pasteboardChangeCountAfter,
            eventPairCount: result.eventPairCount,
            frontmostMatch: result.frontmostMatch,
            elapsedMilliseconds: elapsedMilliseconds
        ))
    }
}
