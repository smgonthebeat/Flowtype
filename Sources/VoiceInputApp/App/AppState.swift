import Foundation
import Combine

enum RecordingState: Equatable {
    case idle
    case preparingModel
    case downloadingModel(progress: Double)
    case listening
    case transcribing
    case pasting
    case error(String)
}

@MainActor
final class AppState: ObservableObject {
    @Published var recordingState: RecordingState = .idle
    @Published var statusText: String = "Ready"
    @Published var partialTranscript: String = ""

    func resetTranscript() {
        partialTranscript = ""
    }
}
