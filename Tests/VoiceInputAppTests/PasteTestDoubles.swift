import Foundation
@testable import VoiceInputApp

final class TestPasteboardWriter: PasteboardStringWriting {
    var value: String?
    var changeCount = 0
    var replaceCallCount = 0
    var shouldSucceed = true

    init(value: String? = nil) {
        self.value = value
    }

    func replaceString(_ text: String) -> Bool {
        replaceCallCount += 1
        guard shouldSucceed else { return false }
        value = text
        changeCount += 1
        return true
    }
}

final class TestPasteShortcutPoster: PasteShortcutPosting {
    var processIdentifiers: [pid_t] = []
    var shouldSucceed = true

    func postCommandV(to processIdentifier: pid_t) -> Bool {
        processIdentifiers.append(processIdentifier)
        return shouldSucceed
    }
}

final class TestPasteInputSourceController: PasteInputSourceControlling {
    var prepareCallCount = 0
    var restoreCallCount = 0
    var returnsRestoreToken = false
    var onPrepare: (() -> Void)?

    func prepareForShortcut() -> PasteInputSourceRestoreToken? {
        prepareCallCount += 1
        onPrepare?()
        guard returnsRestoreToken else { return nil }
        return PasteInputSourceRestoreToken { [weak self] in
            self?.restoreCallCount += 1
        }
    }
}

final class TestPasteTelemetryRecorder: PasteTelemetryRecording {
    var events: [PasteTelemetryEvent] = []

    func record(_ event: PasteTelemetryEvent) {
        events.append(event)
    }
}
