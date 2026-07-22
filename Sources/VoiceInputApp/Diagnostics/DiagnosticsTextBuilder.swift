import Foundation

struct DiagnosticsTextBuilder {
    private let applicationSupportRoot: URL
    private let fileManager: FileManager
    private let diagnosticsExporter: DiagnosticsExporter
    private let timingProvider: @Sendable () -> TranscriptionTimingSample?
    private let processProvider: @Sendable () -> [ProcessRSSSnapshot]
    private let provenanceProvider: @Sendable () -> TranscriptionProvenance?

    init(
        applicationSupportRoot: URL? = nil,
        diagnosticsExporter: DiagnosticsExporter = DiagnosticsExporter(),
        fileManager: FileManager = .default,
        timingProvider: (@Sendable () -> TranscriptionTimingSample?)? = nil,
        processProvider: @escaping @Sendable () -> [ProcessRSSSnapshot] = {
            ProcessRSSSnapshot.flowtypeRelatedProcesses()
        },
        provenanceProvider: (@Sendable () -> TranscriptionProvenance?)? = nil
    ) {
        let root = applicationSupportRoot ?? ((try? ApplicationSupport.directory(fileManager: fileManager)) ??
            fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(ApplicationSupport.appDirectoryName, isDirectory: true))
        self.applicationSupportRoot = root
        self.fileManager = fileManager
        self.diagnosticsExporter = diagnosticsExporter
        self.timingProvider = timingProvider ?? {
            try? TranscriptionTimingStore(applicationSupportRoot: root).loadLastSample()
        }
        self.processProvider = processProvider
        self.provenanceProvider = provenanceProvider ?? {
            try? TranscriptionProvenanceStore(applicationSupportRoot: root).loadRecent().first
        }
    }

    func makeDiagnosticsText(report: ReadinessReport) async -> String {
        await Task.detached(priority: .utility) {
            diagnosticsExporter.makeDiagnosticsText(
                report: report,
                timing: timingProvider(),
                processes: processProvider(),
                provenance: provenanceProvider()
            )
        }.value
    }

    func makeTimeoutFallbackText(report: ReadinessReport, generatedAt: Date) -> String {
        diagnosticsExporter.makeTimeoutFallbackText(
            report: report,
            generatedAt: generatedAt,
            timing: timingProvider(),
            provenance: provenanceProvider()
        )
    }

    func writeLatestDiagnosticsText(_ text: String) throws -> URL {
        let url = applicationSupportRoot
            .appendingPathComponent("Diagnostics", isDirectory: true)
            .appendingPathComponent("latest-diagnostics.txt")
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
