import CoreGraphics
import Foundation

final class FnKeyMonitor {
    typealias EventTapFactory = (UnsafeMutableRawPointer) -> CFMachPort?

    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?

    private let eventTapFactory: EventTapFactory
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isPressed = false
    private let fnKeyCode: Int64 = 0x3F

    init(eventTapFactory: EventTapFactory? = nil) {
        self.eventTapFactory = eventTapFactory ?? Self.makeEventTap
    }

    func start() {
        if eventTap != nil {
            enableTap()
            return
        }

        eventTap = eventTapFactory(Unmanaged.passUnretained(self).toOpaque())

        guard let eventTap else {
            AppLogger.app.error("Failed to create Fn event tap")
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        enableTap()
    }

    private static func makeEventTap(userInfo: UnsafeMutableRawPointer) -> CFMachPort? {
        let mask = (1 << CGEventType.flagsChanged.rawValue)
        return CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<FnKeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    let wasPressed = monitor.isPressed
                    monitor.isPressed = false
                    if wasPressed {
                        DispatchQueue.main.async { monitor.onRelease?() }
                    }
                    monitor.enableTap()
                    return Unmanaged.passUnretained(event)
                }
                return monitor.handle(type: type, event: event)
            },
            userInfo: userInfo
        )
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        isPressed = false
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard type == .flagsChanged else {
            return Unmanaged.passUnretained(event)
        }

        let flags = event.flags
        let fnDown = flags.contains(.maskSecondaryFn)
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        guard keyCode == fnKeyCode else {
            return Unmanaged.passUnretained(event)
        }

        if fnDown && !isPressed {
            isPressed = true
            DispatchQueue.main.async { self.onPress?() }
            return nil
        }

        if !fnDown && isPressed {
            isPressed = false
            DispatchQueue.main.async { self.onRelease?() }
            return nil
        }

        return nil
    }

    private func enableTap() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: true)
        }
    }
}
