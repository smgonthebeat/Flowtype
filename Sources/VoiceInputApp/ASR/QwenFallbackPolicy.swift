import Foundation

enum QwenFailureKind: String, Codable, Equatable {
    case modelNotInstalled
    case helperRuntimeMissing
    case helperRuntimeDamaged
    case helperStartFailed
    case modelLoading
    case helperBusy
    case modelLoadTimedOut
    case helperBusyTimedOut
    case transcriptionTimedOut
    case transcriptionFailed
    case contextLeakDetected
    case emptyAudio
    case permissionMissing
    case cancelled
}

struct QwenReadinessError: Error, Equatable {
    let kind: QwenFailureKind
}

struct QwenFallbackPolicy {
    func shouldFallback(for kind: QwenFailureKind) -> Bool {
        switch kind {
        case .helperRuntimeMissing,
             .helperRuntimeDamaged,
             .helperStartFailed,
             .modelLoadTimedOut,
             .helperBusyTimedOut,
             .transcriptionTimedOut,
             .transcriptionFailed,
             .contextLeakDetected:
            return true
        case .modelNotInstalled,
             .modelLoading,
             .helperBusy,
             .emptyAudio,
             .permissionMissing,
             .cancelled:
            return false
        }
    }

    func classify(_ error: any Error) -> QwenFailureKind {
        if error is CancellationError {
            return .cancelled
        }

        if let readinessError = error as? QwenReadinessError {
            return readinessError.kind
        }

        if let helperError = error as? HelperProcessError {
            switch helperError {
            case .helperDirectoryNotFound,
                 .bundledUVUnavailable:
                return .helperRuntimeMissing
            case .helperManifestInvalid:
                return .helperRuntimeDamaged
            case .portUnavailable,
                 .processExited,
                 .timedOutWaitingForHealth:
                return .helperStartFailed
            }
        }

        if let transcriptionError = error as? TranscriptionError {
            switch transcriptionError {
            case .unavailable:
                return .transcriptionFailed
            case .emptyResult:
                return .emptyAudio
            case .timedOut:
                return .transcriptionTimedOut
            case .contextLeakDetected:
                return .contextLeakDetected
            }
        }

        if let helperError = error as? QwenHelperClientError {
            switch helperError {
            case .invalidResponse:
                return .transcriptionFailed
            case .httpStatus(let status, let message):
                return classifyHTTPStatus(status, message: message)
            }
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                return .transcriptionTimedOut
            case .cancelled:
                return .cancelled
            default:
                break
            }
        }

        return .transcriptionFailed
    }

    private func classifyHTTPStatus(_ status: Int, message: String?) -> QwenFailureKind {
        let lowered = (message ?? "").lowercased()
        if lowered.contains("not installed") || lowered.contains("missing model") {
            return .modelNotInstalled
        }
        if lowered.contains("busy") {
            return .helperBusy
        }
        if status == 409 || lowered.contains("loading") {
            return .modelLoading
        }
        return .transcriptionFailed
    }
}
