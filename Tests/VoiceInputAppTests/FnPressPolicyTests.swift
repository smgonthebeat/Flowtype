import XCTest
@testable import VoiceInputApp

final class FnPressPolicyTests: XCTestCase {
    func testQuickTapIsTreatedAsAccidental() {
        XCTAssertTrue(FnPressPolicy.isAccidentalTap(recordingDuration: 0))
        XCTAssertTrue(FnPressPolicy.isAccidentalTap(recordingDuration: 0.12))
        XCTAssertTrue(FnPressPolicy.isAccidentalTap(recordingDuration: 0.29))
    }

    func testDeliberateShortHoldStillTranscribes() {
        // A one-word answer such as "好" or "yes" takes roughly 0.4 s including the press.
        XCTAssertFalse(FnPressPolicy.isAccidentalTap(recordingDuration: 0.3))
        XCTAssertFalse(FnPressPolicy.isAccidentalTap(recordingDuration: 0.4))
        XCTAssertFalse(FnPressPolicy.isAccidentalTap(recordingDuration: 5))
    }

    func testHintTellsTheUserToHoldFn() {
        XCTAssertEqual(AppCopy.texts(for: .chinese).capsuleHoldFnHint, "按住 Fn 说话，说完再松开")
        XCTAssertTrue(AppCopy.texts(for: .english).capsuleHoldFnHint.contains("Hold Fn"))
    }
}
