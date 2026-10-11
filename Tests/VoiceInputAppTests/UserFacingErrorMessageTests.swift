import XCTest
@testable import VoiceInputApp

final class UserFacingErrorMessageTests: XCTestCase {
    func testPreparationFailuresReadInTheInterfaceLanguage() {
        let network = PreparationFailure.modelPreparationFailed("network_unavailable")
        let chinese = UserFacingErrorMessage.message(for: network, language: .chinese)
        XCTAssertTrue(chinese.contains("网络"))
        XCTAssertTrue(chinese.contains("VPN"))
        // The raw helper code is not shown once there is a specific sentence.
        XCTAssertFalse(chinese.contains("network_unavailable"))
        XCTAssertTrue(UserFacingErrorMessage.message(for: network, language: .english).contains("network"))

        let disk = UserFacingErrorMessage.message(for: PreparationFailure.modelPreparationFailed("insufficient_disk_space"), language: .chinese)
        XCTAssertTrue(disk.contains("磁盘空间"))

        let bundle = UserFacingErrorMessage.message(for: PreparationFailure.appBundleInvalid, language: .chinese)
        XCTAssertTrue(bundle.contains("重新安装"))
    }

    func testUnknownFailuresKeepEnglishTechnicalDetailForDiagnostics() {
        let unknown = UserFacingErrorMessage.message(
            for: PreparationFailure.modelPreparationFailed("mlx_metal_oom"),
            language: .chinese
        )
        XCTAssertTrue(unknown.hasPrefix("本地模型没有准备好"))
        XCTAssertTrue(unknown.contains("技术信息：mlx_metal_oom"))

        let helper = UserFacingErrorMessage.message(
            for: QwenHelperClientError.httpStatus(500, "Unsupported model ID"),
            language: .chinese
        )
        XCTAssertTrue(helper.hasPrefix("本地转写组件"))
        XCTAssertTrue(helper.contains("HTTP 500: Unsupported model ID"))

        let generic = UserFacingErrorMessage.message(for: CocoaError(.fileWriteNoPermission), language: .english)
        XCTAssertTrue(generic.hasPrefix("That didn't work."))
        XCTAssertTrue(generic.contains("Technical detail:"))
    }

    func testDictionaryAndClipboardMessages() {
        XCTAssertEqual(UserFacingErrorMessage.message(for: HotwordStoreError.emptyText, language: .chinese), "词条不能为空。")
        let url = URL(fileURLWithPath: "/tmp/diagnostics.json")
        let copy = UserFacingErrorMessage.message(for: DiagnosticsCopyError.pasteboardWriteFailed(url), language: .chinese)
        XCTAssertTrue(copy.contains("/tmp/diagnostics.json"))
    }

    func testOnboardingBundleFailureFollowsLanguage() {
        guard case let .failed(message) = OnboardingPrepareState.state(for: .blockedByAppBundle, language: .chinese) else {
            return XCTFail("blockedByAppBundle should be a failure")
        }
        XCTAssertTrue(message.contains("安装文件不完整"))
        XCTAssertEqual(OnboardingCopy.texts(for: .english).practiceFailedWithReason("No speech"), "That didn't work. Hold Fn and try again. (No speech)")
        XCTAssertEqual(OnboardingCopy.texts(for: .chinese).practiceFailedWithReason("没有检测到语音"), "这次没成功，再按住 Fn 试一次。（没有检测到语音）")
    }

    func testCopyTablesKnowTheirLanguage() {
        XCTAssertEqual(AppCopy.texts(for: .chinese).language, .chinese)
        XCTAssertTrue(AppCopy.texts(for: .chinese).usesChinese)
        XCTAssertFalse(AppCopy.texts(for: .english).usesChinese)
    }
}
