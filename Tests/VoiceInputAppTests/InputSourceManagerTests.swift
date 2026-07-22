import XCTest
@testable import VoiceInputApp

final class InputSourceManagerTests: XCTestCase {
    func testPrefersABCThenUSBeforeOtherASCIIInputSources() {
        XCTAssertEqual(
            InputSourceManager.preferredASCIIInputSourceIndex(
                identifiers: ["com.example.CustomASCII", "com.apple.keylayout.US", "com.apple.keylayout.ABC"]
            ),
            2
        )
        XCTAssertEqual(
            InputSourceManager.preferredASCIIInputSourceIndex(
                identifiers: ["com.example.CustomASCII", "com.apple.keylayout.US"]
            ),
            1
        )
    }

    func testFallsBackToFirstAvailableASCIIInputSource() {
        XCTAssertEqual(
            InputSourceManager.preferredASCIIInputSourceIndex(
                identifiers: ["com.example.CustomASCII", "com.example.SecondASCII"]
            ),
            0
        )
        XCTAssertNil(InputSourceManager.preferredASCIIInputSourceIndex(identifiers: []))
    }
}
