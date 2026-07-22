import XCTest
@testable import VoiceInputApp

final class NormalizationTypesTests: XCTestCase {
    func testNormalizationContextDefaultsToEmptyCollections() {
        let context = NormalizationContext()

        XCTAssertTrue(context.knownTerms.isEmpty)
        XCTAssertTrue(context.protectedSpans.isEmpty)
    }
}
