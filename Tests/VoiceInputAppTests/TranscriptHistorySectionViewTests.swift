import XCTest
@testable import VoiceInputApp

final class TranscriptHistorySectionViewTests: XCTestCase {
    func testHistoryCardDoesNotReserveTopBlankBand() {
        XCTAssertEqual(TranscriptHistorySectionLayout.cardTopPadding, 0)
    }

    func testHoveredHistoryRowBackgroundTouchesRowBounds() {
        XCTAssertEqual(TranscriptRowLayout.hoverBackgroundVerticalInset, 0)
        XCTAssertEqual(TranscriptRowLayout.hoverBackgroundHorizontalInset, 0)
        XCTAssertNil(TranscriptRowLayout.hoverBackgroundFixedHeight)
    }

    func testHistoryRowActionsReserveLayoutWhileHidden() {
        XCTAssertTrue(TranscriptRowLayout.reservesActionButtonsDuringIdle)
        XCTAssertEqual(TranscriptRowLayout.actionButtonsOpacity(isHovered: false), 0)
        XCTAssertEqual(TranscriptRowLayout.actionButtonsOpacity(isHovered: true), 1)
    }

    func testExpandAffordanceRequiresRenderedOverflow() {
        XCTAssertFalse(
            TranscriptRowLayout.textOverflows(
                collapsedHeight: 80,
                fullHeight: 80
            )
        )
        XCTAssertFalse(
            TranscriptRowLayout.textOverflows(
                collapsedHeight: 80,
                fullHeight: 80.4
            )
        )
        XCTAssertTrue(
            TranscriptRowLayout.textOverflows(
                collapsedHeight: 80,
                fullHeight: 96
            )
        )
    }

    func testTranscriptTextLayoutIsNeverAnimated() {
        XCTAssertFalse(TranscriptRowMotion.animatesTextLayout)
    }

    func testExpandControlMotionRespectsReduceMotion() {
        XCTAssertTrue(TranscriptRowMotion.animatesExpandControl(reduceMotion: false))
        XCTAssertFalse(TranscriptRowMotion.animatesExpandControl(reduceMotion: true))
    }

    func testRetryFeedbackDropsPositionalMotionWhenReduced() {
        XCTAssertTrue(TranscriptRowMotion.retryUsesPositionalMotion(reduceMotion: false))
        XCTAssertFalse(TranscriptRowMotion.retryUsesPositionalMotion(reduceMotion: true))
    }
}
