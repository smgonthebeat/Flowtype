import Foundation

struct ModelReadinessInspector {
    func inspect(
        applicationSupportRoot: URL,
        selectedModelID: String,
        helperStatuses: [String: QwenModelStatus]
    ) -> [ReadinessCheck] {
        var checks: [ReadinessCheck] = [
            selectedModelCheck(selectedModelID: selectedModelID)
        ]

        for model in VoiceInputModel.all {
            let manager = ModelManager(model: model, applicationSupportRoot: applicationSupportRoot)
            let status = matchingStatus(for: model, helperStatuses: helperStatuses)
            checks.append(modelInstallCheck(
                model: model,
                manager: manager,
                selectedModelID: selectedModelID,
                status: status
            ))
            checks.append(modelWarmCheck(model: model, selectedModelID: selectedModelID, status: status))
        }

        return checks
    }

    private func matchingStatus(for model: VoiceInputModel, helperStatuses: [String: QwenModelStatus]) -> QwenModelStatus? {
        guard let status = helperStatuses[model.modelID],
              status.modelId == model.modelID else {
            return nil
        }
        return status
    }

    private func selectedModelCheck(selectedModelID: String) -> ReadinessCheck {
        let model = VoiceInputModel.model(for: selectedModelID)
        return ReadinessCheck(
            id: "selected-model",
            group: .models,
            title: "Selected model",
            detail: "\(model.displayName) is selected for local dictation.",
            status: .ready,
            locationTarget: .selectedModel
        )
    }

    private func modelInstallCheck(
        model: VoiceInputModel,
        manager: ModelManager,
        selectedModelID: String,
        status: QwenModelStatus?
    ) -> ReadinessCheck {
        let isSelected = model.id == selectedModelID

        if manager.isModelInstalled || status?.installed == true {
            return ReadinessCheck(
                id: "model-\(model.id)",
                group: .models,
                title: model.displayName,
                detail: "The model cache is present in Flowtype's Application Support folder.",
                status: .ready,
                locationTarget: isSelected ? .selectedModel : .modelsRoot
            )
        }

        if status?.downloading == true || status?.loading == true {
            return ReadinessCheck(
                id: "model-\(model.id)",
                group: .models,
                title: model.displayName,
                detail: progressDetail(for: status),
                status: isSelected ? .preparing : .optional,
                locationTarget: isSelected ? .selectedModel : .modelsRoot
            )
        }

        if manager.needsRepair {
            return ReadinessCheck(
                id: "model-\(model.id)",
                group: .models,
                title: model.displayName,
                detail: "The model cache looks incomplete and should be reinstalled.",
                status: isSelected ? .needsRepair : .optional,
                locationTarget: isSelected ? .selectedModel : .modelsRoot
            )
        }

        return ReadinessCheck(
            id: "model-\(model.id)",
            group: .models,
            title: model.displayName,
            detail: "Download this model before using local Qwen dictation.",
            status: isSelected ? .notReady : .optional,
            primaryAction: isSelected && model.id == VoiceInputModel.qwen3ASR06B.id ? .downloadDefaultModel : nil,
            locationTarget: isSelected ? .selectedModel : .modelsRoot
        )
    }

    private func modelWarmCheck(
        model: VoiceInputModel,
        selectedModelID: String,
        status: QwenModelStatus?
    ) -> ReadinessCheck {
        guard model.id == selectedModelID else {
            return ReadinessCheck(
                id: "model-\(model.id)-warm",
                group: .models,
                title: "\(model.displayName) preload status",
                detail: "Only the selected model is prepared for lower-latency dictation.",
                status: .optional,
                locationTarget: .modelsRoot
            )
        }

        if status?.loaded == true {
            return ReadinessCheck(
                id: "model-\(model.id)-warm",
                group: .models,
                title: "\(model.displayName) preload status",
                detail: "The selected Qwen model is loaded and ready for lower-latency dictation.",
                status: .ready,
                locationTarget: .selectedModel
            )
        }

        return ReadinessCheck(
            id: "model-\(model.id)-warm",
            group: .models,
            title: "\(model.displayName) preload status",
            detail: "Flowtype prepares the selected model automatically after download and app launch. The first dictation may be slower if preparation has not finished.",
            status: .optional,
            secondaryAction: .copyDiagnostics,
            locationTarget: .selectedModel
        )
    }

    private func progressDetail(for status: QwenModelStatus?) -> String {
        guard let progress = status?.progress else {
            return "Flowtype is preparing the local Qwen model."
        }
        let clampedProgress = min(max(progress, 0), 1)
        return "Flowtype is preparing the local Qwen model: \(Int((clampedProgress * 100).rounded()))%."
    }
}
