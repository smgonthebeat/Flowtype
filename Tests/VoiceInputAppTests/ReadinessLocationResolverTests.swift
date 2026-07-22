import XCTest
@testable import VoiceInputApp

final class ReadinessLocationResolverTests: XCTestCase {
    func testResolvesAppBundleAndApplicationSupportLocations() throws {
        let root = makeDirectory("app-support")
        let bundle = makeDirectory("Flowtype.app")
        let resources = makeDirectory("Resources")
        let resolver = ReadinessLocationResolver(
            bundleURL: bundle,
            resourceURL: resources,
            applicationSupportRoot: root,
            selectedModel: .qwen3ASR06B
        )

        XCTAssertEqual(resolver.url(for: .appBundle), bundle)
        XCTAssertEqual(resolver.url(for: .appResources), resources)
        XCTAssertEqual(resolver.url(for: .applicationSupportRoot), root)
    }

    func testResolvesModelAndHelperLocations() throws {
        let root = makeDirectory("app-support")
        let resolver = ReadinessLocationResolver(
            bundleURL: makeDirectory("Flowtype.app"),
            resourceURL: nil,
            applicationSupportRoot: root,
            selectedModel: .qwen3ASR06B
        )

        XCTAssertEqual(
            resolver.url(for: .localHelper),
            root.appendingPathComponent("qwen-asr-helper", isDirectory: true)
        )
        XCTAssertEqual(
            resolver.url(for: .modelsRoot),
            root.appendingPathComponent("Models", isDirectory: true)
        )
        XCTAssertEqual(
            resolver.url(for: .selectedModel),
            root.appendingPathComponent("Models", isDirectory: true)
                .appendingPathComponent("qwen3-asr-0.6b", isDirectory: true)
        )
        XCTAssertEqual(
            resolver.url(for: .diagnostics),
            root.appendingPathComponent("Diagnostics", isDirectory: true)
        )
    }

    func testNearestExistingURLFallsBackToParent() throws {
        let root = makeDirectory("app-support")
        let resolver = ReadinessLocationResolver(
            bundleURL: makeDirectory("Flowtype.app"),
            resourceURL: nil,
            applicationSupportRoot: root,
            selectedModel: .qwen3ASR06B
        )

        let target = root
            .appendingPathComponent("Models", isDirectory: true)
            .appendingPathComponent("qwen3-asr-0.6b", isDirectory: true)

        XCTAssertEqual(resolver.nearestExistingURL(for: target), root)
    }

    private func makeDirectory(_ name: String) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("flowtype-location-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
