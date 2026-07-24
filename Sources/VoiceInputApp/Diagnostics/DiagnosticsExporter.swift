import Foundation

struct DiagnosticsExporter {
    var appVersionProvider: () -> String = {
        let dictionary = Bundle.main.infoDictionary
        let version = dictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = dictionary?["CFBundleVersion"] as? String ?? "unknown"
        return "\(version) (\(build))"
    }
    var macOSVersionProvider: () -> String = {
        ProcessInfo.processInfo.operatingSystemVersionString
    }
    var hardwareProvider: () -> HardwareSummary = HardwareSummary.current

    func makeDiagnosticsText(
        report: ReadinessReport,
        timing: TranscriptionTimingSample?,
        processes: [ProcessRSSSnapshot],
        provenance: TranscriptionProvenance? = nil
    ) -> String {
        let hardware = hardwareProvider()
        var lines: [String] = [
            "Flowtype Diagnostics",
            "Generated: \(ISO8601DateFormatter().string(from: report.generatedAt))",
            "App: \(sanitize(appVersionProvider()))",
            "macOS: \(sanitize(macOSVersionProvider()))",
            "Hardware: \(sanitize(hardware.machine)), \(sanitize(hardware.processor)), \(hardware.physicalMemoryGB) GB",
            "",
            "Readiness:"
        ]

        for check in report.checks {
            let status = check.status.badgeText
            lines.append("- [\(check.group.rawValue)] \(sanitize(check.title)): \(status) - \(sanitize(check.detail))")
            if let message = check.statusMessage {
                lines.append("  message: \(sanitize(message))")
            }
        }

        lines.append("")
        lines.append("Processes:")
        if processes.isEmpty {
            lines.append("- no Flowtype/helper process sample")
        } else {
            for process in processes {
                lines.append("- \(process.residentMemoryKB) KB RSS: \(processLabel(for: process.command))")
            }
        }

        appendTimingSection(to: &lines, timing: timing)
        appendLatestTranscriptionSection(to: &lines, provenance: provenance)

        return lines.joined(separator: "\n")
    }

    func makeTimeoutFallbackText(
        report: ReadinessReport,
        generatedAt: Date,
        timing: TranscriptionTimingSample?,
        provenance: TranscriptionProvenance?
    ) -> String {
        let summary = report.setupSummary
        var lines: [String] = [
            "Flowtype Diagnostics",
            "Generated: \(ISO8601DateFormatter().string(from: generatedAt))",
            "",
            "Diagnostics detail collection timed out.",
            "",
            "Readiness Summary:",
            "- required_setup_items: \(summary.requiredIssueCount)",
            "- readiness_checks: \(report.checks.count)"
        ]

        appendTimingSection(to: &lines, timing: timing)
        appendLatestTranscriptionSection(to: &lines, provenance: provenance)

        return lines.joined(separator: "\n")
    }

    private func appendTimingSection(to lines: inout [String], timing: TranscriptionTimingSample?) {
        lines.append("")
        lines.append("Last Timing:")
        if let timing {
            lines.append("- created_at: \(ISO8601DateFormatter().string(from: timing.createdAt))")
            lines.append("- model: \(sanitize(timing.modelID))")
            lines.append("- requested_strategy: \(sanitize(timing.requestedStrategy))")
            lines.append("- effective_strategy: \(sanitize(timing.effectiveStrategy))")
            if let duration = timing.recordingDurationSeconds {
                lines.append("- recording_seconds: \(duration)")
            }
            lines.append("- helper_ms: \(timing.helperStartMilliseconds)")
            lines.append("- status_probe_ms: \(timing.modelPreparationMilliseconds)")
            lines.append("- decode_ms: \(timing.decodeMilliseconds)")
            lines.append("- post_ms: \(timing.postProcessingMilliseconds)")
            lines.append("- total_ms: \(timing.totalMilliseconds)")
        } else {
            lines.append("- no timing sample")
        }
    }

    private func appendLatestTranscriptionSection(
        to lines: inout [String],
        provenance: TranscriptionProvenance?
    ) {
        lines.append("")
        lines.append("Latest Transcription:")
        if let provenance {
            lines.append("- recording_id: \(provenance.recordingID.uuidString)")
            lines.append("- selected_engine: \(provenance.selectedEngine.rawValue)")
            lines.append("- winner_engine: \(provenance.winnerEngine?.rawValue ?? "none")")
            if let selectedModelID = provenance.selectedModelID {
                lines.append("- selected_model: \(sanitize(selectedModelID))")
            }
            if let requestedModelID = provenance.requestedModelID {
                lines.append("- requested_model: \(sanitize(requestedModelID))")
            }
            if let requestedStrategy = provenance.requestedStrategy {
                lines.append("- requested_strategy: \(sanitize(requestedStrategy))")
            }
            if let effectiveStrategy = provenance.effectiveStrategy {
                lines.append("- effective_strategy: \(sanitize(effectiveStrategy))")
            }
            if let fallbackReason = provenance.fallbackReason ?? provenance.appleFallbackReason {
                lines.append("- fallback_reason: \(sanitize(fallbackReason))")
            }
            if let qwenErrorKind = provenance.qwenErrorKind {
                lines.append("- qwen_error_kind: \(sanitize(qwenErrorKind))")
            }
            if let contextEchoRecovery = provenance.contextEchoRecovery {
                lines.append("- context_echo_recovery: \(sanitize(contextEchoRecovery))")
            }
            if let sessionStateAtCompletion = provenance.sessionStateAtCompletion {
                lines.append("- session_state_at_completion: \(sanitize(sessionStateAtCompletion))")
            }
            if let commitOutcome = provenance.commitOutcome {
                lines.append("- commit_outcome: \(sanitize(commitOutcome))")
            }
            if let ignoredInputReason = provenance.ignoredInputReason {
                lines.append("- ignored_input_reason: \(sanitize(ignoredInputReason))")
            }
        } else {
            lines.append("- no transcription provenance")
        }
    }

    private func sanitize(_ text: String) -> String {
        redactSecrets(text)
            .replacingOccurrences(
                of: #"/Users/[^/\s,;:]+"#,
                with: "~",
                options: .regularExpression
            )
    }

    private func redactSecrets(_ text: String) -> String {
        text
            .replacingOccurrences(
                of: #"VOICEINPUT_HELPER_TOKEN=[^\s,;]+"#,
                with: "VOICEINPUT_HELPER_TOKEN=<redacted>",
                options: [.regularExpression, .caseInsensitive]
            )
            .replacingOccurrences(
                of: #"X-VoiceInput-Token\s*[:=]\s*[^\s,;]+"#,
                with: "X-VoiceInput-Token=<redacted>",
                options: [.regularExpression, .caseInsensitive]
            )
            .replacingOccurrences(
                of: #"(?i)(--?token|api[_-]?token|hf[_-]?token|access-token)(\s*=\s*)[^\s,;]+"#,
                with: "$1$2<redacted>",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"(?i)(--?token|access-token)(\s+)[^\s,;]+"#,
                with: "$1$2<redacted>",
                options: .regularExpression
            )
    }

    private func processLabel(for command: String) -> String {
        let lowered = command.lowercased()
        if lowered.contains("qwen-asr-helper") {
            return "qwen-asr-helper"
        }
        if lowered.contains("flowtype") {
            return "Flowtype"
        }

        let redacted = sanitize(command)
        let firstToken = redacted.split(separator: " ").first.map(String.init) ?? "unknown process"
        return URL(fileURLWithPath: firstToken).lastPathComponent
    }
}
