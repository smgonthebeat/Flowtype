import XCTest
@testable import VoiceInputApp

final class ReadinessSummaryTests: XCTestCase {
    private func presentation(_ phase: ReadinessPresentationPhase, tasks: [ReadinessTaskKind] = []) -> ReadinessPresentation {
        ReadinessPresentation(
            phase: phase,
            tasks: tasks.map { ReadinessTask(kind: $0, sourceCheckIDs: []) },
            primaryAction: nil,
            checkDetails: [],
            completedChecks: [],
            optionalChecks: [],
            technicalChecks: []
        )
    }

    func testReadyTellsTheUserHowToStart() {
        XCTAssertEqual(
            ReadinessSummary.make(for: presentation(.ready), language: .chinese),
            ReadinessSummary(tone: .ready, text: "已就绪 · 按住 Fn 说话")
        )
        XCTAssertEqual(
            ReadinessSummary.make(for: presentation(.ready), language: .english),
            ReadinessSummary(tone: .ready, text: "Ready · Hold Fn to talk")
        )
    }

    func testMissingPermissionNamesTheFirstTaskAndCountsTheRest() {
        let summary = ReadinessSummary.make(
            for: presentation(.needsSetup, tasks: [.grantAccessibility, .installSelectedModel]),
            language: .chinese
        )
        XCTAssertEqual(summary, ReadinessSummary(tone: .attention, text: "需要辅助功能权限（还有 1 项）"))
        XCTAssertEqual(
            ReadinessSummary.make(for: presentation(.needsSetup, tasks: [.grantMicrophone]), language: .english),
            ReadinessSummary(tone: .attention, text: "Microphone access needed")
        )
    }

    func testTasksWinOverAPreparingPhase() {
        // A missing permission blocks dictation even while the model is still loading.
        let summary = ReadinessSummary.make(
            for: presentation(.preparing, tasks: [.grantAccessibility]),
            language: .english
        )
        XCTAssertEqual(summary.tone, .attention)
    }

    func testCheckingAndPreparingAreNeutral() {
        XCTAssertEqual(ReadinessSummary.make(for: presentation(.checking), language: .chinese).tone, .working)
        XCTAssertEqual(
            ReadinessSummary.make(for: presentation(.preparing), language: .chinese),
            ReadinessSummary(tone: .working, text: "正在准备模型…")
        )
    }
}
