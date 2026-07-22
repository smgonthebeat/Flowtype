import XCTest
@testable import VoiceInputApp

final class HelperManifestTests: XCTestCase {
    func testManifestRoundTripsFromHelperRoot() throws {
        let root = try temporaryDirectory()
        let manifest = HelperManifest(
            helperSchema: 1,
            flowtypeHelperVersion: "2026.05.17",
            sourceCommit: "442840e",
            requiresUVLockHash: "abc123",
            createdAt: "2026-05-17"
        )

        try manifest.write(toHelperRoot: root)

        XCTAssertEqual(try HelperManifest.read(fromHelperRoot: root), manifest)
    }

    func testManifestWritesSnakeCaseJSONKeys() throws {
        let root = try temporaryDirectory()
        let manifest = HelperManifest(
            helperSchema: 1,
            flowtypeHelperVersion: "2026.05.17",
            sourceCommit: "442840e",
            requiresUVLockHash: "abc123",
            createdAt: "2026-05-17"
        )

        try manifest.write(toHelperRoot: root)

        let data = try Data(contentsOf: root.appendingPathComponent(HelperManifest.fileName))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(object["helper_schema"] as? Int, 1)
        XCTAssertEqual(object["flowtype_helper_version"] as? String, "2026.05.17")
        XCTAssertEqual(object["source_commit"] as? String, "442840e")
        XCTAssertEqual(object["requires_uv_lock_hash"] as? String, "abc123")
        XCTAssertEqual(object["created_at"] as? String, "2026-05-17")
        XCTAssertNil(object["helperSchema"])
        XCTAssertNil(object["flowtypeHelperVersion"])
        XCTAssertNil(object["sourceCommit"])
        XCTAssertNil(object["requiresUVLockHash"])
        XCTAssertNil(object["createdAt"])
    }

    func testManifestDetectsMismatch() {
        let bundled = HelperManifest(
            helperSchema: 1,
            flowtypeHelperVersion: "2026.05.17",
            sourceCommit: "442840e",
            requiresUVLockHash: "abc123",
            createdAt: "2026-05-17"
        )
        let copied = HelperManifest(
            helperSchema: 1,
            flowtypeHelperVersion: "2026.05.16",
            sourceCommit: "old",
            requiresUVLockHash: "def456",
            createdAt: "2026-05-16"
        )

        XCTAssertFalse(copied.matchesBundledHelper(bundled))
        XCTAssertTrue(bundled.matchesBundledHelper(bundled))
    }

    func testUVLockHashIsStable() throws {
        let root = try temporaryDirectory()
        let lockURL = root.appendingPathComponent("uv.lock")
        try "package = \"mlx\"\nversion = \"0.26.0\"\n".write(to: lockURL, atomically: true, encoding: .utf8)

        let first = try HelperManifest.uvLockHash(forHelperRoot: root)
        let second = try HelperManifest.uvLockHash(forHelperRoot: root)

        XCTAssertFalse(first.isEmpty)
        XCTAssertEqual(first.count, 64)
        XCTAssertEqual(first, "aae32a9565652d6a41bbf51361b23815d053e7bba93491fbf98ffb2efbb3e9e5")
        XCTAssertEqual(first, second)
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("flowtype-helper-manifest-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
