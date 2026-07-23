import Foundation

struct ReadinessSetupResult: Equatable {
    enum Outcome: Equatable {
        case prepared
        case blockedByAppBundle
        case waitingForPermissions
        case waitingForModelDownloadConsent
        case waitingForModelDownload
        case failed(String)
    }

    let outcome: Outcome
    let report: ReadinessReport
}

enum PreparationIntent: Equatable {
    case interactiveSetup
    case backgroundWarmup
    case dictationPreflight
    case resumeAfterUserAction
}

struct PreparationConfiguration: Hashable {
    let engine: TranscriptionEngineKind
    let modelID: String?
    let runtimeRevision: String
    let generation: Int
}

struct PreparationRequest {
    let intent: PreparationIntent
    let configuration: PreparationConfiguration
    var forceModelRepair = false
}

enum PreparationPermission: Equatable {
    case microphone
    case accessibility
    case speechRecognition
}

enum PreparationUserAction: Equatable {
    case microphone
    case accessibility
    case speechRecognition
    case modelDownloadConsent
}

enum PreparationStage: Equatable {
    case inspecting
    case preparingRuntime
    case startingHelper
    case downloadingModel
    case loadingModel
    case verifying
    case awaitingUserAction(PreparationUserAction)
    case ready
    case failed
}

enum ModelPreparationStageResolver {
    static func stage(for status: QwenModelStatus) -> PreparationStage {
        switch status.phase {
        case .downloading, .absent:
            return .downloadingModel
        case .loading:
            // The helper reports `loading` while its background preparation
            // job is starting, before an absent model has begun downloading.
            return status.installed ? .loadingModel : .downloadingModel
        case .installed:
            return .loadingModel
        case .ready:
            return .verifying
        case .failed:
            return .failed
        }
    }
}

enum PreparationFailure: Error, Equatable {
    case appBundleInvalid
    case consentRequired
    case modelPreparationFailed(String)
    case finalVerificationFailed
    case superseded
}

extension PreparationFailure: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .appBundleInvalid:
            return "Flowtype's app bundle is incomplete."
        case .consentRequired:
            return "Model download consent is required."
        case let .modelPreparationFailed(code):
            return "Qwen model preparation failed (\(code))."
        case .finalVerificationFailed:
            return "Flowtype could not verify that the selected runtime is ready."
        case .superseded:
            return "Preparation was superseded by a newer engine or model selection."
        }
    }
}

struct PreparationEvidence {
    let report: ReadinessReport
    let appBundleReady: Bool
    let runtimeAction: ReadinessActionKind?
    let missingPermissions: [PreparationPermission]
    let selectedModelInstalled: Bool
    let selectedModelLoaded: Bool
    let helperHealthy: Bool
}

struct PreparedRuntimeIdentity: Equatable {
    let configuration: PreparationConfiguration
    let bootID: UUID
    let verifiedAt: Date
}

struct PreparationSnapshot: Equatable {
    let runID: UUID
    let operationID: UUID?
    let configuration: PreparationConfiguration
    let stage: PreparationStage
    let progress: Double?
}

struct PreparationResult {
    enum Outcome: Equatable {
        case ready
        case awaitingUserAction(PreparationUserAction)
        case blocked
        case failed(PreparationFailure)
    }

    let outcome: Outcome
    let report: ReadinessReport
    let runtime: PreparedRuntimeIdentity?

    var isReady: Bool {
        outcome == .ready && runtime != nil
    }
}

struct PreparationSession {
    let runID: UUID
    let configuration: PreparationConfiguration
    let updates: AsyncStream<PreparationSnapshot>
    let result: Task<PreparationResult, Never>
}

protocol FlowtypePreparationDriving: AnyObject {
    func inspect(configuration: PreparationConfiguration, live: Bool) async -> PreparationEvidence
    func prepareRuntime(action: ReadinessActionKind) async throws
    func requestPermission(_ permission: PreparationPermission) async
    func hasDownloadConsent(modelID: String) async -> Bool
    func recordDownloadConsent(modelID: String) async
    func repairSelectedModelStorage(configuration: PreparationConfiguration) async throws
    func prepareSelectedModel(
        configuration: PreparationConfiguration,
        operationID: UUID,
        progress: @escaping (PreparationStage, Double?) async -> Void
    ) async throws -> PreparedRuntimeIdentity
}

actor FlowtypePreparation {
    private struct JobKey: Hashable {
        let engine: TranscriptionEngineKind
        let modelID: String?
        let runtimeRevision: String
    }

    private struct MachineJob {
        let configuration: PreparationConfiguration
        let forceModelRepair: Bool
        let operationID: UUID
        let task: Task<Result<PreparedRuntimeIdentity, PreparationFailure>, Never>
    }

    private struct Subscription {
        let key: JobKey
        let configuration: PreparationConfiguration
        let continuation: AsyncStream<PreparationSnapshot>.Continuation
    }

    private let driver: FlowtypePreparationDriving
    private var jobs: [JobKey: MachineJob] = [:]
    private var subscriptions: [UUID: Subscription] = [:]
    private var activeReservations: [UUID: PreparationConfiguration] = [:]
    private var reservationDrainWaiters: [CheckedContinuation<Void, Never>] = []
    private var exclusiveMutationActive = false
    private var exclusiveMutationWaiters: [CheckedContinuation<Void, Never>] = []
    private var exclusiveAvailabilityWaiters: [CheckedContinuation<Void, Never>] = []
    private var desiredConfiguration: PreparationConfiguration?

    init(driver: FlowtypePreparationDriving) {
        self.driver = driver
    }

    func begin(_ request: PreparationRequest) -> PreparationSession {
        let runID = UUID()
        let key = jobKey(for: request.configuration)
        var continuation: AsyncStream<PreparationSnapshot>.Continuation!
        let stream = AsyncStream<PreparationSnapshot>(bufferingPolicy: .bufferingNewest(16)) {
            continuation = $0
        }
        subscriptions[runID] = Subscription(
            key: key,
            configuration: request.configuration,
            continuation: continuation
        )
        acceptDesiredConfiguration(request.configuration)
        continuation.yield(snapshot(
            runID: runID,
            operationID: jobs[key]?.configuration == request.configuration
                ? jobs[key]?.operationID
                : nil,
            configuration: request.configuration,
            stage: .inspecting
        ))

        let result = Task { [weak self] in
            guard let self else {
                return PreparationResult(
                    outcome: .failed(.superseded),
                    report: ReadinessReport(generatedAt: Date(), checks: []),
                    runtime: nil
                )
            }
            let result = await self.run(request: request, runID: runID)
            await self.finishSubscription(runID: runID)
            return result
        }
        return PreparationSession(
            runID: runID,
            configuration: request.configuration,
            updates: stream,
            result: result
        )
    }

    func withPreparedRuntime<T>(
        for configuration: PreparationConfiguration,
        operation: @escaping (PreparedRuntimeIdentity) async throws -> T
    ) async throws -> T {
        while true {
            let session = begin(PreparationRequest(intent: .dictationPreflight, configuration: configuration))
            let result = await session.result.value
            guard result.outcome == .ready, let runtime = result.runtime else {
                switch result.outcome {
                case let .failed(failure): throw failure
                case .awaitingUserAction: throw PreparationFailure.consentRequired
                case .blocked: throw PreparationFailure.appBundleInvalid
                case .ready: throw PreparationFailure.finalVerificationFailed
                }
            }

            guard let token = reserveRuntimeIfAvailable(configuration) else {
                await waitForExclusiveMutation()
                continue
            }
            do {
                let value = try await operation(runtime)
                releaseReservation(token)
                return value
            } catch {
                releaseReservation(token)
                throw error
            }
        }
    }

    func withExclusiveRuntimeMutation<T>(
        _ operation: @escaping () async throws -> T
    ) async throws -> T {
        await acquireExclusiveMutation()
        await waitForReservationsToDrain()
        do {
            let value = try await operation()
            releaseExclusiveMutation()
            return value
        } catch {
            releaseExclusiveMutation()
            throw error
        }
    }

    private func run(request: PreparationRequest, runID: UUID) async -> PreparationResult {
        let configuration = request.configuration
        let key = jobKey(for: configuration)
        var evidence = await driver.inspect(configuration: configuration, live: false)
        guard isCurrent(configuration) else {
            return failed(.superseded, report: evidence.report, runID: runID, configuration: configuration)
        }
        guard evidence.appBundleReady else {
            publish(key: key, configuration: configuration, stage: .failed)
            return PreparationResult(outcome: .blocked, report: evidence.report, runtime: nil)
        }

        for permission in evidence.missingPermissions {
            guard request.intent == .interactiveSetup else {
                return awaiting(userAction(for: permission), evidence: evidence, configuration: configuration)
            }
            publish(
                key: key,
                configuration: configuration,
                stage: .awaitingUserAction(userAction(for: permission))
            )
            await driver.requestPermission(permission)
            evidence = await driver.inspect(configuration: configuration, live: false)
            guard !evidence.missingPermissions.contains(permission) else {
                return awaiting(userAction(for: permission), evidence: evidence, configuration: configuration)
            }
        }

        if configuration.engine == .qwenLocal,
           !evidence.selectedModelInstalled,
           let modelID = configuration.modelID {
            let hasConsent = await driver.hasDownloadConsent(modelID: modelID)
            if !hasConsent {
                guard request.intent == .interactiveSetup || request.intent == .resumeAfterUserAction else {
                    return awaiting(.modelDownloadConsent, evidence: evidence, configuration: configuration)
                }
                // The one-click setup action is presented beside the selected
                // model identity and download disclosure. Tapping it is the
                // user's explicit consent; do not require a second click.
                await driver.recordDownloadConsent(modelID: modelID)
            }
        }

        let selectedMachineJob: MachineJob?
        if configuration.engine == .qwenLocal {
            selectedMachineJob = machineJob(
                for: configuration,
                initialEvidence: evidence,
                forceModelRepair: request.forceModelRepair
            )
        } else {
            selectedMachineJob = nil
        }

        let runtime: PreparedRuntimeIdentity
        if let selectedMachineJob {
            let machineResult = await selectedMachineJob.task.value
            guard isCurrent(configuration) else {
                return failed(.superseded, report: evidence.report, runID: runID, configuration: configuration)
            }
            switch machineResult {
            case let .success(identity):
                runtime = identity
            case let .failure(failure):
                return failed(failure, report: evidence.report, runID: runID, configuration: configuration)
            }
        } else {
            runtime = PreparedRuntimeIdentity(
                configuration: configuration,
                bootID: UUID(),
                verifiedAt: Date()
            )
        }

        publish(key: key, configuration: configuration, stage: .verifying)
        let finalEvidence = await driver.inspect(configuration: configuration, live: true)
        guard isCurrent(configuration) else {
            return failed(.superseded, report: finalEvidence.report, runID: runID, configuration: configuration)
        }
        guard finalEvidence.missingPermissions.isEmpty,
              configuration.engine == .appleSpeech ||
                (finalEvidence.helperHealthy && finalEvidence.selectedModelLoaded)
        else {
            return failed(
                .finalVerificationFailed,
                report: finalEvidence.report,
                runID: runID,
                configuration: configuration
            )
        }

        publish(key: key, configuration: configuration, stage: .ready)
        return PreparationResult(outcome: .ready, report: finalEvidence.report, runtime: runtime)
    }

    private func machineJob(
        for configuration: PreparationConfiguration,
        initialEvidence: PreparationEvidence,
        forceModelRepair: Bool
    ) -> MachineJob {
        let key = jobKey(for: configuration)
        if let existing = jobs[key],
           existing.configuration == configuration,
           existing.forceModelRepair || !forceModelRepair {
            return existing
        }

        let operationID = UUID()
        let task = Task { [weak self] () -> Result<PreparedRuntimeIdentity, PreparationFailure> in
            guard let self else { return .failure(.superseded) }
            guard await self.isCurrent(configuration) else { return .failure(.superseded) }
            do {
                let identity = try await self.withExclusiveRuntimeMutation {
                    if forceModelRepair {
                        try await self.driver.repairSelectedModelStorage(configuration: configuration)
                    }
                    if let action = initialEvidence.runtimeAction {
                        await self.publish(
                            key: key,
                            configuration: configuration,
                            stage: .preparingRuntime,
                            operationID: operationID
                        )
                        try await self.driver.prepareRuntime(action: action)
                    }
                    await self.publish(
                        key: key,
                        configuration: configuration,
                        stage: .startingHelper,
                        operationID: operationID
                    )
                    return try await self.driver.prepareSelectedModel(
                        configuration: configuration,
                        operationID: operationID,
                        progress: { [weak self] stage, progress in
                            await self?.publish(
                                key: key,
                                configuration: configuration,
                                stage: stage,
                                progress: progress,
                                operationID: operationID
                            )
                        }
                    )
                }
                guard await self.isCurrent(configuration) else { return .failure(.superseded) }
                return .success(identity)
            } catch let failure as PreparationFailure {
                return .failure(failure)
            } catch {
                return .failure(.modelPreparationFailed(error.localizedDescription))
            }
        }
        let job = MachineJob(
            configuration: configuration,
            forceModelRepair: forceModelRepair,
            operationID: operationID,
            task: task
        )
        jobs[key] = job
        Task { [weak self] in
            _ = await task.value
            await self?.finishMachineJob(key: key, operationID: operationID)
        }
        return job
    }

    private func finishMachineJob(key: JobKey, operationID: UUID) {
        guard jobs[key]?.operationID == operationID else { return }
        jobs.removeValue(forKey: key)
    }

    private func acceptDesiredConfiguration(_ configuration: PreparationConfiguration) {
        guard let desiredConfiguration else {
            self.desiredConfiguration = configuration
            return
        }
        if configuration.generation >= desiredConfiguration.generation {
            self.desiredConfiguration = configuration
        }
    }

    private func isCurrent(_ configuration: PreparationConfiguration) -> Bool {
        guard let desiredConfiguration else { return false }
        return desiredConfiguration == configuration
    }

    private func waitForReservationsToDrain() async {
        guard !activeReservations.isEmpty else { return }
        await withCheckedContinuation { continuation in
            reservationDrainWaiters.append(continuation)
        }
    }

    private func waitForExclusiveMutation() async {
        guard exclusiveMutationActive else { return }
        await withCheckedContinuation { continuation in
            exclusiveAvailabilityWaiters.append(continuation)
        }
    }

    private func acquireExclusiveMutation() async {
        if !exclusiveMutationActive {
            exclusiveMutationActive = true
            return
        }
        await withCheckedContinuation { continuation in
            exclusiveMutationWaiters.append(continuation)
        }
    }

    private func releaseExclusiveMutation() {
        if exclusiveMutationWaiters.isEmpty {
            exclusiveMutationActive = false
            let availabilityWaiters = exclusiveAvailabilityWaiters
            exclusiveAvailabilityWaiters.removeAll()
            availabilityWaiters.forEach { $0.resume() }
        } else {
            let next = exclusiveMutationWaiters.removeFirst()
            next.resume()
        }
    }

    private func reserveRuntimeIfAvailable(_ configuration: PreparationConfiguration) -> UUID? {
        guard !exclusiveMutationActive else { return nil }
        let token = UUID()
        activeReservations[token] = configuration
        return token
    }

    private func releaseReservation(_ token: UUID) {
        activeReservations.removeValue(forKey: token)
        guard activeReservations.isEmpty else { return }
        let waiters = reservationDrainWaiters
        reservationDrainWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    private func awaiting(
        _ action: PreparationUserAction,
        evidence: PreparationEvidence,
        configuration: PreparationConfiguration
    ) -> PreparationResult {
        publish(
            key: jobKey(for: configuration),
            configuration: configuration,
            stage: .awaitingUserAction(action)
        )
        return PreparationResult(
            outcome: .awaitingUserAction(action),
            report: evidence.report,
            runtime: nil
        )
    }

    private func failed(
        _ failure: PreparationFailure,
        report: ReadinessReport,
        runID: UUID,
        configuration: PreparationConfiguration
    ) -> PreparationResult {
        publish(key: jobKey(for: configuration), configuration: configuration, stage: .failed)
        return PreparationResult(outcome: .failed(failure), report: report, runtime: nil)
    }

    private func userAction(for permission: PreparationPermission) -> PreparationUserAction {
        switch permission {
        case .microphone: return .microphone
        case .accessibility: return .accessibility
        case .speechRecognition: return .speechRecognition
        }
    }

    private func publish(
        key: JobKey,
        configuration: PreparationConfiguration,
        stage: PreparationStage,
        progress: Double? = nil,
        operationID: UUID? = nil
    ) {
        for (runID, subscription) in subscriptions
        where subscription.key == key && subscription.configuration == configuration {
            subscription.continuation.yield(snapshot(
                runID: runID,
                operationID: operationID ?? jobs[key]?.operationID,
                configuration: configuration,
                stage: stage,
                progress: progress
            ))
        }
    }

    private func finishSubscription(runID: UUID) {
        subscriptions.removeValue(forKey: runID)?.continuation.finish()
    }

    private func snapshot(
        runID: UUID,
        operationID: UUID?,
        configuration: PreparationConfiguration,
        stage: PreparationStage,
        progress: Double? = nil
    ) -> PreparationSnapshot {
        PreparationSnapshot(
            runID: runID,
            operationID: operationID,
            configuration: configuration,
            stage: stage,
            progress: progress
        )
    }

    private func jobKey(for configuration: PreparationConfiguration) -> JobKey {
        JobKey(
            engine: configuration.engine,
            modelID: configuration.modelID,
            runtimeRevision: configuration.runtimeRevision
        )
    }
}
