import XCTest
@testable import VoiceInputApp

struct PackageFixture {
    static let expectedContractHash = "5126ff98c2e994ff8edc84a62949ec4027ca1da23b1741d0f12bf26c874f8bcc"

    let appURL: URL
    let resourcesURL: URL
    let helperURL: URL

    var manifestURL: URL {
        resourcesURL.appendingPathComponent("FlowtypeBundleManifest.json")
    }

    var helperManifestURL: URL {
        helperURL.appendingPathComponent(HelperManifest.fileName)
    }

    static func makeComplete(
        manifestMutation: ((inout [String: Any]) -> Void)? = nil
    ) throws -> PackageFixture {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("flowtype-package-\(UUID().uuidString)", isDirectory: true)
        let appURL = root.appendingPathComponent("Flowtype.app", isDirectory: true)
        let resourcesURL = appURL.appendingPathComponent("Contents/Resources", isDirectory: true)
        let helperURL = resourcesURL.appendingPathComponent("Helpers/qwen-asr-helper", isDirectory: true)
        let fixture = PackageFixture(appURL: appURL, resourcesURL: resourcesURL, helperURL: helperURL)

        let files: [(String, String, Bool)] = [
            ("Contents/Info.plist", "plist", false),
            ("Contents/MacOS/Flowtype", "binary", true),
            ("Contents/Resources/Flowtype-logo.svg", "logo", false),
            ("Contents/Resources/Flowtype-logo.png", "logo", false),
            ("Contents/Resources/Flowtype.icns", "icon", false),
            ("Contents/Resources/HomeCardArtwork-clock.png", "artwork", false),
            ("Contents/Resources/HomeCardArtwork-docs.png", "artwork", false),
            ("Contents/Resources/HomeCardArtwork-mic.png", "artwork", false),
            ("Contents/Resources/HomeCardArtwork-wave.png", "artwork", false),
            ("Contents/Resources/Qwen-logo.svg", "logo", false),
            ("Contents/Resources/Tools/uv", "uv", true),
            ("Contents/Resources/Helpers/qwen-asr-helper/pyproject.toml", "[project]\n", false),
            ("Contents/Resources/Helpers/qwen-asr-helper/uv.lock", "version = 1\n", false),
            ("Contents/Resources/Helpers/qwen-asr-helper/README.md", "helper\n", false),
            ("Contents/Resources/Helpers/qwen-asr-helper/qwen_asr_helper/__init__.py", "", false),
            ("Contents/Resources/Helpers/qwen-asr-helper/qwen_asr_helper/schemas.py", "class Request: pass\n", false),
            ("Contents/Resources/Helpers/qwen-asr-helper/qwen_asr_helper/server.py", "def main(): pass\n", false)
        ]
        for (relativePath, contents, executable) in files {
            let url = appURL.appendingPathComponent(relativePath)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Data(contents.utf8).write(to: url)
            if executable {
                try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
            }
        }

        let uvLockHash = try HelperManifest.uvLockHash(forHelperRoot: helperURL)
        try HelperManifest(
            helperSchema: 1,
            flowtypeHelperVersion: "2026.05.17",
            sourceCommit: "442840e",
            requiresUVLockHash: uvLockHash,
            createdAt: "2026-05-17"
        ).write(toHelperRoot: helperURL)

        let manifestFixtureURL = try XCTUnwrap(Bundle.module.url(
            forResource: "complete",
            withExtension: "json"
        ))
        var manifest = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: manifestFixtureURL)) as? [String: Any]
        )
        manifest["authoringContractSHA256"] = expectedContractHash
        manifest["entries"] = (manifest["entries"] as! [[String: Any]]).sorted {
            ($0["relativePath"] as! String) < ($1["relativePath"] as! String)
        }
        manifestMutation?(&manifest)
        try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
            .write(to: fixture.manifestURL)

        return fixture
    }
}
