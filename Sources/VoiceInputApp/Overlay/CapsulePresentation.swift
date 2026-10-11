import Foundation

enum CapsuleWaveformMode: Equatable {
    case liveAudio
    case idle
}

/// What the capsule is saying, which decides its colour and leading glyph (design-spec 5.10).
enum CapsuleKind: Equatable {
    case listening
    case transcribing
    case info
    case confirmation
    /// Still listening, but close to the time limit: the live waveform turns warning-coloured.
    case warning
    case failure
    /// The recording held no speech: a muted-microphone chip rather than a failure glyph.
    case noSpeech
}

struct CapsulePresentation: Equatable {
    let text: String
    let waveformMode: CapsuleWaveformMode
    let kind: CapsuleKind

    var animatesWaveform: Bool {
        waveformMode == .liveAudio
    }

    /// The transcribing pulse is separate from `animatesWaveform`, which stays tied to live audio.
    var pulsesWaveform: Bool {
        kind == .transcribing
    }

    var showsWaveform: Bool {
        switch kind {
        case .listening, .transcribing, .warning: return true
        case .info, .confirmation, .failure, .noSpeech: return false
        }
    }

    static func listening(_ text: String) -> CapsulePresentation {
        CapsulePresentation(text: text, waveformMode: .liveAudio, kind: .listening)
    }

    /// Countdown near the recording limit: the microphone is still recording, so the waveform stays live.
    static func listeningCountdown(_ text: String) -> CapsulePresentation {
        CapsulePresentation(text: text, waveformMode: .liveAudio, kind: .warning)
    }

    static func transcribing(_ text: String) -> CapsulePresentation {
        CapsulePresentation(text: text, waveformMode: .idle, kind: .transcribing)
    }

    static func status(_ text: String) -> CapsulePresentation {
        CapsulePresentation(text: text, waveformMode: .idle, kind: .info)
    }

    static func result(_ text: String) -> CapsulePresentation {
        CapsulePresentation(text: text, waveformMode: .idle, kind: .confirmation)
    }

    static func failure(_ text: String) -> CapsulePresentation {
        CapsulePresentation(text: text, waveformMode: .idle, kind: .failure)
    }

    static func noSpeech(_ text: String) -> CapsulePresentation {
        CapsulePresentation(text: text, waveformMode: .idle, kind: .noSpeech)
    }
}
