import Foundation
import XCTest
@testable import VoiceInputApp

final class AssembledAppBundleIntegrationTests: XCTestCase {
    func testAssembledAppSatisfiesSwiftRuntimeBundleContract() throws {
        let environmentVariable = "FLOWTYPE_ASSEMBLED_APP"
        guard let configuredPath = ProcessInfo.processInfo.environment[environmentVariable],
              !configuredPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw XCTSkip("Set \(environmentVariable) to an assembled Flowtype.app to run this integration test.")
        }

        let workingDirectoryURL = URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath,
            isDirectory: true
        )
        let appURL = URL(fileURLWithPath: configuredPath, relativeTo: workingDirectoryURL)
            .standardizedFileURL
        let bundle = try XCTUnwrap(
            Bundle(url: appURL),
            "\(environmentVariable) must point to a readable macOS app bundle: \(appURL.path)"
        )
        let resourceURL = try XCTUnwrap(
            bundle.resourceURL,
            "The assembled app bundle has no resource directory: \(appURL.path)"
        )

        let manifest = try AppBundleManifest.read(from: resourceURL)
        let checks = PackageInspector().inspect(bundleURL: appURL, resourceURL: resourceURL)
        let appBundleChecks = checks.filter { $0.group == .appBundle }
        let appBundleReady = !appBundleChecks.isEmpty && appBundleChecks.allSatisfy {
            $0.status == .ready || $0.status == .optional
        }
        let checkDiagnostic = checks.map { check in
            let message = check.status.message.map { ": \($0)" } ?? ""
            return "\(check.id)=\(check.status.badgeText)\(message)"
        }.joined(separator: ", ")
        XCTAssertTrue(
            appBundleReady,
            "PackageInspector reported appBundleReady=false for \(appURL.path): \(checkDiagnostic)"
        )

        let layout = try manifest.helperRuntimeLayout(resourceURL: resourceURL)
        XCTAssertTrue(
            FileManager.default.isExecutableFile(atPath: layout.bundledUVURL.path),
            "Bundled uv is missing or not executable: \(layout.bundledUVURL.path)"
        )

        var isHelperDirectory: ObjCBool = false
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: layout.bundledHelperRoot.path,
                isDirectory: &isHelperDirectory
            ),
            "Bundled helper is missing: \(layout.bundledHelperRoot.path)"
        )
        XCTAssertTrue(
            isHelperDirectory.boolValue,
            "Bundled helper path is not a directory: \(layout.bundledHelperRoot.path)"
        )
        XCTAssertFalse(layout.files.isEmpty, "Helper runtime layout must contain bundled files.")
        for file in layout.files {
            var isDirectory: ObjCBool = false
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: file.sourceURL.path, isDirectory: &isDirectory),
                "Bundled helper runtime file is missing: \(file.relativePath)"
            )
            XCTAssertFalse(
                isDirectory.boolValue,
                "Bundled helper runtime path must be a file: \(file.relativePath)"
            )
        }
    }
}
