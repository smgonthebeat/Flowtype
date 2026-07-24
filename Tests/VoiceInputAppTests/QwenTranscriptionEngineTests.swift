import XCTest
@testable import VoiceInputApp

final class QwenTranscriptionEngineTests: XCTestCase {
    private let syntheticHotwordList = "DEMO1001, TEST2045, Qwen, alpha, beta, gamma, delta, epsilon, zeta, eta, theta, iota, kappa, lambda, markdown, parser, renderer, sample phrase, test fixture, workflow, Example University."
    private let syntheticTerms = ["DEMO1001", "TEST2045", "Qwen", "alpha", "beta", "gamma", "delta", "epsilon", "zeta", "eta", "theta", "iota", "kappa", "lambda", "markdown", "parser", "renderer", "sample phrase", "test fixture", "workflow", "Example University"]

    private var syntheticHotwordContext: QwenPromptContext {
        QwenPromptContext(payload: syntheticTerms.joined(separator: " "), knownTerms: syntheticTerms)
    }

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
        XCTAssertEqual(client.contexts, [context.payload, ""])
        XCTAssertEqual(client.strategies, [.full, .full])
    }

    func testRetriesWithoutContextWhenLongRecordingLeaksFullHotwordContext() async throws {
        let context = syntheticHotwordContext
        let client = RecordingQwenClient(responses: [
            context.payload,
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
        XCTAssertEqual(client.contexts, [context.payload, ""])
        XCTAssertEqual(client.strategies, [.full, .full])
    }

    func testRetriesWithoutContextForAppendedInternalInstructionTail() async throws {
        let guidance = "Keep the text natural, clear, and conversational. Stay close to the spoken wording."
        let context = QwenPromptContext(payload: guidance, internalOnlySegments: [guidance])
        let client = RecordingQwenClient(responses: [
            "X bar. \(guidance)",
            "X bar."
        ])
        let engine = QwenTranscriptionEngine(
            client: client,
            modelID: "Qwen/Qwen3-ASR-0.6B",
            context: context,
            recordingDuration: { _ in 30 }
        )

        let result = try await engine.transcribe(fileURL: URL(fileURLWithPath: "/tmp/long.wav"), languageMode: .mixedChineseEnglish)

        XCTAssertEqual(result.text, "X bar.")
        XCTAssertEqual(result.contextEchoRecovery, .retriedWithoutContext)
        XCTAssertEqual(client.contexts, [guidance, ""])
        XCTAssertEqual(client.strategies, [.full, .full])
    }

    func testRetriesWithoutContextForExactIncidentStylePromptPrefix() async throws {
        let fullGuidance = "Keep the text natural, clear, and conversational. Stay close to the spoken wording. Use conservative punctuation. Do not use exclamation marks. Remove obvious filler words only when they do not change meaning."
        let leakedPrefix = "Keep the text natural, clear, and conversational. Stay close to the spoken wording."
        let context = QwenPromptContext(payload: fullGuidance, internalOnlySegments: [fullGuidance])
        let client = RecordingQwenClient(responses: [leakedPrefix, "X bar."])
        let engine = QwenTranscriptionEngine(
            client: client,
            modelID: "Qwen/Qwen3-ASR-0.6B",
            context: context,
            recordingDuration: { _ in 1.785625 }
        )

        let result = try await engine.transcribe(fileURL: URL(fileURLWithPath: "/tmp/x-bar.wav"), languageMode: .mixedChineseEnglish)

        XCTAssertEqual(result.text, "X bar.")
        XCTAssertEqual(result.contextEchoRecovery, .retriedWithoutContext)
        XCTAssertEqual(client.contexts, [fullGuidance, ""])
    }

    func testFailsClosedWhenRetryAlsoLeaksInternalContext() async {
        let leakedPrefix = "Keep the text natural, clear, and conversational."
        let client = RecordingQwenClient(responses: [leakedPrefix, leakedPrefix])
        let engine = QwenTranscriptionEngine(
            client: client,
            modelID: "Qwen/Qwen3-ASR-0.6B",
            context: .empty,
            recordingDuration: { _ in 1.5 }
        )

        do {
            _ = try await engine.transcribe(fileURL: URL(fileURLWithPath: "/tmp/leak.wav"), languageMode: .mixedChineseEnglish)
            XCTFail("Expected context leak to fail closed")
        } catch {
            XCTAssertEqual(error as? TranscriptionError, .contextLeakDetected)
        }
        XCTAssertEqual(client.contexts, ["", ""])
    }

    func testDoesNotRetryOrdinaryXBarTranscript() async throws {
        let client = RecordingQwenClient(responses: ["X bar."])
        let engine = QwenTranscriptionEngine(
            client: client,
            modelID: "Qwen/Qwen3-ASR-0.6B",
            context: .empty,
            recordingDuration: { _ in 1.785625 }
        )

        let result = try await engine.transcribe(fileURL: URL(fileURLWithPath: "/tmp/x-bar.wav"), languageMode: .mixedChineseEnglish)

        XCTAssertEqual(result.text, "X bar.")
        XCTAssertNil(result.contextEchoRecovery)
        XCTAssertEqual(client.contexts, [""])
    }

    func testRetriesExactSmallVocabularyPayloadButAcceptsItWhenActuallySpokenOnSafeRetry() async throws {
        let context = QwenPromptContext(
            payload: "Qwen Flowtype",
            knownTerms: ["Qwen", "Flowtype"]
        )
        let client = RecordingQwenClient(responses: ["Qwen Flowtype", "Qwen Flowtype"])
        let engine = QwenTranscriptionEngine(
            client: client,
            modelID: "Qwen/Qwen3-ASR-0.6B",
            context: context,
            recordingDuration: { _ in 2.0 }
        )

        let result = try await engine.transcribe(fileURL: URL(fileURLWithPath: "/tmp/spoken-hotwords.wav"), languageMode: .mixedChineseEnglish)

        XCTAssertEqual(result.text, "Qwen Flowtype")
        XCTAssertEqual(result.contextEchoRecovery, .retriedWithoutContext)
        XCTAssertEqual(client.contexts, ["Qwen Flowtype", ""])
    }

    func testRetriesExactSingleVocabularyPayloadButAcceptsSafeRetry() async throws {
        let context = QwenPromptContext(payload: "Qwen", knownTerms: ["Qwen"])
        let client = RecordingQwenClient(responses: ["Qwen", "Qwen"])
        let engine = QwenTranscriptionEngine(
            client: client,
            modelID: "Qwen/Qwen3-ASR-0.6B",
            context: context,
            recordingDuration: { _ in 1.0 }
        )

        let result = try await engine.transcribe(fileURL: URL(fileURLWithPath: "/tmp/spoken-hotword.wav"), languageMode: .mixedChineseEnglish)

        XCTAssertEqual(result.text, "Qwen")
        XCTAssertEqual(result.contextEchoRecovery, .retriedWithoutContext)
        XCTAssertEqual(client.contexts, ["Qwen", ""])
    }

    func testRetriesWithoutContextForAppendedTruncatedInstruction() async throws {
        let client = RecordingQwenClient(responses: [
            "X bar. Keep the text natural, clear",
            "X bar."
        ])
        let engine = QwenTranscriptionEngine(
            client: client,
            modelID: "Qwen/Qwen3-ASR-0.6B",
            context: .empty,
            recordingDuration: { _ in 1.785625 }
        )

        let result = try await engine.transcribe(fileURL: URL(fileURLWithPath: "/tmp/x-bar.wav"), languageMode: .mixedChineseEnglish)

        XCTAssertEqual(result.text, "X bar.")
        XCTAssertEqual(result.contextEchoRecovery, .retriedWithoutContext)
        XCTAssertEqual(client.contexts, ["", ""])
    }

    func testFailsClosedWhenSafeRetryContainsUnicodeObfuscatedInternalTail() async {
        let client = RecordingQwenClient(responses: [
            "Keep the text natural, clear, and conversational.",
            "X bar. Ke\u{200B}ep the text natural, clear"
        ])
        let engine = QwenTranscriptionEngine(
            client: client,
            modelID: "Qwen/Qwen3-ASR-0.6B",
            context: .empty,
            recordingDuration: { _ in 1.785625 }
        )

        do {
            _ = try await engine.transcribe(fileURL: URL(fileURLWithPath: "/tmp/x-bar.wav"), languageMode: .mixedChineseEnglish)
            XCTFail("Expected obfuscated internal leak to fail closed")
        } catch {
            XCTAssertEqual(error as? TranscriptionError, .contextLeakDetected)
        }
        XCTAssertEqual(client.contexts, ["", ""])
    }

    func testFailsClosedWhenSafeRetryContainsTruncatedCJKInternalTail() async {
        let guidance = "请保持原始措辞并准确转写用户说出的内容，不要添加任何新信息。"
        let context = QwenPromptContext(payload: guidance)
        let client = RecordingQwenClient(responses: [
            guidance,
            "X bar. 请保持原始措辞并准确转写用户说出的内容"
        ])
        let engine = QwenTranscriptionEngine(
            client: client,
            modelID: "Qwen/Qwen3-ASR-0.6B",
            context: context,
            recordingDuration: { _ in 1.8 }
        )

        do {
            _ = try await engine.transcribe(fileURL: URL(fileURLWithPath: "/tmp/cjk-leak.wav"), languageMode: .mixedChineseEnglish)
            XCTFail("Expected truncated CJK internal leak to fail closed")
        } catch {
            XCTAssertEqual(error as? TranscriptionError, .contextLeakDetected)
        }
        XCTAssertEqual(client.contexts, [guidance, ""])
    }

    func testFailsClosedWhenCleanRetryRepeatsHighCoverageVocabularyList() async {
        let context = QwenPromptContext(
            payload: "alpha beta gamma",
            knownTerms: ["alpha", "beta", "gamma"]
        )
        let client = RecordingQwenClient(responses: ["alpha beta", "alpha beta"])
        let engine = QwenTranscriptionEngine(
            client: client,
            modelID: "Qwen/Qwen3-ASR-0.6B",
            context: context,
            recordingDuration: { _ in 1.0 }
        )

        do {
            _ = try await engine.transcribe(fileURL: URL(fileURLWithPath: "/tmp/repeated-partial-list.wav"), languageMode: .mixedChineseEnglish)
            XCTFail("Expected repeated high-coverage vocabulary list to fail closed")
        } catch {
            XCTAssertEqual(error as? TranscriptionError, .contextLeakDetected)
        }
        XCTAssertEqual(client.contexts, ["alpha beta gamma", ""])
    }

    func testContextLeakRetryPreservesRequestedChunkedStrategy() async throws {
        let client = RecordingQwenClient(responses: [
            "Keep the text natural, clear, and conversational.",
            "X bar."
        ])
        let engine = QwenTranscriptionEngine(
            client: client,
            modelID: "Qwen/Qwen3-ASR-0.6B",
            context: .empty,
            strategy: .chunked,
            recordingDuration: { _ in 90 }
        )

        let result = try await engine.transcribe(fileURL: URL(fileURLWithPath: "/tmp/long-leak.wav"), languageMode: .mixedChineseEnglish)

        XCTAssertEqual(result.text, "X bar.")
        XCTAssertEqual(result.contextEchoRecovery, .retriedWithoutContext)
        XCTAssertEqual(client.strategies, [.chunked, .chunked])
    }

    func testFailsClosedWhenCleanRetryRepeatsCompleteLargeVocabularyList() async {
        let context = QwenPromptContext(
            payload: "alpha beta gamma delta",
            knownTerms: ["alpha", "beta", "gamma", "delta"]
        )
        let client = RecordingQwenClient(responses: [
            "alpha beta gamma delta",
            "alpha beta gamma delta"
        ])
        let engine = QwenTranscriptionEngine(
            client: client,
            modelID: "Qwen/Qwen3-ASR-0.6B",
            context: context,
            recordingDuration: { _ in 1.0 }
        )

        do {
            _ = try await engine.transcribe(fileURL: URL(fileURLWithPath: "/tmp/repeated-list.wav"), languageMode: .mixedChineseEnglish)
            XCTFail("Expected repeated large vocabulary list to fail closed")
        } catch {
            XCTAssertEqual(error as? TranscriptionError, .contextLeakDetected)
        }
        XCTAssertEqual(client.contexts, ["alpha beta gamma delta", ""])
    }

    func testRetriesShortOrderedPrefixFromLargeVocabularyContext() async throws {
        let terms = [
            "alpha", "beta", "gamma", "delta", "epsilon",
            "zeta", "eta", "theta", "iota", "kappa"
        ]
        let context = QwenPromptContext(
            payload: terms.joined(separator: " "),
            knownTerms: terms
        )
        let client = RecordingQwenClient(responses: ["alpha beta gamma", "ordinary speech"])
        let engine = QwenTranscriptionEngine(
            client: client,
            modelID: "Qwen/Qwen3-ASR-0.6B",
            context: context,
            recordingDuration: { _ in 1.0 }
        )

        let result = try await engine.transcribe(fileURL: URL(fileURLWithPath: "/tmp/large-prefix.wav"), languageMode: .mixedChineseEnglish)

        XCTAssertEqual(result.text, "ordinary speech")
        XCTAssertEqual(result.contextEchoRecovery, .retriedWithoutContext)
        XCTAssertEqual(client.contexts, [context.payload, ""])
    }

    func testFailsClosedWhenCleanRetryRepeatsSymbolOnlyVocabularyList() async {
        let context = QwenPromptContext(
            payload: "🎙️ 🧠 ✨ 🔒",
            knownTerms: ["🎙️", "🧠", "✨", "🔒"]
        )
        let client = RecordingQwenClient(responses: [context.payload, "🎙, 🧠 ✨ 🔒"])
        let engine = QwenTranscriptionEngine(
            client: client,
            modelID: "Qwen/Qwen3-ASR-0.6B",
            context: context,
            recordingDuration: { _ in 1.0 }
        )

        do {
            _ = try await engine.transcribe(fileURL: URL(fileURLWithPath: "/tmp/repeated-symbol-list.wav"), languageMode: .mixedChineseEnglish)
            XCTFail("Expected repeated symbol vocabulary list to fail closed")
        } catch {
            XCTAssertEqual(error as? TranscriptionError, .contextLeakDetected)
        }
        XCTAssertEqual(client.contexts, [context.payload, ""])
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
        XCTAssertEqual(result.contextEchoRecovery, .retriedWithoutContext)
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
