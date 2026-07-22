import Foundation

protocol QwenModelStatusProviding {
    func modelStatus(modelID: String) async throws -> QwenModelStatus
}

struct QwenReadinessGateResult {
    let state: QwenRuntimeState
    let status: QwenModelStatus?
    let failureKind: QwenFailureKind?
    let waitedMilliseconds: Int
}

struct QwenModelReadinessGate {
    var statusProvider: any QwenModelStatusProviding
    var sleep: (UInt64) async -> Void = { nanoseconds in
        try? await Task.sleep(nanoseconds: nanoseconds)
    }
    var pollIntervalNanoseconds: UInt64 = 500_000_000

    func waitForReady(model: VoiceInputModel, budget: TimeInterval) async throws -> QwenReadinessGateResult {
        let startedAt = Date()
        var lastStatus: QwenModelStatus?

        repeat {
            let status = try await statusProvider.modelStatus(modelID: model.modelID)
            lastStatus = status

            if !status.installed {
                return QwenReadinessGateResult(
                    state: .notInstalled,
                    status: status,
                    failureKind: .modelNotInstalled,
                    waitedMilliseconds: milliseconds(since: startedAt)
                )
            }

            if status.loaded {
                return QwenReadinessGateResult(
                    state: .ready,
                    status: status,
                    failureKind: nil,
                    waitedMilliseconds: milliseconds(since: startedAt)
                )
            }

            guard Date().timeIntervalSince(startedAt) < budget else {
                break
            }
            await sleep(pollIntervalNanoseconds)
        } while Date().timeIntervalSince(startedAt) <= budget

        return QwenReadinessGateResult(
            state: .failedRecoverable,
            status: lastStatus,
            failureKind: .modelLoadTimedOut,
            waitedMilliseconds: milliseconds(since: startedAt)
        )
    }

    private func milliseconds(since date: Date) -> Int {
        max(0, Int(Date().timeIntervalSince(date) * 1_000))
    }
}
