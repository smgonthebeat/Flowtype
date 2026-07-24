import XCTest
@testable import VoiceInputApp

final class QwenFallbackPolicyTests: XCTestCase {
    func testLoadingBusyMissingModelAndCancellationDoNotFallback() {
        let policy = QwenFallbackPolicy()

        XCTAssertFalse(policy.shouldFallback(for: .modelNotInstalled))
        XCTAssertFalse(policy.shouldFallback(for: .modelLoading))
        XCTAssertFalse(policy.shouldFallback(for: .helperBusy))
        XCTAssertFalse(policy.shouldFallback(for: .emptyAudio))
        XCTAssertFalse(policy.shouldFallback(for: .cancelled))
    }

    func testTypedTimeoutsAndFatalRuntimeCanFallback() {
        let policy = QwenFallbackPolicy()

        XCTAssertTrue(policy.shouldFallback(for: .modelLoadTimedOut))
        XCTAssertTrue(policy.shouldFallback(for: .helperBusyTimedOut))
        XCTAssertTrue(policy.shouldFallback(for: .transcriptionTimedOut))
        XCTAssertTrue(policy.shouldFallback(for: .helperStartFailed))
        XCTAssertTrue(policy.shouldFallback(for: .transcriptionFailed))
        XCTAssertTrue(policy.shouldFallback(for: .contextLeakDetected))
    }

    func testClassifiesKnownErrors() {
        let policy = QwenFallbackPolicy()

        XCTAssertEqual(policy.classify(TranscriptionError.emptyResult), .emptyAudio)
        XCTAssertEqual(policy.classify(TranscriptionError.timedOut), .transcriptionTimedOut)
        XCTAssertEqual(policy.classify(TranscriptionError.contextLeakDetected), .contextLeakDetected)
        XCTAssertEqual(policy.classify(CancellationError()), .cancelled)
        XCTAssertEqual(policy.classify(URLError(.cancelled)), .cancelled)
        XCTAssertEqual(policy.classify(URLError(.timedOut)), .transcriptionTimedOut)
        XCTAssertEqual(policy.classify(QwenReadinessError(kind: .modelLoadTimedOut)), .modelLoadTimedOut)
        XCTAssertEqual(policy.classify(QwenHelperClientError.httpStatus(404, "Model is not installed")), .modelNotInstalled)
        XCTAssertEqual(policy.classify(QwenHelperClientError.httpStatus(404, "Not Found")), .transcriptionFailed)
    }

    func testClassifiesHelperProcessErrorsByRuntimeOrStartFailure() {
        let policy = QwenFallbackPolicy()

        XCTAssertEqual(policy.classify(HelperProcessError.helperDirectoryNotFound), .helperRuntimeMissing)
        XCTAssertEqual(policy.classify(HelperProcessError.bundledUVUnavailable), .helperRuntimeMissing)
        XCTAssertEqual(policy.classify(HelperProcessError.helperManifestInvalid), .helperRuntimeDamaged)
        XCTAssertEqual(policy.classify(HelperProcessError.portUnavailable), .helperStartFailed)
        XCTAssertEqual(policy.classify(HelperProcessError.processExited), .helperStartFailed)
        XCTAssertEqual(policy.classify(HelperProcessError.timedOutWaitingForHealth), .helperStartFailed)
    }

    func testClassifiesBusyHelperBeforeGenericConflictStatus() {
        let policy = QwenFallbackPolicy()

        XCTAssertEqual(policy.classify(QwenHelperClientError.httpStatus(409, "Helper is busy")), .helperBusy)
    }
}
