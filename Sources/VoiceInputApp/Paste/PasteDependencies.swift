import AppKit
import CoreGraphics
import Foundation

protocol PasteboardStringWriting: AnyObject {
    var changeCount: Int { get }
    func replaceString(_ text: String) -> Bool
}

final class NSPasteboardStringWriter: PasteboardStringWriting {
    private let pasteboard: NSPasteboard

    init(pasteboard: NSPasteboard) {
        self.pasteboard = pasteboard
    }

    var changeCount: Int {
        pasteboard.changeCount
    }

    func replaceString(_ text: String) -> Bool {
        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else { return false }
        return pasteboard.string(forType: .string) == text
    }

}

protocol PasteShortcutPosting: AnyObject {
    func postCommandV(to processIdentifier: pid_t) -> Bool
}

final class PasteShortcutPoster: PasteShortcutPosting {
    typealias EventSink = (_ processIdentifier: pid_t, _ event: CGEvent) -> Void
    typealias EventPairFactory = () -> (keyDown: CGEvent, keyUp: CGEvent)?

    private enum Constants {
        static let vKey: CGKeyCode = 0x09
    }

    private let eventSink: EventSink
    private let eventPairFactory: EventPairFactory

    init(eventSink: @escaping EventSink) {
        self.eventSink = eventSink
        self.eventPairFactory = Self.makeCommandVEventPair
    }

    init(
        eventSink: @escaping EventSink,
        eventPairFactory: @escaping EventPairFactory
    ) {
        self.eventSink = eventSink
        self.eventPairFactory = eventPairFactory
    }

    func postCommandV(to processIdentifier: pid_t) -> Bool {
        guard let pair = eventPairFactory() else { return false }
        eventSink(processIdentifier, pair.keyDown)
        eventSink(processIdentifier, pair.keyUp)
        return true
    }

    private static func makeCommandVEventPair() -> (keyDown: CGEvent, keyUp: CGEvent)? {
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let keyDown = CGEvent(
                  keyboardEventSource: source,
                  virtualKey: Constants.vKey,
                  keyDown: true
              ),
              let keyUp = CGEvent(
                  keyboardEventSource: source,
                  virtualKey: Constants.vKey,
                  keyDown: false
              ) else {
            return nil
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        return (keyDown, keyUp)
    }
}
