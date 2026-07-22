import Foundation

struct UsageStats: Codable, Equatable {
    var firstUsedAt: Date?
    var successfulDictations: Int
    var cumulativeRecordingSeconds: TimeInterval
    var dictatedUnitCount: Int
    var estimatedSavedSeconds: TimeInterval
    var updatedAt: Date?

    static let empty = UsageStats(
        firstUsedAt: nil,
        successfulDictations: 0,
        cumulativeRecordingSeconds: 0,
        dictatedUnitCount: 0,
        estimatedSavedSeconds: 0,
        updatedAt: nil
    )
}

final class UsageStatsStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    static func defaultFileURL(fileManager: FileManager = .default) throws -> URL {
        try ApplicationSupport.directory(fileManager: fileManager)
            .appendingPathComponent("usage-stats.json")
    }

    static func defaultStore(fileManager: FileManager = .default) throws -> UsageStatsStore {
        UsageStatsStore(fileURL: try defaultFileURL(fileManager: fileManager))
    }

    convenience init() {
        do {
            self.init(fileURL: try Self.defaultFileURL())
        } catch {
            preconditionFailure("Unable to resolve UsageStatsStore persistence URL: \(error)")
        }
    }

    init(fileURL: URL) {
        self.fileURL = fileURL
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() throws -> UsageStats {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return .empty
        }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(UsageStats.self, from: data)
    }

    @discardableResult
    func recordSuccessfulDictation(
        text: String,
        recordingDuration: TimeInterval,
        now: Date = Date()
    ) throws -> UsageStats {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return try load()
        }

        let count = Self.dictatedUnitCount(in: normalized)
        let duration = max(0, recordingDuration)
        let manualSeconds = Self.estimatedManualInputSeconds(for: normalized)
        let savedSeconds = max(0, manualSeconds - duration)

        var stats = try load()
        stats.firstUsedAt = stats.firstUsedAt ?? now
        stats.successfulDictations += 1
        stats.cumulativeRecordingSeconds += duration
        stats.dictatedUnitCount += count
        stats.estimatedSavedSeconds += savedSeconds
        stats.updatedAt = now
        try save(stats)
        return stats
    }

    func reset() throws {
        try save(.empty)
    }

    @discardableResult
    func reconcileWithHistory(_ items: [TranscriptHistoryItem], now: Date = Date()) throws -> UsageStats {
        var stats = try load()
        let successfulItems = items.filter { $0.status != .failed }
        guard !successfulItems.isEmpty else {
            return stats
        }

        let historyFirstUsedAt = successfulItems.map(\.createdAt).min() ?? now
        let historyDictationCount = successfulItems.count
        let historyUnitCount = successfulItems.reduce(0) { $0 + $1.wordCount }
        let originalStats = stats

        if let firstUsedAt = stats.firstUsedAt {
            stats.firstUsedAt = min(firstUsedAt, historyFirstUsedAt)
        } else {
            stats.firstUsedAt = historyFirstUsedAt
        }

        stats.successfulDictations = max(stats.successfulDictations, historyDictationCount)
        stats.dictatedUnitCount = max(stats.dictatedUnitCount, historyUnitCount)

        if stats != originalStats {
            stats.updatedAt = now
            try save(stats)
        }

        return stats
    }

    private func save(_ stats: UsageStats) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try encoder.encode(stats)
        try data.write(to: fileURL, options: .atomic)
    }

    static func dictatedUnitCount(in text: String) -> Int {
        var count = 0
        var isInAlphanumericWord = false

        for character in text {
            if character.isCJKDictationUnit {
                count += 1
                isInAlphanumericWord = false
            } else if character.isNonCJKAlphanumeric {
                if !isInAlphanumericWord {
                    count += 1
                    isInAlphanumericWord = true
                }
            } else {
                isInAlphanumericWord = false
            }
        }

        return count
    }

    static func estimatedManualInputSeconds(for text: String) -> TimeInterval {
        let counts = text.inputEstimateCounts
        let chineseSeconds = Double(counts.cjkUnits) / 55 * 60
        let englishSeconds = Double(counts.nonCJKWords) / 35 * 60
        return chineseSeconds + englishSeconds
    }
}

private extension String {
    var inputEstimateCounts: (cjkUnits: Int, nonCJKWords: Int) {
        var cjkUnits = 0
        var nonCJKWords = 0
        var isInAlphanumericWord = false

        for character in self {
            if character.isCJKDictationUnit {
                cjkUnits += 1
                isInAlphanumericWord = false
            } else if character.isNonCJKAlphanumeric {
                if !isInAlphanumericWord {
                    nonCJKWords += 1
                    isInAlphanumericWord = true
                }
            } else {
                isInAlphanumericWord = false
            }
        }

        return (cjkUnits, nonCJKWords)
    }
}

private extension Character {
    var isCJKDictationUnit: Bool {
        unicodeScalars.contains { scalar in
            scalar.isCJKIdeograph || scalar.isKana || scalar.isHangul
        }
    }

    var isNonCJKAlphanumeric: Bool {
        !isCJKDictationUnit && unicodeScalars.allSatisfy { scalar in
            scalar.properties.isAlphabetic || scalar.properties.numericType != nil
        }
    }
}

private extension Unicode.Scalar {
    var isCJKIdeograph: Bool {
        switch value {
        case 0x3400...0x4DBF,
             0x4E00...0x9FFF,
             0xF900...0xFAFF,
             0x20000...0x2A6DF,
             0x2A700...0x2B73F,
             0x2B740...0x2B81F,
             0x2B820...0x2CEAF,
             0x2CEB0...0x2EBEF,
             0x30000...0x3134F:
            return true
        default:
            return false
        }
    }

    var isKana: Bool {
        switch value {
        case 0x3040...0x309F,
             0x30A0...0x30FF,
             0x31F0...0x31FF:
            return true
        default:
            return false
        }
    }

    var isHangul: Bool {
        switch value {
        case 0x1100...0x11FF,
             0x3130...0x318F,
             0xAC00...0xD7AF:
            return true
        default:
            return false
        }
    }
}
