import XCTest
@testable import VoiceInputApp

final class TranscriptionTimingStoreTests: XCTestCase {
    func testSavesAndLoadsLastTimingSample() throws {
        let root = temporaryRoot()
        let store = TranscriptionTimingStore(applicationSupportRoot: root)
        let sample = TranscriptionTimingSample(
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            modelID: "Qwen/Qwen3-ASR-0.6B",
            requestedStrategy: "full",
            effectiveStrategy: "chunked",
            recordingDurationSeconds: 2.4,
            helperStartMilliseconds: 120,
            modelPreparationMilliseconds: 340,
            decodeMilliseconds: 800,
            postProcessingMilliseconds: 45,
            totalMilliseconds: 1_305
        )

        try store.save(sample)

        XCTAssertEqual(try store.loadLastSample(), sample)
    }

    func testDecodesLegacyStrategyIntoRequestedAndEffectiveStrategy() throws {
        let root = temporaryRoot()
        let diagnosticsURL = root
            .appendingPathComponent("Diagnostics", isDirectory: true)
        try FileManager.default.createDirectory(at: diagnosticsURL, withIntermediateDirectories: true)
        let timingURL = diagnosticsURL.appendingPathComponent("last-transcription-timing.json")
        try Data("""
        {
          "createdAt" : "2027-01-15T08:00:00Z",
          "decodeMilliseconds" : 800,
          "helperStartMilliseconds" : 120,
          "modelID" : "Qwen/Qwen3-ASR-0.6B",
          "modelPreparationMilliseconds" : 340,
          "postProcessingMilliseconds" : 45,
          "recordingDurationSeconds" : 2.4,
          "strategy" : "full",
          "totalMilliseconds" : 1305
        }
        """.utf8).write(to: timingURL)
        let store = TranscriptionTimingStore(applicationSupportRoot: root)

        let sample = try store.loadLastSample()

        XCTAssertEqual(sample?.requestedStrategy, "full")
        XCTAssertEqual(sample?.effectiveStrategy, "full")
    }

    func testMissingTimingSampleReturnsNil() throws {
        let store = TranscriptionTimingStore(applicationSupportRoot: temporaryRoot())

        XCTAssertNil(try store.loadLastSample())
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("flowtype-timing-\(UUID().uuidString)", isDirectory: true)
    }
}
