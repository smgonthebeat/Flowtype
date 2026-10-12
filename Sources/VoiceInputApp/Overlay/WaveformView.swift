import AppKit
import QuartzCore

/// Recording waveform (owner choice "V2", 2026-10-03): nine thin bars whose overall height follows
/// the voice while each bar rises and falls at its own pace, so the shape moves like a sound wave
/// instead of inflating as one diamond (the "B1" problem the owner saw in the app).
enum WaveformResponse {
    static let frameAnimationDuration: CFTimeInterval = 0.04
    /// Gentle centre emphasis: the edges stay at 62% so the sides never look starved.
    static let barWeights: [CGFloat] = [0.62, 0.74, 0.86, 0.95, 1.0, 0.95, 0.86, 0.74, 0.62]
    /// Per-bar motion: angular speed (rad/s) and phase, deliberately irregular.
    /// Owner feedback (2026-10-03, "way too much"): slowed to 60% of the first V2 build.
    static let barSpeeds: [Double] = [3.4, 4.7, 4.0, 5.6, 4.3, 5.2, 3.6, 4.9, 4.1]
    static let barPhases: [Double] = [0, 1.7, 3.1, 0.6, 2.4, 4.2, 1.1, 3.7, 5.3]
    /// Each bar swings between 54% and 100% of its share of the level: about 15% more spread
    /// between bars than the calmer 60% build, at the owner's request (2026-10-03).
    static let motionFloor: CGFloat = 0.54
    /// Overall amplitude: a little above the calmed build (0.85), still well below the first 1.25.
    static let motionGain: CGFloat = 0.95
    static let barWidth: CGFloat = 2.5
    static let barGap: CGFloat = 2
    static let minimumBarFraction: CGFloat = 0.1

    static var barCount: Int { barWeights.count }

    static var totalBarWidth: CGFloat {
        CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * barGap
    }

    static func displayedLevel(for inputLevel: CGFloat) -> CGFloat {
        min(max(inputLevel, 0), 1)
    }

    /// Bar heights as fractions of the view height for a level at a moment in time.
    static func barFractions(for inputLevel: CGFloat, at time: CFTimeInterval) -> [CGFloat] {
        let level = displayedLevel(for: inputLevel)
        return barWeights.indices.map { index in
            let swing = CGFloat(abs(sin(time * barSpeeds[index] + barPhases[index])))
            let motion = motionFloor + (1 - motionFloor) * swing
            let share = min(1, level * barWeights[index] * motion * motionGain)
            return minimumBarFraction + (1 - minimumBarFraction) * share
        }
    }

    /// Transcribing (owner choice "C"): three dots bounce in turn.
    static let dotCount = 3
    static let dotSize: CGFloat = 6
    static let dotGap: CGFloat = 5
    static let bounceHeight: CGFloat = 6
    static let bouncePeriod: CFTimeInterval = 1.0
    static let bounceStagger: CFTimeInterval = 0.15

    /// Gradient themes (owner choice "3", 2026-10-12): a soft glow in each bar's own colour.
    static let glowRadius: CGFloat = 3
    static let glowOpacity: Float = 1
}

/// Spreads a theme's gradient stops across the bars, leading to trailing: the first bar takes the
/// first stop, the last bar the last stop, and the bars between blend evenly.
enum WaveformPalette {
    static func colors(stops hexes: [String], count: Int) -> [HexColor.Components] {
        let stops = hexes.map(HexColor.components)
        guard count > 0, let first = stops.first else { return [] }
        guard stops.count > 1, count > 1 else { return Array(repeating: first, count: count) }
        let segments = Double(stops.count - 1)
        return (0..<count).map { index in
            let position = Double(index) / Double(count - 1) * segments
            let lower = min(Int(position), stops.count - 2)
            let fraction = position - Double(lower)
            let from = stops[lower]
            let to = stops[lower + 1]
            return HexColor.Components(
                red: from.red + (to.red - from.red) * fraction,
                green: from.green + (to.green - from.green) * fraction,
                blue: from.blue + (to.blue - from.blue) * fraction,
                alpha: from.alpha + (to.alpha - from.alpha) * fraction
            )
        }
    }
}

final class WaveformView: NSView {
    private var barLayers: [CALayer] = []
    private var dotLayers: [CALayer] = []
    private var displayedLevel: CGFloat = 0
    private var levelTime: CFTimeInterval = 0
    var isAnimating = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setupLayers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        setupLayers()
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        applyBars()
        layoutDots()
        CATransaction.commit()
    }

    func setBarColor(_ color: NSColor) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        (barLayers + dotLayers).forEach { layer in
            layer.backgroundColor = color.cgColor
            layer.shadowOpacity = 0
        }
        CATransaction.commit()
    }

    /// Gradient themes: bars and dots each take their place along the stops and glow in that colour.
    func setBarGradient(stops: [String]) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (layers, count) in [(barLayers, WaveformResponse.barCount), (dotLayers, WaveformResponse.dotCount)] {
            let colors = WaveformPalette.colors(stops: stops, count: count).map(Self.cgColor)
            for (layer, color) in zip(layers, colors) {
                layer.backgroundColor = color
                layer.shadowColor = color
                layer.shadowOffset = .zero
                layer.shadowRadius = WaveformResponse.glowRadius
                layer.shadowOpacity = WaveformResponse.glowOpacity
            }
        }
        CATransaction.commit()
    }

    private static func cgColor(_ components: HexColor.Components) -> CGColor {
        NSColor(
            srgbRed: components.red,
            green: components.green,
            blue: components.blue,
            alpha: components.alpha
        ).cgColor
    }

    /// Drops the bars to their resting height, for states without live audio.
    func resetLevel() {
        displayedLevel = 0
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        applyBars()
        CATransaction.commit()
    }

    /// Transcribing: the bars give way to three bouncing dots; static dots under Reduce Motion.
    func setPulsing(_ isPulsing: Bool, reduceMotion: Bool) {
        let key = "transcribingBounce"
        dotLayers.forEach { $0.removeAnimation(forKey: key) }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        barLayers.forEach { $0.isHidden = isPulsing }
        dotLayers.forEach { $0.isHidden = !isPulsing }
        CATransaction.commit()
        guard isPulsing, !reduceMotion else { return }

        let now = CACurrentMediaTime()
        for (index, dot) in dotLayers.enumerated() {
            let bounce = CAKeyframeAnimation(keyPath: "transform.translation.y")
            // Layer coordinates point up, so a positive offset lifts the dot.
            bounce.values = [0, WaveformResponse.bounceHeight, 0, 0]
            bounce.keyTimes = [0, 0.2, 0.4, 1]
            bounce.timingFunctions = [
                CAMediaTimingFunction(name: .easeOut),
                CAMediaTimingFunction(name: .easeIn),
                CAMediaTimingFunction(name: .linear)
            ]
            bounce.duration = WaveformResponse.bouncePeriod
            bounce.repeatCount = .infinity
            bounce.beginTime = now + Double(index) * WaveformResponse.bounceStagger
            dot.add(bounce, forKey: key)
        }
    }

    func setLevel(_ level: CGFloat) {
        guard isAnimating else { return }
        displayedLevel = WaveformResponse.displayedLevel(for: level)
        levelTime = CACurrentMediaTime()

        CATransaction.begin()
        CATransaction.setAnimationDuration(WaveformResponse.frameAnimationDuration)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        applyBars()
        CATransaction.commit()
    }

    private func setupLayers() {
        // The glow on a full-height bar reaches a few points past the view's edges.
        layer?.masksToBounds = false
        for _ in 0..<WaveformResponse.barCount {
            let bar = CALayer()
            bar.backgroundColor = NSColor.white.withAlphaComponent(0.9).cgColor
            bar.cornerRadius = WaveformResponse.barWidth / 2
            layer?.addSublayer(bar)
            barLayers.append(bar)
        }
        for _ in 0..<WaveformResponse.dotCount {
            let dot = CALayer()
            dot.backgroundColor = NSColor.white.withAlphaComponent(0.9).cgColor
            dot.cornerRadius = WaveformResponse.dotSize / 2
            dot.isHidden = true
            layer?.addSublayer(dot)
            dotLayers.append(dot)
        }
    }

    private func applyBars() {
        let fractions = WaveformResponse.barFractions(for: displayedLevel, at: levelTime)
        let startX = (bounds.width - WaveformResponse.totalBarWidth) / 2
        for (index, bar) in barLayers.enumerated() {
            let height = bounds.height * fractions[index]
            let x = startX + CGFloat(index) * (WaveformResponse.barWidth + WaveformResponse.barGap)
            bar.frame = CGRect(x: x, y: (bounds.height - height) / 2, width: WaveformResponse.barWidth, height: height)
        }
    }

    private func layoutDots() {
        let size = WaveformResponse.dotSize
        let total = CGFloat(WaveformResponse.dotCount) * size + CGFloat(WaveformResponse.dotCount - 1) * WaveformResponse.dotGap
        let startX = (bounds.width - total) / 2
        for (index, dot) in dotLayers.enumerated() {
            dot.frame = CGRect(
                x: startX + CGFloat(index) * (size + WaveformResponse.dotGap),
                y: (bounds.height - size) / 2,
                width: size,
                height: size
            )
        }
    }
}
