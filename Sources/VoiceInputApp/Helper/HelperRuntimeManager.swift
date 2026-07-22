import Foundation

struct HelperRuntimeSnapshot: Equatable {
    let applicationSupportStatus: ReadinessStatus
    let bundledUVStatus: ReadinessStatus
    let helperCopyStatus: ReadinessStatus
    let helperDirectory: URL
    let bundledHelperDirectory: URL?
}

final class HelperRuntimeManager {
    private enum Constants {
        static let helperSupportDirectory = "qwen-asr-helper"
        static let runtimeEnvironmentDirectory = ".venv"
    }

    let applicationSupportRoot: URL
    private let layout: AppBundleManifest.HelperRuntimeLayout?
    private let fileManager: FileManager
    private let moveItem: (URL, URL) throws -> Void

    init(
        applicationSupportRoot: URL? = nil,
        bundleResourceURL: URL? = Bundle.main.resourceURL,
        fileManager: FileManager = .default,
        moveItem: ((URL, URL) throws -> Void)? = nil
    ) {
        self.applicationSupportRoot = applicationSupportRoot ?? ((try? ApplicationSupport.directory(fileManager: fileManager)) ??
            fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(ApplicationSupport.appDirectoryName, isDirectory: true))
        self.layout = bundleResourceURL.flatMap { resourceURL in
            guard let manifest = try? AppBundleManifest.read(from: resourceURL, fileManager: fileManager) else {
                return nil
            }
            return try? manifest.helperRuntimeLayout(resourceURL: resourceURL)
        }
        self.fileManager = fileManager
        self.moveItem = moveItem ?? { source, destination in
            try fileManager.moveItem(at: source, to: destination)
        }
    }

    var helperCopyDirectory: URL {
        applicationSupportRoot.appendingPathComponent(Constants.helperSupportDirectory, isDirectory: true)
    }

    var bundledUVExecutable: URL? {
        guard let bundledUVURL = layout?.bundledUVURL,
              isRegularFile(bundledUVURL),
              fileManager.isExecutableFile(atPath: bundledUVURL.path) else {
            return nil
        }
        return bundledUVURL
    }

    func snapshot() -> HelperRuntimeSnapshot {
        let validBundledHelperRoot = layout.flatMap {
            isManagedHelperDirectory($0.bundledHelperRoot) ? $0.bundledHelperRoot : nil
        }
        return HelperRuntimeSnapshot(
            applicationSupportStatus: directoryExists(applicationSupportRoot) ? .ready : .notReady,
            bundledUVStatus: bundledUVExecutable == nil
                ? .failed("Bundled uv is missing or not executable.")
                : .ready,
            helperCopyStatus: helperCopyReadiness(),
            helperDirectory: helperCopyDirectory,
            bundledHelperDirectory: validBundledHelperRoot
        )
    }

    func prepareRuntime() throws -> URL {
        try prepareRuntime(reuseReadyCopy: true, preserveRuntimeEnvironment: true)
    }

    func repairHelperCopy() throws -> URL {
        try prepareRuntime(reuseReadyCopy: false, preserveRuntimeEnvironment: false)
    }

    private func prepareRuntime(
        reuseReadyCopy: Bool,
        preserveRuntimeEnvironment: Bool
    ) throws -> URL {
        guard bundledUVExecutable != nil else {
            throw HelperProcessError.bundledUVUnavailable
        }
        guard let layout,
              manifestMatchesUVLock(at: layout.bundledHelperRoot) else {
            throw HelperProcessError.helperManifestInvalid
        }
        guard layout.files.allSatisfy({ isRegularFile($0.sourceURL) }) else {
            throw HelperProcessError.helperDirectoryNotFound
        }
        let runtimeEnvironment = preserveRuntimeEnvironment
            ? try runtimeEnvironmentDirectoryIfPresent()
            : nil
        if reuseReadyCopy, helperCopyReadiness() == .ready {
            return helperCopyDirectory
        }
        try fileManager.createDirectory(at: applicationSupportRoot, withIntermediateDirectories: true)
        return try copyBundledHelperToApplicationSupport(
            preserveRuntimeEnvironment: runtimeEnvironment != nil
        )
    }

    private func helperCopyReadiness() -> ReadinessStatus {
        guard directoryExists(helperCopyDirectory) else {
            return .notReady
        }
        guard isManagedHelperDirectory(helperCopyDirectory) else {
            return .needsRepair
        }
        guard let bundledHelperRoot = layout?.bundledHelperRoot,
              manifestMatchesUVLock(at: bundledHelperRoot),
              manifestMatchesUVLock(at: helperCopyDirectory),
              let bundledManifest = try? HelperManifest.read(fromHelperRoot: bundledHelperRoot),
              let copiedManifest = try? HelperManifest.read(fromHelperRoot: helperCopyDirectory) else {
            return .needsRepair
        }
        return copiedManifest.matchesBundledHelper(bundledManifest) ? .ready : .needsRepair
    }

    private func copyBundledHelperToApplicationSupport(
        preserveRuntimeEnvironment: Bool
    ) throws -> URL {
        guard let layout,
              isManagedHelperDirectory(layout.bundledHelperRoot) else {
            throw HelperProcessError.helperDirectoryNotFound
        }

        let stagingDirectory = applicationSupportRoot.appendingPathComponent(
            ".\(Constants.helperSupportDirectory)-staging-\(UUID().uuidString)",
            isDirectory: true
        )
        let backupDirectory = applicationSupportRoot.appendingPathComponent(
            ".\(Constants.helperSupportDirectory)-backup-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? fileManager.removeItem(at: stagingDirectory) }
        try fileManager.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
        for file in layout.files {
            let target = stagingDirectory.appendingPathComponent(file.relativePath)
            try fileManager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fileManager.copyItem(at: file.sourceURL, to: target)
        }

        guard isManagedHelperDirectory(stagingDirectory),
              manifestMatchesUVLock(at: stagingDirectory) else {
            throw HelperProcessError.helperDirectoryNotFound
        }
        let hadPriorCopy = fileManager.fileExists(atPath: helperCopyDirectory.path)
        if hadPriorCopy {
            try moveItem(helperCopyDirectory, backupDirectory)
        }
        let stagingRuntimeEnvironment = stagingDirectory.appendingPathComponent(
            Constants.runtimeEnvironmentDirectory,
            isDirectory: true
        )
        let backupRuntimeEnvironment = backupDirectory.appendingPathComponent(
            Constants.runtimeEnvironmentDirectory,
            isDirectory: true
        )
        do {
            if preserveRuntimeEnvironment {
                try moveItem(backupRuntimeEnvironment, stagingRuntimeEnvironment)
            }
            try moveItem(stagingDirectory, helperCopyDirectory)
        } catch {
            if hadPriorCopy {
                if preserveRuntimeEnvironment,
                   fileManager.fileExists(atPath: stagingRuntimeEnvironment.path) {
                    try moveItem(stagingRuntimeEnvironment, backupRuntimeEnvironment)
                }
                try moveItem(backupDirectory, helperCopyDirectory)
            }
            throw error
        }
        if hadPriorCopy {
            try? fileManager.removeItem(at: backupDirectory)
        }
        return helperCopyDirectory
    }

    private func runtimeEnvironmentDirectoryIfPresent() throws -> URL? {
        let url = helperCopyDirectory.appendingPathComponent(
            Constants.runtimeEnvironmentDirectory,
            isDirectory: true
        )
        let attributes: [FileAttributeKey: Any]
        do {
            attributes = try fileManager.attributesOfItem(atPath: url.path)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return nil
        } catch {
            throw HelperProcessError.helperDirectoryNotFound
        }
        guard attributes[.type] as? FileAttributeType == .typeDirectory else {
            throw HelperProcessError.helperDirectoryNotFound
        }
        return url
    }

    func isManagedHelperPath(_ url: URL) -> Bool {
        canonicalURL(url) == canonicalURL(helperCopyDirectory)
    }

    func isManagedHelperDirectory(_ url: URL) -> Bool {
        guard let layout,
              layout.files.allSatisfy({ file in
                  isRegularFile(url.appendingPathComponent(file.relativePath))
              }),
              manifestMatchesUVLock(at: layout.bundledHelperRoot),
              manifestMatchesUVLock(at: url),
              let bundledManifest = try? HelperManifest.read(fromHelperRoot: layout.bundledHelperRoot),
              let candidateManifest = try? HelperManifest.read(fromHelperRoot: url) else {
            return false
        }
        return candidateManifest.matchesBundledHelper(bundledManifest)
    }

    private func directoryExists(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private func manifestMatchesUVLock(at helperRoot: URL) -> Bool {
        guard let layout,
              layout.helperManifestRelativePath == HelperManifest.fileName,
              layout.uvLockRelativePath == "uv.lock",
              let manifest = try? HelperManifest.read(fromHelperRoot: helperRoot),
              let actualHash = try? HelperManifest.uvLockHash(forHelperRoot: helperRoot) else {
            return false
        }
        return manifest.requiresUVLockHash == actualHash
    }

    private func isRegularFile(_ url: URL) -> Bool {
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let type = attributes[.type] as? FileAttributeType else {
            return false
        }
        return type == .typeRegular
    }

    private func canonicalURL(_ url: URL) -> URL {
        url.standardizedFileURL.resolvingSymlinksInPath()
    }
}

enum HelperContentContract {
    static func isMinimalRepositoryHelper(
        at url: URL,
        fileManager: FileManager = .default
    ) -> Bool {
        ["pyproject.toml", "uv.lock", "qwen_asr_helper/server.py"].allSatisfy { path in
            guard let attributes = try? fileManager.attributesOfItem(
                atPath: url.appendingPathComponent(path).path
            ), let type = attributes[.type] as? FileAttributeType else {
                return false
            }
            return type == .typeRegular
        }
    }
}
