import AppKit
import QuartzCore

enum CapsuleMotion {
    static let showDuration: TimeInterval = 0.18
    static let hideDuration: TimeInterval = 0.14
    static let updateDuration: TimeInterval = 0.18
    static let reducedMotionFadeDuration: TimeInterval = 0.12
    static let fallbackPadding: TimeInterval = 0.10
    static let showOffsetY: CGFloat = -8
    static let hideOffsetY: CGFloat = -8
    static let hideWidthScale: CGFloat = 0.98

    static func animatesFrame(reduceMotion: Bool) -> Bool {
        !reduceMotion
    }
}

private final class CapsulePanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class FloatingCapsulePanel {
    private let panel: NSPanel
    private let label = NSTextField(labelWithString: "")
    private let waveformView = WaveformView()
    private var visibilityGeneration = 0

    private let capsuleHeight: CGFloat = 56
    private let hPad: CGFloat = 24
    private let waveSize: CGFloat = 44
    private let gap: CGFloat = 14
    private let minWidth: CGFloat = 160
    private let maxWidth: CGFloat = 560

    init() {
        panel = CapsulePanel(
            contentRect: NSRect(x: 0, y: 0, width: minWidth, height: capsuleHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        buildContent()
    }

    func show(_ presentation: CapsulePresentation) {
        visibilityGeneration += 1
        apply(presentation)

        let w = idealWidth(for: presentation.text)
        let targetFrame = frame(width: w)
        let reduceMotion = shouldReduceMotion
        let initialFrame = CapsuleMotion.animatesFrame(reduceMotion: reduceMotion)
            ? targetFrame.offsetBy(dx: 0, dy: CapsuleMotion.showOffsetY)
            : targetFrame
        panel.setFrame(initialFrame, display: true)
        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = reduceMotion
                ? CapsuleMotion.reducedMotionFadeDuration
                : CapsuleMotion.showDuration
            context.timingFunction = easeOutTimingFunction
            panel.animator().alphaValue = 1
            if CapsuleMotion.animatesFrame(reduceMotion: reduceMotion) {
                panel.animator().setFrame(targetFrame, display: true)
            }
        }
    }

    func hide() {
        let generation = visibilityGeneration
        let reduceMotion = shouldReduceMotion
        let duration = reduceMotion
            ? CapsuleMotion.reducedMotionFadeDuration
            : CapsuleMotion.hideDuration
        waveformView.isAnimating = false
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = easeOutTimingFunction
            panel.animator().alphaValue = 0
            if CapsuleMotion.animatesFrame(reduceMotion: reduceMotion) {
                let widthDelta = panel.frame.width * (1 - CapsuleMotion.hideWidthScale)
                panel.animator().setFrame(
                    NSRect(
                        x: panel.frame.origin.x + widthDelta / 2,
                        y: panel.frame.origin.y + CapsuleMotion.hideOffsetY,
                        width: panel.frame.width * CapsuleMotion.hideWidthScale,
                        height: capsuleHeight
                    ),
                    display: true
                )
            }
        } completionHandler: {
            Task { @MainActor in
                guard self.visibilityGeneration == generation else { return }
                self.panel.orderOut(nil)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + CapsuleMotion.fallbackPadding) {
            guard self.visibilityGeneration == generation else { return }
            self.panel.alphaValue = 0
            self.panel.orderOut(nil)
        }
    }

    func update(_ presentation: CapsulePresentation) {
        apply(presentation)

        let w = idealWidth(for: presentation.text)
        let newFrame = NSRect(x: frame(width: w).origin.x, y: panel.frame.origin.y, width: w, height: capsuleHeight)
        let reduceMotion = shouldReduceMotion
        guard CapsuleMotion.animatesFrame(reduceMotion: reduceMotion) else {
            panel.setFrame(newFrame, display: true)
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = CapsuleMotion.updateDuration
            context.timingFunction = easeOutTimingFunction
            context.allowsImplicitAnimation = true
            panel.animator().setFrame(newFrame, display: true)
        }
    }

    func updateAudioLevel(_ level: Double) {
        waveformView.setLevel(CGFloat(level))
    }

    private func apply(_ presentation: CapsulePresentation) {
        label.stringValue = presentation.text
        waveformView.isAnimating = presentation.animatesWaveform
    }

    private var shouldReduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    private var easeOutTimingFunction: CAMediaTimingFunction {
        CAMediaTimingFunction(controlPoints: 0.23, 1, 0.32, 1)
    }

    private func buildContent() {
        let content = NSView()
        content.wantsLayer = true

        let shadowHost = NSView()
        shadowHost.wantsLayer = true
        shadowHost.layer?.shadowColor = NSColor.black.withAlphaComponent(0.45).cgColor
        shadowHost.layer?.shadowOffset = CGSize(width: 0, height: -2)
        shadowHost.layer?.shadowRadius = 16
        shadowHost.layer?.shadowOpacity = 1
        shadowHost.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(shadowHost)

        let effectView = NSVisualEffectView()
        effectView.material = .hudWindow
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.appearance = NSAppearance(named: .darkAqua)
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = capsuleHeight / 2
        effectView.layer?.masksToBounds = true
        effectView.translatesAutoresizingMaskIntoConstraints = false
        shadowHost.addSubview(effectView)

        let border = NSView()
        border.wantsLayer = true
        border.layer?.cornerRadius = capsuleHeight / 2
        border.layer?.borderWidth = 0.5
        border.layer?.borderColor = NSColor.white.withAlphaComponent(0.1).cgColor
        border.translatesAutoresizingMaskIntoConstraints = false
        effectView.addSubview(border)

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = gap
        stack.alignment = .centerY
        stack.translatesAutoresizingMaskIntoConstraints = false
        effectView.addSubview(stack)

        waveformView.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(waveformView)

        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = NSColor.white.withAlphaComponent(0.92)
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        stack.addArrangedSubview(label)

        panel.contentView = content

        NSLayoutConstraint.activate([
            shadowHost.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            shadowHost.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            shadowHost.topAnchor.constraint(equalTo: content.topAnchor),
            shadowHost.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            effectView.leadingAnchor.constraint(equalTo: shadowHost.leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: shadowHost.trailingAnchor),
            effectView.topAnchor.constraint(equalTo: shadowHost.topAnchor),
            effectView.bottomAnchor.constraint(equalTo: shadowHost.bottomAnchor),
            border.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
            border.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
            border.topAnchor.constraint(equalTo: effectView.topAnchor),
            border.bottomAnchor.constraint(equalTo: effectView.bottomAnchor),
            waveformView.widthAnchor.constraint(equalToConstant: waveSize),
            waveformView.heightAnchor.constraint(equalToConstant: 32),
            stack.leadingAnchor.constraint(equalTo: effectView.leadingAnchor, constant: hPad),
            stack.trailingAnchor.constraint(equalTo: effectView.trailingAnchor, constant: -hPad),
            stack.centerYAnchor.constraint(equalTo: effectView.centerYAnchor)
        ])
    }

    private func idealWidth(for text: String) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [.font: label.font as Any]
        let textWidth = ceil((text as NSString).size(withAttributes: attrs).width)
        let total = hPad + waveSize + gap + textWidth + hPad
        return min(max(total, minWidth), maxWidth)
    }

    private func frame(width: CGFloat) -> NSRect {
        guard let screen = NSScreen.main else {
            return NSRect(origin: panel.frame.origin, size: NSSize(width: width, height: capsuleHeight))
        }
        let screenFrame = screen.visibleFrame
        return NSRect(
            x: screenFrame.midX - width / 2,
            y: screenFrame.minY + 56,
            width: width,
            height: capsuleHeight
        )
    }
}
