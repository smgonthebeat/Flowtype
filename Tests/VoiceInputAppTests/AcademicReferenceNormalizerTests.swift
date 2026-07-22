import XCTest
@testable import VoiceInputApp

final class AcademicReferenceNormalizerTests: XCTestCase {
    func testFormatsSheetExerciseReferences() {
        XCTAssertEqual(
            AcademicReferenceNormalizer.normalize("sheet 一 exercise 四", context: NormalizationContext()),
            "Sheet 1 Exercise 4"
        )
        XCTAssertEqual(
            AcademicReferenceNormalizer.normalize("sheet one 的 exercise 四 b and c", context: NormalizationContext()),
            "Sheet 1 Exercise 4(b) and (c)"
        )
        XCTAssertEqual(
            AcademicReferenceNormalizer.normalize("Sheet One的Exercise四B和C", context: NormalizationContext()),
            "Sheet 1 Exercise 4(b) and (c)"
        )
        XCTAssertEqual(
            AcademicReferenceNormalizer.normalize("SSheet One的Exercise四B和C", context: NormalizationContext()),
            "Sheet 1 Exercise 4(b) and (c)"
        )
        XCTAssertEqual(
            AcademicReferenceNormalizer.normalize("sheet e Exercise 4", context: NormalizationContext()),
            "Sheet 1 Exercise 4"
        )
        XCTAssertEqual(
            AcademicReferenceNormalizer.normalize("Sheet 1 的 exercise。四B和C", context: NormalizationContext()),
            "Sheet 1 Exercise 4(b) and (c)"
        )
        XCTAssertEqual(
            AcademicReferenceNormalizer.normalize("cheat twelve exercise five", context: NormalizationContext()),
            "Sheet 12 Exercise 5"
        )
        XCTAssertEqual(
            AcademicReferenceNormalizer.normalize("cheat 1 Exercise 4", context: NormalizationContext()),
            "Sheet 1 Exercise 4"
        )
        XCTAssertEqual(
            AcademicReferenceNormalizer.normalize("cheat fifty exercise twenty one", context: NormalizationContext()),
            "Sheet 50 Exercise 21"
        )
    }

    func testFormatsExerciseSheetReferences() {
        XCTAssertEqual(
            AcademicReferenceNormalizer.normalize("exercise sheet four", context: NormalizationContext()),
            "Exercise Sheet 4"
        )
        XCTAssertEqual(
            AcademicReferenceNormalizer.normalize("exercise cheat four", context: NormalizationContext()),
            "Exercise Sheet 4"
        )
        XCTAssertEqual(
            AcademicReferenceNormalizer.normalize("exercise sheet ninety nine", context: NormalizationContext()),
            "Exercise Sheet 99"
        )
        XCTAssertEqual(
            AcademicReferenceNormalizer.normalize("sheet exercise四", context: NormalizationContext()),
            "Sheet Exercise 4"
        )
    }

    func testFormatsStandaloneExerciseReferences() {
        XCTAssertEqual(
            AcademicReferenceNormalizer.normalize("Exercise four B and C.", context: NormalizationContext()),
            "Exercise 4(b) and (c)."
        )
        XCTAssertEqual(
            AcademicReferenceNormalizer.normalize("Exercise 4B and C.", context: NormalizationContext()),
            "Exercise 4(b) and (c)."
        )
    }

    func testFormatsExerciseQuestionReferences() {
        XCTAssertEqual(
            AcademicReferenceNormalizer.normalize("Exercise 3 Q 1", context: NormalizationContext()),
            "Exercise 3 Q1"
        )
        XCTAssertEqual(
            AcademicReferenceNormalizer.normalize("Exercise three Q one", context: NormalizationContext()),
            "Exercise 3 Q1"
        )
        XCTAssertEqual(
            AcademicReferenceNormalizer.normalize("Exercise 12 Q twenty", context: NormalizationContext()),
            "Exercise 12 Q20"
        )
        XCTAssertEqual(
            AcademicReferenceNormalizer.normalize("Exercise 3 Q 1 b", context: NormalizationContext()),
            "Exercise 3 Q1(b)"
        )
        XCTAssertEqual(
            AcademicReferenceNormalizer.normalize("Exercise 3 Q two H", context: NormalizationContext()),
            "Exercise 3 Q2(h)"
        )
    }

    func testFormatsQuestionSheetReferences() {
        XCTAssertEqual(
            AcademicReferenceNormalizer.normalize("question sheet one", context: NormalizationContext()),
            "Question Sheet 1"
        )
        XCTAssertEqual(
            AcademicReferenceNormalizer.normalize("Question Sheet 20", context: NormalizationContext()),
            "Question Sheet 20"
        )
    }

    func testFormatsStandaloneSheetReferences() {
        XCTAssertEqual(
            AcademicReferenceNormalizer.normalize("Sheet one.", context: NormalizationContext()),
            "Sheet 1."
        )
        XCTAssertEqual(
            AcademicReferenceNormalizer.normalize("Sheet十二.", context: NormalizationContext()),
            "Sheet 12."
        )
        XCTAssertEqual(
            AcademicReferenceNormalizer.normalize("cheat five.", context: NormalizationContext()),
            "Sheet 5."
        )
    }

    func testRepairsCommandContextCheatSheetMisrecognition() {
        XCTAssertEqual(
            AcademicReferenceNormalizer.normalize("请打开 cheat two。", context: NormalizationContext()),
            "请打开 Sheet 2。"
        )
        XCTAssertEqual(
            AcademicReferenceNormalizer.normalize("打开 cheat four.", context: NormalizationContext()),
            "打开 Sheet 4."
        )
    }

    func testFormatsQuestionReferences() {
        XCTAssertEqual(
            AcademicReferenceNormalizer.normalize("q 四 b and c", context: NormalizationContext()),
            "Q4(b) and (c)"
        )
        XCTAssertEqual(
            AcademicReferenceNormalizer.normalize("Q4 BNC", context: NormalizationContext()),
            "Q4(b) and (c)"
        )
        XCTAssertEqual(
            AcademicReferenceNormalizer.normalize("question 一", context: NormalizationContext()),
            "Question 1"
        )
    }

    func testFormatsAcademicLetterNumberSequencesInContext() {
        XCTAssertEqual(
            AcademicReferenceNormalizer.normalize("A one，一, A two，二。", context: NormalizationContext()),
            "A1，1, A2，2。"
        )
        XCTAssertEqual(
            AcademicReferenceNormalizer.normalize("A 一 B and C", context: NormalizationContext()),
            "A1(b) and (c)"
        )
        XCTAssertEqual(
            AcademicReferenceNormalizer.normalize("A1 BNC", context: NormalizationContext()),
            "A1(b) and (c)"
        )
    }

    func testFormatsAcademicLetterNumbersBeforeStudyContext() {
        XCTAssertEqual(
            AcademicReferenceNormalizer.normalize("B one的题。", context: NormalizationContext()),
            "B1的题。"
        )
        XCTAssertEqual(
            AcademicReferenceNormalizer.normalize("OK，我们现在来讲 B一的题。", context: NormalizationContext()),
            "OK，我们现在来讲 B1的题。"
        )
        XCTAssertEqual(
            AcademicReferenceNormalizer.normalize("我们现在来讲 B two 的题。", context: NormalizationContext()),
            "我们现在来讲 B2 的题。"
        )
        XCTAssertEqual(
            AcademicReferenceNormalizer.normalize("A five的 cheat sheet。", context: NormalizationContext()),
            "A5的 cheat sheet。"
        )
        XCTAssertEqual(
            AcademicReferenceNormalizer.normalize("A五的 cheat sheet。", context: NormalizationContext()),
            "A5的 cheat sheet。"
        )
        XCTAssertEqual(
            AcademicReferenceNormalizer.normalize("A two 就不可以。", context: NormalizationContext()),
            "A2 就不可以。"
        )
        XCTAssertEqual(
            AcademicReferenceNormalizer.normalize("A one可以，然后 A two就不可以吧？", context: NormalizationContext()),
            "A1可以，然后 A2就不可以吧？"
        )
        XCTAssertEqual(
            AcademicReferenceNormalizer.normalize("C十二要背，X five 的 cheat sheet。", context: NormalizationContext()),
            "C12要背，X5 的 cheat sheet。"
        )
        XCTAssertEqual(
            AcademicReferenceNormalizer.normalize("x五的cheat sheet。c十二要背，b一的题，a one的题，a two的题。", context: NormalizationContext()),
            "X5的cheat sheet。C12要背，B1的题，A1的题，A2的题。"
        )
        XCTAssertEqual(
            AcademicReferenceNormalizer.normalize("bit六，bit一的cheat sheet。", context: NormalizationContext()),
            "B6，B1的cheat sheet。"
        )
    }

    func testFormatsStudySectionReferencesBeforeChineseMemoContext() {
        XCTAssertEqual(
            AcademicReferenceNormalizer.normalize("就是 A four要背的内容。", context: NormalizationContext()),
            "就是 A4要背的内容。"
        )
        XCTAssertEqual(
            AcademicReferenceNormalizer.normalize("就是A四要背的内容。", context: NormalizationContext()),
            "就是A4要背的内容。"
        )
    }

    func testLeavesFalseFriendsUnchanged() {
        XCTAssertEqual(
            AcademicReferenceNormalizer.normalize("I like sheet music", context: NormalizationContext()),
            "I like sheet music"
        )
        XCTAssertEqual(
            AcademicReferenceNormalizer.normalize("B and C are variables", context: NormalizationContext()),
            "B and C are variables"
        )
        XCTAssertEqual(
            AcademicReferenceNormalizer.normalize("我有四个要背的内容。", context: NormalizationContext()),
            "我有四个要背的内容。"
        )
        XCTAssertEqual(
            AcademicReferenceNormalizer.normalize("a one-time reminder", context: NormalizationContext()),
            "a one-time reminder"
        )
    }
}
