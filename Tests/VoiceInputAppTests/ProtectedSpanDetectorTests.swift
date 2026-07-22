import XCTest
@testable import VoiceInputApp

final class ProtectedSpanDetectorTests: XCTestCase {
    func testDetectsURLsEmailsAndFilePaths() {
        let text = "Open /usr/local/bin, email support@example.com, then visit https://example.com/docs."

        let spans = ProtectedSpanDetector.detect(in: text)

        XCTAssertEqual(
            spans.map(\.kind),
            [.filePath, .email, .url]
        )
        XCTAssertEqual(
            spans.map(\.text),
            ["/usr/local/bin", "support@example.com", "https://example.com/docs"]
        )
    }

    func testDetectsModelVersionsCourseCodesAndAcademicReferences() {
        let text = "Use Qwen/Qwen3-ASR-0.6B with v1.2.3 for MATH2045 and Exercise 4(b)."

        let spans = ProtectedSpanDetector.detect(in: text)

        XCTAssertEqual(
            spans.map(\.kind),
            [.modelID, .version, .courseCode, .academicReference]
        )
        XCTAssertEqual(
            spans.map(\.text),
            ["Qwen/Qwen3-ASR-0.6B", "v1.2.3", "MATH2045", "Exercise 4(b)"]
        )
    }

    func testDetectsLowercaseHyphenatedModelIDs() {
        let spans = ProtectedSpanDetector.detect(in: "Open qwen/theta-alpha today.")

        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(spans.first?.kind, .modelID)
        XCTAssertEqual(spans.first?.text, "qwen/theta-alpha")
    }

    func testDoesNotTreatOrdinaryRelativePathsAsModelIDs() {
        let spans = ProtectedSpanDetector.detect(in: "Review docs/theta-alpha and src/beta-gamma.")

        XCTAssertTrue(spans.isEmpty)
    }

    func testDoesNotReturnNestedVersionInsideURL() {
        let spans = ProtectedSpanDetector.detect(in: "Release notes: https://example.com/v1.2.3")

        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(spans.first?.kind, .url)
        XCTAssertEqual(spans.first?.text, "https://example.com/v1.2.3")
    }

    func testTrimsClosingParenthesisFromURL() {
        let spans = ProtectedSpanDetector.detect(in: "(https://example.com)")

        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(spans.first?.kind, .url)
        XCTAssertEqual(spans.first?.text, "https://example.com")
    }

    func testTrimsClosingQuoteFromFilePath() {
        let spans = ProtectedSpanDetector.detect(in: #"Path: "/usr/local/bin""#)

        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(spans.first?.kind, .filePath)
        XCTAssertEqual(spans.first?.text, "/usr/local/bin")
    }
}
