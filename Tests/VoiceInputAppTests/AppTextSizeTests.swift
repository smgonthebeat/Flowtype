import AppKit
import XCTest
@testable import VoiceInputApp

final class AppTextSizeTests: XCTestCase {
    func testSmallKeepsTheOriginalSizes() {
        for base: CGFloat in [10, 12, 13, 15, 17, 20, 24, 34] {
            XCTAssertEqual(AppTextSize.small.scaled(base), base)
        }
    }

    func testStandardAndLargeEnlargeReadingTextSlightly() {
        // Owner decision: keep the original layout, make reading text a little larger.
        XCTAssertEqual(AppTextSize.defaultSize, .standard)
        XCTAssertEqual(AppTextSize.standard.scaled(13), 14)
        XCTAssertEqual(AppTextSize.standard.scaled(12), 13)
        XCTAssertEqual(AppTextSize.standard.scaled(10), 11)
        XCTAssertEqual(AppTextSize.large.scaled(13), 15)
        XCTAssertEqual(AppTextSize.large.scaled(12), 14)
    }

    func testLayoutTextKeepsItsOriginalSize() {
        // Titles, sidebar navigation, stat numbers and headings (15pt and up) do not change.
        for size in AppTextSize.allCases {
            for base: CGFloat in [15, 17, 20, 24, 30, 34, 38] {
                XCTAssertEqual(size.scaled(base), base)
            }
        }
    }

    func testStepsStopAtTheEnds() {
        XCTAssertEqual(AppTextSize.small.larger, .standard)
        XCTAssertEqual(AppTextSize.standard.larger, .large)
        XCTAssertNil(AppTextSize.large.larger)
        XCTAssertEqual(AppTextSize.large.smaller, .standard)
        XCTAssertNil(AppTextSize.small.smaller)
    }

    func testSettingsStorePersistsTextSize() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.textSize, .standard)

        store.textSize = .large
        XCTAssertEqual(SettingsStore(defaults: defaults).textSize, .large)

        defaults.set("huge", forKey: "textSize")
        XCTAssertEqual(SettingsStore(defaults: defaults).textSize, .standard)
    }

    func testOnboardingWindowKeepsItsSizeExceptAtLarge() {
        XCTAssertEqual(OnboardingLayout.windowSize(for: .small), OnboardingLayout.baseWindowSize)
        XCTAssertEqual(OnboardingLayout.windowSize(for: .standard), OnboardingLayout.baseWindowSize)
        let large = OnboardingLayout.windowSize(for: .large)
        XCTAssertEqual(large.width, OnboardingLayout.baseWindowSize.width)
        XCTAssertGreaterThan(large.height, OnboardingLayout.baseWindowSize.height)
        XCTAssertLessThanOrEqual(large.height, 720)
    }

    func testViewMenuOffersTextSizeShortcuts() {
        for language in UILanguage.allCases {
            let copy = AppCopy.texts(for: language)
            let viewMenu = AppMainMenu.make(copy: copy).item(withTitle: copy.mainMenuView)?.submenu
            XCTAssertNotNil(viewMenu)
            let bigger = viewMenu?.items.filter { $0.action == #selector(AppDelegate.increaseTextSize(_:)) } ?? []
            XCTAssertEqual(Set(bigger.map(\.keyEquivalent)), ["+", "="])
            XCTAssertEqual(bigger.filter { !$0.isHidden }.count, 1)
            XCTAssertTrue(bigger.filter(\.isHidden).allSatisfy(\.allowsKeyEquivalentWhenHidden))
            XCTAssertEqual(viewMenu?.item(withTitle: copy.mainMenuTextSmaller)?.keyEquivalent, "-")
            XCTAssertEqual(viewMenu?.item(withTitle: copy.mainMenuTextSmaller)?.action, #selector(AppDelegate.decreaseTextSize(_:)))
            XCTAssertEqual(viewMenu?.item(withTitle: copy.mainMenuTextDefault)?.keyEquivalent, "0")
        }
    }
}
