import AVFoundation
import AudioToolbox
import CoreAudio
import Foundation

enum AudioRecorderError: Error, Equatable {
    case alreadyRecording
    case inputDeviceUnavailable
    case outputFormatUnavailable
    case audioConversionFailed
}

final class AudioRecorder {
    private let engine = AVAudioEngine()
    private var file: AVAudioFile?
    private var meter = RMSMeter()
    private var activeSessionID: UUID?
    private(set) var outputURL: URL?
    private(set) var recordingError: Error?
    var onRMS: ((Double) -> Void)?
    var onError: ((Error) -> Void)?

    static var transcriptionFileFormat: AVAudioFormat? {
        AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        )
    }

    func start(inputDeviceUID: String? = nil) throws -> URL {
        guard !engine.isRunning else {
            throw AudioRecorderError.alreadyRecording
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("flowtype-\(UUID().uuidString)")
            .appendingPathExtension("wav")

        let input = engine.inputNode
        if let inputDeviceUID,
           let deviceID = AudioInputDeviceManager.deviceID(forUID: inputDeviceUID) {
            try applyInputDevice(deviceID, to: input)
        }
        let inputFormat = input.outputFormat(forBus: 0)
        guard let outputFormat = Self.transcriptionFileFormat,
              let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw AudioRecorderError.outputFormatUnavailable
        }
        let audioFile = try AVAudioFile(
            forWriting: url,
            settings: outputFormat.settings,
            commonFormat: outputFormat.commonFormat,
            interleaved: outputFormat.isInterleaved
        )
        let sessionID = UUID()

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }
            do {
                let convertedBuffer = try Self.convert(
                    buffer,
                    using: converter,
                    from: inputFormat,
                    to: outputFormat
                )
                if convertedBuffer.frameLength > 0 {
                    try audioFile.write(from: convertedBuffer)
                }
            } catch {
                DispatchQueue.main.async {
                    guard self.activeSessionID == sessionID else { return }
                    self.recordingError = error
                    self.onError?(error)
                }
                return
            }

            let rms = Self.rms(buffer: buffer)
            DispatchQueue.main.async {
                guard self.activeSessionID == sessionID else { return }
                _ = self.meter.smoothedLevel(forRMS: rms)
                self.onRMS?(rms)
            }
        }

        do {
            file = audioFile
            outputURL = url
            activeSessionID = sessionID
            recordingError = nil
            engine.prepare()
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            engine.stop()
            file = nil
            outputURL = nil
            activeSessionID = nil
            recordingError = error
            throw error
        }

        return url
    }

    func stop() {
        activeSessionID = nil
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        file = nil
    }

    private static func rms(buffer: AVAudioPCMBuffer) -> Double {
        guard let channel = buffer.floatChannelData?[0] else { return 0 }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0 }

        var sum: Float = 0
        for index in 0..<frameLength {
            sum += channel[index] * channel[index]
        }
        return Double(sqrt(sum / Float(frameLength)))
    }

    private static func convert(
        _ buffer: AVAudioPCMBuffer,
        using converter: AVAudioConverter,
        from inputFormat: AVAudioFormat,
        to outputFormat: AVAudioFormat
    ) throws -> AVAudioPCMBuffer {
        let ratio = outputFormat.sampleRate / max(inputFormat.sampleRate, 1)
        let capacity = AVAudioFrameCount(ceil(Double(buffer.frameLength) * ratio)) + 32
        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else {
            throw AudioRecorderError.audioConversionFailed
        }

        var didProvideInput = false
        var conversionError: NSError?
        let status = converter.convert(to: convertedBuffer, error: &conversionError) { _, outStatus in
            if didProvideInput {
                outStatus.pointee = .noDataNow
                return nil
            }
            didProvideInput = true
            outStatus.pointee = .haveData
            return buffer
        }

        if let conversionError {
            throw conversionError
        }

        switch status {
        case .haveData, .inputRanDry:
            return convertedBuffer
        case .error, .endOfStream:
            throw AudioRecorderError.audioConversionFailed
        @unknown default:
            throw AudioRecorderError.audioConversionFailed
        }
    }

    private func applyInputDevice(_ deviceID: AudioDeviceID, to inputNode: AVAudioInputNode) throws {
        guard let audioUnit = inputNode.audioUnit else {
            throw AudioRecorderError.inputDeviceUnavailable
        }

        var selectedDeviceID = deviceID
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &selectedDeviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        guard status == noErr else {
            throw AudioRecorderError.inputDeviceUnavailable
        }
    }
}
