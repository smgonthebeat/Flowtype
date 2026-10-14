import CoreGraphics
import XCTest
@testable import VoiceInputApp

/// The Home stat cards place their four artworks in one shared frame, in every theme (task 19).
final class HomeCardArtworkPlacementTests: XCTestCase {
    private let cards: [(pixelSize: CGSize, content: CGRect)] = [
        (CGSize(width: 360, height: 380), CGRect(x: 17, y: 16, width: 327, height: 314)),
        (CGSize(width: 420, height: 290), CGRect(x: 20, y: 12, width: 383, height: 259)),
        (CGSize(width: 380, height: 370), CGRect(x: 31, y: 15, width: 327, height: 328)),
        (CGSize(width: 390, height: 360), CGRect(x: 26, y: 15, width: 341, height: 321))
    ]

    func testArtworksShareVisualSizeAndCorner() {
        let padding = UsageArtworkPlacement.framePadding
        for card in [CGSize(width: 265, height: 132), CGSize(width: 196, height: 132), CGSize(width: 340, height: 150)] {
            let container = CGSize(width: card.width + padding, height: card.height + padding)
            let expectedVisualSize = min(
                card.height * UsageArtworkPlacement.heightShare,
                card.width * UsageArtworkPlacement.widthShare
            )
            for artwork in cards {
                let placement = UsageArtworkPlacement.shared(
                    in: container,
                    pixelSize: artwork.pixelSize,
                    contentPixelBounds: artwork.content
                )
                let scale = placement.size.width / artwork.pixelSize.width
                XCTAssertEqual(placement.size.height / artwork.pixelSize.height, scale, accuracy: 1e-9, "aspect ratio kept")

                let visualSize = (artwork.content.width * artwork.content.height).squareRoot() * scale
                XCTAssertEqual(visualSize, expectedVisualSize, accuracy: 1e-9)

                let originX = placement.center.x - placement.size.width / 2
                let originY = placement.center.y - placement.size.height / 2
                let contentMaxX = originX + artwork.content.maxX * scale
                let contentMaxY = originY + artwork.content.maxY * scale
                let contentMinY = originY + artwork.content.minY * scale
                // Measured from the card edges, not from the padded frame.
                XCTAssertEqual(contentMaxX, card.width - UsageArtworkPlacement.trailingInset, accuracy: 1e-9)
                XCTAssertEqual(contentMaxY, card.height - UsageArtworkPlacement.bottomInset, accuracy: 1e-9)
                XCTAssertGreaterThan(contentMinY, 0, "the artwork does not reach the top of the card")
            }
        }
    }
}
