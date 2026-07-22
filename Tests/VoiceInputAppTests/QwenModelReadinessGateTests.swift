import XCTest
@testable import VoiceInputApp

final class QwenModelReadinessGateTests: XCTestCase {
    func testReadyModelReturnsImmediately() async throws {
        let provider = FakeQwenModelStatusProvider(statuses: [
            QwenModelStatus(
                installed: true,
                loaded: true,
                loading: false,
                downloading: false,
                progress: nil,
                modelId: VoiceInputModel.qwen3ASR06B.modelID,
                modelPath: nil
            )
        ])
        let gate = QwenModelReadinessGate(statusProvider: provider, sleep: { _ in })

        let result = try await gate.waitForReady(model: .qwen3ASR06B, budget: 1)

        XCTAssertEqual(result.state, .ready)
        XCTAssertNil(result.failureKind)
        XCTAssertEqual(provider.requestedModelIDs, [VoiceInputModel.qwen3ASR06B.modelID])
    }

    func testLoadingModelPollsUntilReadyWithoutFallbackFailure() async throws {
        let provider = FakeQwenModelStatusProvider(statuses: [
            QwenModelStatus(
                installed: true,
                loaded: false,
                loading: true,
                downloading: false,
                progress: nil,
                modelId: VoiceInputModel.qwen3ASR06B.modelID,
                modelPath: nil
            ),
            QwenModelStatus(
                installed: true,
                loaded: true,
                loading: false,
                downloading: false,
                progress: nil,
                modelId: VoiceInputModel.qwen3ASR06B.modelID,
                modelPath: nil
            )
        ])
        let gate = QwenModelReadinessGate(statusProvider: provider, sleep: { _ in })

        let result = try await gate.waitForReady(model: .qwen3ASR06B, budget: 1)

        XCTAssertEqual(result.state, .ready)
        XCTAssertNil(result.failureKind)
        XCTAssertEqual(provider.requestedModelIDs.count, 2)
    }

    func testNotInstalledReturnsNonFallbackFailure() async throws {
        let provider = FakeQwenModelStatusProvider(statuses: [
            QwenModelStatus(
                installed: false,
                loaded: false,
                loading: false,
                downloading: false,
                progress: nil,
                modelId: VoiceInputModel.qwen3ASR06B.modelID,
                modelPath: nil
            )
        ])
        let gate = QwenModelReadinessGate(statusProvider: provider, sleep: { _ in })

        let result = try await gate.waitForReady(model: .qwen3ASR06B, budget: 1)

        XCTAssertEqual(result.state, .notInstalled)
        XCTAssertEqual(result.failureKind, .modelNotInstalled)
        XCTAssertFalse(QwenFallbackPolicy().shouldFallback(for: result.failureKind!))
    }
}

private final class FakeQwenModelStatusProvider: QwenModelStatusProviding {
    private var statuses: [QwenModelStatus]
    private(set) var requestedModelIDs: [String] = []

    init(statuses: [QwenModelStatus]) {
        self.statuses = statuses
    }

    func modelStatus(modelID: String) async throws -> QwenModelStatus {
        requestedModelIDs.append(modelID)
        if statuses.isEmpty {
            return QwenModelStatus(
                installed: true,
                loaded: false,
                loading: true,
                downloading: false,
                progress: nil,
                modelId: modelID,
                modelPath: nil
            )
        }
        return statuses.removeFirst()
    }
}
