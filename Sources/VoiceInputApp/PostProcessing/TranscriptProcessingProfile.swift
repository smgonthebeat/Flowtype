import Foundation

enum TranscriptProcessingProfile: String, Codable, Equatable {
    case general
    case mathStatistics

    static func resolve(from options: TranscriptProcessingOptions) -> TranscriptProcessingProfile {
        options.isMathNotationEnabled ? .mathStatistics : .general
    }
}
