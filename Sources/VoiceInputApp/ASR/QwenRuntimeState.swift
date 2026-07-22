import Foundation

enum QwenRuntimeState: String, Codable, Equatable {
    case unavailable
    case notInstalled
    case preparing
    case loading
    case ready
    case busy
    case transcribing
    case failedRecoverable
    case failedFatal
}
