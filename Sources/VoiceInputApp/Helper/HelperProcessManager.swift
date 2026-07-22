import Darwin
import Foundation

final class HelperProcessManager {
    private enum Constants {
        static let helperRelativePath = "Helpers/qwen-asr-helper"
        static let defaultPath = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
        static let tokenHeader = "X-VoiceInput-Token"
    }

    private var process: Process?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    private var endpoint: HelperEndpoint?
    private var launchedModelID: String?
    private let lifecycleLock = NSLock()
    private let currentModelManager: () -> ModelManager
    private let currentModelID: () -> String
    private let runtimeManager: HelperRuntimeManager

    init(modelManager: ModelManager = ModelManager(), runtimeManager: HelperRuntimeManager? = nil) {
        self.currentModelManager = { modelManager }
        self.currentModelID = { modelManager.model.id }
        self.runtimeManager = runtimeManager ?? HelperRuntimeManager(applicationSupportRoot: modelManager.applicationSupportRoot)
    }

    init(settingsStore: SettingsStore, applicationSupportRoot: URL? = nil, runtimeManager: HelperRuntimeManager? = nil) {
        self.currentModelManager = {
            ModelManager(
                model: VoiceInputModel.model(for: settingsStore.selectedModelID),
                applicationSupportRoot: applicationSupportRoot
            )
        }
        self.currentModelID = {
            VoiceInputModel.model(for: settingsStore.selectedModelID).id
        }
        self.runtimeManager = runtimeManager ?? HelperRuntimeManager(applicationSupportRoot: applicationSupportRoot)
    }

    func startIfNeeded() throws -> HelperEndpoint {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }

        if process?.isRunning == true,
           let endpoint,
           launchedModelID == currentModelID() {
            return endpoint
        }
        if process?.isRunning == true {
            stopLocked()
        }

        let helperDir = try resolveHelperDirectory()
        terminateResidualHelpers(at: helperDir)
        let port = try reserveLocalPort()
        let endpoint = HelperEndpoint(
            baseURL: URL(string: "http://127.0.0.1:\(port)")!,
            authToken: UUID().uuidString,
            bootID: UUID()
        )

        let process = Process()
        let launchCommand = try resolveUVLaunchCommand(helperDir: helperDir)
        process.executableURL = launchCommand.executableURL
        process.arguments = launchCommand.arguments
        process.environment = launchEnvironment(port: port, authToken: endpoint.authToken)

        let outputPipe = drainedPipe()
        let errorPipe = drainedPipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        process.terminationHandler = { [weak self] _ in
            self?.clearPipesFromTerminationHandler()
        }

        do {
            try process.run()
            self.process = process
            self.endpoint = endpoint
            self.launchedModelID = currentModelID()
            self.outputPipe = outputPipe
            self.errorPipe = errorPipe
            try waitUntilHealthy(endpoint: endpoint, timeout: 180)
            return endpoint
        } catch {
            stopLocked()
            throw error
        }
    }

    func stop() {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }

        stopLocked()
    }

    func runningEndpoint() -> HelperEndpoint? {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        guard process?.isRunning == true else { return nil }
        return endpoint
    }

    func runtimeSnapshot() -> HelperRuntimeSnapshot {
        runtimeManager.snapshot()
    }

    func prepareRuntime() throws -> URL {
        try runtimeManager.prepareRuntime()
    }

    func repairHelperCopy() throws -> URL {
        try runtimeManager.repairHelperCopy()
    }

    private func stopLocked() {
        guard let process else { return }
        guard process.isRunning else {
            self.process = nil
            clearPipes()
            return
        }

        let semaphore = DispatchSemaphore(value: 0)
        process.terminationHandler = { [weak self] _ in
            semaphore.signal()
            self?.clearPipesFromTerminationHandler()
        }
        process.terminate()
        if semaphore.wait(timeout: .now() + 2) == .timedOut {
            process.interrupt()
            if semaphore.wait(timeout: .now() + 1) == .timedOut {
                kill(process.processIdentifier, SIGKILL)
                _ = semaphore.wait(timeout: .now() + 1)
            }
        }
        self.process = nil
        endpoint = nil
        launchedModelID = nil
        clearPipes()
    }

    private func terminateResidualHelpers(at helperDir: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        process.arguments = ["-TERM", "-f", helperDir.path]
        try? process.run()
        process.waitUntilExit()
        Thread.sleep(forTimeInterval: 0.2)
    }

    func resolveHelperDirectory() throws -> URL {
        let environment = ProcessInfo.processInfo.environment
        if let override = environment["VOICEINPUT_HELPER_DIR"] {
            let url = URL(fileURLWithPath: override, isDirectory: true)
            if isHelperDirectory(url) { return url }
        }

        if runtimeManager.bundledUVExecutable != nil,
           runtimeManager.snapshot().bundledHelperDirectory != nil {
            return try runtimeManager.prepareRuntime()
        }

        let candidates = [
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true),
            Bundle.main.bundleURL
        ]

        for candidate in candidates {
            if let helperDir = findHelperDirectory(startingAt: candidate) {
                return helperDir
            }
        }

        throw HelperProcessError.helperDirectoryNotFound
    }

    private func findHelperDirectory(startingAt startURL: URL) -> URL? {
        var current = startURL
        if current.pathExtension == "app" {
            current.deleteLastPathComponent()
        }

        while true {
            let helperDir = current.appendingPathComponent(Constants.helperRelativePath, isDirectory: true)
            if isHelperDirectory(helperDir) {
                return helperDir
            }

            let parent = current.deletingLastPathComponent()
            if parent.path == current.path { return nil }
            current = parent
        }
    }

    func isHelperDirectory(_ url: URL) -> Bool {
        if runtimeManager.isManagedHelperPath(url) {
            return runtimeManager.isManagedHelperDirectory(url)
        }
        return HelperContentContract.isMinimalRepositoryHelper(at: url)
    }

    func resolveUVLaunchCommand(helperDir: URL) throws -> (executableURL: URL, arguments: [String]) {
        let uvArguments = ["run", "--project", helperDir.path, "qwen-asr-helper"]
        if let bundledUV = bundledUVExecutable() {
            return (bundledUV, uvArguments)
        }
        if runtimeManager.isManagedHelperPath(helperDir) {
            throw HelperProcessError.bundledUVUnavailable
        }

        return (
            URL(fileURLWithPath: "/usr/bin/env"),
            ["uv"] + uvArguments
        )
    }

    private func bundledUVExecutable() -> URL? {
        runtimeManager.bundledUVExecutable
    }

    func launchEnvironment(port: UInt16, authToken: String) -> [String: String] {
        let modelManager = currentModelManager()
        try? modelManager.ensureDirectories()

        var environment = ProcessInfo.processInfo.environment
        let existingPath = environment["PATH"] ?? ""
        let bundledToolsPath = Bundle.main.resourceURL?
            .appendingPathComponent("Tools", isDirectory: true)
            .path
        let pathPrefix = [bundledToolsPath, Constants.defaultPath]
            .compactMap { $0 }
            .joined(separator: ":")
        environment["PATH"] = existingPath.isEmpty
            ? pathPrefix
            : "\(pathPrefix):\(existingPath)"
        environment["VOICEINPUT_HELPER_PORT"] = String(port)
        environment["VOICEINPUT_HELPER_TOKEN"] = authToken
        environment["VOICEINPUT_MODEL_ID"] = modelManager.model.modelID
        environment["VOICEINPUT_MODELS_ROOT"] = modelManager.modelsRoot.path
        environment["VOICEINPUT_MODEL_ROOT"] = modelManager.modelDirectory.path
        environment["HF_HOME"] = modelManager.huggingFaceHome.path
        environment["TRANSFORMERS_CACHE"] = modelManager.transformersCache.path
        return environment
    }

    private func drainedPipe() -> Pipe {
        let pipe = Pipe()
        pipe.fileHandleForReading.readabilityHandler = { handle in
            _ = handle.availableData
        }
        return pipe
    }

    private func clearPipes() {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        errorPipe?.fileHandleForReading.readabilityHandler = nil
        outputPipe = nil
        errorPipe = nil
    }

    private func clearPipesFromTerminationHandler() {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }

        clearPipes()
    }

    private func waitUntilHealthy(endpoint: HelperEndpoint, timeout: TimeInterval) throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if process?.isRunning != true {
                throw HelperProcessError.processExited
            }
            if healthCheck(endpoint: endpoint) {
                return
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
        throw HelperProcessError.timedOutWaitingForHealth
    }

    private func healthCheck(endpoint: HelperEndpoint) -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var isHealthy = false
        var request = URLRequest(url: endpoint.baseURL.appendingPathComponent("health"))
        request.setValue(endpoint.authToken, forHTTPHeaderField: Constants.tokenHeader)
        let task = URLSession.shared.dataTask(with: request) { data, response, _ in
            defer { semaphore.signal() }
            guard let response = response as? HTTPURLResponse,
                  (200..<300).contains(response.statusCode),
                  let data else {
                return
            }
            isHealthy = data.contains(#""ok":true"#.data(using: .utf8)!)
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + 0.5)
        task.cancel()
        return isHealthy
    }

    private func reserveLocalPort() throws -> UInt16 {
        let socketFileDescriptor = socket(AF_INET, SOCK_STREAM, 0)
        guard socketFileDescriptor >= 0 else {
            throw HelperProcessError.portUnavailable
        }
        defer { close(socketFileDescriptor) }

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = 0
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

        let bindResult = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(socketFileDescriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            throw HelperProcessError.portUnavailable
        }

        var boundAddress = sockaddr_in()
        var boundAddressLength = socklen_t(MemoryLayout<sockaddr_in>.size)
        let nameResult = withUnsafeMutablePointer(to: &boundAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(socketFileDescriptor, $0, &boundAddressLength)
            }
        }
        guard nameResult == 0 else {
            throw HelperProcessError.portUnavailable
        }

        return UInt16(bigEndian: boundAddress.sin_port)
    }
}

struct HelperEndpoint {
    let baseURL: URL
    let authToken: String
    let bootID: UUID
}

enum HelperProcessError: Error, Equatable {
    case helperDirectoryNotFound
    case bundledUVUnavailable
    case helperManifestInvalid
    case portUnavailable
    case processExited
    case timedOutWaitingForHealth
}
