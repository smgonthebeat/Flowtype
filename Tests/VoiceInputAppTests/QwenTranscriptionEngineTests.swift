import XCTest
@testable import VoiceInputApp

final class QwenTranscriptionEngineTests: XCTestCase {
    private let syntheticHotwordList = "DEMO1001, TEST2045, Qwen, alpha, beta, gamma, delta, epsilon, zeta, eta, theta, iota, kappa, lambda, markdown, parser, renderer, sample phrase, test fixture, workflow, Example University."
    private let syntheticHotwordContext = "Important terms to preserve exactly: DEMO1001, TEST2045, Qwen, alpha, beta, gamma, delta, epsilon, zeta, eta, theta, iota, kappa, lambda, markdown, parser, renderer, sample phrase, test fixture, workflow, Example University."

    func testRetriesWithoutContextWhenShortRecordingEchoesHotwords() async throws {
        let client = RecordingQwenClient(responses: [
            syntheticHotwordList,
            "X8."
        ])
        let context = syntheticHotwordContext
        let engine = QwenTranscriptionEngine(
            client: client,
            modelID: "Qwen/Qwen3-ASR-0.6B",
            context: context,
            recordingDuration: { _ in 1.4 }
        )

        let result = try await engine.transcribe(fileURL: URL(fileURLWithPath: "/tmp/short.wav"), languageMode: .mixedChineseEnglish)

        XCTAssertEqual(result.text, "X8.")
        XCTAssertEqual(client.contexts, [context, ""])
        XCTAssertEqual(client.strategies, [.full, .full])
    }

    func testRetriesWithoutContextWhenLongRecordingLeaksFullHotwordContext() async throws {
        let context = syntheticHotwordContext
        let client = RecordingQwenClient(responses: [
            context,
            "八点钟准时买。"
        ])
        let engine = QwenTranscriptionEngine(
            client: client,
            modelID: "Qwen/Qwen3-ASR-0.6B",
            context: context,
            recordingDuration: { _ in 30 }
        )

        let result = try await engine.transcribe(fileURL: URL(fileURLWithPath: "/tmp/long.wav"), languageMode: .mixedChineseEnglish)

        XCTAssertEqual(result.text, "八点钟准时买。")
        XCTAssertEqual(client.contexts, [context, ""])
        XCTAssertEqual(client.strategies, [.full, .full])
    }

    func testStripsAppendedHotwordContextTailFromLongRecording() async throws {
        let context = syntheticHotwordContext
        let client = RecordingQwenClient(responses: [
            "如果八点钟准时买，我用。 \(context)"
        ])
        let engine = QwenTranscriptionEngine(
            client: client,
            modelID: "Qwen/Qwen3-ASR-0.6B",
            context: context,
            recordingDuration: { _ in 30 }
        )

        let result = try await engine.transcribe(fileURL: URL(fileURLWithPath: "/tmp/long.wav"), languageMode: .mixedChineseEnglish)

        XCTAssertEqual(result.text, "如果八点钟准时买，我用。")
        XCTAssertEqual(client.contexts, [context])
        XCTAssertEqual(client.strategies, [.full])
    }

    func testUsesFullStrategyForShortRecordings() async throws {
        let client = RecordingQwenClient(responses: ["short transcript"])
        let engine = QwenTranscriptionEngine(
            client: client,
            modelID: "Qwen/Qwen3-ASR-0.6B",
            recordingDuration: { _ in 3.0 }
        )

        let result = try await engine.transcribe(fileURL: URL(fileURLWithPath: "/tmp/short.wav"), languageMode: .mixedChineseEnglish)

        XCTAssertEqual(result.text, "short transcript")
        XCTAssertEqual(client.strategies, [.full])
    }

    func testResultRecordsEffectiveFullStrategyForShortRecording() async throws {
        let client = RecordingQwenClient(responses: ["short transcript"])
        let engine = QwenTranscriptionEngine(
            client: client,
            modelID: VoiceInputModel.qwen3ASR06B.modelID,
            recordingDuration: { _ in 3.0 }
        )

        let result = try await engine.transcribe(fileURL: URL(fileURLWithPath: "/tmp/short.wav"), languageMode: .mixedChineseEnglish)

        XCTAssertEqual(result.engine, .qwenLocal)
        XCTAssertEqual(result.requestedModelID, VoiceInputModel.qwen3ASR06B.modelID)
        XCTAssertEqual(result.requestedStrategy, "full")
        XCTAssertEqual(result.effectiveStrategy, "full")
    }

    func testUsesFullStrategyForOrdinaryLongDictation() async throws {
        let client = RecordingQwenClient(responses: ["ordinary long transcript"])
        let engine = QwenTranscriptionEngine(
            client: client,
            modelID: "Qwen/Qwen3-ASR-0.6B",
            recordingDuration: { _ in 31.7 }
        )

        let result = try await engine.transcribe(fileURL: URL(fileURLWithPath: "/tmp/ordinary-long.wav"), languageMode: .mixedChineseEnglish)

        XCTAssertEqual(result.text, "ordinary long transcript")
        XCTAssertEqual(client.strategies, [.full])
        XCTAssertEqual(result.requestedStrategy, "full")
        XCTAssertEqual(result.effectiveStrategy, "full")
    }

    func testUsesFullStrategyAtLongDictationThreshold() async throws {
        let client = RecordingQwenClient(responses: ["threshold transcript"])
        let engine = QwenTranscriptionEngine(
            client: client,
            modelID: "Qwen/Qwen3-ASR-0.6B",
            recordingDuration: { _ in 60.0 }
        )

        let result = try await engine.transcribe(fileURL: URL(fileURLWithPath: "/tmp/threshold.wav"), languageMode: .mixedChineseEnglish)

        XCTAssertEqual(result.text, "threshold transcript")
        XCTAssertEqual(client.strategies, [.full])
        XCTAssertEqual(result.effectiveStrategy, "full")
    }

    func testUsesChunkedStrategyForVeryLongRecordings() async throws {
        let client = RecordingQwenClient(responses: ["very long transcript"])
        let engine = QwenTranscriptionEngine(
            client: client,
            modelID: "Qwen/Qwen3-ASR-0.6B",
            recordingDuration: { _ in 60.1 }
        )

        let result = try await engine.transcribe(fileURL: URL(fileURLWithPath: "/tmp/very-long.wav"), languageMode: .mixedChineseEnglish)

        XCTAssertEqual(result.text, "very long transcript")
        XCTAssertEqual(client.strategies, [.chunked])
        XCTAssertEqual(result.requestedStrategy, "full")
        XCTAssertEqual(result.effectiveStrategy, "chunked")
    }

    func testRequestedChunkedStrategyStillUsesChunkedForShortRecording() async throws {
        let client = RecordingQwenClient(responses: ["chunked transcript"])
        let engine = QwenTranscriptionEngine(
            client: client,
            modelID: VoiceInputModel.qwen3ASR06B.modelID,
            strategy: .chunked,
            recordingDuration: { _ in 3.0 }
        )

        let result = try await engine.transcribe(fileURL: URL(fileURLWithPath: "/tmp/chunked.wav"), languageMode: .mixedChineseEnglish)

        XCTAssertEqual(client.strategies, [.chunked])
        XCTAssertEqual(result.requestedStrategy, "chunked")
        XCTAssertEqual(result.effectiveStrategy, "chunked")
    }

    func testReportsDecodeTiming() async throws {
        let client = RecordingQwenClient(responses: ["hello"])
        var recordedDecodeMilliseconds: Int?
        let engine = QwenTranscriptionEngine(
            client: client,
            modelID: "Qwen/Qwen3-ASR-0.6B",
            recordingDuration: { _ in 1.0 },
            onDecodeTiming: { milliseconds in
                recordedDecodeMilliseconds = milliseconds
            }
        )

        _ = try await engine.transcribe(fileURL: URL(fileURLWithPath: "/tmp/short.wav"), languageMode: .mixedChineseEnglish)

        XCTAssertNotNil(recordedDecodeMilliseconds)
        XCTAssertGreaterThanOrEqual(recordedDecodeMilliseconds ?? -1, 0)
    }

    func testReportsEchoRetryDecodeTimingAfterAcceptedRetry() async throws {
        let client = RecordingQwenClient(responses: [
            syntheticHotwordList,
            "accepted retry"
        ])
        let context = syntheticHotwordContext
        var callbackCallCounts: [Int] = []
        let engine = QwenTranscriptionEngine(
            client: client,
            modelID: "Qwen/Qwen3-ASR-0.6B",
            context: context,
            recordingDuration: { _ in 1.4 },
            onDecodeTiming: { _ in
                callbackCallCounts.append(client.contexts.count)
            }
        )

        let result = try await engine.transcribe(fileURL: URL(fileURLWithPath: "/tmp/short.wav"), languageMode: .mixedChineseEnglish)

        XCTAssertEqual(result.text, "accepted retry")
        XCTAssertEqual(callbackCallCounts, [2])
    }
}

private final class RecordingQwenClient: QwenTranscriptionClient {
    private var responses: [String]
    private(set) var contexts: [String] = []
    private(set) var strategies: [QwenTranscriptionStrategy] = []

    init(responses: [String]) {
        self.responses = responses
    }

    func transcribe(
        wavURL: URL,
        modelID: String,
        context: String,
        strategy: QwenTranscriptionStrategy
    ) async throws -> String {
        contexts.append(context)
        strategies.append(strategy)
        return responses.removeFirst()
    }
}
