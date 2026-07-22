import Foundation

enum ReadinessCoverage: Equatable {
    case lightweight
    case live
}

struct ReadinessContext: Equatable {
    let engine: TranscriptionEngineKind
    let selectedModelID: String
}

struct ReadinessSnapshot: Equatable {
    let report: ReadinessReport
    let context: ReadinessContext
    let coverage: ReadinessCoverage
}

enum ReadinessPresentationPhase: Equatable {
    case checking
    case ready
    case needsSetup
    case preparing
    case repairRequired
}

enum ReadinessTaskKind: Hashable {
    case grantMicrophone
    case grantAccessibility
    case grantSpeechRecognition
    case installSelectedModel
    case prepareSelectedModel
    case repairLocalRuntime
    case reinstallApplication
}

struct ReadinessTask: Identifiable, Equatable {
    let kind: ReadinessTaskKind
    let sourceCheckIDs: [String]

    var id: ReadinessTaskKind { kind }
}

struct ReadinessPresentation: Equatable {
    let phase: ReadinessPresentationPhase
    let tasks: [ReadinessTask]
    let primaryAction: ReadinessActionKind?
    let checkDetails: [ReadinessCheck]
    let completedChecks: [ReadinessCheck]
    let optionalChecks: [ReadinessCheck]
    let technicalChecks: [ReadinessCheck]

    var isReady: Bool { phase == .ready }
    var requiredTaskCount: Int { tasks.count }
}

enum ReadinessPresentationPolicy {
    private static let microphoneID = "microphone-permission"
    private static let accessibilityID = "accessibility-permission"
    private static let speechRecognitionID = "speech-recognition-permission"

    static func presentation(for snapshot: ReadinessSnapshot) -> ReadinessPresentation {
        let report = snapshot.report
        let context = snapshot.context
        guard !report.checks.isEmpty else {
            return ReadinessPresentation(
                phase: .checking,
                tasks: [],
                primaryAction: nil,
                checkDetails: [],
                completedChecks: [],
                optionalChecks: [],
                technicalChecks: []
            )
        }
        let selectedModelCheckID = "model-\(context.selectedModelID)"
        let selectedModelWarmCheckID = "\(selectedModelCheckID)-warm"

        var tasks: [ReadinessTask] = []
        appendPermissionTask(
            .grantMicrophone,
            checkID: microphoneID,
            report: report,
            to: &tasks
        )
        appendPermissionTask(
            .grantAccessibility,
            checkID: accessibilityID,
            report: report,
            to: &tasks
        )
        if context.engine == .appleSpeech {
            appendPermissionTask(
                .grantSpeechRecognition,
                checkID: speechRecognitionID,
                report: report,
                to: &tasks
            )
        }

        var selectedModelIsPreparing = false
        var selectedModelLiveStateIsUnknown = false
        var infrastructureIsPreparing = false
        var infrastructureStateIsUnknown = false

        if context.engine == .qwenLocal {
            if let installCheck = report.checks.first(where: { $0.id == selectedModelCheckID }) {
                switch installCheck.status {
                case .ready, .optional:
                    break
                case .preparing:
                    selectedModelIsPreparing = true
                case .unknown:
                    selectedModelLiveStateIsUnknown = true
                case .notReady, .needsRepair, .failed:
                    tasks.append(ReadinessTask(
                        kind: .installSelectedModel,
                        sourceCheckIDs: [installCheck.id]
                    ))
                }
            } else {
                selectedModelLiveStateIsUnknown = true
            }

            if let warmCheck = report.checks.first(where: { $0.id == selectedModelWarmCheckID }) {
                switch warmCheck.status {
                case .ready:
                    break
                case .preparing:
                    selectedModelIsPreparing = true
                case .optional:
                    if snapshot.coverage == .live {
                        selectedModelIsPreparing = true
                    } else {
                        selectedModelLiveStateIsUnknown = true
                    }
                case .unknown:
                    selectedModelLiveStateIsUnknown = true
                case .notReady, .needsRepair, .failed:
                    if snapshot.coverage == .live {
                        tasks.append(ReadinessTask(
                            kind: .prepareSelectedModel,
                            sourceCheckIDs: [warmCheck.id]
                        ))
                    } else {
                        selectedModelLiveStateIsUnknown = true
                    }
                }
            } else {
                selectedModelLiveStateIsUnknown = true
            }

            let selectedHelperFailureIDs = report.checks.filter {
                $0.id == "helper-model-status-\(context.selectedModelID)" && !$0.status.isResolved
            }.map(\.id)
            if !selectedHelperFailureIDs.isEmpty {
                tasks.removeAll { $0.kind == .prepareSelectedModel }
                tasks.append(ReadinessTask(
                    kind: .prepareSelectedModel,
                    sourceCheckIDs: selectedHelperFailureIDs
                ))
            }

            let runtimeChecks = report.checks(in: .localRuntime)
            if runtimeChecks.isEmpty {
                infrastructureStateIsUnknown = true
            }
            let runtimeIssueIDs = actionableIssueIDs(
                in: runtimeChecks,
                isPreparing: &infrastructureIsPreparing,
                isUnknown: &infrastructureStateIsUnknown
            )
            if !runtimeIssueIDs.isEmpty {
                tasks.append(ReadinessTask(kind: .repairLocalRuntime, sourceCheckIDs: runtimeIssueIDs))
            }

            let bundleChecks = report.checks(in: .appBundle)
            if bundleChecks.isEmpty {
                infrastructureStateIsUnknown = true
            }
            let bundleIssueIDs = actionableIssueIDs(
                in: bundleChecks,
                isPreparing: &infrastructureIsPreparing,
                isUnknown: &infrastructureStateIsUnknown
            )
            if !bundleIssueIDs.isEmpty {
                tasks.append(ReadinessTask(kind: .reinstallApplication, sourceCheckIDs: bundleIssueIDs))
            }
        }

        tasks = deduplicated(tasks)

        let phase: ReadinessPresentationPhase
        if tasks.contains(where: { $0.kind == .reinstallApplication || $0.kind == .repairLocalRuntime || $0.kind == .prepareSelectedModel }) {
            phase = .repairRequired
        } else if !tasks.isEmpty {
            phase = .needsSetup
        } else if snapshot.coverage == .lightweight || selectedModelLiveStateIsUnknown || infrastructureStateIsUnknown {
            phase = .checking
        } else if selectedModelIsPreparing || infrastructureIsPreparing {
            phase = .preparing
        } else {
            phase = .ready
        }

        let primaryAction: ReadinessActionKind?
        if tasks.contains(where: { $0.kind == .reinstallApplication }) {
            primaryAction = .reinstallFlowtypeApp
        } else if tasks.isEmpty {
            primaryAction = nil
        } else {
            primaryAction = .prepareFlowtype
        }

        let technicalGroups: Set<ReadinessGroup> = [.appBundle, .localRuntime, .performance]
        let technicalChecks = report.checks.filter { technicalGroups.contains($0.group) }
        let nonTechnicalChecks = report.checks.filter { !technicalGroups.contains($0.group) }
        let taskSourceIDs = Set(tasks.flatMap(\.sourceCheckIDs))
        let completedChecks = nonTechnicalChecks.filter {
            $0.status == .ready && !taskSourceIDs.contains($0.id)
        }
        let optionalChecks = nonTechnicalChecks.filter {
            $0.status == .optional && !taskSourceIDs.contains($0.id)
        }

        return ReadinessPresentation(
            phase: phase,
            tasks: tasks,
            primaryAction: primaryAction,
            checkDetails: nonTechnicalChecks,
            completedChecks: completedChecks,
            optionalChecks: optionalChecks,
            technicalChecks: technicalChecks
        )
    }

    private static func appendPermissionTask(
        _ kind: ReadinessTaskKind,
        checkID: String,
        report: ReadinessReport,
        to tasks: inout [ReadinessTask]
    ) {
        guard let check = report.checks.first(where: { $0.id == checkID }) else {
            tasks.append(ReadinessTask(kind: kind, sourceCheckIDs: [checkID]))
            return
        }
        guard !check.status.isResolved else { return }
        tasks.append(ReadinessTask(kind: kind, sourceCheckIDs: [check.id]))
    }

    private static func deduplicated(_ tasks: [ReadinessTask]) -> [ReadinessTask] {
        var order: [ReadinessTaskKind] = []
        var sourceIDs: [ReadinessTaskKind: [String]] = [:]
        for task in tasks {
            if sourceIDs[task.kind] == nil {
                order.append(task.kind)
                sourceIDs[task.kind] = []
            }
            for sourceID in task.sourceCheckIDs where !(sourceIDs[task.kind]?.contains(sourceID) ?? false) {
                sourceIDs[task.kind, default: []].append(sourceID)
            }
        }
        return order.map { kind in
            ReadinessTask(kind: kind, sourceCheckIDs: sourceIDs[kind] ?? [])
        }
    }

    private static func actionableIssueIDs(
        in checks: [ReadinessCheck],
        isPreparing: inout Bool,
        isUnknown: inout Bool
    ) -> [String] {
        checks.compactMap { check in
            switch check.status {
            case .ready, .optional:
                return nil
            case .preparing:
                isPreparing = true
                return nil
            case .unknown:
                isUnknown = true
                return nil
            case .notReady, .needsRepair, .failed:
                return check.id
            }
        }
    }
}

private extension ReadinessStatus {
    var isResolved: Bool {
        self == .ready || self == .optional
    }
}
