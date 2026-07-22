import CoreGraphics
import XCTest
@testable import VoiceInputApp

final class PasteShortcutPosterTests: XCTestCase {
    func testBuildsCompleteCommandVPairBeforeRoutingToRequestedProcess() {
        var captured: [(pid_t, CGEvent)] = []
        let poster = PasteShortcutPoster { processIdentifier, event in
            captured.append((processIdentifier, event))
        }

        XCTAssertTrue(poster.postCommandV(to: 314))
        XCTAssertEqual(captured.map(\.0), [314, 314])
        XCTAssertEqual(captured.map { $0.1.type }, [.keyDown, .keyUp])
        XCTAssertEqual(
            captured.map { $0.1.getIntegerValueField(.keyboardEventKeycode) },
            [9, 9]
        )
        XCTAssertTrue(captured.allSatisfy { $0.1.flags.contains(.maskCommand) })
    }

    func testEventPairConstructionFailureRoutesNoPartialEvent() {
        var sinkCallCount = 0
        let poster = PasteShortcutPoster(
            eventSink: { _, _ in sinkCallCount += 1 },
            eventPairFactory: { nil }
        )

        XCTAssertFalse(poster.postCommandV(to: 314))
        XCTAssertEqual(sinkCallCount, 0)
    }
}
