import Combine
import Foundation

enum ReadinessDiagnosticsGenerationOutcome: Equatable {
    case generated(DiagnosticsFileResult)
    case failed(String)
    case alreadyRunning
    case cancelled
}

@MainActor
final class ReadinessDiagnosticsActionRunner: ObservableObject {
    @Published private(set) var isGeneratingFile = false
    @Published private(set) var generatedResult: DiagnosticsFileResult?
    @Published private(set) var errorMessage: String?

    func resetFeedback() {
        generatedResult = nil
        errorMessage = nil
    }

    func generateFile(
        report: ReadinessReport,
        action: @escaping (ReadinessReport) async throws -> DiagnosticsFileResult
    ) async -> ReadinessDiagnosticsGenerationOutcome {
        AppLogger.diagnostics.info("diagnostics_ui_generate_clicked")

        guard !isGeneratingFile else {
            AppLogger.diagnostics.info("diagnostics_ui_generate_ignored reason=already_running")
            return .alreadyRunning
        }

        isGeneratingFile = true
        generatedResult = nil
        errorMessage = nil
        AppLogger.diagnostics.info("diagnostics_ui_generate_task_started")

        defer {
            isGeneratingFile = false
        }

        do {
            let result = try await action(report)
            guard !Task.isCancelled else {
                AppLogger.diagnostics.info("diagnostics_ui_generate_cancelled")
                return .cancelled
            }
            generatedResult = result
            AppLogger.diagnostics.info("diagnostics_ui_generate_succeeded file=\(result.timestampedFileName, privacy: .public)")
            return .generated(result)
        } catch is CancellationError {
            AppLogger.diagnostics.info("diagnostics_ui_generate_cancelled")
            return .cancelled
        } catch {
            let message = error.localizedDescription
            errorMessage = message
            AppLogger.diagnostics.error("diagnostics_ui_generate_failed error=\(message, privacy: .private)")
            return .failed(message)
        }
    }
}
