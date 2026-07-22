import XCTest
@testable import VoiceInputApp

final class ASRConfusionCorrectorTests: XCTestCase {
    func testGeneralProfileLeavesVarianceNearMissesUnchanged() {
        let result = ASRConfusionCorrector.correct("variant of X", profile: .general)

        XCTAssertEqual(result.text, "variant of X")
        XCTAssertTrue(result.events.isEmpty)
    }

    func testMathProfileCorrectsVariantOfMathSymbol() {
        let result = ASRConfusionCorrector.correct("variant of X", profile: .mathStatistics)

        XCTAssertEqual(result.text, "variance of X")
        XCTAssertEqual(result.events.first?.ruleID, "variance.variant-of-symbol")
        XCTAssertEqual(result.events.first?.confidence, .high)
    }

    func testMathProfileCorrectsPluralVariantsOfMathSymbol() {
        let result = ASRConfusionCorrector.correct("Variants of Y.", profile: .mathStatistics)

        XCTAssertEqual(result.text, "variance of Y.")
        XCTAssertEqual(result.events.first?.ruleID, "variance.variant-of-symbol")
    }

    func testMathProfileCorrectsVariantOfBetaHat() {
        let result = ASRConfusionCorrector.correct("variant of beta hat", profile: .mathStatistics)

        XCTAssertEqual(result.text, "variance of beta hat")
    }

    func testVariantOfUsesFullGreekCatalog() {
        let result = ASRConfusionCorrector.correct(
            "variant of nu and variant of lambda",
            profile: .mathStatistics
        )

        XCTAssertEqual(result.text, "variance of nu and variance of lambda")
        XCTAssertTrue(result.events.contains { $0.ruleID == "variance.variant-of-symbol" })
    }

    func testDoesNotRewritePlainEnglishVariantContext() {
        let result = ASRConfusionCorrector.correct(
            "the variant in my schedule is annoying",
            profile: .mathStatistics
        )

        XCTAssertEqual(result.text, "the variant in my schedule is annoying")
        XCTAssertTrue(result.events.isEmpty)
    }

    func testDoesNotRewriteVariantOfBetaReleasePlainEnglishContext() {
        let result = ASRConfusionCorrector.correct(
            "variant of beta release",
            profile: .mathStatistics
        )

        XCTAssertEqual(result.text, "variant of beta release")
        XCTAssertTrue(result.events.isEmpty)
    }

    func testDoesNotRewriteVariantGreekAlias() {
        let result = ASRConfusionCorrector.correct("variant theta", profile: .mathStatistics)

        XCTAssertEqual(result.text, "variant theta")
        XCTAssertTrue(result.events.isEmpty)
    }

    func testCorrectsStandardErrorBetaHatNearMisses() {
        XCTAssertEqual(
            ASRConfusionCorrector.correct("SE better head", profile: .mathStatistics).text,
            "SE beta hat"
        )
        XCTAssertEqual(
            ASRConfusionCorrector.correct("standard arrow better hat", profile: .mathStatistics).text,
            "standard error beta hat"
        )
        XCTAssertEqual(
            ASRConfusionCorrector.correct("standard arrow beta head", profile: .mathStatistics).text,
            "standard error beta hat"
        )
        XCTAssertEqual(
            ASRConfusionCorrector.correct("standard error bad head", profile: .mathStatistics).text,
            "standard error beta hat"
        )
        XCTAssertEqual(
            ASRConfusionCorrector.correct("standard error beta head", profile: .mathStatistics).text,
            "standard error beta hat"
        )
    }

    func testDoesNotRewritePlainEnglishStandardArrow() {
        let result = ASRConfusionCorrector.correct("standard arrow message", profile: .mathStatistics)

        XCTAssertEqual(result.text, "standard arrow message")
        XCTAssertTrue(result.events.isEmpty)
    }

    func testCorrectsSpacedStandardDeviationWhenArgumentIsMath() {
        let result = ASRConfusionCorrector.correct("S D X bar", profile: .mathStatistics)

        XCTAssertEqual(result.text, "standard deviation X bar")
        XCTAssertEqual(result.events.first?.ruleID, "standard-deviation.spaced-abbreviation")
    }

    func testDoesNotCorrectSpacedStandardDeviationAcronymLikeArgument() {
        let result = ASRConfusionCorrector.correct("S D I", profile: .mathStatistics)

        XCTAssertEqual(result.text, "S D I")
        XCTAssertTrue(result.events.isEmpty)
    }

    func testDoesNotCorrectSpacedStandardDeviationPlainEnglishArgument() {
        let result = ASRConfusionCorrector.correct("S D card", profile: .mathStatistics)

        XCTAssertEqual(result.text, "S D card")
        XCTAssertTrue(result.events.isEmpty)
    }

    func testCorrectsSpacedStandardErrorBetaHead() {
        let result = ASRConfusionCorrector.correct("S E beta head", profile: .mathStatistics)

        XCTAssertEqual(result.text, "standard error beta hat")
        XCTAssertEqual(result.events.first?.ruleID, "standard-error.beta-hat-near-miss")
    }

    func testDoesNotCorrectSpacedStandardErrorPlainEnglishArgument() {
        let result = ASRConfusionCorrector.correct("S E support ticket", profile: .mathStatistics)

        XCTAssertEqual(result.text, "S E support ticket")
        XCTAssertTrue(result.events.isEmpty)
    }

    func testCorrectsCoreTwoMathSymbolsToCorrelation() {
        let result = ASRConfusionCorrector.correct("core x y", profile: .mathStatistics)

        XCTAssertEqual(result.text, "corr x y")
        XCTAssertEqual(result.events.first?.ruleID, "correlation.core-two-symbols")
    }

    func testCoreCorrelationUsesFullGreekCatalog() {
        let result = ASRConfusionCorrector.correct(
            "core nu mu",
            profile: .mathStatistics
        )

        XCTAssertEqual(result.text, "corr nu mu")
        XCTAssertTrue(result.events.contains { $0.ruleID == "correlation.core-two-symbols" })
    }

    func testDoesNotCorrectPlainEnglishCore() {
        let result = ASRConfusionCorrector.correct("core ideas are useful", profile: .mathStatistics)

        XCTAssertEqual(result.text, "core ideas are useful")
        XCTAssertTrue(result.events.isEmpty)
    }

    func testExpandedCoreCorrelationStillPreservesPlainEnglish() {
        let cases = [
            "core ideas are useful",
            "core id is required",
            "core app settings",
            "this product variant is cheaper",
            "the variant in my schedule is annoying"
        ]

        for input in cases {
            let result = ASRConfusionCorrector.correct(input, profile: .mathStatistics)
            XCTAssertEqual(result.text, input, input)
        }
    }

    func testDoesNotCorrectCoreAcronymLikeArguments() {
        let result = ASRConfusionCorrector.correct("core i d", profile: .mathStatistics)

        XCTAssertEqual(result.text, "core i d")
        XCTAssertTrue(result.events.isEmpty)
    }

    func testCorrectsKSquaredWithTwoDegreesOfFreedomToChiSquared() {
        let result = ASRConfusionCorrector.correct(
            "K squared with 2 degrees of freedom",
            profile: .mathStatistics
        )

        XCTAssertEqual(result.text, "chi squared with 2 degrees of freedom")
        XCTAssertEqual(result.events.first?.ruleID, "chi-square.k-squared-dof")
    }

    func testCorrectsKSquaredWithSpokenTwoDegreesOfFreedomToChiSquared() {
        let result = ASRConfusionCorrector.correct(
            "K squared with two degrees of freedom",
            profile: .mathStatistics
        )

        XCTAssertEqual(result.text, "chi squared with 2 degrees of freedom")
        XCTAssertEqual(result.events.first?.ruleID, "chi-square.k-squared-dof")
    }

    func testCorrectsCarIsSquaredWithDegreesOfFreedomToChiSquared() {
        let result = ASRConfusionCorrector.correct(
            "Car is squared with 2 degrees of freedom",
            profile: .mathStatistics
        )

        XCTAssertEqual(result.text, "chi squared with 2 degrees of freedom")
        XCTAssertEqual(result.events.first?.ruleID, "chi-square.k-squared-dof")
    }

    func testCorrectsChiSquaredNearMissFamilyWithDegreesOfFreedom() {
        let inputs = [
            "Cai squared with 2 degrees of freedom",
            "Coy squared with 2 degrees of freedom",
            "kai squared with 2 degrees of freedom",
            "开 squared with 2 degrees of freedom"
        ]

        for input in inputs {
            let result = ASRConfusionCorrector.correct(input, profile: .mathStatistics)

            XCTAssertEqual(result.text, "chi squared with 2 degrees of freedom", input)
            XCTAssertEqual(result.events.first?.ruleID, "chi-square.k-squared-dof", input)
        }
    }

    func testCorrectsAlreadyRenderedKSquaredWithOfDegreesOfFreedom() {
        let result = ASRConfusionCorrector.correct(
            "K² of 2 degrees of freedom",
            profile: .mathStatistics
        )

        XCTAssertEqual(result.text, "chi squared with 2 degrees of freedom")
        XCTAssertEqual(result.events.first?.ruleID, "chi-square.k-squared-dof")
    }

    func testCorrectsChiSquaredDegreesOfFreedomCounts() {
        let cases = [
            ("K squared with 3 degrees of freedom", "chi squared with 3 degrees of freedom"),
            ("K² of 4 degrees of freedom", "chi squared with 4 degrees of freedom"),
            ("Cai squared with eight degrees of freedom", "chi squared with 8 degrees of freedom"),
            ("K squared with one degree of freedom", "chi squared with 1 degree of freedom")
        ]

        for (input, expected) in cases {
            let result = ASRConfusionCorrector.correct(input, profile: .mathStatistics)

            XCTAssertEqual(result.text, expected, input)
            XCTAssertEqual(result.events.first?.ruleID, "chi-square.k-squared-dof", input)
        }
    }

    func testCorrectsChiSquaredDistributionNearMisses() {
        let inputs = [
            "Kia Squid Distribution",
            "开spread distribution"
        ]

        for input in inputs {
            let result = ASRConfusionCorrector.correct(input, profile: .mathStatistics)

            XCTAssertEqual(result.text, "chi squared distribution", input)
            XCTAssertEqual(result.events.first?.ruleID, "chi-square.distribution-near-miss", input)
        }
    }

    func testCorrectsStandaloneKaiSquadMixedLanguageNearMiss() {
        let result = ASRConfusionCorrector.correct("开Squad", profile: .mathStatistics)

        XCTAssertEqual(result.text, "chi squared")
        XCTAssertEqual(result.events.first?.ruleID, "chi-square.standalone-near-miss")
    }

    func testProtectsInlineCode() {
        let result = ASRConfusionCorrector.correct(
            "Use `variant of X` then variant of X",
            profile: .mathStatistics
        )

        XCTAssertEqual(result.text, "Use `variant of X` then variance of X")
    }

    func testEventRangeIsExplicitlySegmentRelativeForProtectedSegments() {
        let result = ASRConfusionCorrector.correct(
            "Use `variant of X` then variant of X",
            profile: .mathStatistics
        )

        XCTAssertEqual(result.text, "Use `variant of X` then variance of X")
        XCTAssertEqual(result.events.first?.rangeDescription, "segment:6..<18")
    }
}
