import XCTest
@testable import VoiceInputApp

final class DiagnosticsExporterTests: XCTestCase {
    @MainActor
    func testDiagnosticsTextBuilderRunsBlockingProvidersOffMainThread() async {
        let report = ReadinessReport(
            generatedAt: Date(timeIntervalSince1970: 1_800_000_000),
            checks: []
        )
        let exporter = makeExporter()
        let builder = DiagnosticsTextBuilder(
            diagnosticsExporter: exporter,
            timingProvider: { nil },
            processProvider: {
                [
                    ProcessRSSSnapshot(
                        command: Thread.isMainThread ? "main-thread-diagnostics" : "background-diagnostics",
                        residentMemoryKB: 1
                    )
                ]
            },
            provenanceProvider: { nil }
        )

        let text = await builder.makeDiagnosticsText(report: report)

        XCTAssertTrue(text.contains("background-diagnostics"))
        XCTAssertFalse(text.contains("main-thread-diagnostics"))
    }

    func testDiagnosticsIncludesReadinessAndRedactsTokenLikeValues() {
        let report = ReadinessReport(
            generatedAt: Date(timeIntervalSince1970: 1_800_000_000),
            checks: [
                ReadinessCheck(
                    id: "bundled-uv",
                    group: .appBundle,
                    title: "Bundled uv",
                    detail: "Token abc should not leak.",
                    status: .failed("VOICEINPUT_HELPER_TOKEN=secret")
                )
            ]
        )
        let exporter = makeExporter()

        let text = exporter.makeDiagnosticsText(report: report, timing: nil, processes: [])

        XCTAssertTrue(text.contains("Flowtype Diagnostics"))
        XCTAssertTrue(text.contains("Bundled uv"))
        XCTAssertFalse(text.contains("secret"))
        XCTAssertTrue(text.contains("VOICEINPUT_HELPER_TOKEN=<redacted>"))
    }

    func testDiagnosticsTextBuilderWritesLatestDiagnosticsFile() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowtypeDiagnostics-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let report = ReadinessReport(
            generatedAt: Date(timeIntervalSince1970: 1_800_000_000),
            checks: [
                ReadinessCheck(
                    id: "qwen",
                    group: .models,
                    title: "Qwen",
                    detail: "Ready",
                    status: .ready
                )
            ]
        )
        let builder = DiagnosticsTextBuilder(
            applicationSupportRoot: root,
            diagnosticsExporter: makeExporter(),
            timingProvider: { nil },
            processProvider: { [] },
            provenanceProvider: { nil }
        )
        let text = await builder.makeDiagnosticsText(report: report)

        let url = try builder.writeLatestDiagnosticsText(text)

        XCTAssertEqual(url, root.appendingPathComponent("Diagnostics/latest-diagnostics.txt"))
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), text)
    }

    func testDiagnosticsFileWriterWritesLatestAndTimestampedFiles() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowtypeDiagnostics-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let generatedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let report = ReadinessReport(
            generatedAt: generatedAt,
            checks: [
                ReadinessCheck(
                    id: "qwen",
                    group: .models,
                    title: "Qwen",
                    detail: "Ready",
                    status: .ready
                )
            ]
        )
        var calendar = Calendar(identifier: .gregorian)
        let timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.timeZone = timeZone
        let writer = DiagnosticsFileWriter(
            applicationSupportRoot: root,
            textBuilder: DiagnosticsTextBuilder(
                applicationSupportRoot: root,
                diagnosticsExporter: makeExporter(),
                timingProvider: { nil },
                processProvider: { [] },
                provenanceProvider: { nil }
            ),
            now: { generatedAt },
            calendar: calendar,
            timeZone: timeZone
        )

        let result = try await writer.generate(report: report)

        XCTAssertEqual(result.latestURL, root.appendingPathComponent("Diagnostics/latest-diagnostics.txt"))
        XCTAssertEqual(
            result.timestampedURL,
            root.appendingPathComponent("Diagnostics/flowtype-diagnostics-20270115-080000.txt")
        )
        XCTAssertEqual(result.generatedAt, generatedAt)
        XCTAssertEqual(result.timestampedFileName, "flowtype-diagnostics-20270115-080000.txt")
        XCTAssertEqual(try String(contentsOf: result.latestURL, encoding: .utf8), result.text)
        XCTAssertEqual(try String(contentsOf: result.timestampedURL, encoding: .utf8), result.text)
    }

    func testDiagnosticsFileWriterProducesFilesWhenTextCollectionTimesOut() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowtypeDiagnostics-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let generatedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let report = ReadinessReport(
            generatedAt: generatedAt,
            checks: [
                ReadinessCheck(
                    id: "qwen",
                    group: .models,
                    title: "Qwen",
                    detail: "Ready",
                    status: .ready
                )
            ]
        )

        let writer = DiagnosticsFileWriter(
            applicationSupportRoot: root,
            makeText: { _ in
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                return "This slow text should not win the timeout race."
            },
            textTimeoutNanoseconds: 10_000_000,
            now: { generatedAt },
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        let result = try await writer.generate(report: report)

        XCTAssertEqual(result.latestURL, root.appendingPathComponent("Diagnostics/latest-diagnostics.txt"))
        XCTAssertEqual(result.timestampedFileName, "flowtype-diagnostics-20270115-080000.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.latestURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.timestampedURL.path))
        XCTAssertTrue(result.text.contains("Flowtype Diagnostics"))
        XCTAssertTrue(result.text.contains("Diagnostics detail collection timed out."))
        XCTAssertEqual(try String(contentsOf: result.latestURL, encoding: .utf8), result.text)
        XCTAssertEqual(try String(contentsOf: result.timestampedURL, encoding: .utf8), result.text)
    }

    func testDiagnosticsFileWriterReplacesFallbackFilesWhenDetailedTextCompletesAfterTimeout() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowtypeDiagnostics-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let generatedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let report = ReadinessReport(
            generatedAt: generatedAt,
            checks: [
                ReadinessCheck(id: "qwen", group: .models, title: "Qwen", detail: "Ready", status: .ready)
            ]
        )
        let delayedText = DelayedDiagnosticsText("Detailed diagnostics completed after fallback.")
        let writer = DiagnosticsFileWriter(
            applicationSupportRoot: root,
            makeText: { _ in
                await delayedText.value()
            },
            textTimeoutNanoseconds: 1_000_000,
            now: { generatedAt },
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        let result = try await writer.generate(report: report)

        XCTAssertTrue(result.text.contains("Diagnostics detail collection timed out."))
        XCTAssertEqual(try String(contentsOf: result.latestURL, encoding: .utf8), result.text)

        delayedText.finish()
        let detailedText = try await eventuallyReadFile(
            at: result.latestURL,
            containing: "Detailed diagnostics completed after fallback."
        )
        XCTAssertTrue(detailedText.contains("Detailed diagnostics completed after fallback."))
        XCTAssertEqual(detailedText, try String(contentsOf: result.timestampedURL, encoding: .utf8))
    }

    func testDiagnosticsFileWriterTimeoutFallbackIncludesRecentLocalEvidence() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowtypeDiagnostics-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let generatedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let report = ReadinessReport(
            generatedAt: generatedAt,
            checks: [
                ReadinessCheck(id: "qwen", group: .models, title: "Qwen", detail: "Ready", status: .ready)
            ]
        )
        let builder = DiagnosticsTextBuilder(
            applicationSupportRoot: root,
            diagnosticsExporter: makeExporter(),
            timingProvider: {
                TranscriptionTimingSample(
                    createdAt: Date(timeIntervalSince1970: 1_800_000_001),
                    modelID: "Qwen/Qwen3-ASR-0.6B",
                    strategy: "full",
                    recordingDurationSeconds: 1.2,
                    helperStartMilliseconds: 20,
                    modelPreparationMilliseconds: 30,
                    decodeMilliseconds: 400,
                    postProcessingMilliseconds: 10,
                    totalMilliseconds: 460
                )
            },
            processProvider: {
                Thread.sleep(forTimeInterval: 1)
                return []
            },
            provenanceProvider: {
                TranscriptionProvenance(
                    recordingID: UUID(uuidString: "00000000-0000-0000-0000-000000000789")!,
                    createdAt: Date(timeIntervalSince1970: 1_800_000_002),
                    selectedEngine: .qwenLocal,
                    winnerEngine: nil,
                    selectedModelID: VoiceInputModel.qwen3ASR06B.id,
                    sessionStateAtCompletion: "transcribing",
                    commitOutcome: "ignored",
                    ignoredInputReason: "transcription_in_flight"
                )
            }
        )
        let writer = DiagnosticsFileWriter(
            applicationSupportRoot: root,
            textBuilder: builder,
            textTimeoutNanoseconds: 10_000_000,
            now: { generatedAt },
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        let result = try await writer.generate(report: report)

        XCTAssertTrue(result.text.contains("Diagnostics detail collection timed out."))
        XCTAssertTrue(result.text.contains("- helper_ms: 20"))
        XCTAssertTrue(result.text.contains("- session_state_at_completion: transcribing"))
        XCTAssertTrue(result.text.contains("- commit_outcome: ignored"))
        XCTAssertTrue(result.text.contains("- ignored_input_reason: transcription_in_flight"))
        XCTAssertEqual(try String(contentsOf: result.latestURL, encoding: .utf8), result.text)
        XCTAssertEqual(try String(contentsOf: result.timestampedURL, encoding: .utf8), result.text)
    }

    func testDiagnosticsFileWriterDefaultsToGregorianTimestampedFileNames() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowtypeDiagnostics-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let generatedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let timeZone = TimeZone(secondsFromGMT: 0)!
        let report = ReadinessReport(
            generatedAt: generatedAt,
            checks: [
                ReadinessCheck(id: "qwen", group: .models, title: "Qwen", detail: "Ready", status: .ready)
            ]
        )
        let writer = DiagnosticsFileWriter(
            applicationSupportRoot: root,
            textBuilder: DiagnosticsTextBuilder(
                applicationSupportRoot: root,
                diagnosticsExporter: makeExporter(),
                timingProvider: { nil },
                processProvider: { [] },
                provenanceProvider: { nil }
            ),
            now: { generatedAt },
            timeZone: timeZone
        )

        let result = try await writer.generate(report: report)

        XCTAssertEqual(result.timestampedFileName, "flowtype-diagnostics-20270115-080000.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.timestampedURL.path))
    }

    func testDiagnosticsFileWriterOverwritesLatestAndKeepsTimestampedSnapshots() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowtypeDiagnostics-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let firstDate = Date(timeIntervalSince1970: 1_800_000_000)
        let secondDate = Date(timeIntervalSince1970: 1_800_000_061)
        var nextDate = firstDate
        var calendar = Calendar(identifier: .gregorian)
        let timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.timeZone = timeZone
        let writer = DiagnosticsFileWriter(
            applicationSupportRoot: root,
            textBuilder: DiagnosticsTextBuilder(
                applicationSupportRoot: root,
                diagnosticsExporter: makeExporter(),
                timingProvider: { nil },
                processProvider: { [] },
                provenanceProvider: { nil }
            ),
            now: { nextDate },
            calendar: calendar,
            timeZone: timeZone
        )
        let firstReport = ReadinessReport(
            generatedAt: firstDate,
            checks: [
                ReadinessCheck(id: "first", group: .models, title: "First", detail: "Ready", status: .ready)
            ]
        )
        let secondReport = ReadinessReport(
            generatedAt: secondDate,
            checks: [
                ReadinessCheck(id: "second", group: .models, title: "Second", detail: "Ready", status: .ready)
            ]
        )

        let firstResult = try await writer.generate(report: firstReport)
        nextDate = secondDate
        let secondResult = try await writer.generate(report: secondReport)

        XCTAssertEqual(firstResult.timestampedFileName, "flowtype-diagnostics-20270115-080000.txt")
        XCTAssertEqual(secondResult.timestampedFileName, "flowtype-diagnostics-20270115-080101.txt")
        XCTAssertEqual(try String(contentsOf: secondResult.latestURL, encoding: .utf8), secondResult.text)
        XCTAssertEqual(try String(contentsOf: firstResult.timestampedURL, encoding: .utf8), firstResult.text)
        XCTAssertEqual(try String(contentsOf: secondResult.timestampedURL, encoding: .utf8), secondResult.text)
        XCTAssertNotEqual(firstResult.text, secondResult.text)
    }

    func testDiagnosticsRedactsStatusMessageAndProcessCommandTokens() {
        let report = ReadinessReport(
            generatedAt: Date(timeIntervalSince1970: 1_800_000_000),
            checks: [
                ReadinessCheck(
                    id: "helper-health",
                    group: .localRuntime,
                    title: "Helper health",
                    detail: "Header X-VoiceInput-Token:abc123 failed.",
                    status: .failed("request used --token hf_secretValue")
                )
            ]
        )
        let processes = [
            ProcessRSSSnapshot(
                command: "uv run qwen-asr-helper VOICEINPUT_HELPER_TOKEN=processSecret X-VoiceInput-Token=headerSecret",
                residentMemoryKB: 4_096
            )
        ]
        let exporter = makeExporter()

        let text = exporter.makeDiagnosticsText(report: report, timing: nil, processes: processes)

        XCTAssertFalse(text.contains("abc123"))
        XCTAssertFalse(text.contains("hf_secretValue"))
        XCTAssertFalse(text.contains("processSecret"))
        XCTAssertFalse(text.contains("headerSecret"))
        XCTAssertTrue(text.contains("X-VoiceInput-Token=<redacted>"))
        XCTAssertTrue(text.contains("--token <redacted>"))
        XCTAssertTrue(text.contains("4096 KB RSS: qwen-asr-helper"))
        XCTAssertFalse(text.contains("VOICEINPUT_HELPER_TOKEN="))
    }

    func testDiagnosticsScrubsHomePathsFromReadinessText() {
        let report = ReadinessReport(
            generatedAt: Date(timeIntervalSince1970: 1_800_000_000),
            checks: [
                ReadinessCheck(
                    id: "helper-copy",
                    group: .localRuntime,
                    title: "Helper at /Users/example-user/Library/Application Support/Flowtype/qwen-asr-helper",
                    detail: "Missing /Users/example-user/Library/Application Support/Flowtype/qwen-asr-helper/.venv/bin/python3",
                    status: .failed("Tried /Users/example-user/.cache/flowtype/helper.log")
                )
            ]
        )
        let exporter = makeExporter()

        let text = exporter.makeDiagnosticsText(report: report, timing: nil, processes: [])

        XCTAssertFalse(text.contains("/Users/example-user"))
        XCTAssertFalse(text.contains(" example-user"))
        XCTAssertTrue(text.contains("~/Library/Application Support/Flowtype/qwen-asr-helper"))
        XCTAssertTrue(text.contains("~/.cache/flowtype/helper.log"))
    }

    func testDiagnosticsPreservesOrdinaryTokenPhrases() {
        let report = ReadinessReport(
            generatedAt: Date(timeIntervalSince1970: 1_800_000_000),
            checks: [
                ReadinessCheck(
                    id: "copy",
                    group: .performance,
                    title: "Copy",
                    detail: "The token bucket and token parser checks are documentation terms.",
                    status: .failed("The token bucket remains ordinary text.")
                )
            ]
        )
        let exporter = makeExporter()

        let text = exporter.makeDiagnosticsText(report: report, timing: nil, processes: [])

        XCTAssertTrue(text.contains("token bucket"))
        XCTAssertTrue(text.contains("token parser"))
    }

    func testDiagnosticsRedactsCommonTokenLikeAssignmentsAndFlags() {
        let report = ReadinessReport(
            generatedAt: Date(timeIntervalSince1970: 1_800_000_000),
            checks: [
                ReadinessCheck(
                    id: "helper-env",
                    group: .localRuntime,
                    title: "Helper env",
                    detail: "--token=detailSecret api_token=apiSecret HF_TOKEN=hfSecret",
                    status: .failed("access-token accessSecret --TOKEN flagSecret")
                )
            ]
        )
        let processes = [
            ProcessRSSSnapshot(
                command: "uv run qwen-asr-helper --token=processSecret --token splitSecret API_TOKEN=upperSecret hf_token=lowerSecret ACCESS-TOKEN dashedSecret",
                residentMemoryKB: 4_096
            )
        ]
        let exporter = makeExporter()

        let text = exporter.makeDiagnosticsText(report: report, timing: nil, processes: processes)

        for secret in [
            "detailSecret",
            "apiSecret",
            "hfSecret",
            "accessSecret",
            "flagSecret",
            "processSecret",
            "splitSecret",
            "upperSecret",
            "lowerSecret",
            "dashedSecret"
        ] {
            XCTAssertFalse(text.contains(secret), "\(secret) leaked in diagnostics text")
        }
        XCTAssertTrue(text.contains("--token=<redacted>"))
        XCTAssertTrue(text.contains("api_token=<redacted>"))
        XCTAssertTrue(text.contains("HF_TOKEN=<redacted>"))
        XCTAssertTrue(text.contains("access-token <redacted>"))
    }

    func testDiagnosticsSummarizesProcessCommandsWithoutHomePaths() {
        let report = ReadinessReport(generatedAt: Date(timeIntervalSince1970: 1_800_000_000), checks: [])
        let processes = [
            ProcessRSSSnapshot(
                command: "/Users/example-user/Library/Application Support/Flowtype/qwen-asr-helper/.venv/bin/python3 /Users/example-user/Library/Application Support/Flowtype/qwen-asr-helper/qwen_asr_helper/server.py",
                residentMemoryKB: 8_192
            ),
            ProcessRSSSnapshot(
                command: "/Applications/Flowtype.app/Contents/MacOS/Flowtype",
                residentMemoryKB: 16_384
            )
        ]
        let exporter = makeExporter()

        let text = exporter.makeDiagnosticsText(report: report, timing: nil, processes: processes)

        XCTAssertTrue(text.contains("8192 KB RSS: qwen-asr-helper"))
        XCTAssertTrue(text.contains("16384 KB RSS: Flowtype"))
        XCTAssertFalse(text.contains("/Users/example-user"))
        XCTAssertFalse(text.contains("Application Support/Flowtype/qwen-asr-helper"))
    }

    func testDiagnosticsIncludesTimingWithoutTranscriptOrAudioFields() {
        let report = ReadinessReport(generatedAt: Date(timeIntervalSince1970: 1_800_000_000), checks: [])
        let timing = TranscriptionTimingSample(
            createdAt: Date(timeIntervalSince1970: 1_800_000_001),
            modelID: "Qwen/Qwen3-ASR-0.6B",
            strategy: "full",
            recordingDurationSeconds: 1.2,
            helperStartMilliseconds: 20,
            modelPreparationMilliseconds: 30,
            decodeMilliseconds: 400,
            postProcessingMilliseconds: 10,
            totalMilliseconds: 460
        )
        let exporter = makeExporter()

        let text = exporter.makeDiagnosticsText(report: report, timing: timing, processes: [])

        XCTAssertTrue(text.contains("- helper_ms: 20"))
        XCTAssertTrue(text.contains("- status_probe_ms: 30"))
        XCTAssertTrue(text.contains("- decode_ms: 400"))
        XCTAssertTrue(text.contains("- post_ms: 10"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("transcript:"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("audio:"))
    }

    func testDiagnosticsIncludesLatestTranscriptionProvenanceWithoutTranscriptAudioOrTokens() {
        let report = ReadinessReport(generatedAt: Date(timeIntervalSince1970: 1_800_000_000), checks: [])
        let provenance = TranscriptionProvenance(
            recordingID: UUID(uuidString: "00000000-0000-0000-0000-000000000123")!,
            createdAt: Date(timeIntervalSince1970: 1_800_000_002),
            selectedEngine: .qwenLocal,
            winnerEngine: .appleSpeech,
            selectedModelID: VoiceInputModel.qwen3ASR06B.id,
            requestedModelID: VoiceInputModel.qwen3ASR06B.modelID,
            requestedStrategy: "full",
            effectiveStrategy: "chunked",
            qwenErrorKind: QwenFailureKind.transcriptionTimedOut.rawValue,
            appleFallbackReason: "VOICEINPUT_HELPER_TOKEN=secret",
            contextEchoRecovery: QwenContextEchoRecovery.retriedWithoutContext.rawValue,
            sessionStateAtCompletion: "transcribing",
            commitOutcome: "committed",
            ignoredInputReason: "none"
        )
        let exporter = makeExporter()

        let text = exporter.makeDiagnosticsText(
            report: report,
            timing: nil,
            processes: [],
            provenance: provenance
        )

        XCTAssertTrue(text.contains("- selected_engine: qwenLocal"))
        XCTAssertTrue(text.contains("- winner_engine: appleSpeech"))
        XCTAssertTrue(text.contains("- requested_strategy: full"))
        XCTAssertTrue(text.contains("- effective_strategy: chunked"))
        XCTAssertTrue(text.contains("- qwen_error_kind: transcriptionTimedOut"))
        XCTAssertTrue(text.contains("- context_echo_recovery: retriedWithoutContext"))
        XCTAssertTrue(text.contains("- session_state_at_completion: transcribing"))
        XCTAssertTrue(text.contains("- commit_outcome: committed"))
        XCTAssertTrue(text.contains("- ignored_input_reason: none"))
        XCTAssertFalse(text.contains("secret"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("transcript:"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("audio:"))
    }

    private func makeExporter() -> DiagnosticsExporter {
        DiagnosticsExporter(
            appVersionProvider: { "1.0-test" },
            macOSVersionProvider: { "macOS 15.5" },
            hardwareProvider: {
                HardwareSummary(machine: "Mac14,7", processor: "Apple M2", physicalMemoryGB: 16, isAppleSilicon: true)
            }
        )
    }

    private func eventuallyReadFile(
        at url: URL,
        containing expectedText: String,
        attempts: Int = 20
    ) async throws -> String {
        for _ in 0..<attempts {
            let text = try String(contentsOf: url, encoding: .utf8)
            if text.contains(expectedText) {
                return text
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}

private final class DelayedDiagnosticsText: @unchecked Sendable {
    private let lock = NSLock()
    private let text: String
    private var continuation: CheckedContinuation<String, Never>?

    init(_ text: String) {
        self.text = text
    }

    func value() async -> String {
        await withCheckedContinuation { continuation in
            lock.lock()
            self.continuation = continuation
            lock.unlock()
        }
    }

    func finish() {
        lock.lock()
        let continuation = continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(returning: text)
    }
}
