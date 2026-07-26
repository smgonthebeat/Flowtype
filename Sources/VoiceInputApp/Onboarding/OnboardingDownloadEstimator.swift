import Foundation

enum DownloadTransferActivity: Equatable {
    case estimating
    case transferring(bytesPerSecond: Double, remainingSeconds: Int)
    case finishing
    case waitingForNetwork
}

struct DownloadTransferFeedback: Equatable {
    let downloadedBytes: Int64
    let totalBytes: Int64
    let activity: DownloadTransferActivity
}

/// Converts helper byte counters into stable user-facing download feedback.
/// The helper timestamp is used for rate deltas; `receivedAt` is used only to
/// detect a transfer that has stopped advancing.
struct DownloadTransferEstimator {
    private struct Identity: Equatable {
        let operationID: String?
        let source: String?
    }

    private let smoothingFactor: Double
    private let samplesRequiredForEstimate: Int
    private let stallInterval: TimeInterval

    private var identity: Identity?
    private var lastDownloadedBytes: Int64?
    private var lastSampleTime: TimeInterval?
    private var lastReceivedAt: TimeInterval?
    private var lastProgressAt: TimeInterval?
    private var smoothedBytesPerSecond: Double?
    private var positiveSampleCount = 0

    init(
        smoothingFactor: Double = 0.3,
        samplesRequiredForEstimate: Int = 2,
        stallInterval: TimeInterval = 8
    ) {
        self.smoothingFactor = min(max(smoothingFactor, 0), 1)
        self.samplesRequiredForEstimate = max(samplesRequiredForEstimate, 1)
        self.stallInterval = max(stallInterval, 1)
    }

    mutating func reset() {
        identity = nil
        lastDownloadedBytes = nil
        lastSampleTime = nil
        lastReceivedAt = nil
        lastProgressAt = nil
        smoothedBytesPerSecond = nil
        positiveSampleCount = 0
    }

    mutating func update(
        _ sample: DownloadTransferSnapshot,
        receivedAt: TimeInterval = Date().timeIntervalSince1970
    ) -> DownloadTransferFeedback {
        let nextIdentity = Identity(operationID: sample.operationID, source: sample.source)
        let downloadedBytes = min(max(sample.downloadedBytes, 0), sample.totalBytes)
        let sampleTime = sample.updatedAt ?? receivedAt

        if identity != nextIdentity ||
            (lastDownloadedBytes.map { downloadedBytes < $0 } ?? false) ||
            (lastSampleTime.map { sampleTime < $0 } ?? false) {
            reset()
        }

        identity = nextIdentity

        if let previousBytes = lastDownloadedBytes,
           downloadedBytes > previousBytes {
            let helperDelta = sampleTime - (lastSampleTime ?? sampleTime)
            let receiptDelta = receivedAt - (lastReceivedAt ?? receivedAt)
            let elapsed = helperDelta > 0 ? helperDelta : receiptDelta
            if elapsed > 0 {
                let instantaneousRate = Double(downloadedBytes - previousBytes) / elapsed
                if instantaneousRate > 0, instantaneousRate.isFinite {
                    if let smoothedBytesPerSecond {
                        self.smoothedBytesPerSecond = smoothingFactor * instantaneousRate +
                            (1 - smoothingFactor) * smoothedBytesPerSecond
                    } else {
                        smoothedBytesPerSecond = instantaneousRate
                    }
                    positiveSampleCount += 1
                }
            }
            lastProgressAt = receivedAt
        } else if lastProgressAt == nil {
            lastProgressAt = receivedAt
        }

        lastDownloadedBytes = downloadedBytes
        lastSampleTime = sampleTime
        lastReceivedAt = receivedAt

        if downloadedBytes >= sample.totalBytes {
            return DownloadTransferFeedback(
                downloadedBytes: downloadedBytes,
                totalBytes: sample.totalBytes,
                activity: .finishing
            )
        }

        if let lastProgressAt,
           receivedAt - lastProgressAt >= stallInterval {
            return DownloadTransferFeedback(
                downloadedBytes: downloadedBytes,
                totalBytes: sample.totalBytes,
                activity: .waitingForNetwork
            )
        }

        guard positiveSampleCount >= samplesRequiredForEstimate,
              let smoothedBytesPerSecond,
              smoothedBytesPerSecond > 0
        else {
            return DownloadTransferFeedback(
                downloadedBytes: downloadedBytes,
                totalBytes: sample.totalBytes,
                activity: .estimating
            )
        }

        let remainingBytes = max(sample.totalBytes - downloadedBytes, 0)
        let remainingSeconds = Int(ceil(Double(remainingBytes) / smoothedBytesPerSecond))
        return DownloadTransferFeedback(
            downloadedBytes: downloadedBytes,
            totalBytes: sample.totalBytes,
            activity: .transferring(
                bytesPerSecond: smoothedBytesPerSecond,
                remainingSeconds: max(remainingSeconds, 0)
            )
        )
    }
}
