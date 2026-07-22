import AppKit
import QuartzCore

enum WaveformResponse {
    static let frameAnimationDuration: CFTimeInterval = 0.04
    static let barWeights: [CGFloat] = [0.52, 0.78, 1.0, 0.78, 0.52]
    static let barWidth: CGFloat = 4.5
    static let barGap: CGFloat = 3.5
    static let minimumBarFraction: CGFloat = 0.15

    static var barCount: Int { barWeights.count }

    static var totalBarWidth: CGFloat {
        CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * barGap
    }

    static func displayedLevel(for inputLevel: CGFloat) -> CGFloat {
        min(max(inputLevel, 0), 1)
    }

    static func barFractions(for inputLevel: CGFloat) -> [CGFloat] {
        let level = displayedLevel(for: inputLevel)
        return barWeights.map { weight in
            minimumBarFraction + (1 - minimumBarFraction) * level * weight
        }
    }
}

final class WaveformView: NSView {
    private var barLayers: [CALayer] = []
    var isAnimating = false

    private var displayedLevel: CGFloat = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setupBars()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        setupBars()
    }

    override func layout() {
        super.layout()
        applyBars(level: displayedLevel)
    }

    func setLevel(_ level: CGFloat) {
        guard isAnimating else { return }
        displayedLevel = WaveformResponse.displayedLevel(for: level)

        CATransaction.begin()
        CATransaction.setAnimationDuration(WaveformResponse.frameAnimationDuration)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        applyBars(level: displayedLevel)
        CATransaction.commit()
    }

    private func setupBars() {
        for _ in 0..<WaveformResponse.barCount {
            let bar = CALayer()
            bar.backgroundColor = NSColor.white.withAlphaComponent(0.9).cgColor
            bar.cornerRadius = WaveformResponse.barWidth / 2
            layer?.addSublayer(bar)
            barLayers.append(bar)
        }
    }

    private func applyBars(level: CGFloat) {
        let fractions = WaveformResponse.barFractions(for: level)
        let startX = (bounds.width - WaveformResponse.totalBarWidth) / 2

        for (index, bar) in barLayers.enumerated() {
            let height = bounds.height * fractions[index]
            let x = startX + CGFloat(index) * (WaveformResponse.barWidth + WaveformResponse.barGap)
            let y = (bounds.height - height) / 2
            bar.frame = CGRect(x: x, y: y, width: WaveformResponse.barWidth, height: height)
        }
    }
}
