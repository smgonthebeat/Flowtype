import XCTest
@testable import VoiceInputApp

final class TranscriptionProvenanceStoreTests: XCTestCase {
    func testAppendsAndLoadsRecentRecordsNewestFirst() throws {
        let root = temporaryRoot()
        let store = TranscriptionProvenanceStore(applicationSupportRoot: root, limit: 2)
        let first = TranscriptionProvenance(
            recordingID: UUID(),
            createdAt: Date(timeIntervalSince1970: 1),
            selectedEngine: .qwenLocal,
            winnerEngine: .qwenLocal,
            selectedModelID: VoiceInputModel.qwen3ASR06B.id
        )
        let second = TranscriptionProvenance(
            recordingID: UUID(),
            createdAt: Date(timeIntervalSince1970: 2),
            selectedEngine: .qwenLocal,
            winnerEngine: .appleSpeech,
            selectedModelID: VoiceInputModel.qwen3ASR06B.id,
            fallbackReason: QwenFailureKind.transcriptionTimedOut.rawValue
        )
        let third = TranscriptionProvenance(
            recordingID: UUID(),
            createdAt: Date(timeIntervalSince1970: 3),
            selectedEngine: .appleSpeech,
            winnerEngine: .appleSpeech,
            selectedModelID: nil
        )

        try store.append(first)
        try store.append(second)
        try store.append(third)

        XCTAssertEqual(try store.loadRecent().map(\.recordingID), [third.recordingID, second.recordingID])
    }

    func testRecordDoesNotStoreAuthTokenTranscriptOrAudio() throws {
        let record = TranscriptionProvenance(
            recordingID: UUID(),
            createdAt: Date(),
            selectedEngine: .qwenLocal,
            winnerEngine: .qwenLocal,
            selectedModelID: VoiceInputModel.qwen3ASR06B.id,
            capsuleEvents: [CapsuleEvent(at: Date(), text: "Transcribing with Qwen...")]
        )
        let data = try JSONEncoder().encode(record)
        let json = String(decoding: data, as: UTF8.self).lowercased()

        XCTAssertFalse(json.contains("token"))
        XCTAssertFalse(json.contains("transcript"))
        XCTAssertFalse(json.contains("audio"))
    }

    func testRecordEncodesAndDecodesDetailedProvenanceFields() throws {
        let createdAt = Date(timeIntervalSince1970: 1_800_000_000)
        let qwenStartedAt = Date(timeIntervalSince1970: 1_800_000_001)
        let qwenFinishedAt = Date(timeIntervalSince1970: 1_800_000_003)
        let fallbackStartedAt = Date(timeIntervalSince1970: 1_800_000_004)
        let record = TranscriptionProvenance(
            recordingID: UUID(),
            createdAt: createdAt,
            selectedEngine: .qwenLocal,
            winnerEngine: .appleSpeech,
            selectedModelID: VoiceInputModel.qwen3ASR06B.id,
            modelStatusBefore: QwenModelStatusSnapshot(
                installed: true,
                loaded: false,
                loading: true,
                downloading: false,
                progress: 0.42,
                modelID: VoiceInputModel.qwen3ASR06B.modelID
            ),
            qwenStartedAt: qwenStartedAt,
            qwenFinishedAt: qwenFinishedAt,
            qwenErrorKind: QwenFailureKind.modelLoadTimedOut.rawValue,
            appleFallbackStartedAt: fallbackStartedAt,
            appleFallbackReason: QwenFailureKind.modelLoadTimedOut.rawValue,
            contextEchoRecovery: QwenContextEchoRecovery.retriedWithoutContext.rawValue,
            sessionStateAtCompletion: "transcribing",
            commitOutcome: "ignored",
            ignoredInputReason: "transcription_in_flight",
            timing: TranscriptionProvenanceTiming(
                helperStartMilliseconds: 10,
                modelPreparationMilliseconds: 20,
                qwenDecodeMilliseconds: 30,
                postProcessingMilliseconds: 40,
                totalMilliseconds: 100
            )
        )

        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(TranscriptionProvenance.self, from: data)

        XCTAssertEqual(decoded, record)
        XCTAssertEqual(decoded.modelStatusBefore?.modelID, VoiceInputModel.qwen3ASR06B.modelID)
        XCTAssertEqual(decoded.qwenErrorKind, QwenFailureKind.modelLoadTimedOut.rawValue)
        XCTAssertEqual(decoded.appleFallbackReason, QwenFailureKind.modelLoadTimedOut.rawValue)
        XCTAssertEqual(decoded.contextEchoRecovery, QwenContextEchoRecovery.retriedWithoutContext.rawValue)
        XCTAssertEqual(decoded.sessionStateAtCompletion, "transcribing")
        XCTAssertEqual(decoded.commitOutcome, "ignored")
        XCTAssertEqual(decoded.ignoredInputReason, "transcription_in_flight")
        XCTAssertEqual(decoded.timing?.qwenDecodeMilliseconds, 30)
    }

    func testRecordDecodesOldJSONWithoutSessionStateMachineFields() throws {
        let json = """
        {
          "recordingID": "00000000-0000-0000-0000-000000000456",
          "createdAt": "2027-01-15T08:00:00Z",
          "selectedEngine": "qwenLocal",
          "winnerEngine": "qwenLocal",
          "selectedModelID": "qwen3-asr-0.6b",
          "capsuleEvents": []
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let decoded = try decoder.decode(TranscriptionProvenance.self, from: Data(json.utf8))

        XCTAssertNil(decoded.sessionStateAtCompletion)
        XCTAssertNil(decoded.commitOutcome)
        XCTAssertNil(decoded.ignoredInputReason)
        XCTAssertNil(decoded.contextEchoRecovery)
    }

    func testStoreWritesUnderDiagnosticsTranscriptionsDirectory() throws {
        let root = temporaryRoot()
        let store = TranscriptionProvenanceStore(applicationSupportRoot: root, limit: 2)
        let record = TranscriptionProvenance(
            recordingID: UUID(),
            createdAt: Date(),
            selectedEngine: .qwenLocal,
            winnerEngine: .qwenLocal,
            selectedModelID: VoiceInputModel.qwen3ASR06B.id
        )

        try store.append(record)

        let expectedURL = root
            .appendingPathComponent("Diagnostics", isDirectory: true)
            .appendingPathComponent("Transcriptions", isDirectory: true)
            .appendingPathComponent("transcription-provenance.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: expectedURL.path))
    }

    func testConcurrentAppendsDoNotLoseRecords() throws {
        let root = temporaryRoot()
        let expectedCount = 48
        let records = (0..<expectedCount).map { index in
            TranscriptionProvenance(
                recordingID: UUID(),
                createdAt: Date(timeIntervalSince1970: Double(index)),
                selectedEngine: .qwenLocal,
                winnerEngine: index.isMultiple(of: 2) ? .qwenLocal : nil,
                selectedModelID: VoiceInputModel.qwen3ASR06B.id,
                qwenErrorKind: index.isMultiple(of: 2) ? nil : QwenFailureKind.transcriptionFailed.rawValue,
                commitOutcome: index.isMultiple(of: 2) ? "committed" : "failed"
            )
        }
        let queue = DispatchQueue(label: "flowtype.provenance.concurrent-test", attributes: .concurrent)
        let group = DispatchGroup()
        let errorLock = NSLock()
        var errors: [Error] = []

        for record in records {
            group.enter()
            queue.async {
                defer { group.leave() }
                do {
                    try TranscriptionProvenanceStore(applicationSupportRoot: root, limit: expectedCount).append(record)
                } catch {
                    errorLock.withLock {
                        errors.append(error)
                    }
                }
            }
        }
        group.wait()

        XCTAssertTrue(errors.isEmpty, "Concurrent appends should not throw: \(errors)")

        let loaded = try TranscriptionProvenanceStore(applicationSupportRoot: root, limit: expectedCount).loadRecent()
        XCTAssertEqual(
            Set(loaded.map(\.recordingID)),
            Set(records.map(\.recordingID)),
            "Concurrent success/failure provenance appends should preserve every record."
        )
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("flowtype-provenance-\(UUID().uuidString)", isDirectory: true)
    }
}
