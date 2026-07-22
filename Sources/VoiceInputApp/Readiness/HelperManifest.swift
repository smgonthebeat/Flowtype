import CryptoKit
import Foundation

struct HelperManifest: Codable, Equatable {
    static let fileName = "helper_manifest.json"

    let helperSchema: Int
    let flowtypeHelperVersion: String
    let sourceCommit: String
    let requiresUVLockHash: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case helperSchema = "helper_schema"
        case flowtypeHelperVersion = "flowtype_helper_version"
        case sourceCommit = "source_commit"
        case requiresUVLockHash = "requires_uv_lock_hash"
        case createdAt = "created_at"
    }

    func matchesBundledHelper(_ bundled: HelperManifest) -> Bool {
        helperSchema == bundled.helperSchema &&
            flowtypeHelperVersion == bundled.flowtypeHelperVersion &&
            sourceCommit == bundled.sourceCommit &&
            requiresUVLockHash == bundled.requiresUVLockHash
    }

    static func read(fromHelperRoot helperRoot: URL) throws -> HelperManifest {
        let data = try Data(contentsOf: helperRoot.appendingPathComponent(fileName))
        return try JSONDecoder().decode(HelperManifest.self, from: data)
    }

    func write(toHelperRoot helperRoot: URL) throws {
        try FileManager.default.createDirectory(at: helperRoot, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: helperRoot.appendingPathComponent(Self.fileName), options: .atomic)
    }

    static func uvLockHash(forHelperRoot helperRoot: URL) throws -> String {
        let data = try Data(contentsOf: helperRoot.appendingPathComponent("uv.lock"))
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
