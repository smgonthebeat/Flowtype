import Foundation
import XCTest
@testable import VoiceInputApp

final class AppBundleContractParityTests: XCTestCase {
    func testSwiftPMResourcesExactlyMatchAuthoringContract() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let report = try appBundleContractParityReport(repositoryRoot: repositoryRoot)

        XCTAssertTrue(report.isExactMatch, report.diagnostic)
    }

    func testRuntimeInspectionGroupsExactlyMatchAuthoringContract() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let contract = try authoringContract(repositoryRoot: repositoryRoot)

        XCTAssertEqual(
            AppBundleManifest.requiredInspectionGroups,
            Set(contract.entries.map(\.inspectionGroup)),
            "Swift runtime inspection groups must stay in sync with config/app-bundle-contract.json."
        )
    }

    func testParityDiagnosticNamesMissingExtraAndDuplicatePaths() throws {
        let report = appBundleContractParityReport(
            contractSources: [
                "Resources/Info.plist",
                "Resources/Missing.svg",
                "Resources/Missing.svg"
            ],
            packageSources: [
                "Resources/Info.plist",
                "Resources/Extra.svg",
                "Resources/Extra.svg"
            ]
        )

        XCTAssertEqual(
            report.diagnostic,
            """
            SwiftPM resource parity mismatch:
            missing from Package.swift: Resources/Missing.svg
            extra in Package.swift: Resources/Extra.svg
            duplicate contract sources: Resources/Missing.svg
            duplicate Package.swift sources: Resources/Extra.svg
            """
        )
    }

    func testTestTargetCopyCannotSatisfyAppResourceParity() throws {
        let repositoryRoot = URL(fileURLWithPath: "/repo")
        let packageSources = try voiceInputAppResourceSources(
            in: """
            let package = Package(targets: [
                .executableTarget(
                    name: "VoiceInputApp",
                    resources: []
                ),
                .testTarget(
                    name: "VoiceInputAppTests",
                    resources: [
                        .copy("../../Resources/Info.plist")
                    ]
                )
            ])
            """,
            repositoryRoot: repositoryRoot
        )
        let report = appBundleContractParityReport(
            contractSources: ["Resources/Info.plist"],
            packageSources: packageSources
        )

        XCTAssertEqual(packageSources, [])
        XCTAssertEqual(report.missingFromPackage, ["Resources/Info.plist"])
        XCTAssertEqual(report.extraInPackage, [])
    }

    func testUnrelatedTestTargetCopyIsIgnored() throws {
        let repositoryRoot = URL(fileURLWithPath: "/repo")
        let packageSources = try voiceInputAppResourceSources(
            in: """
            let package = Package(targets: [
                .executableTarget(
                    name: "VoiceInputApp",
                    resources: [
                        .copy("../../Resources/Info.plist")
                    ]
                ),
                .testTarget(
                    name: "VoiceInputAppTests",
                    resources: [
                        .copy("Fixtures/sample.json")
                    ]
                )
            ])
            """,
            repositoryRoot: repositoryRoot
        )

        XCTAssertEqual(packageSources, ["Resources/Info.plist"])
    }
}

private struct AuthoringContract: Decodable {
    let entries: [Entry]

    struct Entry: Decodable {
        let source: String?
        let swiftPMResource: Bool
        let inspectionGroup: String
    }
}

private struct AppBundleContractParityReport {
    let missingFromPackage: [String]
    let extraInPackage: [String]
    let duplicateContractSources: [String]
    let duplicatePackageSources: [String]

    var isExactMatch: Bool {
        missingFromPackage.isEmpty
            && extraInPackage.isEmpty
            && duplicateContractSources.isEmpty
            && duplicatePackageSources.isEmpty
    }

    var diagnostic: String {
        guard !isExactMatch else {
            return "SwiftPM resources exactly match the app bundle contract."
        }

        return [
            "SwiftPM resource parity mismatch:",
            "missing from Package.swift: \(missingFromPackage.joined(separator: ", "))",
            "extra in Package.swift: \(extraInPackage.joined(separator: ", "))",
            "duplicate contract sources: \(duplicateContractSources.joined(separator: ", "))",
            "duplicate Package.swift sources: \(duplicatePackageSources.joined(separator: ", "))"
        ].joined(separator: "\n")
    }
}

private func appBundleContractParityReport(
    repositoryRoot: URL
) throws -> AppBundleContractParityReport {
    let contract = try authoringContract(repositoryRoot: repositoryRoot)
    let contractSources: [String] = try contract.entries.compactMap { entry in
        guard entry.swiftPMResource else { return nil }
        guard let source = entry.source else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return source
    }

    let packageURL = repositoryRoot.appendingPathComponent("Package.swift")
    let packageText = try String(contentsOf: packageURL, encoding: .utf8)
    let packageSources = try voiceInputAppResourceSources(
        in: packageText,
        repositoryRoot: repositoryRoot
    )

    return appBundleContractParityReport(
        contractSources: contractSources,
        packageSources: packageSources
    )
}

private func authoringContract(repositoryRoot: URL) throws -> AuthoringContract {
    let contractURL = repositoryRoot.appendingPathComponent("config/app-bundle-contract.json")
    return try JSONDecoder().decode(
        AuthoringContract.self,
        from: Data(contentsOf: contractURL)
    )
}

private func voiceInputAppResourceSources(
    in packageText: String,
    repositoryRoot: URL
) throws -> [String] {
    let targetExpression = try NSRegularExpression(pattern: #"\.executableTarget\s*\("#)
    let targetMatches = targetExpression.matches(
        in: packageText,
        range: NSRange(packageText.startIndex..., in: packageText)
    )
    let nameExpression = try NSRegularExpression(
        pattern: #"^\(\s*name\s*:\s*"VoiceInputApp""#
    )
    let targetBodies = try targetMatches.compactMap { match -> String? in
        guard let matchRange = Range(match.range, in: packageText) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let openingParenthesis = packageText.index(before: matchRange.upperBound)
        let closingParenthesis = try matchingDelimiter(
            in: packageText,
            openingAt: openingParenthesis,
            open: "(",
            close: ")"
        )
        let body = String(packageText[openingParenthesis...closingParenthesis])
        let bodyRange = NSRange(body.startIndex..., in: body)
        return nameExpression.firstMatch(in: body, range: bodyRange) == nil ? nil : body
    }
    guard targetBodies.count == 1, let targetBody = targetBodies.first else {
        throw CocoaError(.fileReadCorruptFile)
    }

    let resourcesExpression = try NSRegularExpression(pattern: #"\bresources\s*:"#)
    let targetRange = NSRange(targetBody.startIndex..., in: targetBody)
    guard
        let resourcesMatch = resourcesExpression.firstMatch(in: targetBody, range: targetRange),
        let resourcesLabelRange = Range(resourcesMatch.range, in: targetBody),
        let openingBracket = targetBody[resourcesLabelRange.upperBound...].firstIndex(of: "[")
    else {
        throw CocoaError(.fileReadCorruptFile)
    }
    let closingBracket = try matchingDelimiter(
        in: targetBody,
        openingAt: openingBracket,
        open: "[",
        close: "]"
    )
    let resourcesBody = String(targetBody[openingBracket...closingBracket])

    let expression = try NSRegularExpression(pattern: #"\.copy\(\s*"([^"]+)"\s*\)"#)
    let packageSourceBase = repositoryRoot.appendingPathComponent("Sources/VoiceInputApp")
    let resourcesRange = NSRange(resourcesBody.startIndex..., in: resourcesBody)
    return try expression.matches(in: resourcesBody, range: resourcesRange).map { match in
        guard let range = Range(match.range(at: 1), in: resourcesBody) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let targetRelativePath = String(resourcesBody[range])
        let absoluteURL = packageSourceBase
            .appendingPathComponent(targetRelativePath)
            .standardizedFileURL
        return try repositoryRelativePath(for: absoluteURL, repositoryRoot: repositoryRoot)
    }
}

private func matchingDelimiter(
    in text: String,
    openingAt openingIndex: String.Index,
    open: Character,
    close: Character
) throws -> String.Index {
    guard text[openingIndex] == open else {
        throw CocoaError(.fileReadCorruptFile)
    }

    var depth = 0
    var index = openingIndex
    var inString = false
    var isEscaped = false
    while index < text.endIndex {
        let character = text[index]
        if inString {
            if isEscaped {
                isEscaped = false
            } else if character == "\\" {
                isEscaped = true
            } else if character == "\"" {
                inString = false
            }
        } else if character == "\"" {
            inString = true
        } else if character == open {
            depth += 1
        } else if character == close {
            depth -= 1
            if depth == 0 {
                return index
            }
        }
        index = text.index(after: index)
    }
    throw CocoaError(.fileReadCorruptFile)
}

private func appBundleContractParityReport(
    contractSources: [String],
    packageSources: [String]
) -> AppBundleContractParityReport {
    let contractSet = Set(contractSources)
    let packageSet = Set(packageSources)
    return AppBundleContractParityReport(
        missingFromPackage: contractSet.subtracting(packageSet).sorted(),
        extraInPackage: packageSet.subtracting(contractSet).sorted(),
        duplicateContractSources: duplicatePaths(in: contractSources),
        duplicatePackageSources: duplicatePaths(in: packageSources)
    )
}

private func duplicatePaths(in paths: [String]) -> [String] {
    Dictionary(grouping: paths, by: { $0 })
        .filter { $0.value.count > 1 }
        .map(\.key)
        .sorted()
}

private func repositoryRelativePath(for url: URL, repositoryRoot: URL) throws -> String {
    let rootPath = repositoryRoot.standardizedFileURL.path
    let path = url.standardizedFileURL.path
    let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
    guard path.hasPrefix(prefix) else {
        throw CocoaError(.fileReadInvalidFileName)
    }
    return String(path.dropFirst(prefix.count))
}
