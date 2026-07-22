import Foundation

enum ApplicationSupport {
    static let appDirectoryName = "Flowtype"
    static let legacyAppDirectoryName = "VoiceInput"

    static func directory(fileManager: FileManager = .default) throws -> URL {
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent(appDirectoryName, isDirectory: true)
        let legacyDirectory = base.appendingPathComponent(legacyAppDirectoryName, isDirectory: true)
        let resolvedDirectory = migrateLegacyDirectoryIfNeeded(
            from: legacyDirectory,
            to: directory,
            fileManager: fileManager
        )
        try fileManager.createDirectory(at: resolvedDirectory, withIntermediateDirectories: true)
        return resolvedDirectory
    }

    private static func migrateLegacyDirectoryIfNeeded(
        from legacyDirectory: URL,
        to directory: URL,
        fileManager: FileManager
    ) -> URL {
        var isDirectory: ObjCBool = false
        guard !fileManager.fileExists(atPath: directory.path) else { return directory }
        guard fileManager.fileExists(atPath: legacyDirectory.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return directory
        }

        do {
            try fileManager.moveItem(at: legacyDirectory, to: directory)
            return directory
        } catch {
            return legacyDirectory
        }
    }
}
