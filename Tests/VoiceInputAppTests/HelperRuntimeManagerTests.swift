import XCTest
@testable import VoiceInputApp

final class HelperRuntimeManagerTests: XCTestCase {
    func testPrepareRuntimeReusesReadyManagedCopyAndPreservesVenv() throws {
        let fixture = try HelperRuntimeFixture.make()
        let initialManager = fixture.makeManager()
        let managedHelper = try initialManager.prepareRuntime()
        let venvSentinel = managedHelper.appendingPathComponent(".venv/bin/sentinel.txt")
        try FileManager.default.createDirectory(
            at: venvSentinel.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try "keep".write(to: venvSentinel, atomically: true, encoding: .utf8)
        var moveCount = 0
        let reuseManager = fixture.makeManager { source, destination in
            moveCount += 1
            try FileManager.default.moveItem(at: source, to: destination)
        }

        let reusedHelper = try reuseManager.prepareRuntime()

        XCTAssertEqual(reusedHelper.standardizedFileURL, managedHelper.standardizedFileURL)
        XCTAssertEqual(moveCount, 0)
        XCTAssertEqual(try String(contentsOf: venvSentinel), "keep")
    }

    func testPrepareRuntimePreservesVenvAcrossBundledHelperUpdateWhileRemovingStaleSource() throws {
        let fixture = try HelperRuntimeFixture.make()
        let manager = fixture.makeManager()
        let managedHelper = try manager.prepareRuntime()
        let venvSentinel = managedHelper.appendingPathComponent(".venv/bin/sentinel.txt")
        let staleSource = managedHelper.appendingPathComponent("qwen_asr_helper/stale.py")
        try FileManager.default.createDirectory(
            at: venvSentinel.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try "keep".write(to: venvSentinel, atomically: true, encoding: .utf8)
        try "remove".write(to: staleSource, atomically: true, encoding: .utf8)
        try fixture.writeBundledHelperManifest(version: "2026.07.12", sourceCommit: "updated")

        _ = try manager.prepareRuntime()

        XCTAssertEqual(try String(contentsOf: venvSentinel), "keep")
        XCTAssertFalse(FileManager.default.fileExists(atPath: staleSource.path))
        XCTAssertEqual(
            try HelperManifest.read(fromHelperRoot: managedHelper),
            try HelperManifest.read(fromHelperRoot: fixture.bundledHelperRoot)
        )
    }

    func testRepairHelperCopyPerformsCleanRepairAndRemovesVenv() throws {
        let fixture = try HelperRuntimeFixture.make()
        let manager = fixture.makeManager()
        let managedHelper = try manager.prepareRuntime()
        let venvSentinel = managedHelper.appendingPathComponent(".venv/bin/sentinel.txt")
        try FileManager.default.createDirectory(
            at: venvSentinel.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try "remove".write(to: venvSentinel, atomically: true, encoding: .utf8)

        _ = try manager.repairHelperCopy()

        XCTAssertFalse(FileManager.default.fileExists(atPath: venvSentinel.path))
        XCTAssertTrue(manager.isManagedHelperDirectory(managedHelper))
    }

    func testPrepareRuntimeRejectsSymlinkedVenvBeforeUpdatingManagedCopy() throws {
        let fixture = try HelperRuntimeFixture.make()
        let manager = fixture.makeManager()
        let managedHelper = try manager.prepareRuntime()
        let externalVenv = fixture.root.appendingPathComponent("external-venv", isDirectory: true)
        let venvURL = managedHelper.appendingPathComponent(".venv", isDirectory: true)
        try FileManager.default.createDirectory(at: externalVenv, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: venvURL, withDestinationURL: externalVenv)
        try fixture.writeBundledHelperManifest(version: "2026.07.12", sourceCommit: "updated")

        XCTAssertThrowsError(try manager.prepareRuntime()) { error in
            XCTAssertEqual(error as? HelperProcessError, .helperDirectoryNotFound)
        }
        let attributes = try FileManager.default.attributesOfItem(atPath: venvURL.path)
        XCTAssertEqual(attributes[.type] as? FileAttributeType, .typeSymbolicLink)
        XCTAssertEqual(manager.snapshot().helperCopyStatus, .needsRepair)
    }

    func testFinalManagedCopyMoveFailureRestoresPriorValidCopy() throws {
        let fixture = try HelperRuntimeFixture.make()
        let initialManager = fixture.makeManager()
        let managedHelper = try initialManager.prepareRuntime()
        let sentinel = managedHelper.appendingPathComponent("prior-copy-sentinel.txt")
        let venvSentinel = managedHelper.appendingPathComponent(".venv/bin/sentinel.txt")
        try "keep".write(to: sentinel, atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(
            at: venvSentinel.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try "keep venv".write(to: venvSentinel, atomically: true, encoding: .utf8)
        try fixture.writeBundledHelperManifest(version: "2026.07.12", sourceCommit: "updated")
        let failingManager = fixture.makeManager { source, destination in
            if source.lastPathComponent.hasPrefix(".qwen-asr-helper-staging-"),
               destination.standardizedFileURL == initialManager.helperCopyDirectory.standardizedFileURL {
                throw InjectedMoveError.finalInstallFailed
            }
            try FileManager.default.moveItem(at: source, to: destination)
        }

        XCTAssertThrowsError(try failingManager.prepareRuntime()) { error in
            XCTAssertEqual(error as? InjectedMoveError, .finalInstallFailed)
        }
        XCTAssertEqual(try String(contentsOf: sentinel), "keep")
        XCTAssertEqual(try String(contentsOf: venvSentinel), "keep venv")
        XCTAssertEqual(failingManager.snapshot().helperCopyStatus, .needsRepair)
    }

    func testManifestRolesDeriveBundledRootsAndCopyEveryDeclaredHelperFile() throws {
        let fixture = try HelperRuntimeFixture.make(
            helperRootRelativePath: "Runtime/embedded-helper",
            uvRelativePath: "Runtime/bin/custom-uv",
            helperFiles: HelperRuntimeFixture.requiredHelperFiles + ["qwen_asr_helper/future.py"]
        )
        let manager = fixture.makeManager()

        let helperURL = try manager.prepareRuntime()

        XCTAssertEqual(manager.bundledUVExecutable?.path, fixture.bundledUVURL.path)
        XCTAssertEqual(manager.snapshot().bundledHelperDirectory?.path, fixture.bundledHelperRoot.path)
        for path in fixture.helperFiles {
            XCTAssertTrue(FileManager.default.fileExists(atPath: helperURL.appendingPathComponent(path).path), path)
        }
        XCTAssertEqual(
            try HelperManifest.read(fromHelperRoot: helperURL),
            try HelperManifest.read(fromHelperRoot: fixture.bundledHelperRoot)
        )
    }

    func testPrepareRuntimeDoesNotCopyHelperFileAbsentFromManifest() throws {
        let fixture = try HelperRuntimeFixture.make()
        try "not declared".write(
            to: fixture.bundledHelperRoot.appendingPathComponent("qwen_asr_helper/unlisted.py"),
            atomically: true,
            encoding: .utf8
        )

        let helperURL = try fixture.makeManager().prepareRuntime()

        XCTAssertFalse(FileManager.default.fileExists(
            atPath: helperURL.appendingPathComponent("qwen_asr_helper/unlisted.py").path
        ))
    }

    func testPrepareRuntimeRejectsMissingManifestRequiredFileBeforeMutatingManagedCopy() throws {
        let fixture = try HelperRuntimeFixture.make()
        let manager = fixture.makeManager()
        try FileManager.default.createDirectory(at: manager.helperCopyDirectory, withIntermediateDirectories: true)
        let sentinel = manager.helperCopyDirectory.appendingPathComponent("sentinel.txt")
        try "keep".write(to: sentinel, atomically: true, encoding: .utf8)
        try FileManager.default.removeItem(
            at: fixture.bundledHelperRoot.appendingPathComponent("qwen_asr_helper/schemas.py")
        )

        XCTAssertThrowsError(try manager.prepareRuntime()) { error in
            XCTAssertEqual(error as? HelperProcessError, .helperDirectoryNotFound)
        }
        XCTAssertEqual(try String(contentsOf: sentinel), "keep")
    }

    func testRepairHelperCopyPreservesModelCaches() throws {
        let fixture = try HelperRuntimeFixture.make()
        let modelsSentinel = fixture.applicationSupportRoot
            .appendingPathComponent("Models/qwen3-asr-0.6b/sentinel.txt")
        try FileManager.default.createDirectory(
            at: modelsSentinel.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try "keep".write(to: modelsSentinel, atomically: true, encoding: .utf8)
        let manager = fixture.makeManager()
        try FileManager.default.createDirectory(at: manager.helperCopyDirectory, withIntermediateDirectories: true)
        let staleManagedFile = manager.helperCopyDirectory.appendingPathComponent("stale.txt")
        try "remove".write(to: staleManagedFile, atomically: true, encoding: .utf8)

        _ = try manager.repairHelperCopy()

        XCTAssertEqual(try String(contentsOf: modelsSentinel), "keep")
        XCTAssertFalse(FileManager.default.fileExists(atPath: staleManagedFile.path))
    }

    func testPrepareRuntimeThrowsWhenBundledUVIsMissing() throws {
        let fixture = try HelperRuntimeFixture.make()
        try FileManager.default.removeItem(at: fixture.bundledUVURL)

        XCTAssertThrowsError(try fixture.makeManager().prepareRuntime()) { error in
            XCTAssertEqual(error as? HelperProcessError, .bundledUVUnavailable)
        }
    }

    func testPrepareRuntimeThrowsWhenBundledManifestIsMissing() throws {
        let fixture = try HelperRuntimeFixture.make()
        try FileManager.default.removeItem(
            at: fixture.bundledHelperRoot.appendingPathComponent(HelperManifest.fileName)
        )

        XCTAssertThrowsError(try fixture.makeManager().prepareRuntime()) { error in
            XCTAssertEqual(error as? HelperProcessError, .helperManifestInvalid)
        }
    }

    func testPrepareRuntimeThrowsWhenBundledManifestIsMalformed() throws {
        let fixture = try HelperRuntimeFixture.make()
        try "{".write(
            to: fixture.bundledHelperRoot.appendingPathComponent(HelperManifest.fileName),
            atomically: true,
            encoding: .utf8
        )

        XCTAssertThrowsError(try fixture.makeManager().prepareRuntime()) { error in
            XCTAssertEqual(error as? HelperProcessError, .helperManifestInvalid)
        }
    }

    func testPrepareRuntimeThrowsWhenBundledManifestHashDoesNotMatchUVLock() throws {
        let fixture = try HelperRuntimeFixture.make()
        try "changed lock".write(
            to: fixture.bundledHelperRoot.appendingPathComponent("uv.lock"),
            atomically: true,
            encoding: .utf8
        )

        XCTAssertThrowsError(try fixture.makeManager().prepareRuntime()) { error in
            XCTAssertEqual(error as? HelperProcessError, .helperManifestInvalid)
        }
    }

    func testSnapshotReportsCopiedHelperManifestMismatchAsNeedsRepairAndBundledUVReady() throws {
        let fixture = try HelperRuntimeFixture.make()
        let manager = fixture.makeManager()
        _ = try manager.prepareRuntime()
        try HelperManifest(
            helperSchema: 1,
            flowtypeHelperVersion: "old",
            sourceCommit: "old",
            requiresUVLockHash: "old",
            createdAt: "2026-05-16"
        ).write(toHelperRoot: manager.helperCopyDirectory)

        let snapshot = manager.snapshot()

        XCTAssertEqual(snapshot.helperCopyStatus, .needsRepair)
        XCTAssertEqual(snapshot.bundledUVStatus, .ready)
    }

    func testSnapshotReportsBundledManifestHashMismatchAsNeedsRepair() throws {
        let fixture = try HelperRuntimeFixture.make()
        let manager = fixture.makeManager()
        _ = try manager.prepareRuntime()
        try "changed bundled lock".write(
            to: fixture.bundledHelperRoot.appendingPathComponent("uv.lock"),
            atomically: true,
            encoding: .utf8
        )

        XCTAssertEqual(manager.snapshot().helperCopyStatus, .needsRepair)
    }

    func testSnapshotReportsCopiedManifestHashMismatchAsNeedsRepair() throws {
        let fixture = try HelperRuntimeFixture.make()
        let manager = fixture.makeManager()
        _ = try manager.prepareRuntime()
        try "changed copied lock".write(
            to: manager.helperCopyDirectory.appendingPathComponent("uv.lock"),
            atomically: true,
            encoding: .utf8
        )

        XCTAssertEqual(manager.snapshot().helperCopyStatus, .needsRepair)
    }

    func testHelperProcessManagerDelegatesManagedHelperValidationToRuntimeManager() throws {
        let fixture = try HelperRuntimeFixture.make()
        let runtimeManager = fixture.makeManager()
        let managedHelper = try runtimeManager.prepareRuntime()
        try FileManager.default.removeItem(
            at: managedHelper.appendingPathComponent("qwen_asr_helper/schemas.py")
        )
        let processManager = HelperProcessManager(
            modelManager: ModelManager(applicationSupportRoot: fixture.applicationSupportRoot),
            runtimeManager: runtimeManager
        )

        XCTAssertFalse(processManager.isHelperDirectory(managedHelper))
    }

    func testManagedHelperValidationRejectsMalformedManifest() throws {
        let fixture = try HelperRuntimeFixture.make()
        let runtimeManager = fixture.makeManager()
        let managedHelper = try runtimeManager.prepareRuntime()
        try "{".write(
            to: managedHelper.appendingPathComponent(HelperManifest.fileName),
            atomically: true,
            encoding: .utf8
        )

        XCTAssertFalse(runtimeManager.isManagedHelperDirectory(managedHelper))
    }

    func testManagedHelperValidationRejectsManifestIncompatibleWithBundledHelper() throws {
        let fixture = try HelperRuntimeFixture.make()
        let runtimeManager = fixture.makeManager()
        let managedHelper = try runtimeManager.prepareRuntime()
        try HelperManifest(
            helperSchema: 1,
            flowtypeHelperVersion: "incompatible",
            sourceCommit: "other",
            requiresUVLockHash: try HelperManifest.uvLockHash(forHelperRoot: managedHelper),
            createdAt: "2026-07-11"
        ).write(toHelperRoot: managedHelper)

        XCTAssertFalse(runtimeManager.isManagedHelperDirectory(managedHelper))
    }

    func testManagedHelperValidationRejectsAlteredUVLock() throws {
        let fixture = try HelperRuntimeFixture.make()
        let runtimeManager = fixture.makeManager()
        let managedHelper = try runtimeManager.prepareRuntime()
        try "altered".write(
            to: managedHelper.appendingPathComponent("uv.lock"),
            atomically: true,
            encoding: .utf8
        )

        XCTAssertFalse(runtimeManager.isManagedHelperDirectory(managedHelper))
    }

    func testRepositoryHelperValidatorRetainsMinimalRunnablePredicate() throws {
        let fixture = try HelperRuntimeFixture.make()
        let repositoryHelper = fixture.root.appendingPathComponent("repository-helper", isDirectory: true)
        try HelperRuntimeFixture.writeHelperFiles(
            at: repositoryHelper,
            paths: ["pyproject.toml", "uv.lock", "qwen_asr_helper/server.py"]
        )
        let processManager = HelperProcessManager(
            modelManager: ModelManager(applicationSupportRoot: fixture.applicationSupportRoot),
            runtimeManager: fixture.makeManager()
        )

        XCTAssertTrue(processManager.isHelperDirectory(repositoryHelper))
        try FileManager.default.removeItem(at: repositoryHelper.appendingPathComponent("uv.lock"))
        XCTAssertFalse(processManager.isHelperDirectory(repositoryHelper))
    }

    func testHelperProcessManagerUsesRepositoryFallbackWhenBundledUVIsMissing() throws {
        let fixture = try HelperRuntimeFixture.make()
        try FileManager.default.removeItem(at: fixture.bundledUVURL)
        let runtimeManager = fixture.makeManager()
        let processManager = HelperProcessManager(
            modelManager: ModelManager(applicationSupportRoot: fixture.applicationSupportRoot),
            runtimeManager: runtimeManager
        )

        let helperDirectory = try processManager.resolveHelperDirectory()

        XCTAssertNotEqual(helperDirectory.path, runtimeManager.helperCopyDirectory.path)
        XCTAssertTrue(helperDirectory.path.hasSuffix("Helpers/qwen-asr-helper"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: runtimeManager.helperCopyDirectory.path))
    }

    func testHelperDirectoryOverrideRetainsRepositoryValidatorBehavior() throws {
        let fixture = try HelperRuntimeFixture.make()
        let override = fixture.root.appendingPathComponent("override-helper", isDirectory: true)
        try HelperRuntimeFixture.writeHelperFiles(
            at: override,
            paths: ["pyproject.toml", "uv.lock", "qwen_asr_helper/server.py"]
        )
        let previousOverride = ProcessInfo.processInfo.environment["VOICEINPUT_HELPER_DIR"]
        setenv("VOICEINPUT_HELPER_DIR", override.path, 1)
        defer {
            if let previousOverride {
                setenv("VOICEINPUT_HELPER_DIR", previousOverride, 1)
            } else {
                unsetenv("VOICEINPUT_HELPER_DIR")
            }
        }
        let processManager = HelperProcessManager(
            modelManager: ModelManager(applicationSupportRoot: fixture.applicationSupportRoot),
            runtimeManager: fixture.makeManager()
        )

        XCTAssertEqual(try processManager.resolveHelperDirectory().path, override.path)
    }

    func testManagedHelperOverrideCannotBypassManifestIntegrityValidation() throws {
        let fixture = try HelperRuntimeFixture.make()
        let runtimeManager = fixture.makeManager()
        let managedHelper = try runtimeManager.prepareRuntime()
        try "{".write(
            to: managedHelper.appendingPathComponent(HelperManifest.fileName),
            atomically: true,
            encoding: .utf8
        )
        try FileManager.default.removeItem(at: fixture.bundledUVURL)
        let previousOverride = ProcessInfo.processInfo.environment["VOICEINPUT_HELPER_DIR"]
        setenv("VOICEINPUT_HELPER_DIR", managedHelper.path, 1)
        defer {
            if let previousOverride {
                setenv("VOICEINPUT_HELPER_DIR", previousOverride, 1)
            } else {
                unsetenv("VOICEINPUT_HELPER_DIR")
            }
        }
        let processManager = HelperProcessManager(
            modelManager: ModelManager(applicationSupportRoot: fixture.applicationSupportRoot),
            runtimeManager: runtimeManager
        )

        XCTAssertNotEqual(try processManager.resolveHelperDirectory().standardizedFileURL, managedHelper.standardizedFileURL)
    }

    func testAppManagedHelperCopyRequiresBundledUVLaunchCommand() throws {
        let fixture = try HelperRuntimeFixture.make()
        try FileManager.default.removeItem(at: fixture.bundledUVURL)
        let runtimeManager = fixture.makeManager()
        let processManager = HelperProcessManager(
            modelManager: ModelManager(applicationSupportRoot: fixture.applicationSupportRoot),
            runtimeManager: runtimeManager
        )

        XCTAssertThrowsError(try processManager.resolveUVLaunchCommand(helperDir: runtimeManager.helperCopyDirectory)) { error in
            XCTAssertEqual(error as? HelperProcessError, .bundledUVUnavailable)
        }
    }

    func testManagedHelperAliasPathCannotFallThroughToEnvironmentUV() throws {
        let fixture = try HelperRuntimeFixture.make()
        try FileManager.default.removeItem(at: fixture.bundledUVURL)
        let runtimeManager = fixture.makeManager()
        let processManager = HelperProcessManager(
            modelManager: ModelManager(applicationSupportRoot: fixture.applicationSupportRoot),
            runtimeManager: runtimeManager
        )
        let alias = runtimeManager.helperCopyDirectory
            .appendingPathComponent("..", isDirectory: true)
            .appendingPathComponent(runtimeManager.helperCopyDirectory.lastPathComponent, isDirectory: true)

        XCTAssertThrowsError(try processManager.resolveUVLaunchCommand(helperDir: alias)) { error in
            XCTAssertEqual(error as? HelperProcessError, .bundledUVUnavailable)
        }
    }

    func testRepositoryFallbackMayLaunchThroughEnvironmentUV() throws {
        let fixture = try HelperRuntimeFixture.make()
        try FileManager.default.removeItem(at: fixture.bundledUVURL)
        let processManager = HelperProcessManager(
            modelManager: ModelManager(applicationSupportRoot: fixture.applicationSupportRoot),
            runtimeManager: fixture.makeManager()
        )
        let repositoryHelper = fixture.root.appendingPathComponent("repository-helper", isDirectory: true)

        let command = try processManager.resolveUVLaunchCommand(helperDir: repositoryHelper)

        XCTAssertEqual(command.executableURL.path, "/usr/bin/env")
        XCTAssertEqual(command.arguments.prefix(2), ["uv", "run"])
    }
}

private struct HelperRuntimeFixture {
    static let requiredHelperFiles = [
        "README.md",
        HelperManifest.fileName,
        "pyproject.toml",
        "qwen_asr_helper/__init__.py",
        "qwen_asr_helper/schemas.py",
        "qwen_asr_helper/server.py",
        "uv.lock"
    ]

    let root: URL
    let applicationSupportRoot: URL
    let resourceURL: URL
    let bundledHelperRoot: URL
    let bundledUVURL: URL
    let helperFiles: [String]

    func makeManager(
        moveItem: ((URL, URL) throws -> Void)? = nil
    ) -> HelperRuntimeManager {
        HelperRuntimeManager(
            applicationSupportRoot: applicationSupportRoot,
            bundleResourceURL: resourceURL,
            moveItem: moveItem
        )
    }

    func writeBundledHelperManifest(version: String, sourceCommit: String) throws {
        let uvLockHash = try HelperManifest.uvLockHash(forHelperRoot: bundledHelperRoot)
        try HelperManifest(
            helperSchema: 1,
            flowtypeHelperVersion: version,
            sourceCommit: sourceCommit,
            requiresUVLockHash: uvLockHash,
            createdAt: "2026-07-12"
        ).write(toHelperRoot: bundledHelperRoot)
    }

    static func make(
        helperRootRelativePath: String = "Helpers/qwen-asr-helper",
        uvRelativePath: String = "Tools/uv",
        helperFiles: [String] = requiredHelperFiles
    ) throws -> HelperRuntimeFixture {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("flowtype-helper-runtime-\(UUID().uuidString)", isDirectory: true)
        let support = root.appendingPathComponent("Application Support/Flowtype", isDirectory: true)
        let resourceURL = root.appendingPathComponent("Flowtype.app/Contents/Resources", isDirectory: true)
        let bundled = resourceURL.appendingPathComponent(helperRootRelativePath, isDirectory: true)
        let uvURL = resourceURL.appendingPathComponent(uvRelativePath)

        try writeHelperFiles(at: bundled, paths: helperFiles.filter { $0 != HelperManifest.fileName })
        try FileManager.default.createDirectory(at: uvURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "uv".write(to: uvURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: uvURL.path)
        try "artwork".write(
            to: resourceURL.appendingPathComponent("HomeCardArtwork-mic.png"),
            atomically: true,
            encoding: .utf8
        )
        let uvLockHash = try HelperManifest.uvLockHash(forHelperRoot: bundled)
        try HelperManifest(
            helperSchema: 1,
            flowtypeHelperVersion: "2026.05.17",
            sourceCommit: "442840e",
            requiresUVLockHash: uvLockHash,
            createdAt: "2026-05-17"
        ).write(toHelperRoot: bundled)
        try writeManifest(
            resourceURL: resourceURL,
            helperRootRelativePath: helperRootRelativePath,
            uvRelativePath: uvRelativePath,
            helperFiles: helperFiles
        )

        return HelperRuntimeFixture(
            root: root,
            applicationSupportRoot: support,
            resourceURL: resourceURL,
            bundledHelperRoot: bundled,
            bundledUVURL: uvURL,
            helperFiles: helperFiles
        )
    }

    static func writeHelperFiles(at root: URL, paths: [String]) throws {
        for path in paths {
            let url = root.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let content = path == "uv.lock" ? "lock" : "fixture: \(path)"
            try content.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private static func writeManifest(
        resourceURL: URL,
        helperRootRelativePath: String,
        uvRelativePath: String,
        helperFiles: [String]
    ) throws {
        var entries: [[String: Any]] = [
            entry(id: "app-binary", path: "Contents/MacOS/Flowtype", group: "app-binary"),
            entry(id: "flowtype-icon", path: "Contents/Resources/Flowtype.icns", group: "flowtype-icon"),
            entry(
                id: "home-card-artwork-mic",
                path: "Contents/Resources/HomeCardArtwork-mic.png",
                group: "home-card-artwork"
            ),
            entry(id: "qwen-logo", path: "Contents/Resources/Qwen-logo.svg", group: "qwen-logo"),
            entry(
                id: "bundled-uv",
                path: "Contents/Resources/\(uvRelativePath)",
                executable: true,
                group: "bundled-uv"
            )
        ]
        entries += helperFiles.map { path in
            entry(
                id: path == HelperManifest.fileName ? "helper-manifest" : "helper:\(path)",
                path: "Contents/Resources/\(helperRootRelativePath)/\(path)",
                group: path == HelperManifest.fileName ? "helper-manifest" : "bundled-qwen-helper",
                helperPath: path
            )
        }
        entries.sort { ($0["relativePath"] as! String) < ($1["relativePath"] as! String) }
        let manifest: [String: Any] = [
            "runtimeSchemaVersion": 1,
            "authoringContractSHA256": String(repeating: "a", count: 64),
            "entries": entries,
            "forbiddenContent": []
        ]
        let data = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
        try FileManager.default.createDirectory(at: resourceURL, withIntermediateDirectories: true)
        try data.write(to: resourceURL.appendingPathComponent(AppBundleManifest.fileName))
    }

    private static func entry(
        id: String,
        path: String,
        executable: Bool = false,
        group: String,
        helperPath: String? = nil
    ) -> [String: Any] {
        var value: [String: Any] = [
            "artifactID": id,
            "relativePath": path,
            "kind": "file",
            "executable": executable,
            "inspectionGroup": group
        ]
        if let helperPath {
            value["helperRuntimeRelativePath"] = helperPath
        }
        return value
    }
}

private enum InjectedMoveError: Error, Equatable {
    case finalInstallFailed
}
