import Foundation

enum PermissionState: Equatable {
    case unknown
    case granted
    case denied
    case notDetermined
}

struct PermissionSnapshot: Equatable {
    var microphone: PermissionState
    var accessibility: PermissionState
    var speechRecognition: PermissionState

    var canRecordWithQwen: Bool {
        microphone == .granted && accessibility == .granted
    }
}
