import XCTest
@testable import VoiceInputApp

final class DictationSessionControllerTests: XCTestCase {
    func testStartRequestStartsOnlyFromIdle() {
        var controller = DictationSessionController()

        let result = controller.handleStartRequest()

        guard case let .started(session) = result else {
            return XCTFail("Expected start request from idle to start a session.")
        }
        XCTAssertEqual(controller.state, .recording(session))
    }

    func testStartRequestWhileRecordingKeepsCurrentSession() {
        var controller = DictationSessionController()
        let session = startedSession(from: &controller)

        let result = controller.handleStartRequest()

        XCTAssertEqual(result, .ignored(reason: .alreadyRecording, session: session))
        XCTAssertEqual(controller.state, .recording(session))
    }

    func testStartRequestWhileTranscribingIsIgnoredAndKeepsActiveSession() {
        var controller = DictationSessionController()
        let session = startedSession(from: &controller)
        XCTAssertEqual(controller.handleStopRequest(), .startedTranscribing(session: session))

        let result = controller.handleStartRequest()

        XCTAssertEqual(result, .ignored(reason: .transcriptionInFlight, session: session))
        XCTAssertEqual(controller.state, .transcribing(session))
    }

    func testStartRequestDuringResultPresentationIsIgnored() {
        var controller = DictationSessionController()
        let session = transcribingSession(from: &controller)
        XCTAssertEqual(controller.handleSuccess(session: session), .presentResult(session: session, shouldCommit: true))

        let result = controller.handleStartRequest()

        XCTAssertEqual(result, .ignored(reason: .presentationInFlight, session: session))
        XCTAssertEqual(controller.state, .presentingResult(session))
    }

    func testStartRequestDuringFailurePresentationIsIgnored() {
        var controller = DictationSessionController()
        let session = transcribingSession(from: &controller)
        XCTAssertEqual(controller.handleFailure(session: session), .presentFailure(session: session))

        let result = controller.handleStartRequest()

        XCTAssertEqual(result, .ignored(reason: .presentationInFlight, session: session))
        XCTAssertEqual(controller.state, .presentingFailure(session))
    }

    func testStopRequestMovesRecordingToTranscribing() {
        var controller = DictationSessionController()
        let session = startedSession(from: &controller)

        let result = controller.handleStopRequest()

        XCTAssertEqual(result, .startedTranscribing(session: session))
        XCTAssertEqual(controller.state, .transcribing(session))
    }

    func testAbortRecordingStartReturnsMatchingRecordingSessionToIdle() {
        var controller = DictationSessionController()
        let session = startedSession(from: &controller)

        XCTAssertTrue(controller.abortRecordingStart(session: session))
        XCTAssertEqual(controller.state, .idle)
    }

    func testAbortRecordingStartIgnoresNonMatchingSession() {
        var controller = DictationSessionController()
        let session = startedSession(from: &controller)

        XCTAssertFalse(controller.abortRecordingStart(session: UUID()))
        XCTAssertEqual(controller.state, .recording(session))
    }

    func testStopRequestOutsideRecordingIsIgnored() {
        var controller = DictationSessionController()

        XCTAssertEqual(controller.handleStopRequest(), .ignored(reason: .notRecording, session: nil))
        XCTAssertEqual(controller.state, .idle)

        let session = transcribingSession(from: &controller)
        XCTAssertEqual(controller.handleStopRequest(), .ignored(reason: .notRecording, session: session))
        XCTAssertEqual(controller.state, .transcribing(session))
    }

    func testStopRequestDuringPresentationIsIgnoredAsPresentationInFlight() {
        var controller = DictationSessionController()
        let session = transcribingSession(from: &controller)
        XCTAssertEqual(controller.handleSuccess(session: session), .presentResult(session: session, shouldCommit: true))

        let result = controller.handleStopRequest()

        XCTAssertEqual(result, .ignored(reason: .presentationInFlight, session: session))
        XCTAssertEqual(controller.state, .presentingResult(session))
    }

    func testCurrentSuccessMovesTranscribingToPresentingResultAndAllowsCommit() {
        var controller = DictationSessionController()
        let session = transcribingSession(from: &controller)

        let result = controller.handleSuccess(session: session)

        XCTAssertEqual(result, .presentResult(session: session, shouldCommit: true))
        XCTAssertEqual(controller.state, .presentingResult(session))
    }

    func testStaleSuccessDoesNotMutateActiveStateOrAllowCommit() {
        var controller = DictationSessionController()
        let activeSession = transcribingSession(from: &controller)
        let staleSession = UUID()

        let result = controller.handleSuccess(session: staleSession)

        XCTAssertEqual(result, .ignored(reason: .staleSession, session: staleSession))
        XCTAssertEqual(controller.state, .transcribing(activeSession))
    }

    func testCurrentFailureMovesTranscribingToPresentingFailure() {
        var controller = DictationSessionController()
        let session = transcribingSession(from: &controller)

        let result = controller.handleFailure(session: session)

        XCTAssertEqual(result, .presentFailure(session: session))
        XCTAssertEqual(controller.state, .presentingFailure(session))
    }

    func testStaleFailureDoesNotMutateActiveState() {
        var controller = DictationSessionController()
        let activeSession = transcribingSession(from: &controller)
        let staleSession = UUID()

        let result = controller.handleFailure(session: staleSession)

        XCTAssertEqual(result, .ignored(reason: .staleSession, session: staleSession))
        XCTAssertEqual(controller.state, .transcribing(activeSession))
    }

    func testFinishPresentationReturnsMatchingResultSessionToIdle() {
        var controller = DictationSessionController()
        let session = transcribingSession(from: &controller)
        XCTAssertEqual(controller.handleSuccess(session: session), .presentResult(session: session, shouldCommit: true))

        let result = controller.finishPresentation(session: session)

        XCTAssertEqual(result, .finished(session: session))
        XCTAssertEqual(controller.state, .idle)
    }

    func testFinishPresentationReturnsMatchingFailureSessionToIdle() {
        var controller = DictationSessionController()
        let session = transcribingSession(from: &controller)
        XCTAssertEqual(controller.handleFailure(session: session), .presentFailure(session: session))

        let result = controller.finishPresentation(session: session)

        XCTAssertEqual(result, .finished(session: session))
        XCTAssertEqual(controller.state, .idle)
    }

    func testFinishPresentationIgnoresNonMatchingOrNonPresentationSession() {
        var controller = DictationSessionController()
        let activeSession = transcribingSession(from: &controller)

        XCTAssertEqual(controller.finishPresentation(session: activeSession), .ignored(reason: .notPresenting, session: activeSession))
        XCTAssertEqual(controller.state, .transcribing(activeSession))

        XCTAssertEqual(controller.handleFailure(session: activeSession), .presentFailure(session: activeSession))
        let staleSession = UUID()
        XCTAssertEqual(controller.finishPresentation(session: staleSession), .ignored(reason: .staleSession, session: staleSession))
        XCTAssertEqual(controller.state, .presentingFailure(activeSession))
    }

    func testCanCommitOnlyWhileTranscribingThatSession() {
        var controller = DictationSessionController()
        let session = startedSession(from: &controller)

        XCTAssertFalse(controller.canCommit(session: session))
        XCTAssertEqual(controller.handleStopRequest(), .startedTranscribing(session: session))
        XCTAssertTrue(controller.canCommit(session: session))
        XCTAssertFalse(controller.canCommit(session: UUID()))
        XCTAssertEqual(controller.handleSuccess(session: session), .presentResult(session: session, shouldCommit: true))
        XCTAssertFalse(controller.canCommit(session: session))
    }

    func testIsPresentingResultOnlyForMatchingResultSession() {
        var controller = DictationSessionController()
        let session = transcribingSession(from: &controller)

        XCTAssertFalse(controller.isPresentingResult(session: session))
        XCTAssertEqual(controller.handleSuccess(session: session), .presentResult(session: session, shouldCommit: true))
        XCTAssertTrue(controller.isPresentingResult(session: session))
        XCTAssertFalse(controller.isPresentingResult(session: UUID()))
    }

    private func startedSession(from controller: inout DictationSessionController) -> UUID {
        guard case let .started(session) = controller.handleStartRequest() else {
            XCTFail("Expected a new recording session.")
            return UUID()
        }
        return session
    }

    private func transcribingSession(from controller: inout DictationSessionController) -> UUID {
        let session = startedSession(from: &controller)
        XCTAssertEqual(controller.handleStopRequest(), .startedTranscribing(session: session))
        return session
    }
}
