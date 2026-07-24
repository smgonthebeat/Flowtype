import XCTest
@testable import VoiceInputApp

final class ModelsViewTests: XCTestCase {
    func testModelStatusPollingIsFastWhilePreparationIsActive() {
        XCTAssertEqual(
            ModelStatusRefreshPolicy.intervalNanoseconds(hasActivePreparation: true),
            500_000_000
        )
    }

    func testModelStatusPollingRemainsBoundedWhileIdle() {
        XCTAssertEqual(
            ModelStatusRefreshPolicy.intervalNanoseconds(hasActivePreparation: false),
            2_000_000_000
        )
    }

    func testRefreshFailurePreservesActiveDownloadProgress() {
        let result = ModelStatusRefreshPolicy.stateAfterRefreshFailure(
            current: .downloading(0.43),
            fallback: .repairNeeded
        )

        guard case let .downloading(progress) = result else {
            return XCTFail("Expected active download state to be preserved")
        }
        XCTAssertEqual(progress, 0.43)
    }

    func testRefreshFailureUsesLocalFallbackWhenNoDownloadIsActive() {
        let result = ModelStatusRefreshPolicy.stateAfterRefreshFailure(
            current: .notInstalled,
            fallback: .repairNeeded
        )

        guard case .repairNeeded = result else {
            return XCTFail("Expected local fallback state")
        }
    }
}
