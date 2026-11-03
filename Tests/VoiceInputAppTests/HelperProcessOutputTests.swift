import XCTest
@testable import VoiceInputApp

/// 2026-11-03: after a model switch the old helper's termination handler switched off reading of
/// the new helper's stdout pipe; the new helper blocked on a full pipe ~10 minutes later. Output
/// now goes to a log file, so a helper that writes a lot keeps answering after any number of switches.
final class HelperProcessOutputTests: XCTestCase {
    private var root: URL!
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        suiteName = "HelperProcessOutputTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: root)
    }

    func testHelperKeepsAnsweringAfterModelSwitchesAndLargeOutput() throws {
        let python = URL(fileURLWithPath: "/usr/bin/python3")
        try XCTSkipUnless(FileManager.default.isExecutableFile(atPath: python.path), "needs /usr/bin/python3")
        let script = root.appendingPathComponent("fake_helper.py")
        try Self.fakeHelper.write(to: script, atomically: true, encoding: .utf8)

        let settings = SettingsStore(defaults: defaults)
        settings.selectedModelID = VoiceInputModel.qwen3ASR06B.id
        let manager = HelperProcessManager(
            settingsStore: settings,
            applicationSupportRoot: root,
            launchCommandOverride: { (python, ["-u", script.path]) }
        )
        defer { manager.stop() }

        _ = try manager.startIfNeeded()
        settings.selectedModelID = VoiceInputModel.qwen3ASR17B.id
        _ = try manager.startIfNeeded()
        settings.selectedModelID = VoiceInputModel.qwen3ASR06B.id
        let endpoint = try manager.startIfNeeded()

        // 300 requests x 1 KB of output: far beyond the 64 KB a pipe holds.
        for index in 0..<300 {
            XCTAssertTrue(Self.answers(endpoint), "helper stopped answering at request \(index)")
        }

        let logSize = try XCTUnwrap(
            FileManager.default.attributesOfItem(
                atPath: HelperLog.currentURL(applicationSupportRoot: root).path
            )[.size] as? Int
        )
        XCTAssertGreaterThan(logSize, 250_000)
    }

    /// The mechanics the dictation restart relies on, with a real frozen process: a status call
    /// gives up within the 5 s limit, stopping the frozen helper finishes, and a fresh one answers.
    func testFrozenHelperTimesOutIsStoppedAndReplaced() async throws {
        let python = URL(fileURLWithPath: "/usr/bin/python3")
        try XCTSkipUnless(FileManager.default.isExecutableFile(atPath: python.path), "needs /usr/bin/python3")
        let script = root.appendingPathComponent("fake_helper.py")
        try Self.fakeHelper.write(to: script, atomically: true, encoding: .utf8)
        let settings = SettingsStore(defaults: defaults)
        let manager = HelperProcessManager(
            settingsStore: settings,
            applicationSupportRoot: root,
            launchCommandOverride: { (python, ["-u", script.path]) }
        )
        defer { manager.stop() }

        let frozen = try manager.startIfNeeded()
        let pid = try XCTUnwrap(Self.listeningProcess(port: frozen.baseURL.port!))
        XCTAssertEqual(kill(pid, SIGSTOP), 0)

        let client = QwenHelperClient(baseURL: frozen.baseURL, authToken: frozen.authToken)
        let started = Date()
        do {
            _ = try await client.health()
            XCTFail("a frozen helper must not answer")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .timedOut)
        }
        XCTAssertLessThan(Date().timeIntervalSince(started), QwenHelperClient.statusTimeout + 2)

        let stopStarted = Date()
        manager.stop()
        XCTAssertLessThan(Date().timeIntervalSince(stopStarted), 5)
        XCTAssertNotEqual(kill(pid, 0), 0, "the frozen helper must be gone")

        let fresh = try manager.startIfNeeded()
        XCTAssertNotEqual(fresh.baseURL, frozen.baseURL)
        XCTAssertTrue(Self.answers(fresh))
    }

    private static func listeningProcess(port: Int) -> pid_t? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-t", "-iTCP:\(port)", "-sTCP:LISTEN"]
        process.standardOutput = pipe
        try? process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
            .split(separator: "\n").first.flatMap { pid_t(String($0)) }
    }

    private static func answers(_ endpoint: HelperEndpoint) -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var ok = false
        let task = URLSession.shared.dataTask(with: endpoint.baseURL.appendingPathComponent("health")) { data, _, _ in
            ok = data.map { String(decoding: $0, as: UTF8.self).contains("\"ok\":true") } ?? false
            semaphore.signal()
        }
        task.resume()
        if semaphore.wait(timeout: .now() + 3) == .timedOut {
            task.cancel()
            return false
        }
        return ok
    }

    private static let fakeHelper = """
    import os, sys
    from http.server import BaseHTTPRequestHandler, HTTPServer

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            sys.stdout.write("x" * 1023 + "\\n")
            sys.stdout.flush()
            body = b'{"ok":true,"engine":"fake"}'
            self.send_response(200)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *args):
            pass

    HTTPServer(("127.0.0.1", int(os.environ["VOICEINPUT_HELPER_PORT"])), Handler).serve_forever()
    """
}
