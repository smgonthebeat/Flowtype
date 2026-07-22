import Foundation

struct PackageInspector {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func inspect(
        bundleURL: URL = Bundle.main.bundleURL,
        resourceURL: URL? = Bundle.main.resourceURL
    ) -> [ReadinessCheck] {
        guard let resourceURL else {
            return [appResourcesFailure()]
        }

        do {
            let manifest = try AppBundleManifest.read(from: resourceURL, fileManager: fileManager)
            let resolvedEntries = try Dictionary(
                uniqueKeysWithValues: manifest.entries.map { entry in
                    (
                        entry.artifactID,
                        try manifest.resolvedURL(
                            for: entry,
                            bundleURL: bundleURL,
                            fileManager: fileManager
                        )
                    )
                }
            )

            return [
                fileCheck(
                    manifest: manifest,
                    resolvedEntries: resolvedEntries,
                    inspectionGroup: "app-binary",
                    title: "Flowtype app binary",
                    readyDetail: "The Flowtype executable is present.",
                    failureMessage: "The app binary is missing.",
                    locationTarget: .appBundle
                ),
                fileCheck(
                    manifest: manifest,
                    resolvedEntries: resolvedEntries,
                    inspectionGroup: "bundled-uv",
                    title: "Bundled uv",
                    readyDetail: "Bundled uv is present and executable.",
                    failureMessage: "Bundled uv is missing or not executable.",
                    locationTarget: .appResources
                ),
                helperCheck(manifest: manifest, resolvedEntries: resolvedEntries),
                manifestCheck(manifest: manifest, resolvedEntries: resolvedEntries),
                fileCheck(
                    manifest: manifest,
                    resolvedEntries: resolvedEntries,
                    inspectionGroup: "flowtype-icon",
                    title: "Flowtype icon",
                    readyDetail: "The app icon resource is present.",
                    failureMessage: "Flowtype.icns is missing.",
                    locationTarget: .appResources
                ),
                fileCheck(
                    manifest: manifest,
                    resolvedEntries: resolvedEntries,
                    inspectionGroup: "qwen-logo",
                    title: "Qwen logo",
                    readyDetail: "The Qwen logo resource is present.",
                    failureMessage: "Qwen-logo.svg is missing.",
                    locationTarget: .appResources
                )
            ]
        } catch {
            return [appResourcesFailure()]
        }
    }

    private func appResourcesFailure() -> ReadinessCheck {
        ReadinessCheck(
            id: "app-resources",
            group: .appBundle,
            title: "App resources",
            detail: "Flowtype could not locate its bundled resources.",
            status: .failed("Bundle resources are unavailable."),
            primaryAction: .reinstallFlowtypeApp,
            secondaryAction: .copyDiagnostics,
            locationTarget: .appBundle
        )
    }

    private func fileCheck(
        manifest: AppBundleManifest,
        resolvedEntries: [String: URL],
        inspectionGroup: String,
        title: String,
        readyDetail: String,
        failureMessage: String,
        locationTarget: ReadinessLocationTarget
    ) -> ReadinessCheck {
        let entries = manifest.entries(in: inspectionGroup)
        let complete = entries.allSatisfy { entry in
            guard let url = resolvedEntries[entry.artifactID], regularFileExists(at: url) else {
                return false
            }
            return !entry.executable || fileManager.isExecutableFile(atPath: url.path)
        }

        if complete {
            return ReadinessCheck(
                id: inspectionGroup,
                group: .appBundle,
                title: title,
                detail: readyDetail,
                status: .ready,
                locationTarget: locationTarget
            )
        }

        return failedCheck(id: inspectionGroup, title: title, detail: nil, failureMessage: failureMessage)
    }

    private func helperCheck(
        manifest: AppBundleManifest,
        resolvedEntries: [String: URL]
    ) -> ReadinessCheck {
        let entries = manifest.entries(in: "bundled-qwen-helper")
        let missing = entries.filter { entry in
            guard let url = resolvedEntries[entry.artifactID] else { return true }
            return !regularFileExists(at: url) ||
                (entry.executable && !fileManager.isExecutableFile(atPath: url.path))
        }

        if missing.isEmpty {
            return ReadinessCheck(
                id: "bundled-qwen-helper",
                group: .appBundle,
                title: "Bundled Qwen helper",
                detail: "The bundled helper source is present.",
                status: .ready,
                locationTarget: .appResources
            )
        }

        let missingPaths = missing.map { $0.helperRuntimeRelativePath ?? $0.relativePath }
        return failedCheck(
            id: "bundled-qwen-helper",
            title: "Bundled Qwen helper",
            detail: "Missing helper files: \(missingPaths.joined(separator: ", ")). Reinstall Flowtype from the DMG.",
            failureMessage: "Bundled helper is incomplete."
        )
    }

    private func manifestCheck(
        manifest: AppBundleManifest,
        resolvedEntries: [String: URL]
    ) -> ReadinessCheck {
        let entries = manifest.entries(in: "helper-manifest")
        guard entries.allSatisfy({ entry in
            resolvedEntries[entry.artifactID].map(regularFileExists(at:)) == true
        }),
        let entry = entries.first,
        let manifestURL = resolvedEntries[entry.artifactID],
        let helperRelativePath = entry.helperRuntimeRelativePath else {
            return failedCheck(
                id: "helper-manifest",
                title: "Helper version manifest",
                detail: nil,
                failureMessage: "Helper manifest is missing."
            )
        }

        let helperRootURL = helperRelativePath.split(separator: "/").reduce(manifestURL) { url, _ in
            url.deletingLastPathComponent()
        }

        do {
            let helperManifest = try HelperManifest.read(fromHelperRoot: helperRootURL)
            let uvLockHash = try HelperManifest.uvLockHash(forHelperRoot: helperRootURL)
            guard helperManifest.requiresUVLockHash == uvLockHash else {
                return failedCheck(
                    id: "helper-manifest",
                    title: "Helper version manifest",
                    detail: "The bundled helper manifest does not match uv.lock. Reinstall Flowtype from the DMG.",
                    failureMessage: "Helper manifest does not match uv.lock."
                )
            }
            return ReadinessCheck(
                id: "helper-manifest",
                group: .appBundle,
                title: "Helper version manifest",
                detail: "The bundled helper manifest is present.",
                status: .ready,
                locationTarget: .appResources
            )
        } catch {
            return failedCheck(
                id: "helper-manifest",
                title: "Helper version manifest",
                detail: "The bundled helper manifest could not be decoded. Reinstall Flowtype from the DMG.",
                failureMessage: "Helper manifest is invalid."
            )
        }
    }

    private func failedCheck(
        id: String,
        title: String,
        detail: String?,
        failureMessage: String
    ) -> ReadinessCheck {
        ReadinessCheck(
            id: id,
            group: .appBundle,
            title: title,
            detail: detail ?? "This Flowtype app bundle is incomplete. Reinstall Flowtype from the DMG.",
            status: .failed(failureMessage),
            primaryAction: .reinstallFlowtypeApp,
            secondaryAction: .copyDiagnostics,
            locationTarget: .appBundle
        )
    }

    private func regularFileExists(at url: URL) -> Bool {
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let type = attributes[.type] as? FileAttributeType else {
            return false
        }
        return type == .typeRegular
    }
}
