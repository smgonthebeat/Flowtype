import XCTest
@testable import VoiceInputApp

final class PackageInspectorTests: XCTestCase {
    func testCompleteManifestWithArtworkPreservesSixReadinessChecks() throws {
        let fixture = try PackageFixture.makeComplete()

        let checks = PackageInspector().inspect(bundleURL: fixture.appURL, resourceURL: fixture.resourcesURL)

        XCTAssertEqual(checks.map(\.id), [
            "app-binary",
            "bundled-uv",
            "bundled-qwen-helper",
            "helper-manifest",
            "flowtype-icon",
            "qwen-logo"
        ])
        XCTAssertEqual(checks.map(\.title), [
            "Flowtype app binary",
            "Bundled uv",
            "Bundled Qwen helper",
            "Helper version manifest",
            "Flowtype icon",
            "Qwen logo"
        ])
        XCTAssertEqual(checks.map(\.detail), [
            "The Flowtype executable is present.",
            "Bundled uv is present and executable.",
            "The bundled helper source is present.",
            "The bundled helper manifest is present.",
            "The app icon resource is present.",
            "The Qwen logo resource is present."
        ])
        XCTAssertEqual(checks.map(\.status), Array(repeating: .ready, count: 6))
        XCTAssertEqual(checks.map(\.primaryAction), Array(repeating: nil, count: 6))
        XCTAssertEqual(checks.map(\.secondaryAction), Array(repeating: nil, count: 6))
        XCTAssertEqual(checks.map(\.locationTarget), [
            .appBundle, .appResources, .appResources, .appResources, .appResources, .appResources
        ])
    }

    func testMissingFilesFailTheirExistingInspectionGroupAndRepairAction() throws {
        let cases: [(String, String, ReadinessStatus)] = [
            ("Contents/MacOS/Flowtype", "app-binary", .failed("The app binary is missing.")),
            ("Contents/Resources/Tools/uv", "bundled-uv", .failed("Bundled uv is missing or not executable.")),
            (
                "Contents/Resources/Helpers/qwen-asr-helper/qwen_asr_helper/schemas.py",
                "bundled-qwen-helper",
                .failed("Bundled helper is incomplete.")
            ),
            (
                "Contents/Resources/Helpers/qwen-asr-helper/qwen_asr_helper/server.py",
                "bundled-qwen-helper",
                .failed("Bundled helper is incomplete.")
            ),
            ("Contents/Resources/Flowtype.icns", "flowtype-icon", .failed("Flowtype.icns is missing.")),
            ("Contents/Resources/Qwen-logo.svg", "qwen-logo", .failed("Qwen-logo.svg is missing."))
        ]

        for (relativePath, checkID, expectedStatus) in cases {
            let fixture = try PackageFixture.makeComplete()
            try FileManager.default.removeItem(at: fixture.appURL.appendingPathComponent(relativePath))

            let check = PackageInspector()
                .inspect(bundleURL: fixture.appURL, resourceURL: fixture.resourcesURL)
                .check(checkID)

            XCTAssertEqual(check?.status, expectedStatus, relativePath)
            XCTAssertEqual(check?.primaryAction, .reinstallFlowtypeApp, relativePath)
            XCTAssertEqual(check?.secondaryAction, .copyDiagnostics, relativePath)
            XCTAssertEqual(check?.locationTarget, .appBundle, relativePath)
        }
    }

    func testNonExecutableBinaryAndUVFailTheirExistingChecks() throws {
        let cases = [
            ("Contents/MacOS/Flowtype", "app-binary", ReadinessStatus.failed("The app binary is missing.")),
            (
                "Contents/Resources/Tools/uv",
                "bundled-uv",
                ReadinessStatus.failed("Bundled uv is missing or not executable.")
            )
        ]

        for (relativePath, checkID, expectedStatus) in cases {
            let fixture = try PackageFixture.makeComplete()
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o644],
                ofItemAtPath: fixture.appURL.appendingPathComponent(relativePath).path
            )

            let check = PackageInspector()
                .inspect(bundleURL: fixture.appURL, resourceURL: fixture.resourcesURL)
                .check(checkID)

            XCTAssertEqual(check?.status, expectedStatus, relativePath)
            XCTAssertEqual(check?.primaryAction, .reinstallFlowtypeApp, relativePath)
        }
    }

    func testDamagedManifestReturnsOnlyAppResourcesFailure() throws {
        let mutations: [(String, (inout [String: Any]) -> Void)] = [
            ("unsupported schema", { $0["runtimeSchemaVersion"] = 2 }),
            ("unsafe path", { manifest in
                var entries = manifest["entries"] as! [[String: Any]]
                entries[0]["relativePath"] = "../outside"
                manifest["entries"] = entries
            }),
            ("duplicate path", { manifest in
                var entries = manifest["entries"] as! [[String: Any]]
                entries[1]["relativePath"] = entries[0]["relativePath"]
                manifest["entries"] = entries
            }),
            ("malformed contract hash", { $0["authoringContractSHA256"] = "not-a-sha256" }),
            ("contract hash with trailing newline", {
                $0["authoringContractSHA256"] = String(repeating: "a", count: 64) + "\n"
            }),
            ("contract hash with non-ASCII lookalikes", {
                $0["authoringContractSHA256"] = String(repeating: "ａ", count: 64)
            }),
            ("missing inspection group", { manifest in
                var entries = manifest["entries"] as! [[String: Any]]
                entries.removeAll { $0["inspectionGroup"] as? String == "qwen-logo" }
                manifest["entries"] = entries
            }),
            ("unknown inspection group", { manifest in
                var entries = manifest["entries"] as! [[String: Any]]
                entries[0]["inspectionGroup"] = "future-group"
                manifest["entries"] = entries
            })
        ]

        for (label, mutation) in mutations {
            let fixture = try PackageFixture.makeComplete(manifestMutation: mutation)
            assertDamagedManifest(
                PackageInspector().inspect(bundleURL: fixture.appURL, resourceURL: fixture.resourcesURL),
                label
            )
        }

        let missingFixture = try PackageFixture.makeComplete()
        try FileManager.default.removeItem(at: missingFixture.manifestURL)
        assertDamagedManifest(
            PackageInspector().inspect(
                bundleURL: missingFixture.appURL,
                resourceURL: missingFixture.resourcesURL
            ),
            "missing manifest"
        )

        let malformedFixture = try PackageFixture.makeComplete()
        let malformedURL = try XCTUnwrap(Bundle.module.url(
            forResource: "malformed",
            withExtension: "json"
        ))
        try Data(contentsOf: malformedURL).write(to: malformedFixture.manifestURL)
        assertDamagedManifest(
            PackageInspector().inspect(
                bundleURL: malformedFixture.appURL,
                resourceURL: malformedFixture.resourcesURL
            ),
            "malformed manifest"
        )
    }

    func testSymlinkedBundleAncestorReturnsOnlyAppResourcesFailure() throws {
        let fixture = try PackageFixture.makeComplete()
        let relocatedResourcesURL = fixture.appURL
            .appendingPathComponent("Contents/RealResources", isDirectory: true)
        try FileManager.default.moveItem(at: fixture.resourcesURL, to: relocatedResourcesURL)
        try FileManager.default.createSymbolicLink(
            at: fixture.resourcesURL,
            withDestinationURL: relocatedResourcesURL
        )

        assertDamagedManifest(
            PackageInspector().inspect(
                bundleURL: fixture.appURL,
                resourceURL: fixture.resourcesURL
            ),
            "symlinked Resources ancestor"
        )
    }

    func testUnknownFieldsDecodeAtSupportedSchema() throws {
        let fixture = try PackageFixture.makeComplete { manifest in
            manifest["futureTopLevelField"] = ["value": true]
            var entries = manifest["entries"] as! [[String: Any]]
            entries[0]["futureEntryField"] = 42
            manifest["entries"] = entries
        }

        let checks = PackageInspector().inspect(bundleURL: fixture.appURL, resourceURL: fixture.resourcesURL)

        XCTAssertEqual(checks.count, 6)
        XCTAssertTrue(checks.allSatisfy { $0.status == .ready })
    }

    func testWellFormedContractHashIsNotComparedWithRepositoryAtRuntime() throws {
        let fixture = try PackageFixture.makeComplete { manifest in
            manifest["authoringContractSHA256"] = String(repeating: "a", count: 64)
        }

        let checks = PackageInspector().inspect(bundleURL: fixture.appURL, resourceURL: fixture.resourcesURL)

        XCTAssertEqual(checks.count, 6)
        XCTAssertTrue(checks.allSatisfy { $0.status == .ready })
    }

    func testMissingHelperManifestReportsRepairNeeded() throws {
        let fixture = try PackageFixture.makeComplete()
        try FileManager.default.removeItem(at: fixture.helperManifestURL)

        let checks = PackageInspector().inspect(bundleURL: fixture.appURL, resourceURL: fixture.resourcesURL)

        XCTAssertEqual(checks.check("helper-manifest")?.status, .failed("Helper manifest is missing."))
        XCTAssertEqual(checks.check("helper-manifest")?.primaryAction, .reinstallFlowtypeApp)
    }

    func testMalformedHelperManifestReportsInvalidManifest() throws {
        let fixture = try PackageFixture.makeComplete()
        try Data("{not json".utf8).write(to: fixture.helperManifestURL)

        let checks = PackageInspector().inspect(bundleURL: fixture.appURL, resourceURL: fixture.resourcesURL)

        XCTAssertEqual(checks.check("helper-manifest")?.status, .failed("Helper manifest is invalid."))
        XCTAssertEqual(checks.check("helper-manifest")?.primaryAction, .reinstallFlowtypeApp)
    }

    func testHelperManifestUVLockHashMismatchReportsInvalidPackage() throws {
        let fixture = try PackageFixture.makeComplete()
        try Data("version = 2\n".utf8).write(to: fixture.helperURL.appendingPathComponent("uv.lock"))

        let checks = PackageInspector().inspect(bundleURL: fixture.appURL, resourceURL: fixture.resourcesURL)

        XCTAssertEqual(checks.check("helper-manifest")?.status, .failed("Helper manifest does not match uv.lock."))
        XCTAssertEqual(checks.check("helper-manifest")?.primaryAction, .reinstallFlowtypeApp)
    }

    func testNilResourceURLReturnsAppResourcesFailure() throws {
        let fixture = try PackageFixture.makeComplete()

        let checks = PackageInspector().inspect(bundleURL: fixture.appURL, resourceURL: nil)

        assertDamagedManifest(checks, "nil resource URL")
    }

    private func assertDamagedManifest(
        _ checks: [ReadinessCheck],
        _ context: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(checks.count, 1, context, file: file, line: line)
        XCTAssertEqual(checks.first?.id, "app-resources", context, file: file, line: line)
        XCTAssertEqual(
            checks.first?.title,
            "App resources",
            context,
            file: file,
            line: line
        )
        XCTAssertEqual(
            checks.first?.detail,
            "Flowtype could not locate its bundled resources.",
            context,
            file: file,
            line: line
        )
        XCTAssertEqual(
            checks.first?.status,
            .failed("Bundle resources are unavailable."),
            context,
            file: file,
            line: line
        )
        XCTAssertEqual(checks.first?.primaryAction, .reinstallFlowtypeApp, context, file: file, line: line)
        XCTAssertEqual(checks.first?.secondaryAction, .copyDiagnostics, context, file: file, line: line)
        XCTAssertEqual(checks.first?.locationTarget, .appBundle, context, file: file, line: line)
    }
}

private extension Array where Element == ReadinessCheck {
    func check(_ id: String) -> ReadinessCheck? {
        first { $0.id == id }
    }
}
