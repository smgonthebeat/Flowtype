import Foundation

struct AppBundleManifest: Decodable {
    static let fileName = "FlowtypeBundleManifest.json"
    static let supportedSchemaVersion = 1
    static let requiredInspectionGroups: Set<String> = [
        "app-binary",
        "bundled-uv",
        "bundled-qwen-helper",
        "helper-manifest",
        "flowtype-icon",
        "home-card-artwork",
        "qwen-logo"
    ]

    struct Entry: Decodable {
        let artifactID: String
        let relativePath: String
        let kind: String
        let executable: Bool
        let inspectionGroup: String
        let helperRuntimeRelativePath: String?
    }

    struct ForbiddenContent: Decodable {
        let root: String
        let patterns: [String]
    }

    struct HelperRuntimeLayout {
        struct File {
            let sourceURL: URL
            let relativePath: String
        }

        let bundledUVURL: URL
        let bundledHelperRoot: URL
        let files: [File]
        let helperManifestRelativePath: String
        let uvLockRelativePath: String
    }

    let runtimeSchemaVersion: Int
    let authoringContractSHA256: String
    let entries: [Entry]
    let forbiddenContent: [ForbiddenContent]

    static func read(
        from resourceURL: URL,
        fileManager: FileManager = .default
    ) throws -> AppBundleManifest {
        let manifestURL = resourceURL.appendingPathComponent(fileName)
        guard isRegularFile(at: manifestURL, fileManager: fileManager) else {
            throw ValidationError.invalidManifest
        }

        let manifest = try JSONDecoder().decode(
            AppBundleManifest.self,
            from: Data(contentsOf: manifestURL)
        )
        try manifest.validate()
        return manifest
    }

    func entries(in inspectionGroup: String) -> [Entry] {
        entries.filter { $0.inspectionGroup == inspectionGroup }
    }

    func resolvedURL(
        for entry: Entry,
        bundleURL: URL,
        fileManager: FileManager = .default
    ) throws -> URL {
        try Self.validateRelativePath(entry.relativePath)
        var componentURL = bundleURL.standardizedFileURL
        guard !Self.isSymbolicLink(at: componentURL, fileManager: fileManager) else {
            throw ValidationError.invalidManifest
        }
        for component in entry.relativePath.split(separator: "/") {
            componentURL.appendPathComponent(String(component))
            guard !Self.isSymbolicLink(at: componentURL, fileManager: fileManager) else {
                throw ValidationError.invalidManifest
            }
        }
        let canonicalBundleURL = bundleURL.standardizedFileURL.resolvingSymlinksInPath()
        let resolvedURL = bundleURL
            .appendingPathComponent(entry.relativePath)
            .standardizedFileURL
            .resolvingSymlinksInPath()
        guard Self.isDescendant(resolvedURL, of: canonicalBundleURL) else {
            throw ValidationError.invalidManifest
        }
        return resolvedURL
    }

    func helperRuntimeLayout(resourceURL: URL) throws -> HelperRuntimeLayout {
        let bundleURL = resourceURL.deletingLastPathComponent().deletingLastPathComponent()
        let uvEntries = entries(in: "bundled-uv")
        let helperEntries = entries.filter { $0.helperRuntimeRelativePath != nil }
        let manifestEntries = entries(in: "helper-manifest")
        guard uvEntries.count == 1,
              let uvEntry = uvEntries.first,
              !helperEntries.isEmpty,
              manifestEntries.count == 1,
              let manifestPath = manifestEntries.first?.helperRuntimeRelativePath,
              manifestPath == HelperManifest.fileName,
              let uvLockEntry = helperEntries.first(where: { $0.helperRuntimeRelativePath == "uv.lock" }),
              let uvLockPath = uvLockEntry.helperRuntimeRelativePath,
              uvLockPath == "uv.lock" else {
            throw ValidationError.invalidManifest
        }

        let helperRoots = try Set(helperEntries.map(Self.helperRootRelativePath(for:)))
        guard helperRoots.count == 1, let helperRootRelativePath = helperRoots.first else {
            throw ValidationError.invalidManifest
        }
        let helperRootEntry = Entry(
            artifactID: "helper-root",
            relativePath: helperRootRelativePath,
            kind: "file",
            executable: false,
            inspectionGroup: "bundled-qwen-helper",
            helperRuntimeRelativePath: nil
        )

        return HelperRuntimeLayout(
            bundledUVURL: try resolvedURL(for: uvEntry, bundleURL: bundleURL),
            bundledHelperRoot: try resolvedURL(for: helperRootEntry, bundleURL: bundleURL),
            files: try helperEntries.map { entry in
                guard let relativePath = entry.helperRuntimeRelativePath else {
                    throw ValidationError.invalidManifest
                }
                return HelperRuntimeLayout.File(
                    sourceURL: try resolvedURL(for: entry, bundleURL: bundleURL),
                    relativePath: relativePath
                )
            },
            helperManifestRelativePath: manifestPath,
            uvLockRelativePath: uvLockPath
        )
    }

    private func validate() throws {
        guard runtimeSchemaVersion == Self.supportedSchemaVersion,
              Self.isLowercaseASCIIHexSHA256(authoringContractSHA256),
              !entries.isEmpty else {
            throw ValidationError.invalidManifest
        }

        var artifactIDs = Set<String>()
        var relativePaths = Set<String>()
        var previousPath: String?
        for entry in entries {
            guard !entry.artifactID.isEmpty,
                  entry.kind == "file",
                  Self.requiredInspectionGroups.contains(entry.inspectionGroup),
                  artifactIDs.insert(entry.artifactID).inserted,
                  relativePaths.insert(entry.relativePath).inserted else {
                throw ValidationError.invalidManifest
            }
            try Self.validateRelativePath(entry.relativePath)
            if let previousPath, previousPath >= entry.relativePath {
                throw ValidationError.invalidManifest
            }
            previousPath = entry.relativePath
            try Self.validateHelperRuntimeRole(for: entry)
        }

        guard Set(entries.map(\.inspectionGroup)) == Self.requiredInspectionGroups else {
            throw ValidationError.invalidManifest
        }

        let helperEntries = entries.filter { $0.helperRuntimeRelativePath != nil }
        guard !helperEntries.isEmpty,
              Set(try helperEntries.map(Self.helperRootRelativePath(for:))).count == 1 else {
            throw ValidationError.invalidManifest
        }

        for rule in forbiddenContent {
            try Self.validateRelativePath(rule.root)
            guard !rule.patterns.isEmpty,
                  rule.patterns.allSatisfy({ !$0.isEmpty }) else {
                throw ValidationError.invalidManifest
            }
        }
    }

    private static func validateHelperRuntimeRole(for entry: Entry) throws {
        let isHelperRole = entry.inspectionGroup == "bundled-qwen-helper" ||
            entry.inspectionGroup == "helper-manifest"
        if isHelperRole {
            guard entry.helperRuntimeRelativePath != nil else {
                throw ValidationError.invalidManifest
            }
            _ = try helperRootRelativePath(for: entry)
        } else if entry.helperRuntimeRelativePath != nil {
            throw ValidationError.invalidManifest
        }
    }

    private static func helperRootRelativePath(for entry: Entry) throws -> String {
        guard let helperRuntimeRelativePath = entry.helperRuntimeRelativePath else {
            throw ValidationError.invalidManifest
        }
        try validateRelativePath(helperRuntimeRelativePath)
        let suffix = "/" + helperRuntimeRelativePath
        guard entry.relativePath.hasPrefix("Contents/Resources/"),
              entry.relativePath.hasSuffix(suffix) else {
            throw ValidationError.invalidManifest
        }
        let root = String(entry.relativePath.dropLast(suffix.count))
        try validateRelativePath(root)
        return root
    }

    private static func validateRelativePath(_ path: String) throws {
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        guard !path.isEmpty,
              !path.hasPrefix("/"),
              !path.hasSuffix("/"),
              !components.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }) else {
            throw ValidationError.invalidManifest
        }
    }

    private static func isLowercaseASCIIHexSHA256(_ value: String) -> Bool {
        let bytes = Array(value.utf8)
        return bytes.count == 64 && bytes.allSatisfy { byte in
            (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte) ||
                (UInt8(ascii: "a")...UInt8(ascii: "f")).contains(byte)
        }
    }

    private static func isDescendant(_ candidate: URL, of root: URL) -> Bool {
        candidate.path.hasPrefix(root.path + "/")
    }

    private static func isRegularFile(at url: URL, fileManager: FileManager) -> Bool {
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let type = attributes[.type] as? FileAttributeType else {
            return false
        }
        return type == .typeRegular
    }

    private static func isSymbolicLink(at url: URL, fileManager: FileManager) -> Bool {
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let type = attributes[.type] as? FileAttributeType else {
            return false
        }
        return type == .typeSymbolicLink
    }

    private enum ValidationError: Error {
        case invalidManifest
    }
}
