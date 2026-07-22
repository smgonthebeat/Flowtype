import XCTest
@testable import VoiceInputApp

@MainActor
final class ReadinessDiagnosticsActionRunnerTests: XCTestCase {
    func testGenerateFileCallsActionAndStoresResult() async {
        let generatedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let report = Self.makeReport()
        let result = Self.makeResult(generatedAt: generatedAt)
        let runner = ReadinessDiagnosticsActionRunner()
        var receivedReport: ReadinessReport?

        let outcome = await runner.generateFile(report: report) { incoming in
            receivedReport = incoming
            return result
        }

        XCTAssertEqual(receivedReport, report)
        XCTAssertEqual(outcome, .generated(result))
        XCTAssertFalse(runner.isGeneratingFile)
        XCTAssertEqual(runner.generatedResult, result)
        XCTAssertNil(runner.errorMessage)
    }

    func testGenerateFileFailureClearsBusyStateAndStoresError() async {
        struct SampleError: LocalizedError {
            var errorDescription: String? { "writer failed" }
        }

        let runner = ReadinessDiagnosticsActionRunner()

        let outcome = await runner.generateFile(report: Self.makeReport()) { _ in
            throw SampleError()
        }

        XCTAssertEqual(outcome, .failed("writer failed"))
        XCTAssertFalse(runner.isGeneratingFile)
        XCTAssertNil(runner.generatedResult)
        XCTAssertEqual(runner.errorMessage, "writer failed")
    }

    func testGenerateFileCancellationClearsBusyStateWithoutUserVisibleError() async {
        let runner = ReadinessDiagnosticsActionRunner()

        let outcome = await runner.generateFile(report: Self.makeReport()) { _ in
            throw CancellationError()
        }

        XCTAssertEqual(outcome, .cancelled)
        XCTAssertFalse(runner.isGeneratingFile)
        XCTAssertNil(runner.generatedResult)
        XCTAssertNil(runner.errorMessage)
    }

    func testGenerateFileIgnoresDuplicateWhileRunning() async {
        let runner = ReadinessDiagnosticsActionRunner()
        let report = Self.makeReport()
        let firstStarted = expectation(description: "first started")
        let releaseFirst = expectation(description: "release first")

        let firstTask = Task {
            await runner.generateFile(report: report) { _ in
                firstStarted.fulfill()
                await self.fulfillment(of: [releaseFirst], timeout: 1.0)
                return Self.makeResult(generatedAt: Date(timeIntervalSince1970: 1_800_000_000))
            }
        }

        await fulfillment(of: [firstStarted], timeout: 1.0)
        let duplicateOutcome = await runner.generateFile(report: report) { _ in
            XCTFail("duplicate action should not run")
            return Self.makeResult(generatedAt: Date(timeIntervalSince1970: 1_800_000_001))
        }

        XCTAssertEqual(duplicateOutcome, .alreadyRunning)
        releaseFirst.fulfill()
        _ = await firstTask.value
    }

    private static func makeReport() -> ReadinessReport {
        ReadinessReport(
            generatedAt: Date(timeIntervalSince1970: 1_800_000_000),
            checks: [
                ReadinessCheck(id: "qwen", group: .models, title: "Qwen", detail: "Ready", status: .ready)
            ]
        )
    }

    private static func makeResult(generatedAt: Date) -> DiagnosticsFileResult {
        let url = URL(fileURLWithPath: "/tmp/flowtype-diagnostics.txt")
        return DiagnosticsFileResult(
            latestURL: url,
            timestampedURL: url,
            generatedAt: generatedAt,
            text: "diagnostics",
            timestampedFileName: "flowtype-diagnostics-20270115-080000.txt"
        )
    }
}
