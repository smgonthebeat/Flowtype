import AppKit
import SwiftUI
import XCTest
@testable import VoiceInputApp

/// Motion and brand renders for the launch-video asset library
/// (`public-release/marketing/flowtype-asset-library`). One version of each thing, per language.
///
///     FLOWTYPE_ASSET_LIBRARY_DIR=<dir> swift test --filter AssetLibraryRenderTests
///
/// Skipped unless `FLOWTYPE_ASSET_LIBRARY_DIR` is set. Everything is drawn offscreen from the
/// app's own views and constants; no window is shown and the app is never activated.
///
/// Output under `<dir>`:
/// - `capsule/<language>.png`: the real `FloatingCapsulePanel` listening, on a transparent
///   background, at 4x. Its live HUD blur cannot render offscreen, so the body is painted with
///   the solid dark fill the onboarding copy of the capsule uses (`MockCapsuleView`).
/// - `capsule-motion/<language>/frame-NNNN.png`: one capsule cycle (appear, listen, transcribe,
///   disappear) drawn with `MockCapsuleView`, transparent, 4x, 60 fps.
/// - `hold-fn-motion/<language>/frame-NNNN.png`: one full loop of the onboarding hold-Fn
///   animation (`HoldFnAnimation`), transparent, 3x, 30 fps.
/// - `welcome-flow/<language>.png`, `dawn-background.png`, `menu-bar-icon.png`: stills.
/// - `files.json`: every path written by this run.
@MainActor
final class AssetLibraryRenderTests: XCTestCase {
    func testRenderAssetLibrary() throws {
        guard let outputPath = ProcessInfo.processInfo.environment["FLOWTYPE_ASSET_LIBRARY_DIR"],
              !outputPath.isEmpty
        else {
            throw XCTSkip("Set FLOWTYPE_ASSET_LIBRARY_DIR=<dir> to render the asset library motion and brand files.")
        }
        // Resource lookups fall back to "Resources/<name>" relative to the working directory.
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        FileManager.default.changeCurrentDirectoryPath(packageRoot.path)

        let renderer = AssetRenderer(outputRoot: URL(fileURLWithPath: outputPath, isDirectory: true).standardizedFileURL)
        try renderer.renderAll()

        XCTAssertFalse(NSApp.isActive, "The asset renderer must never activate the app.")
        XCTAssertTrue(NSApp.windows.allSatisfy { !$0.isVisible }, "The asset renderer must never show a window.")
        print("Asset library: wrote \(renderer.written.count) files to \(renderer.outputRoot.path)")
    }
}

/// One capsule cycle for the motion clip. Show and hide follow `CapsuleMotion`.
private enum CapsuleCycle {
    static let fps = 60.0
    static let duration = 6.0
    static let showAt = 0.1
    static let transcribeAt = 4.1
    static let hideAt = 5.6

    /// 0...1 visibility (opacity, and the 8 pt rise or sink) at a time in the clip.
    static func visibility(at time: Double) -> Double {
        let shown = easeOut((time - showAt) / CapsuleMotion.showDuration)
        let hidden = easeOut((time - hideAt) / CapsuleMotion.hideDuration)
        return shown * (1 - hidden)
    }

    /// Close to the capsule's `cubic-bezier(0.23, 1, 0.32, 1)`: fast start, long settle.
    static func easeOut(_ x: Double) -> Double {
        let t = min(max(x, 0), 1)
        return 1 - pow(1 - t, 4)
    }
}

@MainActor
private final class AssetRenderer {
    let outputRoot: URL
    let theme = AppTheme.theme(for: .flowtype)
    /// Paths relative to `outputRoot`, also saved as `files.json` so the build script reads
    /// exactly this run's files.
    private(set) var written: [String] = []
    private var retained: [AnyObject] = []

    init(outputRoot: URL) {
        self.outputRoot = outputRoot
    }

    func renderAll() throws {
        for language in [UILanguage.chinese, .english] {
            try renderCapsuleStill(language: language)
            try renderCapsuleMotion(language: language)
            try renderHoldFnMotion(language: language)
            try renderWelcomeFlow(language: language)
        }
        try renderBackground()
        try renderMenuBarIcon()
        let list = try JSONSerialization.data(withJSONObject: written, options: [.prettyPrinted])
        try list.write(to: outputRoot.appendingPathComponent("files.json"), options: .atomic)
    }

    // MARK: Capsule

    /// Fill used by `MockCapsuleView` for the capsule body; stands in for the HUD material.
    static let capsuleBodyWhite: CGFloat = 0.12

    private func renderCapsuleStill(language: UILanguage) throws {
        let copy = AppCopy.texts(for: language)
        let capsule = FloatingCapsulePanel()
        capsule.themeProvider = { [theme] in theme }
        retained.append(capsule)
        guard let content = capsule.layoutOffscreen(.listening(copy.capsuleListening)) else {
            throw AssetError("The capsule panel has no content view.")
        }
        paintCapsuleBody(in: content)
        capsule.updateAudioLevel(0.62)
        settle(0.25)
        content.layoutSubtreeIfNeeded()
        // Transparent margin so the glow and any later shadow are never clipped.
        let padding: CGFloat = 24
        let bitmap = try makeBitmap(
            pointSize: NSSize(width: content.bounds.width + padding * 2, height: content.bounds.height + padding * 2),
            scale: 4
        )
        let inner = try makeBitmap(pointSize: content.bounds.size, scale: 4)
        content.cacheDisplay(in: content.bounds, to: inner)
        try draw(into: bitmap) {
            inner.draw(
                in: NSRect(x: padding, y: padding, width: content.bounds.width, height: content.bounds.height),
                from: .zero,
                operation: .sourceOver,
                fraction: 1,
                respectFlipped: false,
                hints: nil
            )
        }
        try write(bitmap, to: "capsule/\(language.fileTag).png")
    }

    /// The HUD blur only renders in an on-screen window; offscreen AppKit draws a flat grey
    /// instead. Swap the material for the solid dark body of the SwiftUI capsule copy.
    private func paintCapsuleBody(in view: NSView) {
        for effect in view.descendants(of: NSVisualEffectView.self) {
            effect.state = .inactive
            effect.material = .hudWindow
            effect.layer?.backgroundColor = NSColor(white: Self.capsuleBodyWhite, alpha: 1).cgColor
        }
    }

    /// A speech-like level: syllable bumps on a phrase envelope, with a short pause.
    static func speechLevel(at time: Double) -> Double {
        let phrase = 0.55 + 0.25 * sin(time * 1.3) + 0.12 * sin(time * 0.47 + 1.1)
        let syllables = 0.5 + 0.5 * sin(time * 11.0) * sin(time * 3.7 + 0.4)
        let pause = (time.truncatingRemainder(dividingBy: 4.0) > 3.2) ? 0.25 : 1.0
        return min(max(phrase * (0.55 + 0.45 * syllables) * pause, 0.08), 1)
    }

    /// Appear, listen to speech, transcribe, disappear, on a fixed canvas so every frame has the
    /// same size (the capsule narrows from the listening label to the transcribing label).
    private func renderCapsuleMotion(language: UILanguage) throws {
        let copy = AppCopy.texts(for: language)
        let frames = Int(CapsuleCycle.duration * CapsuleCycle.fps)
        for frame in 0..<frames {
            let time = Double(frame) / CapsuleCycle.fps
            let visibility = CapsuleCycle.visibility(at: time)
            let capsule = Group {
                if time < CapsuleCycle.transcribeAt {
                    MockCapsuleView(kind: .listening, text: copy.capsuleListening, time: time, level: Self.speechLevel(at: time))
                } else {
                    MockCapsuleView(kind: .transcribing, text: copy.capsuleTranscribing, time: time - CapsuleCycle.transcribeAt)
                }
            }
            let view = capsule
                .opacity(visibility)
                .offset(y: CGFloat(1 - visibility) * -CapsuleMotion.showOffsetY)
                .frame(width: 280, height: 88)
            try renderSwiftUI(view, scale: 4, to: "capsule-motion/\(language.fileTag)/frame-\(frameTag(frame)).png")
        }
    }

    // MARK: Onboarding animation

    private func renderHoldFnMotion(language: UILanguage) throws {
        let copy = AppCopy.texts(for: language)
        let guide = OnboardingCopy.texts(for: language)
        let fps = 30.0
        let frames = Int(HoldFnAnimation.cycle * fps)
        for frame in 0..<frames {
            let time = Double(frame) / fps
            let view = HoldFnAnimation(
                copy: guide,
                listeningText: copy.capsuleListening,
                transcribingText: copy.capsuleTranscribing,
                stillTime: time
            )
            .frame(width: 600)
            .padding(16)
            try renderSwiftUI(view, scale: 3, to: "hold-fn-motion/\(language.fileTag)/frame-\(frameTag(frame)).png")
        }
    }

    // MARK: Stills

    private func renderWelcomeFlow(language: UILanguage) throws {
        let copy = AppCopy.texts(for: language)
        let guide = OnboardingCopy.texts(for: language)
        try renderSwiftUI(
            WelcomeFlowIllustration(copy: guide, listeningText: copy.capsuleListening)
                .frame(width: 600)
                .padding(16),
            scale: 3,
            to: "welcome-flow/\(language.fileTag).png"
        )
    }

    /// The Dawn window backdrop alone (no UI), 4K landscape.
    private func renderBackground() throws {
        try renderSwiftUI(
            ThemeBackdropArtwork(theme: theme).frame(width: 1920, height: 1080),
            scale: 2,
            to: "dawn-background.png"
        )
    }

    /// The exact menu bar icon, black (for the light Dawn look), at 8x.
    private func renderMenuBarIcon() throws {
        guard let icon = MenuBarController.makeStatusIcon() else {
            throw AssetError("The menu bar icon could not be built.")
        }
        let bitmap = try makeBitmap(pointSize: icon.size, scale: 8)
        try draw(into: bitmap) {
            let rect = NSRect(origin: .zero, size: icon.size)
            icon.draw(in: rect)
            NSColor.black.set()
            rect.fill(using: .sourceAtop)
        }
        try write(bitmap, to: "menu-bar-icon.png")
    }

    // MARK: Helpers

    private func frameTag(_ frame: Int) -> String {
        String(format: "%04d", frame)
    }

    private func renderSwiftUI<Content: View>(_ content: Content, scale: CGFloat, to path: String) throws {
        let renderer = ImageRenderer(content: content.environment(\.appTheme, theme))
        renderer.scale = scale
        renderer.isOpaque = false
        guard let image = renderer.cgImage else {
            throw AssetError("Could not render \(path).")
        }
        try write(NSBitmapImageRep(cgImage: image), to: path)
    }

    private func makeBitmap(pointSize: NSSize, scale: CGFloat) throws -> NSBitmapImageRep {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int((pointSize.width * scale).rounded()),
            pixelsHigh: Int((pointSize.height * scale).rounded()),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw AssetError("Could not allocate a \(pointSize) bitmap.")
        }
        bitmap.size = pointSize
        return bitmap
    }

    private func draw(into bitmap: NSBitmapImageRep, _ body: () -> Void) throws {
        guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            throw AssetError("Could not create a drawing context.")
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        body()
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
    }

    private func write(_ bitmap: NSBitmapImageRep, to path: String) throws {
        let url = outputRoot.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw AssetError("Could not encode \(path).")
        }
        try data.write(to: url, options: .atomic)
        written.append(path)
    }

    private func settle(_ seconds: TimeInterval) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }
}

private struct AssetError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

private extension UILanguage {
    var fileTag: String { self == .chinese ? "zh" : "en" }
}

private extension NSView {
    func descendants<T: NSView>(of type: T.Type) -> [T] {
        subviews.flatMap { subview -> [T] in
            ((subview as? T).map { [$0] } ?? []) + subview.descendants(of: type)
        }
    }
}
