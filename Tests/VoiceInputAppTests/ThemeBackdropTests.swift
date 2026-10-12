import AppKit
import XCTest
@testable import VoiceInputApp

final class ThemeBackdropTests: XCTestCase {
    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func pixelSize(of image: NSImage) throws -> CGSize {
        let rep = try XCTUnwrap(image.representations.compactMap { $0 as? NSBitmapImageRep }.first)
        return CGSize(width: rep.pixelsWide, height: rep.pixelsHigh)
    }

    func testBothBackdropImagesLoadFromTheResourcesFallbackAtProductionSize() throws {
        let resources = repositoryRoot.appendingPathComponent("Resources").path
        // An empty bundle forces the fallback path, as in tests and snapshots.
        let emptyBundle = Bundle(for: ThemeBackdropTests.self)

        for backdrop in ThemeBackdropImage.allCases {
            let image = try XCTUnwrap(
                backdrop.loadImage(in: emptyBundle, fallbackRoot: resources),
                "\(backdrop.rawValue) did not load from Resources/"
            )
            XCTAssertEqual(try pixelSize(of: image), ThemeBackdropImage.pixelSize, backdrop.rawValue)
        }
    }

    func testBothBackdropImagesLoadThroughABundle() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("flowtype-backdrop-bundle-\(UUID().uuidString)", isDirectory: true)
        let bundleURL = root.appendingPathComponent("Fixture.bundle", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        for backdrop in ThemeBackdropImage.allCases {
            try FileManager.default.copyItem(
                at: repositoryRoot.appendingPathComponent("Resources/\(backdrop.rawValue).png"),
                to: bundleURL.appendingPathComponent("\(backdrop.rawValue).png")
            )
        }
        let bundle = try XCTUnwrap(Bundle(url: bundleURL))

        for backdrop in ThemeBackdropImage.allCases {
            // The fallback root does not exist, so a successful load proves the bundle path.
            let image = try XCTUnwrap(
                backdrop.loadImage(in: bundle, fallbackRoot: "/nonexistent"),
                "\(backdrop.rawValue) did not load from the bundle"
            )
            XCTAssertEqual(try pixelSize(of: image), ThemeBackdropImage.pixelSize, backdrop.rawValue)
        }
    }

    func testMissingBackdropImageReturnsNilInsteadOfCrashing() {
        let emptyBundle = Bundle(for: ThemeBackdropTests.self)

        XCTAssertNil(ThemeBackdropImage.topLeading.loadImage(in: emptyBundle, fallbackRoot: "/nonexistent"))
    }

    func testBackdropFramesFollowTheApprovedFractions() {
        XCTAssertEqual(ThemeBackdropImage.topLeading.frameFraction, CGSize(width: 0.473, height: 0.694))
        XCTAssertEqual(ThemeBackdropImage.bottomTrailing.frameFraction, CGSize(width: 0.636, height: 0.935))
    }

    func testReduceTransparencyMakesFlowtypeCardsAndSidebarOpaqueButLeavesOtherThemesAlone() {
        let flowtype = AppTheme.theme(for: .flowtype)
        let reduced = flowtype.resolvingReduceTransparency(true)

        XCTAssertEqual(reduced.elevatedSurfaceHex, "#FFFFFF")
        XCTAssertEqual(reduced.sidebarSurfaceHex, "#FFFFFF")
        XCTAssertEqual(reduced.backdrop, .referenceCorners)
        XCTAssertEqual(flowtype.resolvingReduceTransparency(false), flowtype)

        for id in AppThemeID.allCases where id != .flowtype {
            let theme = AppTheme.theme(for: id)
            XCTAssertEqual(theme.resolvingReduceTransparency(true), theme, id.rawValue)
        }
    }

    func testSaturationMatrixMatchesCSSSaturateAndKeepsGrey() {
        // saturate(1) is the identity.
        let identity = ImageSaturation.matrix(1)
        for row in 0..<3 {
            for column in 0..<3 {
                XCTAssertEqual(identity[row][column], row == column ? 1 : 0, accuracy: 1e-9)
            }
        }
        // A grey pixel stays grey at any saturation.
        let grey = ImageSaturation.apply(1.25, toRed: 0.5, green: 0.5, blue: 0.5)
        XCTAssertEqual(grey.red, 0.5, accuracy: 0.002)
        XCTAssertEqual(grey.green, 0.5, accuracy: 0.002)
        XCTAssertEqual(grey.blue, 0.5, accuracy: 0.002)
        // The blue-ish pixel the owner's mock-up showed at the right edge gets bluer.
        let blue = ImageSaturation.apply(1.25, toRed: 189 / 255, green: 202 / 255, blue: 228 / 255)
        XCTAssertLessThan(blue.red, 189 / 255)
        XCTAssertGreaterThan(blue.blue, 228 / 255)
    }

    /// A 2x1 image drawn from raw sRGB bytes: left an opaque light blue, right fully transparent.
    private func twoPixelImage() throws -> NSImage {
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        var bytes: [UInt8] = [189, 202, 228, 255, 0, 0, 0, 0]
        let info = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        let cgImage = try bytes.withUnsafeMutableBytes { buffer -> CGImage in
            let context = try XCTUnwrap(CGContext(
                data: buffer.baseAddress, width: 2, height: 1, bitsPerComponent: 8,
                bytesPerRow: 8, space: space, bitmapInfo: info
            ))
            return try XCTUnwrap(context.makeImage())
        }
        return NSImage(cgImage: cgImage, size: NSSize(width: 2, height: 1))
    }

    /// Premultiplied sRGB RGBA bytes of a 2x1 image.
    private func pixels(of image: NSImage) throws -> [UInt8] {
        let source = try XCTUnwrap(image.cgImage(forProposedRect: nil, context: nil, hints: nil))
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        var bytes = [UInt8](repeating: 0, count: 8)
        let info = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        try bytes.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(
                data: buffer.baseAddress, width: 2, height: 1, bitsPerComponent: 8,
                bytesPerRow: 8, space: space, bitmapInfo: info
            ))
            context.draw(source, in: CGRect(x: 0, y: 0, width: 2, height: 1))
        }
        return bytes
    }

    func testSaturatedImageKeepsSizeAndAlphaAndChangesColour() throws {
        let source = try twoPixelImage()
        let result = ImageSaturation.saturated(source, by: 1.25)
        XCTAssertEqual(result.size, source.size)

        let out = try pixels(of: result)
        // Opaque pixel: alpha kept, red lower, blue higher (it got bluer).
        XCTAssertEqual(out[3], 255)
        XCTAssertLessThan(out[0], 189)
        XCTAssertGreaterThan(out[2], 228)
        // Transparent pixel stays transparent.
        XCTAssertEqual(out[7], 0)
    }

    func testSaturatingByOneReturnsTheSameImage() {
        let image = NSImage(size: NSSize(width: 1, height: 1))
        XCTAssertTrue(ImageSaturation.saturated(image, by: 1) === image)
    }
}
