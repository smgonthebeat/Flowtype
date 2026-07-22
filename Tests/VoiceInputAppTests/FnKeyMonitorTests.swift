import XCTest
@testable import VoiceInputApp

final class FnKeyMonitorTests: XCTestCase {
    func testStartRetriesEventTapCreationAfterPreviousFailure() {
        var creationAttempts = 0
        let monitor = FnKeyMonitor(eventTapFactory: { _ in
            creationAttempts += 1
            return nil
        })

        monitor.start()
        monitor.start()

        XCTAssertEqual(creationAttempts, 2)
    }
}
