import Foundation

enum FillerCleanupFormatter {
    static func format(_ text: String) -> String {
        formatWithEvents(text).text
    }

    static func formatWithEvents(
        _ text: String,
        context: NormalizationContext = NormalizationContext()
    ) -> FillerCleanupResult {
        FillerCleanupEngine.clean(text, context: context)
    }
}
