import Foundation

@MainActor
final class PasteInjector {
    private enum Constants {
        static let inputSourceRestoreDelay: TimeInterval = 0.3
    }

    private let pasteboardWriter: PasteboardStringWriting
    private let shortcutPoster: PasteShortcutPosting
    private let inputSourceController: PasteInputSourceControlling
    private let inputSourceRestoreDelay: TimeInterval
    private var isInputSourceTransitionInFlight = false

    init(
        pasteboardWriter: PasteboardStringWriting,
        shortcutPoster: PasteShortcutPosting,
        inputSourceController: PasteInputSourceControlling,
        inputSourceRestoreDelay: TimeInterval = Constants.inputSourceRestoreDelay
    ) {
        self.pasteboardWriter = pasteboardWriter
        self.shortcutPoster = shortcutPoster
        self.inputSourceController = inputSourceController
        self.inputSourceRestoreDelay = inputSourceRestoreDelay
    }

    nonisolated static func isPasteable(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return trimmed.rangeOfCharacter(from: CharacterSet.alphanumerics.union(.letters)) != nil
    }

    @discardableResult
    func copyPermanent(_ text: String) -> Bool {
        guard Self.isPasteable(text) else { return false }
        return pasteboardWriter.replaceString(text)
    }

    func noOpResult(_ outcome: PasteOutcome) -> PasteOperationResult {
        let changeCount = pasteboardWriter.changeCount
        return PasteOperationResult(
            outcome: outcome,
            pasteboardChangeCountBefore: changeCount,
            pasteboardChangeCountAfter: changeCount,
            eventPairCount: 0,
            frontmostMatch: nil
        )
    }

    func copyOnly(
        _ text: String,
        reason: CopyOnlyReason,
        frontmostMatch: Bool? = nil
    ) -> PasteOperationResult {
        write(
            text,
            successOutcome: .copiedOnly(reason: reason),
            frontmostMatch: frontmostMatch
        )
    }

    func dispatch(
        _ text: String,
        to processIdentifier: pid_t,
        validateTarget: () -> Bool
    ) -> PasteOperationResult {
        let changeCountBefore = pasteboardWriter.changeCount
        guard Self.isPasteable(text) else {
            return result(
                outcome: .invalidText,
                changeCountBefore: changeCountBefore,
                eventPairCount: 0,
                frontmostMatch: nil
            )
        }
        guard pasteboardWriter.replaceString(text) else {
            return result(
                outcome: .clipboardWriteFailed,
                changeCountBefore: changeCountBefore,
                eventPairCount: 0,
                frontmostMatch: nil
            )
        }
        guard !isInputSourceTransitionInFlight else {
            return result(
                outcome: .copiedOnly(reason: .inputSourceBusy),
                changeCountBefore: changeCountBefore,
                eventPairCount: 0,
                frontmostMatch: nil
            )
        }

        let restoreToken = inputSourceController.prepareForShortcut()
        if restoreToken != nil {
            isInputSourceTransitionInFlight = true
        }

        guard validateTarget() else {
            scheduleInputSourceRestore(restoreToken)
            return result(
                outcome: .copiedOnly(reason: .targetRejected),
                changeCountBefore: changeCountBefore,
                eventPairCount: 0,
                frontmostMatch: false
            )
        }

        let didPostEventPair = shortcutPoster.postCommandV(to: processIdentifier)
        scheduleInputSourceRestore(restoreToken)
        return result(
            outcome: didPostEventPair
                ? .eventDispatched
                : .copiedOnly(reason: .eventCreationFailed),
            changeCountBefore: changeCountBefore,
            eventPairCount: didPostEventPair ? 1 : 0,
            frontmostMatch: true
        )
    }

    private func write(
        _ text: String,
        successOutcome: PasteOutcome,
        frontmostMatch: Bool?
    ) -> PasteOperationResult {
        let changeCountBefore = pasteboardWriter.changeCount
        guard Self.isPasteable(text) else {
            return result(
                outcome: .invalidText,
                changeCountBefore: changeCountBefore,
                eventPairCount: 0,
                frontmostMatch: nil
            )
        }
        guard pasteboardWriter.replaceString(text) else {
            return result(
                outcome: .clipboardWriteFailed,
                changeCountBefore: changeCountBefore,
                eventPairCount: 0,
                frontmostMatch: nil
            )
        }
        return result(
            outcome: successOutcome,
            changeCountBefore: changeCountBefore,
            eventPairCount: 0,
            frontmostMatch: frontmostMatch
        )
    }

    private func result(
        outcome: PasteOutcome,
        changeCountBefore: Int,
        eventPairCount: Int,
        frontmostMatch: Bool?
    ) -> PasteOperationResult {
        PasteOperationResult(
            outcome: outcome,
            pasteboardChangeCountBefore: changeCountBefore,
            pasteboardChangeCountAfter: pasteboardWriter.changeCount,
            eventPairCount: eventPairCount,
            frontmostMatch: frontmostMatch
        )
    }

    private func scheduleInputSourceRestore(_ token: PasteInputSourceRestoreToken?) {
        guard let token else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + inputSourceRestoreDelay) { [weak self] in
            token.restore()
            self?.isInputSourceTransitionInFlight = false
        }
    }
}
