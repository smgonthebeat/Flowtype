import Foundation

final class HotwordStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    static func defaultFileURL(fileManager: FileManager = .default) throws -> URL {
        try ApplicationSupport.directory(fileManager: fileManager)
            .appendingPathComponent("hotwords.json")
    }

    static func defaultStore(fileManager: FileManager = .default) throws -> HotwordStore {
        HotwordStore(fileURL: try defaultFileURL(fileManager: fileManager))
    }

    convenience init() {
        do {
            self.init(fileURL: try Self.defaultFileURL())
        } catch {
            preconditionFailure("Unable to resolve HotwordStore persistence URL: \(error)")
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

    func load() throws -> [Hotword] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode([Hotword].self, from: data)
    }

    func enabledHotwords() throws -> [Hotword] {
        try load().filter(\.isEnabled)
    }

    @discardableResult
    func add(_ text: String) throws -> Hotword {
        try addWithOutcome(text).hotword
    }

    func addWithOutcome(_ text: String) throws -> HotwordAddOutcome {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            throw HotwordStoreError.emptyText
        }

        var words = try load()
        if let index = words.firstIndex(where: { $0.text.caseInsensitiveCompare(normalized) == .orderedSame }) {
            if Self.shouldUpgradeSeedCasing(existing: words[index].text, newText: normalized) {
                words[index].text = normalized
                words[index].updatedAt = Date()
                try save(words)
                return .updated(words[index])
            }
            return .existing(words[index])
        }

        let word = Hotword(text: normalized)
        words.insert(word, at: 0)
        try save(words)
        return .inserted(word)
    }

    func delete(id: UUID) throws {
        let words = try load().filter { $0.id != id }
        try save(words)
    }

    func search(_ query: String) throws -> [Hotword] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return try load() }
        return try load().filter {
            $0.text.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    func save(_ words: [Hotword]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try encoder.encode(words)
        try data.write(to: fileURL, options: .atomic)
    }

    private static func shouldUpgradeSeedCasing(existing: String, newText: String) -> Bool {
        existing == existing.lowercased()
            && newText != newText.lowercased()
            && lowercaseSeedTexts.contains(existing)
    }

    private static let lowercaseSeedTexts = Set(["claude code"])
}

enum HotwordAddOutcome: Equatable {
    case inserted(Hotword)
    case existing(Hotword)
    case updated(Hotword)

    var hotword: Hotword {
        switch self {
        case let .inserted(hotword), let .existing(hotword), let .updated(hotword):
            return hotword
        }
    }
}

enum HotwordStoreError: Error, Equatable {
    case emptyText
}
