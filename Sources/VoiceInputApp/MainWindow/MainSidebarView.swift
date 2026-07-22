import AppKit
import SwiftUI

struct MainSidebarView: View {
    @Environment(\.appTheme) private var theme

    @Binding var selectedSection: MainWindowSection
    let uiLanguage: UILanguage
    let actions: MainWindowActions

    var body: some View {
        let copy = AppCopy.texts(for: uiLanguage)

        VStack(spacing: 0) {
            appIdentity

            VStack(spacing: 6) {
                ForEach(MainWindowSection.allCases) { section in
                    sidebarSectionButton(section)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            Spacer()
            sidebarActions(copy: copy)
        }
        .frame(width: 196)
        .background(theme.sidebarSurface)
        .foregroundStyle(theme.ink)
    }

    private var appIdentity: some View {
        HStack(spacing: 9) {
            FlowtypeLogoMark()
                .frame(height: 21)
            Text("Flowtype")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(theme.ink)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    private func sidebarSectionButton(_ section: MainWindowSection) -> some View {
        let isSelected = selectedSection == section

        return Button {
            selectedSection = section
        } label: {
            Label(section.title(for: uiLanguage), systemImage: section.systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isSelected ? theme.onAccent : theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    isSelected ? theme.accent : Color.clear,
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
        }
        .buttonStyle(.plain)
    }

    private func sidebarActions(copy: AppCopy.Texts) -> some View {
        VStack(spacing: 2) {
            Button(action: actions.openSettings) {
                Label(copy.settingsTitle, systemImage: "gearshape")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.secondaryInk)

            Button(action: actions.showHelp) {
                Label(copy.helpTitle, systemImage: "questionmark.circle")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.secondaryInk)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private struct FlowtypeLogoMark: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        if let image = FlowtypeLogoAsset.templateMark {
            Image(nsImage: image)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(theme.ink)
        } else {
            Image(systemName: "waveform")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(theme.ink)
        }
    }
}

enum FlowtypeLogoAsset {
    /// The Flowtype mark as a template image, cropped to its visible content so
    /// it can be tinted with the current theme's ink color. The source SVG is a
    /// square canvas with the mark occupying a horizontal band in the middle.
    static let templateMark: NSImage? = makeTemplateMark()

    private static func makeTemplateMark() -> NSImage? {
        guard let source = loadSourceImage() else { return nil }

        let rasterPixels = 512
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: rasterPixels,
            pixelsHigh: rasterPixels,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        source.draw(
            in: NSRect(x: 0, y: 0, width: rasterPixels, height: rasterPixels),
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )
        NSGraphicsContext.restoreGraphicsState()

        guard let contentRect = alphaBoundingBox(of: bitmap, threshold: 0.05) else {
            return nil
        }

        let padding: CGFloat = 4
        let cropRect = contentRect
            .insetBy(dx: -padding, dy: -padding)
            .intersection(NSRect(x: 0, y: 0, width: rasterPixels, height: rasterPixels))

        let mark = NSImage(size: cropRect.size, flipped: false) { destination in
            bitmap.draw(
                in: destination,
                from: cropRect,
                operation: .sourceOver,
                fraction: 1,
                respectFlipped: false,
                hints: [.interpolation: NSImageInterpolation.high]
            )
            return true
        }
        mark.isTemplate = true
        return mark
    }

    private static func loadSourceImage() -> NSImage? {
        if let url = Bundle.main.url(forResource: "Flowtype-logo", withExtension: "svg") {
            return NSImage(contentsOf: url)
        }
        return NSImage(contentsOfFile: "Resources/Flowtype-logo.svg")
    }

    /// Bounding box of non-transparent pixels, in the bitmap's bottom-left
    /// coordinate space used by `NSBitmapImageRep.draw(in:from:)`.
    /// Scans the raw alpha bytes; this runs on the main thread during the
    /// first sidebar render, so per-pixel `colorAt` NSColor allocation is
    /// too slow here.
    private static func alphaBoundingBox(of bitmap: NSBitmapImageRep, threshold: CGFloat) -> NSRect? {
        guard let data = bitmap.bitmapData, bitmap.samplesPerPixel >= 4, !bitmap.isPlanar else {
            return nil
        }

        let width = bitmap.pixelsWide
        let height = bitmap.pixelsHigh
        let bytesPerRow = bitmap.bytesPerRow
        let samplesPerPixel = bitmap.samplesPerPixel
        let alphaOffset = samplesPerPixel - 1
        let alphaThreshold = UInt8(min(max(threshold, 0), 1) * 255)

        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1

        for y in 0..<height {
            let row = data + y * bytesPerRow
            for x in 0..<width {
                guard row[x * samplesPerPixel + alphaOffset] > alphaThreshold else {
                    continue
                }
                minX = min(minX, x)
                maxX = max(maxX, x)
                minY = min(minY, y)
                maxY = max(maxY, y)
            }
        }

        guard maxX >= minX, maxY >= minY else { return nil }

        // Byte rows use a top-left origin; convert to bottom-left for drawing.
        return NSRect(
            x: CGFloat(minX),
            y: CGFloat(height - maxY - 1),
            width: CGFloat(maxX - minX + 1),
            height: CGFloat(maxY - minY + 1)
        )
    }
}
