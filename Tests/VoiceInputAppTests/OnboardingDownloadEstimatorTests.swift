import XCTest
@testable import VoiceInputApp

final class OnboardingDownloadEstimatorTests: XCTestCase {
    func testProducesSmoothedSpeedAndETAAfterEnoughProgressSamples() {
        var estimator = DownloadTransferEstimator(
            smoothingFactor: 0.5,
            samplesRequiredForEstimate: 2,
            stallInterval: 8
        )

        XCTAssertEqual(
            estimator.update(sample(bytes: 0, timestamp: 0), receivedAt: 0).activity,
            .estimating
        )
        XCTAssertEqual(
            estimator.update(sample(bytes: 100, timestamp: 1), receivedAt: 1).activity,
            .estimating
        )

        let feedback = estimator.update(sample(bytes: 300, timestamp: 2), receivedAt: 2)
        guard case let .transferring(bytesPerSecond, remainingSeconds) = feedback.activity else {
            return XCTFail("Expected an active transfer estimate")
        }

        XCTAssertEqual(bytesPerSecond, 150, accuracy: 0.001)
        XCTAssertEqual(remainingSeconds, 5)
        XCTAssertEqual(feedback.downloadedBytes, 300)
        XCTAssertEqual(feedback.totalBytes, 1_000)
    }

    func testReportsWaitingWhenBytesStopAdvancing() {
        var estimator = DownloadTransferEstimator(
            samplesRequiredForEstimate: 1,
            stallInterval: 8
        )

        _ = estimator.update(sample(bytes: 100, timestamp: 0), receivedAt: 0)
        _ = estimator.update(sample(bytes: 200, timestamp: 1), receivedAt: 1)
        let feedback = estimator.update(sample(bytes: 200, timestamp: 1), receivedAt: 9)

        XCTAssertEqual(feedback.activity, .waitingForNetwork)
    }

    func testReportsFinishingWhenAllBytesArriveBeforeHelperLeavesDownloadPhase() {
        var estimator = DownloadTransferEstimator(samplesRequiredForEstimate: 1)

        _ = estimator.update(sample(bytes: 100, timestamp: 0), receivedAt: 0)
        _ = estimator.update(sample(bytes: 500, timestamp: 1), receivedAt: 1)
        let feedback = estimator.update(sample(bytes: 1_000, timestamp: 2), receivedAt: 2)

        XCTAssertEqual(feedback.activity, .finishing)
        XCTAssertEqual(feedback.downloadedBytes, feedback.totalBytes)
    }

    func testNewOperationResetsAnExistingEstimate() {
        var estimator = DownloadTransferEstimator(samplesRequiredForEstimate: 1)

        _ = estimator.update(sample(bytes: 100, timestamp: 0), receivedAt: 0)
        let active = estimator.update(sample(bytes: 200, timestamp: 1), receivedAt: 1)
        guard case .transferring = active.activity else {
            return XCTFail("Expected the first operation to have an estimate")
        }

        let restarted = estimator.update(
            sample(bytes: 20, timestamp: 2, operationID: "operation-2"),
            receivedAt: 2
        )
        XCTAssertEqual(restarted.activity, .estimating)
    }

    private func sample(
        bytes: Int64,
        timestamp: TimeInterval,
        operationID: String = "operation-1"
    ) -> DownloadTransferSnapshot {
        DownloadTransferSnapshot(
            operationID: operationID,
            downloadedBytes: bytes,
            totalBytes: 1_000,
            updatedAt: timestamp,
            source: "modelscope"
        )
    }
}
