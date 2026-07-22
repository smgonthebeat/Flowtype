import XCTest
@testable import VoiceInputApp

final class PerformanceInspectorTests: XCTestCase {
    func testAppleChipMarketingNameIsPreferredOverGenericProcessorString() {
        let summary = HardwareSummary(
            machine: "Mac15,9",
            processor: "Apple M3 Max",
            physicalMemoryGB: 48,
            isAppleSilicon: true
        )

        XCTAssertEqual(summary.displayProcessorName, "Apple M3 Max")
    }

    func testAppleChipMarketingNameSupportsM1ThroughM5Variants() {
        let cases = [
            "Apple M1",
            "Apple M1 Pro",
            "Apple M2 Max",
            "Apple M3 Ultra",
            "Apple M4",
            "Apple M5 Pro"
        ]

        for chipName in cases {
            let summary = HardwareSummary(
                machine: "Mac15,9",
                processor: "\(chipName) (Virtual)",
                physicalMemoryGB: 48,
                isAppleSilicon: true
            )

            XCTAssertEqual(summary.displayProcessorName, chipName)
        }
    }

    func testAppleChipMarketingNameFallsBackToMachineWhenProcessorIsGeneric() {
        let summary = HardwareSummary(
            machine: "Mac14,7",
            processor: "8",
            physicalMemoryGB: 16,
            isAppleSilicon: true
        )

        XCTAssertEqual(summary.displayProcessorName, "Apple Silicon Mac14,7")
    }

    func testPerformanceCheckUsesDisplayProcessorName() {
        let inspector = PerformanceInspector(
            hardwareProvider: {
                HardwareSummary(
                    machine: "Mac14,7",
                    processor: "Apple M2",
                    physicalMemoryGB: 16,
                    isAppleSilicon: true
                )
            },
            processProvider: { [] },
            timingProvider: { nil }
        )

        let checks = inspector.inspectLightweight(selectedModel: .qwen3ASR06B)

        XCTAssertEqual(checks.check("apple-silicon")?.detail, "Apple M2 is supported.")
    }

    func testSystemProfilerChipNameParserReadsHardwareData() {
        let output = """
        Hardware:

            Hardware Overview:

              Model Name: MacBook Pro
              Model Identifier: Mac14,7
              Chip: Apple M2 Pro
              Total Number of Cores: 10
        """

        XCTAssertEqual(HardwareSummary.parseSystemProfilerChipName(output), "Apple M2 Pro")
    }

    func testSystemProfilerChipNameParserIgnoresEmptyChipValue() {
        let output = """
        Hardware:
          Chip:
          Memory: 16 GB
        """

        XCTAssertNil(HardwareSummary.parseSystemProfilerChipName(output))
    }

    func testSixteenGBMacWithLargeModelShowsAdvisoryNotRepair() {
        let inspector = PerformanceInspector(
            hardwareProvider: {
                HardwareSummary(machine: "Mac14,7", processor: "Apple M2", physicalMemoryGB: 16, isAppleSilicon: true)
            },
            processProvider: { [] },
            timingProvider: { nil }
        )

        let checks = inspector.inspect(selectedModel: .qwen3ASR17B)

        XCTAssertEqual(checks.check("memory-tier")?.status, .optional)
        XCTAssertNil(checks.check("memory-tier")?.primaryAction)
        XCTAssertTrue(checks.check("selected-model-recommendation")?.detail.contains("Qwen3-ASR 1.7B may be much slower") == true)
        XCTAssertTrue(checks.check("selected-model-recommendation")?.detail.contains("16 GB unified memory") == true)
        XCTAssertEqual(checks.check("selected-model-recommendation")?.status, .optional)
        XCTAssertNil(checks.check("selected-model-recommendation")?.primaryAction)
    }

    func testTwentyFourGBMacWithLargeModelShowsAdvisoryNotRepair() {
        let inspector = PerformanceInspector(
            hardwareProvider: {
                HardwareSummary(machine: "Mac14,7", processor: "Apple M2 Pro", physicalMemoryGB: 24, isAppleSilicon: true)
            },
            processProvider: { [] },
            timingProvider: { nil }
        )

        let checks = inspector.inspect(selectedModel: .qwen3ASR17B)

        XCTAssertEqual(checks.check("memory-tier")?.status, .optional)
        XCTAssertNil(checks.check("memory-tier")?.primaryAction)
        XCTAssertEqual(checks.check("selected-model-recommendation")?.status, .optional)
        XCTAssertNil(checks.check("selected-model-recommendation")?.primaryAction)
    }

    func testThirtyTwoGBMacWithLargeModelIsReadyPerformanceAdvice() {
        let inspector = PerformanceInspector(
            hardwareProvider: {
                HardwareSummary(machine: "Mac15,9", processor: "Apple M3 Pro", physicalMemoryGB: 32, isAppleSilicon: true)
            },
            processProvider: { [] },
            timingProvider: { nil }
        )

        let checks = inspector.inspect(selectedModel: .qwen3ASR17B)

        XCTAssertEqual(checks.check("memory-tier")?.status, .ready)
        XCTAssertEqual(checks.check("selected-model-recommendation")?.status, .ready)
    }

    func testUnsupportedArchitectureFailsAppleSiliconCheck() {
        let inspector = PerformanceInspector(
            hardwareProvider: {
                HardwareSummary(machine: "MacBookPro16,1", processor: "Intel Core i9", physicalMemoryGB: 32, isAppleSilicon: false)
            },
            processProvider: { [] },
            timingProvider: { nil }
        )

        let checks = inspector.inspect(selectedModel: .qwen3ASR06B)

        XCTAssertEqual(checks.check("apple-silicon")?.status, .failed("Unsupported architecture"))
    }

    func testLightweightInspectDoesNotSampleProcessesOrTiming() {
        var processProviderCallCount = 0
        var timingProviderCallCount = 0
        let inspector = PerformanceInspector(
            hardwareProvider: {
                HardwareSummary(machine: "Mac15,9", processor: "Apple M4 Max", physicalMemoryGB: 48, isAppleSilicon: true)
            },
            processProvider: {
                processProviderCallCount += 1
                XCTFail("inspectLightweight must not sample processes")
                return []
            },
            timingProvider: {
                timingProviderCallCount += 1
                XCTFail("inspectLightweight must not load timing samples")
                return nil
            }
        )

        let checks = inspector.inspectLightweight(selectedModel: .qwen3ASR06B)

        XCTAssertEqual(processProviderCallCount, 0)
        XCTAssertEqual(timingProviderCallCount, 0)
        XCTAssertEqual(checks.check("apple-silicon")?.status, .ready)
        XCTAssertEqual(checks.check("memory-tier")?.status, .ready)
        XCTAssertEqual(checks.check("selected-model-recommendation")?.status, .ready)
        XCTAssertNil(checks.check("helper-memory"))
        XCTAssertNil(checks.check("last-transcription-timing"))
    }

    func testProcessOutputCaptureDrainsOutputLargerThanPipeBuffer() throws {
        let output = try XCTUnwrap(
            ProcessOutputCapture.run(
                executableURL: URL(fileURLWithPath: "/usr/bin/jot"),
                arguments: ["25000"]
            )
        )

        XCTAssertTrue(output.hasPrefix("1\n2\n3\n"))
        XCTAssertTrue(output.hasSuffix("24999\n25000"))
    }

    func testHelperMemorySumsHelperAndUVProcessesOnly() {
        let inspector = PerformanceInspector(
            hardwareProvider: {
                HardwareSummary(machine: "Mac15,9", processor: "Apple M4 Max", physicalMemoryGB: 48, isAppleSilicon: true)
            },
            processProvider: {
                [
                    ProcessRSSSnapshot(command: "Flowtype", residentMemoryKB: 20_480),
                    ProcessRSSSnapshot(command: "uv run --project /tmp/qwen-asr-helper qwen-asr-helper", residentMemoryKB: 30_720),
                    ProcessRSSSnapshot(command: "/tmp/qwen-asr-helper/.venv/bin/qwen-asr-helper", residentMemoryKB: 40_960),
                    ProcessRSSSnapshot(command: "Safari qwen-asr-helper docs", residentMemoryKB: 999_999)
                ]
            },
            timingProvider: { nil }
        )

        let checks = inspector.inspect(selectedModel: .qwen3ASR06B)

        XCTAssertEqual(checks.check("helper-memory")?.detail, "Flowtype helper processes are using 70 MB RSS.")
        XCTAssertEqual(checks.check("helper-memory")?.status, .ready)
    }

    func testMissingHelperMemorySampleIsOptional() {
        let inspector = PerformanceInspector(
            hardwareProvider: {
                HardwareSummary(machine: "Mac15,9", processor: "Apple M4 Max", physicalMemoryGB: 48, isAppleSilicon: true)
            },
            processProvider: { [] },
            timingProvider: { nil }
        )

        let checks = inspector.inspect(selectedModel: .qwen3ASR06B)

        XCTAssertEqual(checks.check("helper-memory")?.status, .optional)
    }

    func testPSOutputParserKeepsOnlyFlowtypeHelperAndUVRunProcesses() {
        let output = """
         20480 /Applications/Flowtype.app/Contents/MacOS/Flowtype
         30720 uv run --project /tmp/qwen-asr-helper qwen-asr-helper
         32768 /opt/flowtype/uv run --project /tmp/qwen-asr-helper qwen-asr-helper
         40960 /tmp/qwen-asr-helper/.venv/bin/python3 /tmp/qwen-asr-helper/.venv/bin/qwen-asr-helper
         99999 Safari qwen-asr-helper docs
         88888 python3 -c print('/tmp/qwen-asr-helper/.venv/bin/qwen-asr-helper')
         invalid qwen-asr-helper
        """

        let snapshots = ProcessRSSSnapshot.parsePSOutput(output)

        XCTAssertEqual(
            snapshots,
            [
                ProcessRSSSnapshot(command: "/Applications/Flowtype.app/Contents/MacOS/Flowtype", residentMemoryKB: 20_480),
                ProcessRSSSnapshot(command: "uv run --project /tmp/qwen-asr-helper qwen-asr-helper", residentMemoryKB: 30_720),
                ProcessRSSSnapshot(command: "/opt/flowtype/uv run --project /tmp/qwen-asr-helper qwen-asr-helper", residentMemoryKB: 32_768),
                ProcessRSSSnapshot(command: "/tmp/qwen-asr-helper/.venv/bin/python3 /tmp/qwen-asr-helper/.venv/bin/qwen-asr-helper", residentMemoryKB: 40_960)
            ]
        )
    }

    func testPSOutputParserIgnoresUVRunCommandsThatDoNotLaunchHelper() {
        let output = """
         11111 uv run --project /tmp/qwen-asr-helper pytest
         22222 /opt/flowtype/uv run --project /tmp/qwen-asr-helper pytest
         33333 uv run python -c "print('/tmp/qwen-asr-helper')"
         44444 /opt/flowtype/uv run python -c "print('/tmp/qwen-asr-helper')"
         55555 uv run --project /tmp/qwen-asr-helper qwen-asr-helper
        """

        let snapshots = ProcessRSSSnapshot.parsePSOutput(output)

        XCTAssertEqual(
            snapshots,
            [
                ProcessRSSSnapshot(command: "uv run --project /tmp/qwen-asr-helper qwen-asr-helper", residentMemoryKB: 55_555)
            ]
        )
    }

    func testTimingSampleIsShownWhenAvailable() {
        let sample = TranscriptionTimingSample(
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            modelID: "Qwen/Qwen3-ASR-0.6B",
            strategy: "full",
            recordingDurationSeconds: 1.2,
            helperStartMilliseconds: 20,
            modelPreparationMilliseconds: 30,
            decodeMilliseconds: 400,
            postProcessingMilliseconds: 10,
            totalMilliseconds: 460
        )
        let inspector = PerformanceInspector(
            hardwareProvider: {
                HardwareSummary(machine: "Mac15,9", processor: "Apple M4 Max", physicalMemoryGB: 48, isAppleSilicon: true)
            },
            processProvider: { [] },
            timingProvider: { sample }
        )

        let checks = inspector.inspect(selectedModel: .qwen3ASR06B)

        XCTAssertEqual(checks.check("last-transcription-timing")?.status, .ready)
        XCTAssertTrue(checks.check("last-transcription-timing")?.detail.contains("helper 20 ms") == true)
        XCTAssertTrue(checks.check("last-transcription-timing")?.detail.contains("status probe 30 ms") == true)
        XCTAssertTrue(checks.check("last-transcription-timing")?.detail.contains("decode 400 ms") == true)
        XCTAssertTrue(checks.check("last-transcription-timing")?.detail.contains("post 10 ms") == true)
    }

    func testNoTimingSampleIsOptional() {
        let inspector = PerformanceInspector(
            hardwareProvider: {
                HardwareSummary(machine: "Mac15,9", processor: "Apple M4 Max", physicalMemoryGB: 48, isAppleSilicon: true)
            },
            processProvider: { [] },
            timingProvider: { nil }
        )

        let checks = inspector.inspect(selectedModel: .qwen3ASR06B)

        XCTAssertEqual(checks.check("last-transcription-timing")?.status, .optional)
    }
}

private extension Array where Element == ReadinessCheck {
    func check(_ id: String) -> ReadinessCheck? {
        first { $0.id == id }
    }
}
