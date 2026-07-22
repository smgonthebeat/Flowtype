import Foundation

struct RMSMeter {
    private var smoothed: Double = 0
    private let attack: Double = 0.55
    private let release: Double = 0.14
    private let weights: [Double] = [0.5, 0.8, 1.0, 0.75, 0.55]

    private static let noiseFloorDecibels = -50.0
    private static let fullScaleDecibels = -10.0
    private static let perceptualExponent = 0.80

    mutating func smoothedLevel(forRMS rms: Double) -> Double {
        let clamped = min(max(rms, 0), 1)
        let coefficient = clamped > smoothed ? attack : release
        smoothed = smoothed + (clamped - smoothed) * coefficient
        return smoothed
    }

    mutating func barHeights(forRMS rms: Double, maxHeight: Double) -> [Double] {
        let level = max(0.10, smoothedLevel(forRMS: rms))
        return weights.enumerated().map { index, weight in
            let jitter = 1.0 + sin(Double(index) * 12.9898 + level * 78.233) * 0.04
            return min(maxHeight, max(4, maxHeight * level * weight * jitter))
        }
    }

    mutating func normalizedLevel(forRMS rms: Double) -> Double {
        smoothedLevel(forRMS: Self.normalizedInputLevel(forRMS: rms))
    }

    static func normalizedInputLevel(forRMS rms: Double) -> Double {
        let decibels = 20 * log10(max(rms, 1e-6))
        let linear = max(
            0,
            min(
                1,
                (decibels - noiseFloorDecibels) / (fullScaleDecibels - noiseFloorDecibels)
            )
        )
        return pow(linear, perceptualExponent)
    }
}
