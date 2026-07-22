import Foundation

enum PermissionFlowPolicy {
    private static let requiredPermissionIDs: Set<String> = [
        "microphone-permission",
        "accessibility-permission",
        "speech-recognition-permission"
    ]
    private static let authorizationOrder = [
        "microphone-permission",
        "accessibility-permission",
        "speech-recognition-permission"
    ]

    static func shouldOpenSetupStatusOnLaunch(report: ReadinessReport) -> Bool {
        hasUnresolvedRequiredPermission(in: report)
    }

    static func hasUnresolvedRequiredPermission(in report: ReadinessReport) -> Bool {
        report.checks.contains { check in
            check.group == .permissions &&
                requiredPermissionIDs.contains(check.id) &&
                check.status != .ready &&
                check.status != .optional
        }
    }

    static func nextAuthorizationAction(report: ReadinessReport) -> ReadinessActionKind? {
        for permissionID in authorizationOrder {
            guard let check = report.checks.first(where: { $0.id == permissionID }) else {
                continue
            }
            if check.status != .ready && check.status != .optional {
                return check.primaryAction
            }
        }
        return nil
    }
}
