//
//  GameplayThinkingService.swift
//  DmdApp
//

import Foundation
import Observation

@MainActor
@Observable
final class GameplayThinkingService {
    enum Status: Equatable {
        case idle
        case preparing
        case ready
        case working
        case error(String)
    }

    private(set) var status: Status = .idle
    private(set) var lastSummary = ""

    let preferences: ThinkingModelPreferences
    let masterEngine: MasterAlgorithmEngine
    let playthroughStore: PlaythroughMemoryStore

    private let gameplayLLM: GameplayLLMService
    private let analysisLLM: CampaignLLMService

    init(
        preferences: ThinkingModelPreferences,
        gameplayLLM: GameplayLLMService,
        analysisLLM: CampaignLLMService,
        masterEngine: MasterAlgorithmEngine,
        playthroughStore: PlaythroughMemoryStore
    ) {
        self.preferences = preferences
        self.gameplayLLM = gameplayLLM
        self.analysisLLM = analysisLLM
        self.masterEngine = masterEngine
        self.playthroughStore = playthroughStore
    }

    var activeModelTitle: String {
        preferences.selectedModel.title
    }

    func rebuildMasterIndex(for campaign: ParsedCampaign) async {
        await masterEngine.buildIndex(for: campaign)
    }

    func prepareForGameplay(campaign: ParsedCampaign) async {
        status = .preparing
        playthroughStore.load(for: campaign)

        switch preferences.selectedModel {
        case .masterAlgorithm:
            await gameplayLLM.unloadModel()
            await masterEngine.buildIndex(for: campaign)
            await analysisLLM.prepareModel(unloadingGameplayFrom: gameplayLLM)

            var summary = masterEngine.lastBuildSummary
            if analysisLLM.isReady {
                summary += " Llama 7B gotowy — wspólna interpretacja kampanii."
            } else if case .error(let message) = analysisLLM.status {
                summary += " Llama niedostępna (\(message)) — tylko Algorytm Mistrza."
            } else {
                summary += " Llama niezaładowana — tylko Algorytm Mistrza."
            }
            lastSummary = summary
            status = masterEngine.isReady ? .ready : .error("Nie udało się zbudować indeksu Mistrza.")

        case .tinyLlama:
            masterEngine.unload()
            await gameplayLLM.prepareModel(unloadingAnalysisFrom: analysisLLM)
            syncStatusFromLLM()

        case .llama7B:
            masterEngine.loadOrBuildIndex(for: campaign)
            await gameplayLLM.unloadModel()
            await analysisLLM.prepareModel()
            if analysisLLM.isReady {
                status = .ready
                lastSummary = "Llama 7B + indeks Mistrza gotowe do interpretacji."
            } else if case .error(let message) = analysisLLM.status {
                status = .error(message)
            } else {
                status = .idle
            }
        }
    }

    func recommendChoice(
        for player: PlayerCharacter,
        playerSlot: Int,
        campaign: ParsedCampaign,
        sceneIndex: Int,
        decisionIndex: Int
    ) -> MasterChoiceRecommendation? {
        switch preferences.selectedModel {
        case .masterAlgorithm:
            return masterEngine.recommendChoice(
                for: player,
                playerSlot: playerSlot,
                decisionIndex: decisionIndex,
                sceneIndex: sceneIndex,
                playthrough: playthroughStore.memory
            )
        case .tinyLlama, .llama7B:
            return heuristicRecommendation(
                campaign: campaign,
                player: player,
                playerSlot: playerSlot,
                decisionIndex: decisionIndex
            )
        }
    }

    func interpretScene(
        campaign: ParsedCampaign,
        sceneIndex: Int,
        decisionIndex: Int?,
        players: [PlayerCharacter],
        selectedChoices: [UUID: String]
    ) async -> String {
        status = .working
        let decisionIdx = decisionIndex ?? sceneIndex

        var recommendations: [UUID: MasterChoiceRecommendation] = [:]
        for (slot, player) in players.enumerated() {
            if let rec = recommendChoice(
                for: player,
                playerSlot: slot,
                campaign: campaign,
                sceneIndex: sceneIndex,
                decisionIndex: decisionIdx
            ) {
                recommendations[player.id] = rec
            }
        }

        let result: String
        switch preferences.selectedModel {
        case .masterAlgorithm:
            result = await interpretWithMasterAndLlama(
                campaign: campaign,
                sceneIndex: sceneIndex,
                decisionIndex: decisionIndex,
                players: players,
                selectedChoices: selectedChoices,
                recommendations: recommendations
            )

        case .tinyLlama:
            result = await gameplayLLM.interpretScene(
                campaign: campaign,
                sceneIndex: sceneIndex,
                decisionIndex: decisionIndex,
                players: players,
                selectedChoices: selectedChoices
            )
            lastSummary = gameplayLLM.lastInterpretationSummary

        case .llama7B:
            result = await interpretWithMasterAndLlama(
                campaign: campaign,
                sceneIndex: sceneIndex,
                decisionIndex: decisionIndex,
                players: players,
                selectedChoices: selectedChoices,
                recommendations: recommendations
            )
        }

        status = .ready
        return result
    }

    func resolveAbilityEffect(ability: CreatedAbility) async -> AbilityEffectResolution {
        await AbilityEffectResolver.resolve(
            ability: ability,
            llm: analysisLLM.isReady ? analysisLLM : nil
        )
    }

    func applyRecommendedChoice(
        campaign: ParsedCampaign,
        playerSlot: Int,
        playerID: UUID,
        decisionIndex: Int,
        recommendation: MasterChoiceRecommendation
    ) {
        playthroughStore.record(
            campaign: campaign,
            decisionIndex: decisionIndex,
            playerSlot: playerSlot,
            choiceIndex: recommendation.choiceIndex,
            choiceText: recommendation.choiceText
        )
        _ = playerID
    }

    func modelIsOnDisk(for model: GameplayThinkingModel) -> Bool {
        guard let role = model.llmRole else { return true }
        return LocalLLMConfig.isModelOnDisk(role)
    }

    func modelFileSizeLabel(for model: GameplayThinkingModel) -> String {
        guard let role = model.llmRole else {
            return masterEngine.indexSizeLabel
        }
        return LocalLLMConfig.validateModelFile(at: role.fileURL(), role: role).message
    }

    func downloadModel(for model: GameplayThinkingModel) async {
        guard let role = model.llmRole else {
            lastSummary = "Algorytm Mistrza nie wymaga pobierania."
            return
        }

        status = .preparing
        switch model {
        case .tinyLlama:
            await gameplayLLM.prepareModel(unloadingAnalysisFrom: analysisLLM)
            syncStatusFromLLM()
        case .llama7B:
            await analysisLLM.prepareModel()
            if analysisLLM.isReady {
                status = .ready
                lastSummary = "Llama 7B pobrana."
            }
        case .masterAlgorithm:
            break
        }
    }

    private func interpretWithMasterAndLlama(
        campaign: ParsedCampaign,
        sceneIndex: Int,
        decisionIndex: Int?,
        players: [PlayerCharacter],
        selectedChoices: [UUID: String],
        recommendations: [UUID: MasterChoiceRecommendation]
    ) async -> String {
        let masterNarrative = masterEngine.interpretScene(
            campaign: campaign,
            sceneIndex: sceneIndex,
            decisionIndex: decisionIndex,
            players: players,
            selectedChoices: selectedChoices,
            recommendations: recommendations,
            playthrough: playthroughStore.memory
        )

        guard analysisLLM.isReady else {
            lastSummary = "Algorytm Mistrza — interpretacja (Llama niedostępna)."
            return masterNarrative
        }

        let prompt = MasterLlamaCollaboration.buildGameplayPrompt(
            campaign: campaign,
            masterBrief: masterEngine.campaignStructureBrief(for: campaign),
            masterNarrative: masterNarrative,
            sceneIndex: sceneIndex,
            decisionIndex: decisionIndex,
            players: players,
            selectedChoices: selectedChoices,
            recommendations: recommendations
        )

        do {
            let response = try await analysisLLM.generateText(
                prompt: prompt,
                systemPrompt: MasterLlamaCollaboration.llamaSystemPrompt,
                maxTokens: 480
            )
            lastSummary = "Algorytm Mistrza + Llama 7B — wspólna interpretacja."
            return response.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            lastSummary = "Llama niedostępna — użyto interpretacji Mistrza."
            return masterNarrative
        }
    }

    private func heuristicRecommendation(
        campaign: ParsedCampaign,
        player: PlayerCharacter,
        playerSlot: Int,
        decisionIndex: Int
    ) -> MasterChoiceRecommendation? {
        masterEngine.loadOrBuildIndex(for: campaign)
        return masterEngine.recommendChoice(
            for: player,
            playerSlot: playerSlot,
            decisionIndex: decisionIndex,
            sceneIndex: decisionIndex,
            playthrough: playthroughStore.memory
        )
    }

    private func syncStatusFromLLM() {
        switch gameplayLLM.status {
        case .ready:
            status = .ready
            lastSummary = gameplayLLM.lastInterpretationSummary
        case .error(let message):
            status = .error(message)
        default:
            status = .idle
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
