//
//  CampaignLLMService.swift
//  BoardCore
//

import Foundation
import Observation

@Observable
final class CampaignLLMService {
    enum Status: Equatable {
        case idle
        case downloading(progress: Double)
        case loadingModel
        case ready
        case analyzing
        case error(String)
    }

    private(set) var status: Status = .idle
    private(set) var lastAnalysisSummary = ""
    private(set) var loadedProfileName = ""
    private(set) var modelValidationMessage = ""

    private let engine = LlamaCampaignEngine()
    private let downloader = ModelDownloadManager()
    private let modelRole: LocalLLMModelRole = .analysis

    var isReady: Bool {
        if case .ready = status { return true }
        return false
    }

    var modelIsOnDisk: Bool {
        LocalLLMConfig.isModelOnDisk(modelRole)
    }

    var modelFileSizeLabel: String {
        let validation = LocalLLMConfig.validateModelFile(at: modelRole.fileURL(), role: modelRole)
        return validation.message
    }

    func refreshModelValidation() {
        modelValidationMessage = LocalLLMConfig.validateModelFile(at: modelRole.fileURL(), role: modelRole).message
    }

    func prepareModel(unloadingGameplayFrom gameplayService: GameplayLLMService? = nil) async {
        LocalLLMConfig.removeLegacyModels()
        refreshModelValidation()

        do {
            await gameplayService?.unloadModel()
            await engine.unload()

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
            lastAnalysisSummary = "Model załadowany (profil \(loadedProfileName))."
        } catch {
            status = .error(error.localizedDescription)
            lastAnalysisSummary = error.localizedDescription
        }
    }

    func loadExistingModel() async {
        LocalLLMConfig.removeLegacyModels()
        refreshModelValidation()

        guard LocalLLMConfig.isModelOnDisk(modelRole) else {
            status = .error("Brak poprawnego pliku modelu. Usuń stary plik i pobierz Llama 2 7B.")
            return
        }

        do {
            await engine.unload()
            status = .loadingModel
            try await engine.load(role: modelRole)
            loadedProfileName = await engine.activeProfileName
            status = .ready
            lastAnalysisSummary = "Model załadowany (profil \(loadedProfileName))."
        } catch {
            status = .error(error.localizedDescription)
            lastAnalysisSummary = error.localizedDescription
        }
    }

    func removeModelAndReset() async {
        await engine.unload()
        try? downloader.removeDownloadedModel(role: modelRole)
        refreshModelValidation()
        status = .idle
        loadedProfileName = ""
        lastAnalysisSummary = "Usunięto plik modelu."
    }

    func unloadModel() async {
        await engine.unload()
        loadedProfileName = ""
        if modelIsOnDisk {
            status = .idle
            lastAnalysisSummary = "Model na dysku — nie załadowany do RAM."
        } else {
            status = .idle
            lastAnalysisSummary = ""
        }
    }

    /// Pobiera plik modelu bez ładowania wag do RAM (zarządzanie w LLM Gry).
    func downloadModelToDisk() async {
        LocalLLMConfig.removeLegacyModels()
        refreshModelValidation()

        guard !modelIsOnDisk else {
            lastAnalysisSummary = "Llama 7B jest już na dysku."
            return
        }

        do {
            await engine.unload()
            status = .downloading(progress: 0)
            downloader.onProgress = { [weak self] progress in
                Task { @MainActor in
                    self?.status = .downloading(progress: progress)
                }
            }
            try await downloader.downloadModelIfNeeded(role: modelRole)
            refreshModelValidation()
            status = .idle
            lastAnalysisSummary = "Llama 7B pobrana. Model załaduje się przy analizie kampanii."
        } catch {
            status = .error(error.localizedDescription)
            lastAnalysisSummary = error.localizedDescription
        }
    }

    func generateText(
        prompt: String,
        systemPrompt: String,
        maxTokens: Int = LocalLLMModelRole.analysis.maxGenerationTokens
    ) async throws -> String {
        let loaded = await engine.isLoaded
        if !loaded {
            try await engine.load(role: modelRole)
            loadedProfileName = await engine.activeProfileName
            status = .ready
        }
        return try await engine.generate(prompt: prompt, systemPrompt: systemPrompt, maxTokens: maxTokens)
    }

    func analyzeCampaign(_ rawText: String) async -> ParsedCampaign {
        await analyzeCampaignWithMaster(rawText, masterEngine: nil)
    }

    func analyzeCampaignWithMaster(
        _ rawText: String,
        masterEngine: MasterAlgorithmEngine?
    ) async -> ParsedCampaign {
        let parserResult = CampaignParser.parse(rawText)
        guard !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return parserResult
        }

        if let masterEngine {
            await masterEngine.buildIndex(for: parserResult)
        }

        guard let masterEngine, masterEngine.isReady else {
            lastAnalysisSummary = "Parser: \(parserResult.scenes.count) scen, \(parserResult.decisions.count) decyzji."
            return parserResult
        }

        do {
            let loaded = await engine.isLoaded
            if !loaded {
                try await engine.load(role: modelRole)
                loadedProfileName = await engine.activeProfileName
                status = .ready
            }

            status = .analyzing

            let structureReady = !parserResult.decisions.isEmpty && !parserResult.scenes.isEmpty
            let merged: ParsedCampaign

            if structureReady {
                let outlinePrompt = MasterLlamaCollaboration.buildOutlineEnrichmentPrompt(
                    rawText: rawText,
                    parserResult: parserResult
                )
                let outlineResponse = try await engine.generate(
                    prompt: outlinePrompt,
                    systemPrompt: MasterLlamaCollaboration.llamaSystemPrompt,
                    maxTokens: 420
                )
                let outline = outlineResponse.trimmingCharacters(in: .whitespacesAndNewlines)
                var enriched = parserResult
                if outline.count > 80 {
                    enriched.storyOutline = outline
                }
                merged = enriched
            } else {
                let masterBrief = masterEngine.campaignStructureBrief(for: parserResult)
                let prompt = MasterLlamaCollaboration.buildAnalysisPrompt(
                    rawText: rawText,
                    parserResult: parserResult,
                    masterBrief: masterBrief
                )
                let response = try await engine.generate(
                    prompt: prompt,
                    systemPrompt: "Jesteś parserem kampanii RPG współpracującym z Algorytmem Mistrza. Zwracasz tylko JSON.",
                    maxTokens: 640
                )
                let llmParsed = parseLLMResponse(response, fallbackTitle: parserResult.title)
                merged = MasterLlamaCollaboration.mergeCampaign(parser: parserResult, llm: llmParsed)
            }

            await masterEngine.buildIndex(for: merged)

            lastAnalysisSummary = "Mistrz + Llama: \(merged.scenes.count) scen, \(merged.decisions.count) decyzji (parser: \(parserResult.scenes.count)/\(parserResult.decisions.count))."
            status = .ready
            return merged
        } catch {
            status = .error(error.localizedDescription)
            lastAnalysisSummary = "Mistrz + Llama niedostępny — użyto parsera (\(parserResult.scenes.count) scen, \(parserResult.decisions.count) decyzji)."
            return parserResult
        }
    }

    private func buildAnalysisPrompt(for rawText: String) -> String {
        let clipped = clipCampaignText(rawText, maxCharacters: 2800)
        return """
        Jesteś parserem kampanii fabularnej RPG. Przeanalizuj tekst i zwróć WYŁĄCZNIE poprawny JSON (bez komentarzy, bez markdown).

        Format:
        {
          "title": "tytuł kampanii",
          "storyOutline": "zarys fabularny z >>ZARYG_FABULARNY<<",
          "decisions": [
            {
              "sceneTitle": "nazwa sceny",
              "question": "pytanie decyzji",
              "choicesByPlayer": [
                ["wybór 1 gracza 1", "wybór 2", "..."],
                ["wybór 1 gracza 2", "..."],
                ["wybór 1 gracza 3", "..."],
                ["wybór 1 gracza 4", "..."]
              ],
              "choiceDetailsByPlayer": [
                [
                  {
                    "text": "opis wyboru",
                    "advantage": "zaleta",
                    "disadvantage": "wada",
                    "effects": {
                      "strength": 0, "coins": 0, "abilities": 0,
                      "boardMove": 0, "blockRounds": 0, "health": 0, "mana": 0
                    }
                  }
                ]
              ],
              "alternatives": ["fallback jeśli brak choicesByPlayer"]
            }
          ],
          "scenes": [
            { "title": "tytuł sceny", "narrative": "treść narracji z Części I" }
          ]
        }

        Zasady:
        - Wyciągnij zarys fabularny (storyOutline) z >>ZARYG_FABULARNY<<.
        - Wyciągnij sceny narracji z >>SCENY<< (scenes).
        - Wyciągnij wszystkie decyzje oznaczone * [DECYZJA N | SCENA M] * z >>DECYZJE<<.
        - Dla każdej decyzji wyciągnij wybory per gracz (>>WYBORY_GRACZA_K<<, max \(CampaignPromptBuilder.choicesPerPlayer) opcji).
        - Pole "question" to wyłącznie pytanie fabularne — bez [ZALETA], [WADA], [SKUTKI] i bez powielania tekstów wyborów.
        - W "text" wyboru tylko krótka nazwa akcji; zaleta i wada w osobnych polach advantage/disadvantage.
        - Nie duplikuj wyborów z poprzednich decyzji w kolejnych rundach.
        - choiceDetailsByPlayer: pełne dane wyborów z [ZALETA], [WADA], [SKUTKI].
        - choicesByPlayer to tablica 4 tablic stringów (skrócony tekst wyboru + zaleta/wada).
        - effects: SIŁA, MONETY, ZDOLNOŚCI, PLANSZA, BLOKADA, ZDROWIE, MANA (liczby całkowite, 0 jeśli brak).
        - alternatives = spłaszczona lista wszystkich wyborów jeśli brak podziału na graczy.
        - Zachowaj sens i brzmienie oryginału po polsku.
        - Jeśli brakuje tytułu, zaproponuj krótki.

        Tekst kampanii:
        <<<
        \(clipped)
        >>>

        JSON:
        """
    }

    private func clipCampaignText(_ text: String, maxCharacters: Int) -> String {
        guard maxCharacters > 0, text.count > maxCharacters else { return text }
        guard let index = text.index(text.startIndex, offsetBy: maxCharacters, limitedBy: text.endIndex) else {
            return text
        }
        return String(text[..<index]) + "\n...[ucięto]"
    }

    private func parseLLMResponse(_ response: String, fallbackTitle: String) -> ParsedCampaign {
        let jsonString = extractJSON(from: response) ?? response
        guard
            let data = jsonString.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return ParsedCampaign(title: fallbackTitle, scenes: [], decisions: [])
        }

        let title = (object["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let storyOutline = (object["storyOutline"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let decisionsRaw = object["decisions"] as? [[String: Any]] ?? []
        let scenesRaw = object["scenes"] as? [[String: Any]] ?? []

        let scenes = scenesRaw.compactMap { item -> CampaignScene? in
            let sceneTitle = (item["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let narrative = (item["narrative"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !sceneTitle.isEmpty, !narrative.isEmpty else { return nil }
            return CampaignScene(title: sceneTitle, narrative: narrative)
        }

        let decisions = decisionsRaw.compactMap { item -> CampaignDecision? in
            let sceneTitle = (item["sceneTitle"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Scena"
            let question = (item["question"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            let choicesByPlayer = (item["choicesByPlayer"] as? [[String]] ?? [])
                .map { playerChoices in
                    playerChoices
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                }
                .filter { !$0.isEmpty }

            var alternatives = (item["alternatives"] as? [String] ?? [])
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            let choiceDetailsByPlayer = parseChoiceDetailsByPlayer(from: item)

            if alternatives.isEmpty,
               let firstPlayerChoices = choicesByPlayer.first,
               !firstPlayerChoices.isEmpty {
                alternatives = firstPlayerChoices
            }

            let hasChoices = !choiceDetailsByPlayer.isEmpty || !choicesByPlayer.isEmpty || alternatives.count >= 2
            guard !question.isEmpty, hasChoices else { return nil }

            let syncedChoices = choicesByPlayer.isEmpty && !choiceDetailsByPlayer.isEmpty
                ? choiceDetailsByPlayer.map { $0.map(\.displayText) }
                : choicesByPlayer

            return CampaignDecision(
                sceneTitle: sceneTitle,
                question: question,
                alternatives: alternatives,
                choicesByPlayer: syncedChoices,
                choiceDetailsByPlayer: choiceDetailsByPlayer
            )
        }

        return ParsedCampaign(
            title: title?.isEmpty == false ? title! : fallbackTitle,
            storyOutline: storyOutline,
            scenes: scenes,
            decisions: decisions
        )
    }

    private func parseChoiceDetailsByPlayer(from item: [String: Any]) -> [[CampaignChoice]] {
        guard let rawPlayers = item["choiceDetailsByPlayer"] as? [[[String: Any]]] else { return [] }

        return rawPlayers.map { playerChoices in
            playerChoices.compactMap { choiceItem -> CampaignChoice? in
                let text = (choiceItem["text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !text.isEmpty else { return nil }

                let advantage = (choiceItem["advantage"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let disadvantage = (choiceItem["disadvantage"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let effectsRaw = choiceItem["effects"] as? [String: Any] ?? [:]

                let effects = CampaignChoiceEffects(
                    strength: effectsRaw["strength"] as? Int ?? 0,
                    coins: effectsRaw["coins"] as? Int ?? 0,
                    abilities: effectsRaw["abilities"] as? Int ?? 0,
                    boardMove: effectsRaw["boardMove"] as? Int ?? 0,
                    blockRounds: effectsRaw["blockRounds"] as? Int ?? 0,
                    health: effectsRaw["health"] as? Int ?? 0,
                    mana: effectsRaw["mana"] as? Int ?? 0
                )

                return CampaignChoice(
                    text: text,
                    advantage: advantage,
                    disadvantage: disadvantage,
                    effects: effects
                )
            }
        }.filter { !$0.isEmpty }
    }

    private func extractJSON(from text: String) -> String? {
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"), start <= end else {
            return nil
        }
        return String(text[start...end])
    }
}
