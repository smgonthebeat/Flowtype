import AppKit

/// Saturation applied to pixels once, up front, with the same matrix as CSS `saturate()` (the
/// owner's mock-up) so the result matches it numerically. SwiftUI's `.saturation` is a render-time
/// effect that `NSView.cacheDisplay` (the snapshot harness) silently skips, so the corner
/// backdrop's saturation is baked into the cached image instead.
enum ImageSaturation {
    /// CSS `saturate(amount)` matrix, row-major over R, G, B.
    static func matrix(_ s: Double) -> [[Double]] {
        [
            [0.213 + 0.787 * s, 0.715 - 0.715 * s, 0.072 - 0.072 * s],
            [0.213 - 0.213 * s, 0.715 + 0.285 * s, 0.072 - 0.072 * s],
            [0.213 - 0.213 * s, 0.715 - 0.715 * s, 0.072 + 0.928 * s]
        ]
    }

    /// One straight-alpha pixel, components in 0...1.
    static func apply(_ amount: Double, toRed r: Double, green g: Double, blue b: Double) -> (red: Double, green: Double, blue: Double) {
        let m = matrix(amount)
        func channel(_ row: [Double]) -> Double {
            min(max(row[0] * r + row[1] * g + row[2] * b, 0), 1)
        }
        return (channel(m[0]), channel(m[1]), channel(m[2]))
    }

    /// A copy of `image` with its colours saturated by `amount` (1 = unchanged), alpha untouched.
    /// Returns the original when `amount` is 1 or the pixels cannot be read.
    static func saturated(_ image: NSImage, by amount: Double) -> NSImage {
        guard amount != 1,
              let source = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
        else { return image }

        let width = source.width
        let height = source.height
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        let info = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: info
            ) else { return false }
            context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return image }

        let m = matrix(amount)
        let (m00, m01, m02) = (m[0][0], m[0][1], m[0][2])
        let (m10, m11, m12) = (m[1][0], m[1][1], m[1][2])
        let (m20, m21, m22) = (m[2][0], m[2][1], m[2][2])
        pixels.withUnsafeMutableBufferPointer { buffer in
            for offset in stride(from: 0, to: buffer.count, by: 4) {
                let alpha = Double(buffer[offset + 3])
                guard alpha > 0 else { continue }
                // Premultiplied in, straight for the matrix, premultiplied out.
                let r = min(Double(buffer[offset]) / alpha, 1)
                let g = min(Double(buffer[offset + 1]) / alpha, 1)
                let b = min(Double(buffer[offset + 2]) / alpha, 1)
                buffer[offset] = UInt8((min(max(m00 * r + m01 * g + m02 * b, 0), 1) * alpha).rounded())
                buffer[offset + 1] = UInt8((min(max(m10 * r + m11 * g + m12 * b, 0), 1) * alpha).rounded())
                buffer[offset + 2] = UInt8((min(max(m20 * r + m21 * g + m22 * b, 0), 1) * alpha).rounded())
            }
        }

        let result = pixels.withUnsafeMutableBytes { buffer -> CGImage? in
            CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: info
            )?.makeImage()
        }
        guard let result else { return image }
        return NSImage(cgImage: result, size: image.size)
    }
}
