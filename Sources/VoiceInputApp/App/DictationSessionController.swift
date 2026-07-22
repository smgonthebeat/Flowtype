import Foundation

struct DictationSessionController {
    enum State: Equatable {
        case idle
        case recording(UUID)
        case transcribing(UUID)
        case presentingResult(UUID)
        case presentingFailure(UUID)

        var diagnosticName: String {
            switch self {
            case .idle:
                return "idle"
            case .recording:
                return "recording"
            case .transcribing:
                return "transcribing"
            case .presentingResult:
                return "presentingResult"
            case .presentingFailure:
                return "presentingFailure"
            }
        }
    }

    enum IgnoreReason: Equatable {
        case alreadyRecording
        case transcriptionInFlight
        case presentationInFlight
        case notRecording
        case staleSession
        case notPresenting

        var diagnosticName: String {
            switch self {
            case .alreadyRecording:
                return "alreadyRecording"
            case .transcriptionInFlight:
                return "transcriptionInFlight"
            case .presentationInFlight:
                return "presentationInFlight"
            case .notRecording:
                return "notRecording"
            case .staleSession:
                return "staleSession"
            case .notPresenting:
                return "notPresenting"
            }
        }
    }

    enum StartResult: Equatable {
        case started(UUID)
        case ignored(reason: IgnoreReason, session: UUID?)
    }

    enum StopResult: Equatable {
        case startedTranscribing(session: UUID)
        case ignored(reason: IgnoreReason, session: UUID?)
    }

    enum CompletionResult: Equatable {
        case presentResult(session: UUID, shouldCommit: Bool)
        case presentFailure(session: UUID)
        case ignored(reason: IgnoreReason, session: UUID)
    }

    enum PresentationResult: Equatable {
        case finished(session: UUID)
        case ignored(reason: IgnoreReason, session: UUID)
    }

    private(set) var state: State

    init(state: State = .idle) {
        self.state = state
    }

    mutating func handleStartRequest() -> StartResult {
        switch state {
        case .idle:
            let session = UUID()
            state = .recording(session)
            return .started(session)
        case .recording(let session):
            return .ignored(reason: .alreadyRecording, session: session)
        case .transcribing(let session):
            return .ignored(reason: .transcriptionInFlight, session: session)
        case .presentingResult(let session), .presentingFailure(let session):
            return .ignored(reason: .presentationInFlight, session: session)
        }
    }

    mutating func handleStopRequest() -> StopResult {
        switch state {
        case .recording(let session):
            state = .transcribing(session)
            return .startedTranscribing(session: session)
        case .presentingResult(let session), .presentingFailure(let session):
            return .ignored(reason: .presentationInFlight, session: session)
        case .idle:
            return .ignored(reason: .notRecording, session: nil)
        case .transcribing(let session):
            return .ignored(reason: .notRecording, session: session)
        }
    }

    mutating func abortRecordingStart(session: UUID) -> Bool {
        guard case let .recording(activeSession) = state, activeSession == session else {
            return false
        }
        state = .idle
        return true
    }

    mutating func handleSuccess(session: UUID) -> CompletionResult {
        guard case let .transcribing(activeSession) = state, activeSession == session else {
            return .ignored(reason: activeSessionMatches(session) ? .notRecording : .staleSession, session: session)
        }

        state = .presentingResult(session)
        return .presentResult(session: session, shouldCommit: true)
    }

    mutating func handleFailure(session: UUID) -> CompletionResult {
        guard case let .transcribing(activeSession) = state, activeSession == session else {
            return .ignored(reason: activeSessionMatches(session) ? .notRecording : .staleSession, session: session)
        }

        state = .presentingFailure(session)
        return .presentFailure(session: session)
    }

    mutating func finishPresentation(session: UUID) -> PresentationResult {
        switch state {
        case let .presentingResult(activeSession) where activeSession == session,
             let .presentingFailure(activeSession) where activeSession == session:
            state = .idle
            return .finished(session: session)
        case .presentingResult, .presentingFailure:
            return .ignored(reason: .staleSession, session: session)
        case .idle, .recording, .transcribing:
            return .ignored(reason: .notPresenting, session: session)
        }
    }

    func canCommit(session: UUID) -> Bool {
        state == .transcribing(session)
    }

    func isPresentingResult(session: UUID) -> Bool {
        guard case let .presentingResult(activeSession) = state else {
            return false
        }
        return activeSession == session
    }

    private func activeSessionMatches(_ session: UUID) -> Bool {
        switch state {
        case .idle:
            return false
        case .recording(let activeSession),
             .transcribing(let activeSession),
             .presentingResult(let activeSession),
             .presentingFailure(let activeSession):
            return activeSession == session
        }
    }
}
