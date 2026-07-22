import Carbon
import Foundation

final class PasteInputSourceRestoreToken {
    private let restoreAction: () -> Void

    init(restoreAction: @escaping () -> Void) {
        self.restoreAction = restoreAction
    }

    func restore() {
        restoreAction()
    }
}

protocol PasteInputSourceControlling: AnyObject {
    func prepareForShortcut() -> PasteInputSourceRestoreToken?
}

final class InputSourceManager: PasteInputSourceControlling {
    func prepareForShortcut() -> PasteInputSourceRestoreToken? {
        guard let originalSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              !isASCIICapable(originalSource),
              let asciiSource = findASCIIInputSource(),
              TISSelectInputSource(asciiSource) == noErr else {
            return nil
        }

        usleep(50_000)
        return PasteInputSourceRestoreToken {
            TISSelectInputSource(originalSource)
        }
    }

    private func isASCIICapable(_ source: TISInputSource) -> Bool {
        guard let pointer = TISGetInputSourceProperty(source, kTISPropertyInputSourceIsASCIICapable) else {
            return false
        }
        let value = Unmanaged<CFBoolean>.fromOpaque(pointer).takeUnretainedValue()
        return CFBooleanGetValue(value)
    }

    private func findASCIIInputSource() -> TISInputSource? {
        guard let keyboardInputSourceCategory = kTISCategoryKeyboardInputSource else {
            return nil
        }
        let filter = [
            kTISPropertyInputSourceCategory as String: keyboardInputSourceCategory,
            kTISPropertyInputSourceIsEnabled as String: true,
            kTISPropertyInputSourceIsASCIICapable as String: true
        ] as CFDictionary
        guard let sources = TISCreateInputSourceList(filter, false)?.takeRetainedValue()
            as? [TISInputSource]
        else {
            return nil
        }
        let identifiers = sources.map(inputSourceID)
        guard let index = Self.preferredASCIIInputSourceIndex(identifiers: identifiers) else {
            return nil
        }
        return sources[index]
    }

    nonisolated static func preferredASCIIInputSourceIndex(
        identifiers: [String?]
    ) -> Int? {
        for preferredID in ["com.apple.keylayout.ABC", "com.apple.keylayout.US"] {
            if let index = identifiers.firstIndex(where: { $0 == preferredID }) {
                return index
            }
        }
        return identifiers.indices.first
    }

    private func inputSourceID(_ source: TISInputSource) -> String? {
        guard let pointer = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else {
            return nil
        }
        return Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String
    }
}
