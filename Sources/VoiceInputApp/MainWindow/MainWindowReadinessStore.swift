import Combine
import Foundation

@MainActor
final class MainWindowReadinessStore: ObservableObject {
    @Published private(set) var snapshot: ReadinessSnapshot
    @Published private(set) var isRefreshing = false
    @Published private(set) var didLastRefreshFail = false

    private let refreshLightweightAction: () async -> ReadinessReport
    private let refreshLiveAction: () async -> ReadinessReport
    private var liveRefreshTask: Task<ReadinessReport, Never>?
    private var liveRefreshToken: UUID?
    private var followUpRefreshTask: Task<Void, Never>?

    init(
        initialSnapshot: ReadinessSnapshot,
        refreshLightweight: @escaping () async -> ReadinessReport,
        refreshLive: @escaping () async -> ReadinessReport
    ) {
        snapshot = initialSnapshot
        refreshLightweightAction = refreshLightweight
        refreshLiveAction = refreshLive
    }

    var presentation: ReadinessPresentation {
        ReadinessPresentationPolicy.presentation(for: snapshot)
    }

    func accept(_ report: ReadinessReport, coverage: ReadinessCoverage) {
        guard !report.checks.isEmpty else {
            didLastRefreshFail = true
            return
        }
        snapshot = ReadinessSnapshot(
            report: report,
            context: snapshot.context,
            coverage: coverage
        )
        didLastRefreshFail = false
    }

    func replace(with lightweightSnapshot: ReadinessSnapshot) {
        precondition(lightweightSnapshot.coverage == .lightweight)
        liveRefreshToken = nil
        liveRefreshTask?.cancel()
        liveRefreshTask = nil
        isRefreshing = false
        didLastRefreshFail = false
        snapshot = lightweightSnapshot
    }

    func refreshLightweight() async {
        let context = snapshot.context
        let report = await refreshLightweightAction()
        guard context == snapshot.context else { return }
        accept(report, coverage: .lightweight)
    }

    func refreshLive() async {
        if let liveRefreshTask {
            _ = await liveRefreshTask.value
            return
        }

        let context = snapshot.context
        let token = UUID()
        let task = Task { await refreshLiveAction() }
        liveRefreshToken = token
        liveRefreshTask = task
        isRefreshing = true

        let report = await task.value
        guard liveRefreshToken == token else { return }

        liveRefreshToken = nil
        liveRefreshTask = nil
        isRefreshing = false
        guard context == snapshot.context else { return }
        accept(report, coverage: .live)
        if presentation.phase == .preparing {
            scheduleFollowUpRefreshes()
        }
    }

    func scheduleFollowUpRefreshes() {
        guard followUpRefreshTask == nil else { return }
        followUpRefreshTask = Task { [weak self] in
            guard let self else { return }
            defer { followUpRefreshTask = nil }
            for _ in 0..<20 {
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                await refreshLive()
                if presentation.phase == .ready {
                    return
                }
            }
        }
    }

    deinit {
        liveRefreshTask?.cancel()
        followUpRefreshTask?.cancel()
    }
}
