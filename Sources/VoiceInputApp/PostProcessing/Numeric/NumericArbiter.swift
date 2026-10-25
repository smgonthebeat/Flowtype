import Foundation

/// A recogniser's positive decision: convert exactly `range` to `replacement`.
struct NumericProposal {
    let range: Range<Int>
    let replacement: String
    let ruleID: String
    let evidence: String
    /// Tie-breaker between equally long overlapping proposals (higher wins).
    var specificity = 0
}

/// A recogniser's decision to keep exactly `range` as dictated. It blocks every proposal
/// that overlaps it, and nothing outside it.
struct NumericAbstention {
    let range: Range<Int>
    let ruleID: String
    let reason: String
}

struct NumericDecisions {
    private(set) var proposals: [NumericProposal] = []
    private(set) var abstentions: [NumericAbstention] = []

    mutating func propose(_ range: Range<Int>, _ replacement: String, rule: String, evidence: String, specificity: Int = 0) {
        guard !range.isEmpty else { return }
        proposals.append(NumericProposal(range: range, replacement: replacement, ruleID: rule,
                                         evidence: evidence, specificity: specificity))
    }

    mutating func abstain(_ range: Range<Int>, rule: String, reason: String) {
        guard !range.isEmpty else { return }
        abstentions.append(NumericAbstention(range: range, ruleID: rule, reason: reason))
    }

    /// Drops every decision that overlaps one of `ranges` (spans another recogniser has claimed).
    mutating func removeOverlapping(_ ranges: [Range<Int>]) {
        proposals.removeAll { proposal in ranges.contains { $0.overlaps(proposal.range) } }
        abstentions.removeAll { abstention in ranges.contains { $0.overlaps(abstention.range) } }
    }

    mutating func merge(_ other: NumericDecisions) {
        proposals += other.proposals
        abstentions += other.abstentions
    }
}

struct NumericArbiterResult {
    let text: String
    let events: [PostProcessingEvent]
    /// Applied edits in original character offsets, sorted by position.
    let applied: [NumericProposal]

    /// Maps an original character offset to the corresponding offset in `text`.
    func mappedOffset(_ offset: Int) -> Int {
        var delta = 0
        for edit in applied where edit.range.upperBound <= offset {
            delta += edit.replacement.count - edit.range.count
        }
        return offset + delta
    }
}

enum NumericArbiter {
    static func resolve(
        _ text: NumericText,
        decisions: NumericDecisions,
        protected: [Range<Int>]
    ) -> NumericArbiterResult {
        let blocked = protected + decisions.abstentions.map(\.range)
        let eligible = decisions.proposals.filter { proposal in
            !blocked.contains { $0.overlaps(proposal.range) }
                && text.slice(proposal.range) != proposal.replacement
        }
        let ranked = eligible.sorted { lhs, rhs in
            if lhs.range.count != rhs.range.count { return lhs.range.count > rhs.range.count }
            if lhs.specificity != rhs.specificity { return lhs.specificity > rhs.specificity }
            return lhs.range.lowerBound < rhs.range.lowerBound
        }
        var selected: [NumericProposal] = []
        for proposal in ranked where !selected.contains(where: { $0.range.overlaps(proposal.range) }) {
            selected.append(proposal)
        }
        selected.sort { $0.range.lowerBound < $1.range.lowerBound }

        var output = text.string
        for proposal in selected.reversed() {
            output.replaceSubrange(text.index(proposal.range.lowerBound)..<text.index(proposal.range.upperBound),
                                   with: proposal.replacement)
        }

        var events: [(Int, PostProcessingEvent)] = selected.map { proposal in
            (proposal.range.lowerBound, PostProcessingEvent(
                ruleID: proposal.ruleID,
                rangeDescription: describe(proposal.range),
                before: text.slice(proposal.range),
                after: proposal.replacement,
                reason: proposal.evidence,
                confidence: .high
            ))
        }
        var seenAbstentions = Set<String>()
        for abstention in decisions.abstentions {
            let key = "\(abstention.ruleID)|\(abstention.range)"
            guard seenAbstentions.insert(key).inserted else { continue }
            let original = text.slice(abstention.range)
            events.append((abstention.range.lowerBound, PostProcessingEvent(
                ruleID: abstention.ruleID,
                rangeDescription: describe(abstention.range),
                before: original,
                after: original,
                reason: abstention.reason,
                confidence: .medium
            )))
        }
        events.sort { $0.0 < $1.0 }
        return NumericArbiterResult(text: output, events: events.map(\.1), applied: selected)
    }

    private static func describe(_ range: Range<Int>) -> String {
        "chars:\(range.lowerBound)..<\(range.upperBound)"
    }
}
