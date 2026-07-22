import Foundation

enum ModelDownloadState: Equatable {
    case notInstalled
    case downloading(Double?)
    case ready
    case repairNeeded
    case failed(String)
}

struct VoiceInputModel: Equatable, Identifiable {
    let id: String
    let modelID: String
    let displayName: String
    let directoryName: String

    static let qwen3ASR06B = VoiceInputModel(
        id: "qwen3-asr-0.6b",
        modelID: "Qwen/Qwen3-ASR-0.6B",
        displayName: "Qwen3-ASR 0.6B",
        directoryName: "qwen3-asr-0.6b"
    )

    static let qwen3ASR17B = VoiceInputModel(
        id: "qwen3-asr-1.7b",
        modelID: "Qwen/Qwen3-ASR-1.7B",
        displayName: "Qwen3-ASR 1.7B",
        directoryName: "qwen3-asr-1.7b"
    )

    static let all: [VoiceInputModel] = [.qwen3ASR06B, .qwen3ASR17B]

    static func model(for id: String) -> VoiceInputModel {
        all.first(where: { $0.id == id }) ?? .qwen3ASR06B
    }
}

final class ModelManager {
    let model: VoiceInputModel
    let applicationSupportRoot: URL

    init(model: VoiceInputModel = .qwen3ASR06B, applicationSupportRoot: URL? = nil) {
        self.model = model
        if let applicationSupportRoot {
            self.applicationSupportRoot = applicationSupportRoot
        } else {
            self.applicationSupportRoot = (try? ApplicationSupport.directory()) ??
                FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(ApplicationSupport.appDirectoryName, isDirectory: true)
        }
    }

    var modelDirectory: URL {
        applicationSupportRoot
            .appendingPathComponent("Models", isDirectory: true)
            .appendingPathComponent(model.directoryName, isDirectory: true)
    }

    var modelsRoot: URL {
        applicationSupportRoot.appendingPathComponent("Models", isDirectory: true)
    }

    var huggingFaceHome: URL {
        modelDirectory.appendingPathComponent("huggingface", isDirectory: true)
    }

    var transformersCache: URL {
        huggingFaceHome.appendingPathComponent("transformers", isDirectory: true)
    }

    var huggingFaceHubModelDirectory: URL {
        let cacheName = "models--\(model.modelID.replacingOccurrences(of: "/", with: "--"))"
        return huggingFaceHome
            .appendingPathComponent("hub", isDirectory: true)
            .appendingPathComponent(cacheName, isDirectory: true)
    }

    var markerFile: URL {
        modelDirectory.appendingPathComponent(".voiceinput-ready")
    }

    var isModelInstalled: Bool {
        hasCachedModelSnapshot
    }

    var needsRepair: Bool {
        !isModelInstalled && hasModelStorageFiles
    }

    private var hasCachedModelSnapshot: Bool {
        let snapshotsDirectory = huggingFaceHubModelDirectory.appendingPathComponent("snapshots", isDirectory: true)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: snapshotsDirectory.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return false
        }

        let snapshotURLs = (try? FileManager.default.contentsOfDirectory(
            at: snapshotsDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        return snapshotURLs.contains { url in
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
                return false
            }
            return Self.isValidSnapshotDirectory(url)
        }
    }

    private var hasModelStorageFiles: Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: modelDirectory.path, isDirectory: &isDirectory),
              isDirectory.boolValue,
              let enumerator = FileManager.default.enumerator(
                at: modelDirectory,
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
                options: [.skipsPackageDescendants]
              ) else {
            return false
        }

        for case let fileURL as URL in enumerator {
            guard fileURL.lastPathComponent != ".DS_Store" else { continue }
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory),
                  !isDirectory.boolValue else { continue }
            return true
        }
        return false
    }

    private static func isValidSnapshotDirectory(_ snapshotDirectory: URL) -> Bool {
        guard let enumerator = FileManager.default.enumerator(
            at: snapshotDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return false
        }

        var hasWeights = false
        var hasConfig = false

        for case let fileURL as URL in enumerator {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory),
                  !isDirectory.boolValue else { continue }

            switch fileURL.pathExtension.lowercased() {
            case "safetensors":
                hasWeights = true
            case "json":
                hasConfig = true
            default:
                break
            }

            if hasWeights && hasConfig {
                return true
            }
        }

        return false
    }

    func ensureDirectories() throws {
        try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
    }

    func markInstalled() throws {
        try ensureDirectories()
        try "ready".write(to: markerFile, atomically: true, encoding: .utf8)
    }

    /// Total size of the model's on-disk storage, or nil when nothing is stored.
    func storageSizeBytes() -> Int64? {
        guard let enumerator = FileManager.default.enumerator(
            at: modelDirectory,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsPackageDescendants]
        ) else {
            return nil
        }

        var total: Int64 = 0
        var sawFile = false
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  values.isRegularFile == true else {
                continue
            }
            sawFile = true
            total += Int64(values.fileSize ?? 0)
        }
        return sawFile ? total : nil
    }

    func resetModelStorage() throws {
        if FileManager.default.fileExists(atPath: modelDirectory.path) {
            try FileManager.default.removeItem(at: modelDirectory)
        }
        try ensureDirectories()
    }
}
