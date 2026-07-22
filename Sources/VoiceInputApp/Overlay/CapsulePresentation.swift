import Foundation

enum CapsuleWaveformMode: Equatable {
    case liveAudio
    case idle
}

struct CapsulePresentation: Equatable {
    let text: String
    let waveformMode: CapsuleWaveformMode

    var animatesWaveform: Bool {
        waveformMode == .liveAudio
    }

    static func listening(_ text: String = "Listening...") -> CapsulePresentation {
        CapsulePresentation(text: text, waveformMode: .liveAudio)
    }

    static func transcribing(_ text: String) -> CapsulePresentation {
        CapsulePresentation(text: text, waveformMode: .idle)
    }

    static func status(_ text: String) -> CapsulePresentation {
        CapsulePresentation(text: text, waveformMode: .idle)
    }

    static func result(_ text: String) -> CapsulePresentation {
        CapsulePresentation(text: text, waveformMode: .idle)
    }

    static func failure(_ text: String) -> CapsulePresentation {
        CapsulePresentation(text: text, waveformMode: .idle)
    }
}
