import XCTest
@testable import VoiceInputApp

final class InlineFeedbackMotionTests: XCTestCase {
    func testFeedbackMotionIsShortAndOpacityOnly() {
        XCTAssertEqual(InlineFeedbackMotion.duration(reduceMotion: false), 0.12)
        XCTAssertEqual(InlineFeedbackMotion.duration(reduceMotion: true), 0.08)
        XCTAssertTrue(InlineFeedbackMotion.usesOpacityOnly)
        XCTAssertFalse(InlineFeedbackMotion.animatesLayout)
    }

    func testStatusFeedbackUsesAQuieterReducedMotionAcknowledgement() {
        XCTAssertLessThan(
            InlineFeedbackMotion.duration(reduceMotion: true),
            InlineFeedbackMotion.duration(reduceMotion: false)
        )
        XCTAssertTrue(InlineFeedbackMotion.usesOpacityOnly)
        XCTAssertFalse(InlineFeedbackMotion.animatesLayout)
    }
}
