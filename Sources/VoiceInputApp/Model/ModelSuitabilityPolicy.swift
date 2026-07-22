import Foundation

enum ModelSuitabilityLevel: String, Equatable, Codable {
    case recommended
    case allowedWithWarning
    case reasonableOptIn
    case suitable
    case stronglyDiscouraged
}

struct ModelSuitabilityRecommendation: Equatable {
    let level: ModelSuitabilityLevel
    let summary: String
    let detail: String
    let physicalMemoryGB: Int?
}

struct ModelSuitabilityPolicy {
    func recommendation(hardware: HardwareSummary, model: VoiceInputModel) -> ModelSuitabilityRecommendation {
        if model.id == VoiceInputModel.qwen3ASR06B.id {
            return ModelSuitabilityRecommendation(
                level: .recommended,
                summary: "Recommended",
                detail: "Qwen3-ASR 0.6B is recommended for fast daily dictation on this Mac.",
                physicalMemoryGB: hardware.physicalMemoryGB
            )
        }

        if hardware.physicalMemoryGB <= 16 {
            return ModelSuitabilityRecommendation(
                level: .stronglyDiscouraged,
                summary: "Not recommended on this Mac",
                detail: "Qwen3-ASR 1.7B may be much slower on \(hardware.physicalMemoryGB) GB unified memory, especially after launch, after model switching, and for longer recordings.",
                physicalMemoryGB: hardware.physicalMemoryGB
            )
        }

        if hardware.physicalMemoryGB <= 24 {
            return ModelSuitabilityRecommendation(
                level: .allowedWithWarning,
                summary: "Use with warning",
                detail: "Qwen3-ASR 1.7B can improve difficult audio but may feel noticeably slower on \(hardware.physicalMemoryGB) GB unified memory.",
                physicalMemoryGB: hardware.physicalMemoryGB
            )
        }

        if hardware.physicalMemoryGB < 48 {
            return ModelSuitabilityRecommendation(
                level: .reasonableOptIn,
                summary: "Optional accuracy mode",
                detail: "Qwen3-ASR 1.7B is a reasonable opt-in when accuracy matters more than speed.",
                physicalMemoryGB: hardware.physicalMemoryGB
            )
        }

        return ModelSuitabilityRecommendation(
            level: .suitable,
            summary: "Suitable",
            detail: "Qwen3-ASR 1.7B is suitable on this Mac when accuracy matters more than speed.",
            physicalMemoryGB: hardware.physicalMemoryGB
        )
    }

    func requiresConfirmation(hardware: HardwareSummary, model: VoiceInputModel) -> Bool {
        let level = recommendation(hardware: hardware, model: model).level
        return level == .stronglyDiscouraged || level == .allowedWithWarning
    }
}
