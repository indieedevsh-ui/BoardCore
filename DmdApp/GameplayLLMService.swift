//
//  GameplayLLMService.swift
//  DmdApp
//

import Foundation
import Observation

@Observable
final class GameplayLLMService {
    enum Status: Equatable {
        case idle
        case downloading(progress: Double)
        case loadingModel
        case ready
        case interpreting
        case error(String)
    }

    private(set) var status: Status = .idle
    private(set) var lastInterpretationSummary = ""
    private(set) var loadedProfileName = ""
    private(set) var modelValidationMessage = ""

    private let engine = LlamaCampaignEngine()
    private let downloader = ModelDownloadManager()
    private let modelRole: LocalLLMModelRole = .gameplay

    var isReady: Bool {
        if case .ready = status { return true }
        return false
    }

    var modelIsOnDisk: Bool {
        LocalLLMConfig.isModelOnDisk(modelRole)
    }

    var modelFileSizeLabel: String {
        LocalLLMConfig.validateModelFile(at: modelRole.fileURL(), role: modelRole).message
    }

    func refreshModelValidation() {
        modelValidationMessage = LocalLLMConfig.validateModelFile(at: modelRole.fileURL(), role: modelRole).message
    }

    func prepareModel(unloadingAnalysisFrom analysisService: CampaignLLMService?) async {
        LocalLLMConfig.removeLegacyModels()
        refreshModelValidation()

        do {
            await analysisService?.unloadModel()

            if !LocalLLMConfig.isModelOnDisk(modelRole) {
                status = .downloading(progress: 0)
                downloader.onProgress = { [weak self] progress in
                    Task { @MainActor in
                        self?.status = .downloading(progress: progress)
                    }
                }
                try await downloader.downloadModelIfNeeded(role: modelRole)
                refreshModelValidation()
            }

            guard LocalLLMConfig.isModelOnDisk(modelRole) else {
                throw LlamaEngineError.invalidModelFile(modelValidationMessage)
            }

            status = .loadingModel
            try await engine.load(role: modelRole)
            loadedProfileName = await engine.activeProfileName
            status = .ready
            lastInterpretationSummary = "TinyLlama gotowy (profil \(loadedProfileName))."
        } catch {
            status = .error(error.localizedDescription)
            lastInterpretationSummary = error.localizedDescription
        }
    }

    func loadExistingModel(unloadingAnalysisFrom analysisService: CampaignLLMService?) async {
        LocalLLMConfig.removeLegacyModels()
        refreshModelValidation()

        guard LocalLLMConfig.isModelOnDisk(modelRole) else {
            status = .error("Brak TinyLlama. Pobierz model w ustawieniach LLM.")
            return
        }

        do {
            await analysisService?.unloadModel()
            status = .loadingModel
            try await engine.load(role: modelRole)
            loadedProfileName = await engine.activeProfileName
            status = .ready
            lastInterpretationSummary = "TinyLlama załadowany (profil \(loadedProfileName))."
        } catch {
            status = .error(error.localizedDescription)
            lastInterpretationSummary = error.localizedDescription
        }
    }

    func removeModelAndReset() async {
        await engine.unload()
        try? downloader.removeDownloadedModel(role: modelRole)
        refreshModelValidation()
        status = .idle
        loadedProfileName = ""
        lastInterpretationSummary = "Usunięto plik TinyLlama."
    }

    func unloadModel() async {
        await engine.unload()
        loadedProfileName = ""
        status = .idle
        lastInterpretationSummary = "TinyLlama zwolniony z pamięci RAM."
    }

    func interpretScene(
        campaign: ParsedCampaign,
        sceneIndex: Int,
        decisionIndex: Int?,
        players: [PlayerCharacter],
        selectedChoices: [UUID: String]
    ) async -> String {
        status = .interpreting

        do {
            let loaded = await engine.isLoaded
            if !loaded {
                try await engine.load(role: modelRole)
                loadedProfileName = await engine.activeProfileName
            }

            let prompt = buildInterpretationPrompt(
                campaign: campaign,
                sceneIndex: sceneIndex,
                decisionIndex: decisionIndex,
                players: players,
                selectedChoices: selectedChoices
            )

            let response = try await engine.generate(
                prompt: prompt,
                systemPrompt: "Jesteś Mistrzem Gry RPG. Interpretujesz zapisaną kampanię po polsku — narracja, emocje, konsekwencje wyborów. Nie wymyślaj nowej fabuły poza tym co jest w kampanii.",
                maxTokens: modelRole.maxGenerationTokens
            )

            lastInterpretationSummary = "TinyLlama wygenerował interpretację sceny."
            status = .ready
            return response
        } catch {
            status = .error(error.localizedDescription)
            lastInterpretationSummary = "Interpretacja nie powiodła się."
            return fallbackInterpretation(
                campaign: campaign,
                sceneIndex: sceneIndex,
                decisionIndex: decisionIndex
            )
        }
    }

    private func buildInterpretationPrompt(
        campaign: ParsedCampaign,
        sceneIndex: Int,
        decisionIndex: Int?,
        players: [PlayerCharacter],
        selectedChoices: [UUID: String]
    ) -> String {
        let scene = campaign.scenes[safe: sceneIndex] ?? campaign.scene(forDecisionIndex: decisionIndex ?? sceneIndex)
        let decision = decisionIndex.flatMap { campaign.decisions[safe: $0] }

        var sections: [String] = [
            "Kampania: \(campaign.title)",
        ]

        if let scene {
            sections.append("Scena: \(scene.title)")
            sections.append("Narracja:\n\(clip(scene.narrative, max: 900))")
        }

        if let decision {
            sections.append("Decyzja: \(decision.question)")
            for (index, player) in players.enumerated() {
                let choices = campaign.choices(forPlayerIndex: index, decisionIndex: decisionIndex ?? sceneIndex)
                let choiceList = choices.enumerated().map { "\($0.offset + 1)) \($0.element)" }.joined(separator: "\n")
                sections.append("Dostępne wybory — \(player.className):\n\(clip(choiceList, max: 500))")

                if let selected = selectedChoices[player.id] {
                    sections.append("\(player.className) wybrał: \(selected)")
                }
            }
        }

        sections.append("""
        Na podstawie powyższej fabuły i wyborów napisz krótką (3–5 zdań) interpretację tej chwili rozgrywki:
        - opisz co się dzieje teraz w scenie,
        - wspomnij o wyborach graczy jeśli są,
        - zakończ jednym zdaniem napięcia lub pytaniem co dalej.
        """)

        return sections.joined(separator: "\n\n")
    }

    private func fallbackInterpretation(
        campaign: ParsedCampaign,
        sceneIndex: Int,
        decisionIndex: Int?
    ) -> String {
        if let scene = campaign.scenes[safe: sceneIndex] {
            let excerpt = clip(scene.narrative, max: 280)
            return "Scena „\(scene.title)”:\n\(excerpt)"
        }
        if let index = decisionIndex, let decision = campaign.decisions[safe: index] {
            return "Decyzja: \(decision.question)"
        }
        return "Kampania „\(campaign.title)” — kontynuuj rozgrywkę według zapisanych wyborów."
    }

    private func clip(_ text: String, max maxLength: Int) -> String {
        guard maxLength > 0, text.count > maxLength else { return text }
        guard let index = text.index(text.startIndex, offsetBy: maxLength, limitedBy: text.endIndex) else {
            return text
        }
        return String(text[..<index]) + "…"
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
