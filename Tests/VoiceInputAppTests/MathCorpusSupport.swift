import Foundation
@testable import VoiceInputApp

/// Shared loaders for the math notation rebuild fixtures.
/// Corpus source of truth: docs/maintenance/artifacts/2026-10-03-math-notation-rebuild/corpus.jsonl
/// (the fixture is a byte-identical copy; MathCorpusTests checks that).
enum MathCorpusSupport {
    struct CorpusRow: Decodable {
        let id: String
        let kind: String
        let category: String
        let source: String
        let scope: String?
        let input: String
        let knownTerms: [String]?
        let expectedUnicode: String
        let expectedLatex: String
        let note: String?

        private enum CodingKeys: String, CodingKey {
            case id, kind, category, source, scope, input, knownTerms, note
            case expectedUnicode = "expected_unicode"
            case expectedLatex = "expected_latex"
        }

        var isMustChange: Bool { kind == "must-change" }
        var isPipelineScope: Bool { scope == "pipeline" }
        var terms: [String] { knownTerms ?? [] }

        func expected(_ format: MathNotationOutputFormat) -> String {
            format == .latex ? expectedLatex : expectedUnicode
        }
    }

    struct SnapshotRow: Decodable {
        let input: String
        let knownTerms: [String]
        let numericAcademic: String
        let all: String
    }

    static func fixturesDirectory(file: StaticString = #filePath) -> URL {
        URL(fileURLWithPath: "\(file)").deletingLastPathComponent().appendingPathComponent("Fixtures", isDirectory: true)
    }

    static func worktreeRoot(file: StaticString = #filePath) -> URL {
        URL(fileURLWithPath: "\(file)").deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    static var corpusArtifactURL: URL {
        worktreeRoot().appendingPathComponent("docs/maintenance/artifacts/2026-10-03-math-notation-rebuild/corpus.jsonl")
    }

    static var corpusFixtureURL: URL { fixturesDirectory().appendingPathComponent("math-corpus.jsonl") }

    static func loadJSONL<Row: Decodable>(_ url: URL, as: Row.Type) throws -> [Row] {
        let contents = try String(contentsOf: url, encoding: .utf8)
        let decoder = JSONDecoder()
        return try contents.split(separator: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { try decoder.decode(Row.self, from: Data($0.utf8)) }
    }

    static func corpus() throws -> [CorpusRow] {
        try loadJSONL(corpusFixtureURL, as: CorpusRow.self)
    }

    static func snapshot() throws -> [SnapshotRow] {
        try loadJSONL(fixturesDirectory().appendingPathComponent("math-off-snapshot.jsonl"), as: SnapshotRow.self)
    }

    /// The corpus settings: numeric, academic and math on, filler off, with the row's known terms.
    static func options(
        _ format: MathNotationOutputFormat,
        knownTerms: [String],
        math: Bool = true,
        filler: Bool = false
    ) -> TranscriptProcessingOptions {
        TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: true,
            isAcademicReferenceFormattingEnabled: true,
            isFillerCleanupEnabled: filler,
            isMathNotationEnabled: math,
            mathNotationOutputFormat: format,
            knownTerms: knownTerms
        )
    }
}
