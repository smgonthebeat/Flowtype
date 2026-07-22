import Foundation

enum CandidateSource: String, Codable, Equatable {
    case original
    case confusionCorrected
    case mathRendered
}

struct TranscriptCandidate: Equatable {
    let text: String
    let source: CandidateSource
    let transformations: [PostProcessingEvent]
}

struct CandidateScoringContext: Equatable {
    let profile: TranscriptProcessingProfile
    let sourceText: String
    let hasMathSignal: Bool
    let hasPlainEnglishBlocker: Bool
    let hasCodeLikeBlocker: Bool
}

struct CandidateScore: Equatable {
    let value: Int
    let reasons: [String]
}

enum CandidateScorer {
    static func choose(
        _ candidates: [TranscriptCandidate],
        context: CandidateScoringContext
    ) -> TranscriptCandidate? {
        candidates.max { lhs, rhs in
            let lhsScore = score(lhs, context: context)
            let rhsScore = score(rhs, context: context)
            if lhsScore.value != rhsScore.value {
                return lhsScore.value < rhsScore.value
            }
            return sourcePriority(lhs.source) < sourcePriority(rhs.source)
        }
    }

    static func score(
        _ candidate: TranscriptCandidate,
        context: CandidateScoringContext
    ) -> CandidateScore {
        var value = 0
        var reasons: [String] = []

        switch candidate.source {
        case .original:
            value += 2
            reasons.append("original text is safest")
        case .confusionCorrected:
            value += 4
            reasons.append("confusion-corrected candidate")
        case .mathRendered:
            value += 6
            reasons.append("rendered math candidate")
        }

        if context.profile == .mathStatistics, context.hasMathSignal {
            value += 8
            reasons.append("math profile with math signal")
            if candidate.source == .mathRendered {
                value += 6
                reasons.append("math profile prefers rendered math")
            }
        }

        if context.profile == .general, candidate.source != .original {
            value -= 20
            reasons.append("general profile avoids math-only correction")
        }

        if context.hasPlainEnglishBlocker, candidate.source != .original {
            value -= 20
            reasons.append("plain-English blocker")
        }

        if context.hasCodeLikeBlocker, candidate.source != .original {
            value -= 20
            reasons.append("code-like blocker")
        }

        return CandidateScore(value: value, reasons: reasons)
    }

    private static func sourcePriority(_ source: CandidateSource) -> Int {
        switch source {
        case .original:
            return 0
        case .confusionCorrected:
            return 1
        case .mathRendered:
            return 2
        }
    }
}
