import AppKit
import SwiftUI

/// The two corner images of the `.referenceCorners` backdrop. The fades into the window base
/// colour are already baked into each image's alpha channel.
enum ThemeBackdropImage: String, CaseIterable {
    case topLeading = "FlowtypeBackdrop-topLeading"
    case bottomTrailing = "FlowtypeBackdrop-bottomTrailing"

    /// Pixel size of both production images.
    static let pixelSize = CGSize(width: 1200, height: 1118)

    /// Image frame as a fraction of the window, so the composition scales with the window.
    var frameFraction: CGSize {
        switch self {
        case .topLeading:
            return CGSize(width: 0.473, height: 0.694)
        case .bottomTrailing:
            return CGSize(width: 0.636, height: 0.935)
        }
    }

    /// `Bundle.main` first, then `Resources/<name>.png` relative to the working directory, which
    /// is how tests and the snapshot harness find it. Loaded once, saturated by the Dawn corner
    /// saturation (see `FlowtypeDawnSurface`), and cached.
    var image: NSImage? {
        Self.cache.image(for: self)
    }

    /// The lookup behind `image`, without the cache. `fallbackRoot` is the directory that holds
    /// the PNG when `bundle` does not.
    func loadImage(in bundle: Bundle = .main, fallbackRoot: String = "Resources") -> NSImage? {
        if let url = bundle.url(forResource: rawValue, withExtension: "png") {
            return NSImage(contentsOf: url)
        }
        return NSImage(contentsOfFile: "\(fallbackRoot)/\(rawValue).png")
    }

    private static let cache = ImageCache()

    private final class ImageCache: @unchecked Sendable {
        private let lock = NSLock()
        private var images: [ThemeBackdropImage: NSImage] = [:]
        private var reportedMissing: Set<ThemeBackdropImage> = []

        func image(for backdrop: ThemeBackdropImage) -> NSImage? {
            lock.lock()
            defer { lock.unlock() }
            if let cached = images[backdrop] { return cached }

            let loaded = backdrop.loadImage().map {
                ImageSaturation.saturated($0, by: FlowtypeDawnSurface.cornerSaturation)
            }
            if let loaded {
                images[backdrop] = loaded
            } else if reportedMissing.insert(backdrop).inserted {
                AppLogger.app.error("Theme backdrop image \(backdrop.rawValue, privacy: .public) is missing; painting the base colour only.")
            }
            return loaded
        }
    }
}

/// Window-sized artwork painted once behind all content, sidebar included, running under the
/// transparent titlebar. Themes without a backdrop get their flat surface colour.
struct ThemeBackdropView: View {
    let theme: AppTheme

    var body: some View {
        ThemeBackdropArtwork(theme: theme)
            .ignoresSafeArea()
    }
}

/// The backdrop at whatever size it is given, without extending into safe areas. Used directly
/// for small miniatures such as the theme picker tile.
struct ThemeBackdropArtwork: View {
    let theme: AppTheme

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                theme.surface

                if theme.backdrop == .referenceCorners {
                    // Both corner images, then a second, translucent copy of each: the "colour
                    // density" that keeps the corners rich against the near-white base.
                    cornerImage(.topLeading, in: proxy.size)
                    cornerImage(.bottomTrailing, in: proxy.size)
                    cornerImage(.topLeading, in: proxy.size, opacity: FlowtypeDawnSurface.cornerDensity)
                    cornerImage(.bottomTrailing, in: proxy.size, opacity: FlowtypeDawnSurface.cornerDensity)
                    centreGlow(in: proxy.size)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .clipped()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// A soft white ellipse over the middle of the page, so the area between the two corners reads
    /// as clean white rather than a grey-violet haze. Built from a circular gradient stretched to
    /// the ellipse, because `EllipticalGradient` needs a newer macOS than the app supports.
    private func centreGlow(in size: CGSize) -> some View {
        let radius = FlowtypeDawnSurface.centreGlowRadius
        let centre = FlowtypeDawnSurface.centreGlowCentre
        let diameter = size.width * radius.width * 2
        let stretch = size.height * radius.height * 2 / max(diameter, 1)
        let peak = FlowtypeDawnSurface.centreGlow

        return Rectangle()
            .fill(
                RadialGradient(
                    stops: [
                        .init(color: .white.opacity(peak), location: 0),
                        .init(
                            color: .white.opacity(peak * FlowtypeDawnSurface.centreGlowMidFraction),
                            location: FlowtypeDawnSurface.centreGlowMidLocation
                        ),
                        .init(color: .white.opacity(0), location: 1)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: diameter / 2
                )
            )
            .frame(width: diameter, height: diameter)
            .scaleEffect(x: 1, y: stretch)
            .position(x: size.width * centre.x, y: size.height * centre.y)
    }

    @ViewBuilder
    private func cornerImage(_ backdrop: ThemeBackdropImage, in size: CGSize, opacity: Double = 1) -> some View {
        if let image = backdrop.image {
            let fraction = backdrop.frameFraction
            let width = size.width * fraction.width
            let height = size.height * fraction.height
            let x = backdrop == .topLeading ? 0 : size.width - width
            let y = backdrop == .topLeading ? 0 : size.height - height

            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .frame(width: width, height: height)
                .opacity(opacity)
                .offset(x: x, y: y)
        }
    }
}

extension View {
    /// Page and scroll backgrounds: the flat surface for themes without a backdrop, nothing for
    /// themes with one, so the window's backdrop shows through.
    func themedPageBackground(_ theme: AppTheme) -> some View {
        background(theme.backdrop == nil ? theme.surface : Color.clear)
    }
}

extension View {
    /// In a backdrop theme, fades content out toward the top edge so scrolled text does not run
    /// through the titlebar over the artwork. Other themes are returned unchanged.
    @ViewBuilder
    func backdropTitlebarFade(_ theme: AppTheme) -> some View {
        if theme.backdrop == nil {
            self
        } else {
            mask {
                GeometryReader { proxy in
                    VStack(spacing: 0) {
                        LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                            .frame(height: proxy.safeAreaInsets.top + AppSpacing.x2)
                        Rectangle().fill(.black)
                    }
                    .ignoresSafeArea(edges: .top)
                }
            }
        }
    }
}
