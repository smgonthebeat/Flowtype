import XCTest
@testable import VoiceInputApp

final class HelperLogTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testEachLaunchStartsANewLogAndKeepsThePreviousOne() throws {
        let first = HelperLog.handleForNewLaunch(applicationSupportRoot: root)
        try first.write(contentsOf: Data("first launch\n".utf8))
        try first.close()

        let second = HelperLog.handleForNewLaunch(applicationSupportRoot: root)
        try second.write(contentsOf: Data("second launch\n".utf8))
        try second.close()

        let current = try String(contentsOf: HelperLog.currentURL(applicationSupportRoot: root), encoding: .utf8)
        let previous = try String(contentsOf: HelperLog.previousURL(applicationSupportRoot: root), encoding: .utf8)
        XCTAssertEqual(current, "second launch\n")
        XCTAssertEqual(previous, "first launch\n")
    }

    func testTailReturnsTheLastLinesIncludingProgressBarUpdates() throws {
        let handle = HelperLog.handleForNewLaunch(applicationSupportRoot: root)
        let body = (1...60).map { "line \($0)" }.joined(separator: "\n") + "\nprogress 10%\rprogress 99%\n"
        try handle.write(contentsOf: Data(body.utf8))
        try handle.close()

        let tail = try XCTUnwrap(HelperLog.tail(applicationSupportRoot: root))

        XCTAssertEqual(tail.count, HelperLog.tailLineCount)
        XCTAssertEqual(tail.last, "progress 99%")
        XCTAssertEqual(tail.first, "line 23")
    }

    func testTailIsNilWithoutALog() {
        XCTAssertNil(HelperLog.tail(applicationSupportRoot: root))
    }

    func testUnwritableLogDirectoryFallsBackToNullDeviceNotAPipe() throws {
        let blocker = root.appendingPathComponent("Logs")
        try Data().write(to: blocker)

        let handle = HelperLog.handleForNewLaunch(applicationSupportRoot: root)

        XCTAssertNoThrow(try handle.write(contentsOf: Data(repeating: 65, count: 200_000)))
    }
}
