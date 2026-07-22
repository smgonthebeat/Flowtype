import Foundation

struct PermissionReadinessInspector {
    func inspect(snapshot: PermissionSnapshot, includeSpeechRecognition: Bool) -> [ReadinessCheck] {
        var checks = [
            permissionCheck(
                id: "microphone-permission",
                title: "Microphone",
                grantedDetail: "Flowtype can record audio.",
                missingDetail: "Flowtype needs Microphone permission to record dictation audio.",
                state: snapshot.microphone,
                action: .requestMicrophone
            ),
            permissionCheck(
                id: "accessibility-permission",
                title: "Accessibility",
                grantedDetail: "Flowtype can listen for Fn and paste transcripts.",
                missingDetail: "Flowtype needs Accessibility permission to listen for Fn and paste text.",
                state: snapshot.accessibility,
                action: .openAccessibilitySettings
            )
        ]

        if includeSpeechRecognition {
            checks.append(
                permissionCheck(
                    id: "speech-recognition-permission",
                    title: "Speech Recognition",
                    grantedDetail: "Apple Speech fallback can run when needed.",
                    missingDetail: "Speech Recognition permission is only needed for Apple Speech fallback.",
                    state: snapshot.speechRecognition,
                    action: .requestSpeechRecognition
                )
            )
        }

        return checks
    }

    private func permissionCheck(
        id: String,
        title: String,
        grantedDetail: String,
        missingDetail: String,
        state: PermissionState,
        action: ReadinessActionKind
    ) -> ReadinessCheck {
        switch state {
        case .granted:
            return ReadinessCheck(
                id: id,
                group: .permissions,
                title: title,
                detail: grantedDetail,
                status: .ready
            )
        case .denied:
            return ReadinessCheck(
                id: id,
                group: .permissions,
                title: title,
                detail: missingDetail,
                status: .failed("\(title) permission is denied."),
                primaryAction: action
            )
        case .notDetermined:
            return ReadinessCheck(
                id: id,
                group: .permissions,
                title: title,
                detail: missingDetail,
                status: .notReady,
                primaryAction: action
            )
        case .unknown:
            return ReadinessCheck(
                id: id,
                group: .permissions,
                title: title,
                detail: missingDetail,
                status: .unknown,
                primaryAction: action
            )
        }
    }
}
