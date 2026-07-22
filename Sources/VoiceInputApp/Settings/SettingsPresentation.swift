import Foundation

enum SettingsPresentation {
    static func primaryEngineName(selectedModelID: String) -> String {
        "\(VoiceInputModel.model(for: selectedModelID).displayName) Local"
    }

    static func modelsRootPath(applicationSupportRoot: URL? = nil) -> String {
        ModelManager(applicationSupportRoot: applicationSupportRoot).modelsRoot.path
    }

    static func retainedRecordingsPath(applicationSupportRoot: URL? = nil) -> String {
        if let applicationSupportRoot {
            return applicationSupportRoot
                .appendingPathComponent("Recordings", isDirectory: true)
                .path
        }
        return (try? RetainedRecordingStore.defaultStore().directoryURL.path)
            ?? "Application Support/\(ApplicationSupport.appDirectoryName)/Recordings"
    }
}
