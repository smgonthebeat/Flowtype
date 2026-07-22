import Foundation
import Speech

final class AppleSpeechEngine: TranscriptionEngine {
    private let localeIdentifier: String
    private let timeout: TimeInterval

    init(localeIdentifier: String = "zh-CN", timeout: TimeInterval = 30) {
        self.localeIdentifier = localeIdentifier
        self.timeout = timeout
    }

    func transcribe(fileURL: URL, languageMode: LanguageMode) async throws -> TranscriptionResult {
        let selectedLocaleIdentifier = Self.localeIdentifier(
            for: languageMode,
            configuredLocaleIdentifier: localeIdentifier
        )
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: selectedLocaleIdentifier))
        guard let recognizer, recognizer.isAvailable else {
            throw TranscriptionError.unavailable
        }
        guard recognizer.supportsOnDeviceRecognition else {
            throw TranscriptionError.unavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: fileURL)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false

        let sessionBox = SpeechRecognitionSessionBox()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let resume = SingleResumeContinuation(continuation)
                let session = SpeechRecognitionSession(resume: resume)
                sessionBox.set(session)

                let task = recognizer.recognitionTask(with: request) { result, error in
                    if let error {
                        session.fail(error)
                        return
                    }

                    guard let result, result.isFinal else { return }
                    let text = result.bestTranscription.formattedString
                    guard PasteInjector.isPasteable(text) else {
                        session.fail(TranscriptionError.emptyResult)
                        return
                    }
                    session.succeed(TranscriptionResult(text: text, engine: .appleSpeech))
                }
                session.setTask(task)

                DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                    session.cancel(with: TranscriptionError.timedOut)
                }
            }
        } onCancel: {
            sessionBox.cancel(with: CancellationError())
        }
    }

    static func localeIdentifier(
        for languageMode: LanguageMode,
        configuredLocaleIdentifier: String
    ) -> String {
        switch languageMode {
        case .english:
            return "en-US"
        case .chinese, .mixedChineseEnglish:
            return configuredLocaleIdentifier
        }
    }
}

private final class SpeechRecognitionSessionBox: @unchecked Sendable {
    private let lock = NSLock()
    private var session: SpeechRecognitionSession?

    func set(_ session: SpeechRecognitionSession) {
        lock.lock()
        self.session = session
        lock.unlock()
    }

    func cancel(with error: any Error) {
        lock.lock()
        let session = session
        lock.unlock()
        session?.cancel(with: error)
    }
}

private final class SpeechRecognitionSession: @unchecked Sendable {
    private let lock = NSLock()
    private var task: SFSpeechRecognitionTask?
    private let resume: SingleResumeContinuation<TranscriptionResult>

    init(resume: SingleResumeContinuation<TranscriptionResult>) {
        self.resume = resume
    }

    func setTask(_ task: SFSpeechRecognitionTask) {
        lock.lock()
        self.task = task
        lock.unlock()
    }

    func succeed(_ result: TranscriptionResult) {
        _ = resume.return(result)
    }

    func fail(_ error: any Error) {
        _ = resume.throw(error)
    }

    func cancel(with error: any Error) {
        lock.lock()
        let task = task
        lock.unlock()

        if resume.throw(error) {
            task?.cancel()
        }
    }
}

private final class SingleResumeContinuation<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var didResume = false
    private let continuation: CheckedContinuation<T, any Error>

    init(_ continuation: CheckedContinuation<T, any Error>) {
        self.continuation = continuation
    }

    @discardableResult
    func `return`(_ value: T) -> Bool {
        guard markResumed() else { return false }
        continuation.resume(returning: value)
        return true
    }

    @discardableResult
    func `throw`(_ error: any Error) -> Bool {
        guard markResumed() else { return false }
        continuation.resume(throwing: error)
        return true
    }

    private func markResumed() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !didResume else { return false }
        didResume = true
        return true
    }
}
