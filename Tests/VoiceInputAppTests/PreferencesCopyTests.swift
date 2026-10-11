import XCTest
@testable import VoiceInputApp

final class PreferencesCopyTests: XCTestCase {
    func testChineseFillerCleanupCopyMatchesSafetyContract() {
        let copy = PreferencesCopy.texts(for: .chinese)

        // design-spec 5.13: Chinese UI copy quotes with 「」; the wording is unchanged.
        XCTAssertEqual(
            copy.fillerCleanupDetail,
            "按本地规则清理部分停顿词，包括连续中文中的「呃」和「那嗯，继续」这类表达。保留引文、code、术语和未支持的表达；不判断 like、就是等词是否多余。有意说出的停顿音仍可能被误删。默认关闭。"
        )
        XCTAssertEqual(copy.fillerCleanupExamples, "示例：嗯，我现在先说结论 → 我现在先说结论")
        XCTAssertEqual(
            copy.fillerCleanupSafetyNotice,
            "为防止误删正常词语，本次更新已关闭口头填充词清理。你可以查看说明后重新开启。"
        )
        XCTAssertEqual(copy.fillerCleanupSafetyNoticeDismiss, "关闭提示")
    }

    func testEnglishFillerCleanupCopyMatchesSafetyContract() {
        let copy = PreferencesCopy.texts(for: .english)

        XCTAssertEqual(
            copy.fillerCleanupDetail,
            "Uses local rules to clean some pauses, including 呃 inside Chinese text and attached 嗯 before a comma and continuation. Preserves quoted text, code, terms, and unsupported expressions. It does not decide whether words such as like are redundant; intentional pause sounds can still be removed. Off by default."
        )
        XCTAssertEqual(
            copy.fillerCleanupExamples,
            "Example: Um, I will start with the conclusion → I will start with the conclusion"
        )
        XCTAssertEqual(
            copy.fillerCleanupSafetyNotice,
            "Filler cleanup was turned off in this update to prevent normal words from being removed. You can review it and re-enable it."
        )
        XCTAssertEqual(copy.fillerCleanupSafetyNoticeDismiss, "Dismiss")
    }
}
