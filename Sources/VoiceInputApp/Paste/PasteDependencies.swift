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
    typealias ShortcutEventFactory = () -> [CGEvent]?

    private enum Constants {
        static let commandKey: CGKeyCode = 0x37
        static let vKey: CGKeyCode = 0x09
        // NX_DEVICELCMDKEYMASK: a physical left Command key sets this alongside .maskCommand.
        static let leftCommandDevice = CGEventFlags(rawValue: 0x0000_0008)
        static let commandHeld: CGEventFlags = [.maskCommand, leftCommandDevice]
    }

    private let eventSink: EventSink
    private let shortcutEventFactory: ShortcutEventFactory

    init(eventSink: @escaping EventSink) {
        self.eventSink = eventSink
        self.shortcutEventFactory = Self.makeCommandVShortcutEvents
    }

    init(
        eventSink: @escaping EventSink,
        shortcutEventFactory: @escaping ShortcutEventFactory
    ) {
        self.eventSink = eventSink
        self.shortcutEventFactory = shortcutEventFactory
    }

    func postCommandV(to processIdentifier: pid_t) -> Bool {
        guard let events = shortcutEventFactory(), !events.isEmpty else { return false }
        events.forEach { eventSink(processIdentifier, $0) }
        return true
    }

    // Mirror a physical Command-V, including the Command press and release.
    // Mac Catalyst apps track held keys themselves; AppKit can swallow the
    // Command-modified V key-up, so without the Command release they treat
    // the shortcut as still held and auto-repeat the paste.
    private static func makeCommandVShortcutEvents() -> [CGEvent]? {
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let commandDown = CGEvent(
                  keyboardEventSource: source,
                  virtualKey: Constants.commandKey,
                  keyDown: true
              ),
              let vDown = CGEvent(
                  keyboardEventSource: source,
                  virtualKey: Constants.vKey,
                  keyDown: true
              ),
              let vUp = CGEvent(
                  keyboardEventSource: source,
                  virtualKey: Constants.vKey,
                  keyDown: false
              ),
              let commandUp = CGEvent(
                  keyboardEventSource: source,
                  virtualKey: Constants.commandKey,
                  keyDown: false
              ) else {
            return nil
        }

        commandDown.type = .flagsChanged
        commandDown.flags = Constants.commandHeld
        vDown.flags = Constants.commandHeld
        vUp.flags = Constants.commandHeld
        commandUp.type = .flagsChanged
        commandUp.flags = []
        return [commandDown, vDown, vUp, commandUp]
    }
}
