import Foundation

struct HardwareSummary: Equatable {
    let machine: String
    let processor: String
    let physicalMemoryGB: Int
    let isAppleSilicon: Bool

    var displayProcessorName: String {
        let trimmedProcessor = processor.trimmingCharacters(in: .whitespacesAndNewlines)
        if let chipName = Self.appleChipMarketingName(in: trimmedProcessor) {
            return chipName
        }
        if isAppleSilicon {
            let trimmedMachine = machine.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmedMachine.isEmpty ? "Apple Silicon Mac" : "Apple Silicon \(trimmedMachine)"
        }
        return trimmedProcessor.isEmpty ? machine : trimmedProcessor
    }

    private static func appleChipMarketingName(in text: String) -> String? {
        let pattern = #"Apple M[1-5](?:\s+(?:Pro|Max|Ultra))?"#
        guard let range = text.range(of: pattern, options: .regularExpression) else {
            return nil
        }
        return String(text[range])
    }
}

struct ProcessRSSSnapshot: Equatable {
    let command: String
    let residentMemoryKB: Int
}

enum ProcessOutputCapture {
    static func run(executableURL: URL, arguments: [String]) -> String? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = executableURL
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            // Drain stdout while the child is running. Waiting first can deadlock
            // when the child fills the pipe buffer before it can exit.
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                return nil
            }
            let value = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return value?.isEmpty == false ? value : nil
        } catch {
            return nil
        }
    }
}

struct PerformanceInspector {
    var hardwareProvider: () -> HardwareSummary = HardwareSummary.current
    var processProvider: () -> [ProcessRSSSnapshot] = ProcessRSSSnapshot.flowtypeRelatedProcesses
    var timingProvider: () -> TranscriptionTimingSample? = {
        try? TranscriptionTimingStore().loadLastSample()
    }
    var suitabilityPolicy = ModelSuitabilityPolicy()

    func inspectLightweight(selectedModel: VoiceInputModel) -> [ReadinessCheck] {
        let hardware = hardwareProvider()

        return [
            architectureCheck(hardware),
            memoryTierCheck(hardware, selectedModel: selectedModel),
            selectedModelRecommendation(hardware, selectedModel: selectedModel)
        ]
    }

    func inspect(selectedModel: VoiceInputModel) -> [ReadinessCheck] {
        let hardware = hardwareProvider()
        let processes = processProvider()
        let timing = timingProvider()

        return [
            architectureCheck(hardware),
            memoryTierCheck(hardware, selectedModel: selectedModel),
            selectedModelRecommendation(hardware, selectedModel: selectedModel),
            processMemoryCheck(processes),
            timingCheck(timing)
        ]
    }

    private func architectureCheck(_ hardware: HardwareSummary) -> ReadinessCheck {
        ReadinessCheck(
            id: "apple-silicon",
            group: .performance,
            title: "Apple Silicon",
            detail: hardware.isAppleSilicon ? "\(hardware.displayProcessorName) is supported." : "Flowtype local Qwen is designed for Apple Silicon.",
            status: hardware.isAppleSilicon ? .ready : .failed("Unsupported architecture")
        )
    }

    private func memoryTierCheck(_ hardware: HardwareSummary, selectedModel: VoiceInputModel) -> ReadinessCheck {
        let recommendation = suitabilityPolicy.recommendation(hardware: hardware, model: selectedModel)
        let warnsForLargeModel = recommendation.level == .stronglyDiscouraged || recommendation.level == .allowedWithWarning
        return ReadinessCheck(
            id: "memory-tier",
            group: .performance,
            title: "Memory tier",
            detail: "\(hardware.physicalMemoryGB) GB unified memory detected.",
            status: warnsForLargeModel ? .optional : .ready
        )
    }

    private func selectedModelRecommendation(_ hardware: HardwareSummary, selectedModel: VoiceInputModel) -> ReadinessCheck {
        let recommendation = suitabilityPolicy.recommendation(hardware: hardware, model: selectedModel)
        if recommendation.level == .stronglyDiscouraged || recommendation.level == .allowedWithWarning {
            return ReadinessCheck(
                id: "selected-model-recommendation",
                group: .performance,
                title: "Model recommendation",
                detail: recommendation.detail,
                status: .optional,
                modelSuitabilityRecommendation: recommendation
            )
        }

        return ReadinessCheck(
            id: "selected-model-recommendation",
            group: .performance,
            title: "Model recommendation",
            detail: "\(selectedModel.displayName) matches this Mac's memory tier.",
            status: .ready,
            modelSuitabilityRecommendation: recommendation
        )
    }

    private func processMemoryCheck(_ processes: [ProcessRSSSnapshot]) -> ReadinessCheck {
        let helperMemory = processes
            .filter { ProcessRSSSnapshot.isHelperOrUVRunProcess(command: $0.command) }
            .map(\.residentMemoryKB)
            .reduce(0, +)

        return ReadinessCheck(
            id: "helper-memory",
            group: .performance,
            title: "Helper memory",
            detail: helperMemory > 0 ? "Flowtype helper processes are using \(helperMemory / 1024) MB RSS." : "No helper memory sample is available yet.",
            status: helperMemory > 0 ? .ready : .optional
        )
    }

    private func timingCheck(_ timing: TranscriptionTimingSample?) -> ReadinessCheck {
        guard let timing else {
            return ReadinessCheck(
                id: "last-transcription-timing",
                group: .performance,
                title: "Last transcription timing",
                detail: "No local Qwen timing sample has been recorded yet.",
                status: .optional
            )
        }

        return ReadinessCheck(
            id: "last-transcription-timing",
            group: .performance,
            title: "Last transcription timing",
            detail: "Last run: helper \(timing.helperStartMilliseconds) ms, status probe \(timing.modelPreparationMilliseconds) ms, decode \(timing.decodeMilliseconds) ms, post \(timing.postProcessingMilliseconds) ms.",
            status: .ready
        )
    }
}

extension HardwareSummary {
    static func current() -> HardwareSummary {
        let machine = systemValue(["/usr/sbin/sysctl", "-n", "hw.model"]) ?? "Unknown Mac"
        let isAppleSilicon = machineHardwareName == "arm64"
        let cheapProcessor = systemValue(["/usr/sbin/sysctl", "-n", "machdep.cpu.brand_string"])
        let processor = processorName(
            cheapProcessor: cheapProcessor,
            machine: machine,
            isAppleSilicon: isAppleSilicon
        )

        return HardwareSummary(
            machine: machine,
            processor: processor,
            physicalMemoryGB: max(1, Int((Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824).rounded())),
            isAppleSilicon: isAppleSilicon
        )
    }

    private static func processorName(cheapProcessor: String?, machine: String, isAppleSilicon: Bool) -> String {
        if let cheapProcessor,
           shouldUseCheapProcessorName(cheapProcessor, isAppleSilicon: isAppleSilicon) {
            return cheapProcessor
        }
        if isAppleSilicon, let chipName = systemProfilerChipName() {
            return chipName
        }
        return cheapProcessor ?? ProcessInfo.processInfo.processorCount.description
    }

    private static func shouldUseCheapProcessorName(_ processor: String, isAppleSilicon: Bool) -> Bool {
        let trimmed = processor.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return false
        }
        if HardwareSummary.appleChipMarketingName(in: trimmed) != nil {
            return true
        }
        return !isAppleSilicon
    }

    static func parseSystemProfilerChipName(_ output: String) -> String? {
        for line in output.split(separator: "\n") {
            let text = String(line).trimmingCharacters(in: .whitespaces)
            if text.hasPrefix("Chip:") {
                let value = text
                    .replacingOccurrences(of: "Chip:", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return value.isEmpty ? nil : value
            }
        }
        return nil
    }

    private static func systemProfilerChipName() -> String? {
        guard let output = systemValue(["/usr/sbin/system_profiler", "SPHardwareDataType"]) else {
            return nil
        }
        return parseSystemProfilerChipName(output)
    }

    private static var machineHardwareName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? ""
            }
        }
    }

    private static func systemValue(_ command: [String]) -> String? {
        guard let executable = command.first else { return nil }
        return ProcessOutputCapture.run(
            executableURL: URL(fileURLWithPath: executable),
            arguments: Array(command.dropFirst())
        )
    }
}

extension ProcessRSSSnapshot {
    static func flowtypeRelatedProcesses() -> [ProcessRSSSnapshot] {
        guard let output = ProcessOutputCapture.run(
            executableURL: URL(fileURLWithPath: "/bin/ps"),
            arguments: ["-axo", "rss=,command="]
        ) else {
            return []
        }
        return parsePSOutput(output)
    }

    static func parsePSOutput(_ output: String) -> [ProcessRSSSnapshot] {
        output.split(separator: "\n").compactMap { line in
            let text = String(line).trimmingCharacters(in: .whitespaces)
            guard let firstSpace = text.firstIndex(where: \.isWhitespace) else {
                return nil
            }
            let rssText = text[..<firstSpace]
            let command = text[firstSpace...].trimmingCharacters(in: .whitespaces)
            guard let rss = Int(rssText), isFlowtypeRelatedProcess(command: command) else {
                return nil
            }
            return ProcessRSSSnapshot(command: command, residentMemoryKB: rss)
        }
    }

    static func isHelperOrUVRunProcess(command: String) -> Bool {
        if executableName(command) == "uv" {
            return isUVRunProcess(command: command)
        }
        return isQwenHelperProcess(command: command)
    }

    private static func isFlowtypeRelatedProcess(command: String) -> Bool {
        executableName(command) == "Flowtype" || isHelperOrUVRunProcess(command: command)
    }

    private static func isQwenHelperProcess(command: String) -> Bool {
        let tokens = command.split(whereSeparator: \.isWhitespace).map(String.init)
        if tokens.first.map({ URL(fileURLWithPath: $0).lastPathComponent == "qwen-asr-helper" }) == true {
            return true
        }
        return tokens.dropFirst().contains { token in
            token.contains("/") && URL(fileURLWithPath: token).lastPathComponent == "qwen-asr-helper"
        }
    }

    private static func isUVRunProcess(command: String) -> Bool {
        let tokens = command.split(whereSeparator: \.isWhitespace).map(String.init)
        guard executableName(command) == "uv",
              let runIndex = tokens.firstIndex(of: "run") else {
            return false
        }

        var index = tokens.index(after: runIndex)
        while index < tokens.endIndex {
            let token = tokens[index]
            if token == "--project" || token == "--directory" || token == "--env-file" {
                index = tokens.index(index, offsetBy: 2, limitedBy: tokens.endIndex) ?? tokens.endIndex
                continue
            }
            if token.hasPrefix("--project=") || token.hasPrefix("--directory=") || token.hasPrefix("--env-file=") {
                index = tokens.index(after: index)
                continue
            }
            if token.hasPrefix("-") {
                index = tokens.index(after: index)
                continue
            }
            return URL(fileURLWithPath: token).lastPathComponent == "qwen-asr-helper"
        }
        return false
    }

    private static func executableName(_ command: String) -> String {
        guard let executable = command.split(whereSeparator: \.isWhitespace).first else {
            return ""
        }
        return URL(fileURLWithPath: String(executable)).lastPathComponent
    }
}
