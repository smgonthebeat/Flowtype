import XCTest
@testable import VoiceInputApp

final class HomeReadinessPresentationTests: XCTestCase {
    func testHomeMapsSharedPresentationPhasesWithoutReadingRawChecks() {
        XCTAssertEqual(home(.checking), .checking)
        XCTAssertEqual(home(.ready), .ready)
        XCTAssertEqual(home(.needsSetup, taskCount: 2), .needsSetup(2))
        XCTAssertEqual(home(.preparing), .preparing)
        XCTAssertEqual(home(.repairRequired, taskCount: 1), .repairRequired(1))
    }

    func testOnlyActionableStatesUseProminentHomeCard() {
        XCTAssertFalse(HomeReadinessPresentation.checking.showsProminentCard)
        XCTAssertFalse(HomeReadinessPresentation.ready.showsProminentCard)
        XCTAssertFalse(HomeReadinessPresentation.preparing.showsProminentCard)
        XCTAssertTrue(HomeReadinessPresentation.needsSetup(1).showsProminentCard)
        XCTAssertTrue(HomeReadinessPresentation.repairRequired(1).showsProminentCard)
    }

    // Owner decision (2026-10-03): no inline "ready" line; only preparation shows one, and the
    // brief launch check shows nothing so the header does not appear and then vanish.
    func testOnlyPreparationShowsAnInlineHeaderLine() {
        XCTAssertTrue(HomeReadinessPresentation.preparing.showsInlineStatus)
        XCTAssertFalse(HomeReadinessPresentation.ready.showsInlineStatus)
        XCTAssertFalse(HomeReadinessPresentation.checking.showsInlineStatus)
        XCTAssertFalse(HomeReadinessPresentation.needsSetup(1).showsInlineStatus)
        XCTAssertFalse(HomeReadinessPresentation.repairRequired(1).showsInlineStatus)
    }

    private func home(
        _ phase: ReadinessPresentationPhase,
        taskCount: Int = 0
    ) -> HomeReadinessPresentation {
        let tasks = (0..<taskCount).map { index in
            ReadinessTask(
                kind: index == 0 ? .grantMicrophone : .grantAccessibility,
                sourceCheckIDs: ["task-\(index)"]
            )
        }
        let presentation = ReadinessPresentation(
            phase: phase,
            tasks: tasks,
            primaryAction: tasks.isEmpty ? nil : .prepareFlowtype,
            checkDetails: [],
            completedChecks: [],
            optionalChecks: [],
            technicalChecks: []
        )
        return HomeReadinessPresentation.presentation(for: presentation)
    }
}
