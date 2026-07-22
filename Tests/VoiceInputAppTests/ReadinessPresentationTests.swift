import XCTest
@testable import VoiceInputApp

final class ReadinessPresentationTests: XCTestCase {
    func testLightweightSnapshotCannotClaimReady() {
        let presentation = ReadinessPresentationPolicy.presentation(for: snapshot(
            coverage: .lightweight,
            checks: readyQwenChecks()
        ))

        XCTAssertEqual(presentation.phase, .checking)
        XCTAssertTrue(presentation.tasks.isEmpty)
    }

    func testQwenIgnoresSpeechRecognitionPermission() {
        var checks = readyQwenChecks()
        checks.append(check(id: "speech-recognition-permission", group: .permissions, status: .notReady))

        let presentation = ReadinessPresentationPolicy.presentation(for: snapshot(checks: checks))

        XCTAssertEqual(presentation.phase, .ready)
        XCTAssertFalse(presentation.tasks.contains { $0.kind == .grantSpeechRecognition })
    }

    func testAppleSpeechIgnoresQwenRuntimeAndModels() {
        let checks = [
            check(id: "microphone-permission", group: .permissions, status: .ready),
            check(id: "accessibility-permission", group: .permissions, status: .ready),
            check(id: "speech-recognition-permission", group: .permissions, status: .ready),
            check(id: "local-helper-copy", group: .localRuntime, status: .needsRepair),
            check(id: "model-qwen3-asr-0.6b", group: .models, status: .notReady)
        ]

        let presentation = ReadinessPresentationPolicy.presentation(for: snapshot(
            engine: .appleSpeech,
            checks: checks
        ))

        XCTAssertEqual(presentation.phase, .ready)
        XCTAssertTrue(presentation.tasks.isEmpty)
    }

    func testAppleSpeechRequiresSpeechRecognitionPermission() {
        let checks = [
            check(id: "microphone-permission", group: .permissions, status: .ready),
            check(id: "accessibility-permission", group: .permissions, status: .ready),
            check(id: "speech-recognition-permission", group: .permissions, status: .notReady)
        ]

        let presentation = ReadinessPresentationPolicy.presentation(for: snapshot(
            engine: .appleSpeech,
            checks: checks
        ))

        XCTAssertEqual(presentation.phase, .needsSetup)
        XCTAssertEqual(presentation.tasks.map(\.kind), [.grantSpeechRecognition])
    }

    func testMultipleBundleFailuresBecomeOneReinstallTask() {
        var checks = readyQwenChecks()
        checks.append(check(id: "bundled-uv", group: .appBundle, status: .failed("missing")))
        checks.append(check(id: "bundled-helper", group: .appBundle, status: .needsRepair))

        let presentation = ReadinessPresentationPolicy.presentation(for: snapshot(checks: checks))

        XCTAssertEqual(presentation.phase, .repairRequired)
        XCTAssertEqual(presentation.tasks.filter { $0.kind == .reinstallApplication }.count, 1)
        XCTAssertEqual(
            Set(presentation.tasks.first { $0.kind == .reinstallApplication }?.sourceCheckIDs ?? []),
            ["bundled-uv", "bundled-helper"]
        )
        XCTAssertEqual(presentation.primaryAction, .reinstallFlowtypeApp)
    }

    func testMissingMicrophoneAndAccessibilityRemainDistinctTasks() {
        var checks = readyQwenChecks().filter {
            $0.id != "microphone-permission" && $0.id != "accessibility-permission"
        }
        checks.append(check(id: "microphone-permission", group: .permissions, status: .notReady))
        checks.append(check(id: "accessibility-permission", group: .permissions, status: .notReady))

        let presentation = ReadinessPresentationPolicy.presentation(for: snapshot(checks: checks))

        XCTAssertEqual(presentation.phase, .needsSetup)
        XCTAssertEqual(presentation.tasks.map(\.kind), [.grantMicrophone, .grantAccessibility])
    }

    func testUnknownSelectedModelStateIsCheckingNotRepair() {
        let checks = readyQwenChecks().map { item -> ReadinessCheck in
            guard item.id == "model-qwen3-asr-0.6b-warm" else { return item }
            return check(id: item.id, group: .models, status: .unknown)
        }

        let presentation = ReadinessPresentationPolicy.presentation(for: snapshot(checks: checks))

        XCTAssertEqual(presentation.phase, .checking)
        XCTAssertFalse(presentation.tasks.contains { $0.kind == .prepareSelectedModel })
    }

    func testMissingOrUnknownInfrastructureEvidenceIsCheckingNotRepair() {
        let missingRuntime = readyQwenChecks().filter { $0.group != .localRuntime }
        let missingPresentation = ReadinessPresentationPolicy.presentation(for: snapshot(checks: missingRuntime))

        var unknownRuntime = readyQwenChecks().filter { $0.group != .localRuntime }
        unknownRuntime.append(check(id: "runtime", group: .localRuntime, status: .unknown))
        let unknownPresentation = ReadinessPresentationPolicy.presentation(for: snapshot(checks: unknownRuntime))

        XCTAssertEqual(missingPresentation.phase, .checking)
        XCTAssertEqual(unknownPresentation.phase, .checking)
        XCTAssertFalse(unknownPresentation.tasks.contains { $0.kind == .repairLocalRuntime })
    }

    func testPerformanceAdvisoryNeverAddsSetupTask() {
        var checks = readyQwenChecks()
        checks.append(check(id: "memory-tier", group: .performance, status: .needsRepair))

        let presentation = ReadinessPresentationPolicy.presentation(for: snapshot(checks: checks))

        XCTAssertEqual(presentation.phase, .ready)
        XCTAssertTrue(presentation.tasks.isEmpty)
    }

    private func snapshot(
        engine: TranscriptionEngineKind = .qwenLocal,
        coverage: ReadinessCoverage = .live,
        checks: [ReadinessCheck]
    ) -> ReadinessSnapshot {
        ReadinessSnapshot(
            report: ReadinessReport(generatedAt: Date(), checks: checks),
            context: ReadinessContext(engine: engine, selectedModelID: VoiceInputModel.qwen3ASR06B.id),
            coverage: coverage
        )
    }

    private func readyQwenChecks() -> [ReadinessCheck] {
        [
            check(id: "app", group: .appBundle, status: .ready),
            check(id: "runtime", group: .localRuntime, status: .ready),
            check(id: "microphone-permission", group: .permissions, status: .ready),
            check(id: "accessibility-permission", group: .permissions, status: .ready),
            check(id: "model-qwen3-asr-0.6b", group: .models, status: .ready),
            check(id: "model-qwen3-asr-0.6b-warm", group: .models, status: .ready)
        ]
    }

    private func check(
        id: String,
        group: ReadinessGroup,
        status: ReadinessStatus
    ) -> ReadinessCheck {
        ReadinessCheck(id: id, group: group, title: id, detail: id, status: status)
    }
}
