import Foundation

enum CandidateConfidence: String, Codable, Equatable {
    case low
    case medium
    case high
}

enum PostProcessingStage: String, Codable, Equatable {
    case protectedSpans
    case confusionCorrection
    case technicalTerms
    case normalization
    case fillerCleanup
    case mathNotation
    case candidateScoring
    case finalCleanup
}

struct PostProcessingEvent: Codable, Equatable {
    let ruleID: String
    let rangeDescription: String
    let before: String
    let after: String
    let reason: String
    let confidence: CandidateConfidence
}

struct PostProcessingStageTrace: Codable, Equatable {
    let stage: PostProcessingStage
    let input: String
    let output: String
    let events: [PostProcessingEvent]
}

struct PostProcessingTrace: Codable, Equatable {
    let originalText: String
    let profile: TranscriptProcessingProfile
    var stages: [PostProcessingStageTrace]

    mutating func append(
        stage: PostProcessingStage,
        input: String,
        output: String,
        events: [PostProcessingEvent] = []
    ) {
        stages.append(
            PostProcessingStageTrace(
                stage: stage,
                input: input,
                output: output,
                events: events
            )
        )
    }
}

struct TranscriptProcessingResult: Equatable {
    let text: String
    let trace: PostProcessingTrace
}
