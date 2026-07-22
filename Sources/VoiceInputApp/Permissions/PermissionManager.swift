import AVFoundation
import AppKit
import ApplicationServices
import Speech

final class PermissionManager {
    func snapshot() -> PermissionSnapshot {
        PermissionSnapshot(
            microphone: microphoneState(),
            accessibility: accessibilityState(),
            speechRecognition: speechRecognitionState()
        )
    }

    func requestMicrophone(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio, completionHandler: completion)
    }

    func requestSpeechRecognition(completion: @escaping (PermissionState) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            completion(Self.mapSpeechStatus(status))
        }
    }

    func requestAccessibilityPrompt() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    private func microphoneState() -> PermissionState {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return .granted
        case .denied, .restricted: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .unknown
        }
    }

    private func accessibilityState() -> PermissionState {
        AXIsProcessTrusted() ? .granted : .notDetermined
    }

    private func speechRecognitionState() -> PermissionState {
        Self.mapSpeechStatus(SFSpeechRecognizer.authorizationStatus())
    }

    private static func mapSpeechStatus(_ status: SFSpeechRecognizerAuthorizationStatus) -> PermissionState {
        switch status {
        case .authorized: return .granted
        case .denied, .restricted: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .unknown
        }
    }
}
