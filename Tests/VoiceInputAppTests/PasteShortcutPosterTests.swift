import CoreGraphics
import XCTest
@testable import VoiceInputApp

final class PasteShortcutPosterTests: XCTestCase {
    func testPostsPhysicalCommandVSequenceToRequestedProcess() {
        var captured: [(pid_t, CGEvent)] = []
        let poster = PasteShortcutPoster { processIdentifier, event in
            captured.append((processIdentifier, event))
        }

        XCTAssertTrue(poster.postCommandV(to: 314))
        XCTAssertEqual(captured.map(\.0), [314, 314, 314, 314])
        XCTAssertEqual(
            captured.map { $0.1.type },
            [.flagsChanged, .keyDown, .keyUp, .flagsChanged]
        )
        XCTAssertEqual(
            captured.map { $0.1.getIntegerValueField(.keyboardEventKeycode) },
            [55, 9, 9, 55]
        )
        XCTAssertEqual(
            captured.map { $0.1.flags.contains(.maskCommand) },
            [true, true, true, false]
        )
        let leftCommandDevice = CGEventFlags(rawValue: 0x0000_0008)
        XCTAssertEqual(
            captured.map { $0.1.flags.contains(leftCommandDevice) },
            [true, true, true, false]
        )
    }

    func testFinalEventLeavesCommandReleased() {
        var lastEvent: CGEvent?
        let poster = PasteShortcutPoster { _, event in lastEvent = event }

        XCTAssertTrue(poster.postCommandV(to: 314))
        XCTAssertEqual(lastEvent?.type, .flagsChanged)
        XCTAssertEqual(lastEvent?.getIntegerValueField(.keyboardEventKeycode), 55)
        XCTAssertEqual(lastEvent?.flags.contains(.maskCommand), false)
    }

    func testEventConstructionFailureRoutesNoPartialEvent() {
        var sinkCallCount = 0
        let poster = PasteShortcutPoster(
            eventSink: { _, _ in sinkCallCount += 1 },
            shortcutEventFactory: { nil }
        )

        XCTAssertFalse(poster.postCommandV(to: 314))
        XCTAssertEqual(sinkCallCount, 0)
    }
}
