import Foundation

struct DiagnosticsFileResult: Equatable {
    let latestURL: URL
    let timestampedURL: URL
    let generatedAt: Date
    let text: String
    let timestampedFileName: String
}

struct DiagnosticsFileWriter {
    private let applicationSupportRoot: URL
    private let makeText: @Sendable (ReadinessReport) async -> String
    private let makeFallbackText: @Sendable (ReadinessReport, Date) -> String
    private let textTimeoutNanoseconds: UInt64
    private let fileManager: FileManager
    private let now: () -> Date
    private let calendar: Calendar
    private let timeZone: TimeZone

    var diagnosticsDirectory: URL {
        applicationSupportRoot.appendingPathComponent("Diagnostics", isDirectory: true)
    }

    init(
        applicationSupportRoot: URL? = nil,
        textBuilder: DiagnosticsTextBuilder? = nil,
        makeText: (@Sendable (ReadinessReport) async -> String)? = nil,
        textTimeoutNanoseconds: UInt64 = 8_000_000_000,
        fileManager: FileManager = .default,
        now: @escaping () -> Date = Date.init,
        calendar: Calendar = Calendar(identifier: .gregorian),
        timeZone: TimeZone = .current
    ) {
        let root = applicationSupportRoot ?? ((try? ApplicationSupport.directory(fileManager: fileManager)) ??
            fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(ApplicationSupport.appDirectoryName, isDirectory: true))
        self.applicationSupportRoot = root
        let builder = textBuilder ?? DiagnosticsTextBuilder(applicationSupportRoot: root, fileManager: fileManager)
        self.makeText = makeText ?? { report in
            await builder.makeDiagnosticsText(report: report)
        }
        self.makeFallbackText = { report, generatedAt in
            builder.makeTimeoutFallbackText(report: report, generatedAt: generatedAt)
        }
        self.textTimeoutNanoseconds = textTimeoutNanoseconds
        self.fileManager = fileManager
        self.now = now
        self.calendar = calendar
        self.timeZone = timeZone
    }

    func generate(report: ReadinessReport) async throws -> DiagnosticsFileResult {
        let generatedAt = now()
        let latestURL = diagnosticsDirectory.appendingPathComponent("latest-diagnostics.txt")
        let timestampedFileName = Self.timestampedFileName(for: generatedAt, calendar: calendar, timeZone: timeZone)
        let timestampedURL = diagnosticsDirectory.appendingPathComponent(timestampedFileName)
        var text = makeFallbackText(report, generatedAt)

        try fileManager.createDirectory(at: diagnosticsDirectory, withIntermediateDirectories: true)
        try text.write(to: latestURL, atomically: true, encoding: .utf8)
        try text.write(to: timestampedURL, atomically: true, encoding: .utf8)

        switch await detailedTextRace(report: report) {
        case .detailed(let detailedText):
            text = detailedText
            try writeDiagnosticsText(text, latestURL: latestURL, timestampedURL: timestampedURL)
        case .timedOut(let detailedTask):
            Task(priority: .utility) {
                let detailedText = await detailedTask.value
                try? writeDiagnosticsText(detailedText, latestURL: latestURL, timestampedURL: timestampedURL)
            }
            break
        }

        return DiagnosticsFileResult(
            latestURL: latestURL,
            timestampedURL: timestampedURL,
            generatedAt: generatedAt,
            text: text,
            timestampedFileName: timestampedFileName
        )
    }

    private func detailedTextRace(report: ReadinessReport) async -> DiagnosticsTextRaceResult {
        let state = DiagnosticsTextRaceState()
        let detailedTask = Task {
            await makeText(report)
        }

        return await withCheckedContinuation { continuation in
            Task {
                let text = await detailedTask.value
                state.finish(.detailed(text), continuation: continuation)
            }
            Task {
                try? await Task.sleep(nanoseconds: textTimeoutNanoseconds)
                state.finish(.timedOut(detailedTask), continuation: continuation)
            }
        }
    }

    private func writeDiagnosticsText(_ text: String, latestURL: URL, timestampedURL: URL) throws {
        try text.write(to: latestURL, atomically: true, encoding: .utf8)
        try text.write(to: timestampedURL, atomically: true, encoding: .utf8)
    }

    private static func timestampedFileName(for date: Date, calendar: Calendar, timeZone: TimeZone) -> String {
        var calendar = calendar
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        return String(
            format: "flowtype-diagnostics-%04d%02d%02d-%02d%02d%02d.txt",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0,
            components.hour ?? 0,
            components.minute ?? 0,
            components.second ?? 0
        )
    }
}

private enum DiagnosticsTextRaceResult {
    case detailed(String)
    case timedOut(Task<String, Never>)
}

private final class DiagnosticsTextRaceState: @unchecked Sendable {
    private let lock = NSLock()
    private var didFinish = false

    func finish(
        _ result: DiagnosticsTextRaceResult,
        continuation: CheckedContinuation<DiagnosticsTextRaceResult, Never>
    ) {
        lock.lock()
        guard !didFinish else {
            lock.unlock()
            return
        }
        didFinish = true
        lock.unlock()

        continuation.resume(returning: result)
    }
}
