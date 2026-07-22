import Foundation
import XCTest
@testable import VoiceInputApp

private struct TestFailure: LocalizedError {
    let errorDescription: String?
}

final class TranscriptionFailureClassifierTests: XCTestCase {
    func testTypedEmptyResultIsNoSpeechDetected() {
        let category = TranscriptionFailureClassifier.category(for: TranscriptionError.emptyResult)

        XCTAssertEqual(category, .noSpeechDetected)
        XCTAssertFalse(TranscriptionFailureClassifier.canCreateRecoverableHomeRow(
            category: category,
            selectedEngine: .qwenLocal
        ))
    }

    func testNoSpeechIsNonRecoverable() {
        let category = TranscriptionFailureClassifier.category(
            for: TestFailure(errorDescription: "no usable speech in audio")
        )

        XCTAssertEqual(category, .noSpeechDetected)
        XCTAssertFalse(TranscriptionFailureClassifier.canCreateRecoverableHomeRow(
            category: category,
            selectedEngine: .qwenLocal
        ))
    }

    func testAudioSetupIsNonRecoverable() {
        let category = TranscriptionFailureClassifier.category(
            for: TestFailure(errorDescription: "audio resampling failed")
        )

        XCTAssertEqual(category, .audioSetupError)
        XCTAssertFalse(TranscriptionFailureClassifier.canCreateRecoverableHomeRow(
            category: category,
            selectedEngine: .qwenLocal
        ))
    }

    func testGenericQwenFailureIsRecoverable() {
        let category = TranscriptionFailureClassifier.category(
            for: TestFailure(errorDescription: "helper returned HTTP 500")
        )

        XCTAssertEqual(category, .transcriptionFailed)
        XCTAssertTrue(TranscriptionFailureClassifier.canCreateRecoverableHomeRow(
            category: category,
            selectedEngine: .qwenLocal
        ))
        XCTAssertFalse(TranscriptionFailureClassifier.canCreateRecoverableHomeRow(
            category: category,
            selectedEngine: .appleSpeech
        ))
    }

    func testFallbackFailureUsesOriginalQwenFailureForRecoverableHomeRow() {
        let error = TranscriptionFallbackFailure(
            primaryError: TestFailure(errorDescription: "helper returned HTTP 500"),
            fallbackError: TestFailure(errorDescription: "apple speech fallback failed")
        )

        XCTAssertEqual(
            TranscriptionFailureClassifier.recoverableHomeRowCategory(
                for: error,
                selectedEngine: .qwenLocal
            ),
            .transcriptionFailed
        )
    }

    func testGenericAppleSpeechFailureIsNonRecoverable() {
        let category = TranscriptionFailureClassifier.category(
            for: TestFailure(errorDescription: "recognizer returned an internal error")
        )

        XCTAssertEqual(category, .transcriptionFailed)
        XCTAssertFalse(TranscriptionFailureClassifier.canCreateRecoverableHomeRow(
            category: category,
            selectedEngine: .appleSpeech
        ))
    }

    func testCapsuleFallbackCopyMatchesCurrentMessages() {
        XCTAssertEqual(
            TranscriptionFailureClassifier.capsuleText(for: .noSpeechDetected),
            "No speech detected"
        )
        XCTAssertEqual(
            TranscriptionFailureClassifier.capsuleText(for: .audioSetupError),
            "Audio setup error"
        )
        XCTAssertEqual(
            TranscriptionFailureClassifier.capsuleText(for: .transcriptionFailed),
            "Transcription failed"
        )
    }
}
