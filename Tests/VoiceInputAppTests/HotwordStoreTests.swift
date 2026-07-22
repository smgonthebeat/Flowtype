import XCTest
@testable import VoiceInputApp

final class HotwordStoreTests: XCTestCase {
    private var temporaryDirectories: [URL] = []

    override func tearDownWithError() throws {
        try temporaryDirectories.forEach {
            if FileManager.default.fileExists(atPath: $0.path) {
                try FileManager.default.removeItem(at: $0)
            }
        }
        temporaryDirectories.removeAll()
    }

    private func makeStore() -> HotwordStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        temporaryDirectories.append(directory)
        return HotwordStore(fileURL: directory.appendingPathComponent("hotwords.json"))
    }

    func testStartsEmptyWhenFileIsMissing() throws {
        let store = makeStore()

        let words = try store.load()

        XCTAssertTrue(words.isEmpty)
    }

    func testLoadsSavedUserManagedTerms() throws {
        let store = makeStore()
        let expected = ["example term", "sample phrase", "DemoTool"]
        try store.save(expected.map { Hotword(text: $0) })

        let words = try store.load()

        XCTAssertEqual(words.map(\.text), expected)
    }

    func testAddTrimsAndDeduplicatesCaseInsensitively() throws {
        let store = makeStore()

        let inserted = try store.addWithOutcome("  Cursor  ")
        let existing = try store.addWithOutcome("cursor")
        let words = try store.load()

        guard case .inserted = inserted else {
            return XCTFail("Expected the first add to insert a term")
        }
        guard case .existing = existing else {
            return XCTFail("Expected the duplicate add to report the existing term")
        }
        XCTAssertEqual(words.filter { $0.text.lowercased() == "cursor" }.count, 1)
        XCTAssertTrue(words.contains { $0.text == "Cursor" })
    }

    func testAddUpgradesSpecialSeedCasingAndDeduplicatesCaseInsensitively() throws {
        let store = makeStore()

        _ = try store.add("Claude Code")
        let words = try store.load()
        let matches = words.filter { $0.text.caseInsensitiveCompare("claude code") == .orderedSame }

        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches.first?.text, "Claude Code")
    }

    func testAddDoesNotRecaseUserCreatedLowercaseDuplicate() throws {
        let store = makeStore()

        _ = try store.add("custom term")
        _ = try store.add("Custom Term")
        let words = try store.load()
        let matches = words.filter { $0.text.caseInsensitiveCompare("custom term") == .orderedSame }

        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches.first?.text, "custom term")
    }

    func testAddRejectsEmptyText() throws {
        let store = makeStore()

        XCTAssertThrowsError(try store.add(" \n\t ")) { error in
            XCTAssertEqual(error as? HotwordStoreError, .emptyText)
        }
    }

    func testDeleteRemovesWord() throws {
        let store = makeStore()
        let word = try store.add("Qwen3-ASR")

        try store.delete(id: word.id)

        XCTAssertFalse(try store.load().contains { $0.id == word.id })
    }

    func testSearchMatchesCaseInsensitively() throws {
        let store = makeStore()
        _ = try store.add("Claude Code")

        let results = try store.search("claude")

        XCTAssertTrue(results.contains { $0.text == "Claude Code" })
    }
}
