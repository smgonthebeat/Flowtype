import Foundation

struct ReadinessLocationResolver {
    let bundleURL: URL
    let resourceURL: URL?
    let applicationSupportRoot: URL
    let selectedModel: VoiceInputModel

    func url(for target: ReadinessLocationTarget) -> URL {
        switch target {
        case .appBundle:
            return bundleURL
        case .appResources:
            return resourceURL ?? bundleURL.appendingPathComponent("Contents/Resources", isDirectory: true)
        case .applicationSupportRoot:
            return applicationSupportRoot
        case .localHelper:
            return applicationSupportRoot.appendingPathComponent("qwen-asr-helper", isDirectory: true)
        case .modelsRoot:
            return applicationSupportRoot.appendingPathComponent("Models", isDirectory: true)
        case .selectedModel:
            return applicationSupportRoot
                .appendingPathComponent("Models", isDirectory: true)
                .appendingPathComponent(selectedModel.directoryName, isDirectory: true)
        case .diagnostics:
            return applicationSupportRoot.appendingPathComponent("Diagnostics", isDirectory: true)
        }
    }

    func nearestExistingURL(for url: URL) -> URL {
        var candidate = url
        while candidate.path != "/" {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDirectory) {
                return candidate
            }
            candidate.deleteLastPathComponent()
        }
        return URL(fileURLWithPath: "/")
    }
}
