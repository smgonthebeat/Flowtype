import XCTest
@testable import VoiceInputApp

final class HelpCopyTests: XCTestCase {
    func testBothLanguagesCoverTheSameProblemsWithTheSameActions() {
        let chinese = HelpCopy.texts(for: .chinese).problems
        let english = HelpCopy.texts(for: .english).problems
        XCTAssertEqual(chinese.map(\.id), english.map(\.id))
        XCTAssertEqual(chinese.map(\.action), english.map(\.action))
        XCTAssertEqual(Set(chinese.map(\.id)).count, chinese.count)
    }

    func testAnswersUseTheLabelsTheAppShows() {
        let zh = AppCopy.texts(for: .chinese)
        let en = AppCopy.texts(for: .english)
        let zhAnswers = HelpCopy.texts(for: .chinese).problems.map(\.answer).joined()
        let enAnswers = HelpCopy.texts(for: .english).problems.map(\.answer).joined()
        XCTAssertTrue(zhAnswers.contains(zh.rowPossibleTruncation))
        XCTAssertTrue(enAnswers.contains(en.rowPossibleTruncation))
        XCTAssertTrue(zhAnswers.contains(zh.rowRetrySegmented))
        XCTAssertTrue(enAnswers.contains(en.rowRetrySegmented))
        XCTAssertTrue(zhAnswers.contains(zh.capsuleCopiedPressToPaste))
        XCTAssertTrue(enAnswers.contains(en.capsuleCopiedPressToPaste))
        XCTAssertTrue(zhAnswers.contains(zh.modelPrecisionRoleTitle))
        XCTAssertTrue(enAnswers.contains(en.modelPrecisionRoleTitle))
        for language in UILanguage.allCases {
            let preferences = PreferencesCopy.texts(for: language)
            let answers = HelpCopy.texts(for: language).problems.map(\.answer).joined()
            XCTAssertTrue(answers.contains(preferences.numericFormattingTitle))
            XCTAssertTrue(answers.contains(preferences.fillerCleanupTitle))
            XCTAssertTrue(answers.contains(preferences.academicReferenceFormattingTitle))
            XCTAssertTrue(answers.contains(preferences.mathNotationTitle))
        }
    }

    func testOldPermissionWordingStaysGone() {
        // Kept from the previous help text: permissions live in 准备状态, not "设置权限".
        let zh = HelpCopy.texts(for: .chinese).problems.map(\.answer).joined()
        XCTAssertFalse(zh.contains("设置权限"))
        XCTAssertTrue(zh.contains("准备状态"))
    }

    func testContactLinksPointAtTheOwnersEmailAndIssues() throws {
        XCTAssertEqual(HelpContact.issuesURL.absoluteString, "https://github.com/smgonthebeat/Flowtype/issues")
        for language in UILanguage.allCases {
            let copy = HelpCopy.texts(for: language)
            let url = try XCTUnwrap(HelpContact.mailURL(subject: copy.contactEmailSubject, body: copy.contactEmailBody))
            XCTAssertEqual(url.scheme, "mailto")
            let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
            XCTAssertEqual(components.path, HelpContact.email)
            let items = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
            XCTAssertEqual(items["subject"], copy.contactEmailSubject)
            XCTAssertEqual(items["body"], copy.contactEmailBody)
            // The body tells the user where to paste the copied report.
            XCTAssertTrue(copy.contactEmailBody.contains("⌘V"))
            // The diagnostics text names both destinations it now offers.
            XCTAssertTrue(copy.diagnosticsBody.contains("GitHub"))
        }
    }
}
