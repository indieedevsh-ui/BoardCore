//
//  MasterLlamaCollaboration.swift
//  DmdApp
//
//  Wspólna interpretacja: Algorytm Mistrza (struktura + dopasowanie) + Llama 7B (narracja).
//

import Foundation

enum MasterLlamaCollaboration {
    static let llamaSystemPrompt = """
    Jesteś Mistrzem Gry RPG po polsku. Dostajesz ustrukturyzowany kontekst z Algorytmu Mistrza \
    (sceny, decyzje, zalety, wady, skutki statystyk) oraz tekst kampanii z ChatGPT.
    Interpretuj wiernie materiał źródłowy. Nie wymyślaj nowych postaci ani scen spoza kontekstu.
    Pisz zwięźle, dramatycznie, 4–8 zdań.
    """

    /// Parser jest źródłem prawdy dla liczby scen i decyzji — Llama tylko uzupełnia, nigdy nie usuwa.
    static func mergeCampaign(parser: ParsedCampaign, llm: ParsedCampaign) -> ParsedCampaign {
        var merged = parser

        if merged.title == "Kampania bez tytułu", !llm.title.isEmpty {
            merged.title = llm.title
        }
        if merged.storyOutline.isEmpty, !llm.storyOutline.isEmpty {
            merged.storyOutline = llm.storyOutline
        } else if llm.storyOutline.count > merged.storyOutline.count {
            merged.storyOutline = llm.storyOutline
        }

        merged.scenes = mergeScenes(parser: parser.scenes, llm: llm.scenes)
        merged.decisions = mergeDecisions(parser: parser.decisions, llm: llm.decisions)

        return merged
    }

    static func resolvedPreview(parser: ParsedCampaign, llm: ParsedCampaign?) -> ParsedCampaign {
        guard let llm else { return parser }
        return mergeCampaign(parser: parser, llm: llm)
    }

    private static func mergeScenes(parser: [CampaignScene], llm: [CampaignScene]) -> [CampaignScene] {
        guard !parser.isEmpty else { return llm }
        guard llm.count > parser.count else { return parser }

        var merged = parser
        let parserTitles = Set(parser.map { normalizeKey($0.title) })
        for scene in llm where !parserTitles.contains(normalizeKey(scene.title)) {
            merged.append(scene)
        }
        return merged
    }

    private static func mergeDecisions(parser: [CampaignDecision], llm: [CampaignDecision]) -> [CampaignDecision] {
        guard !parser.isEmpty else { return llm }
        if llm.isEmpty || llm.count <= parser.count { return parser }

        var merged = parser
        let parserKeys = Set(parser.map { normalizeKey($0.sceneTitle) + "|" + normalizeKey($0.question) })
        for decision in llm {
            let key = normalizeKey(decision.sceneTitle) + "|" + normalizeKey(decision.question)
            if parserKeys.contains(key) { continue }
            merged.append(decision)
        }
        return merged.sorted { $0.sceneTitle < $1.sceneTitle }
    }

    private static func normalizeKey(_ text: String) -> String {
        text.lowercased()
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pl_PL"))
            .replacingOccurrences(of: " ", with: "")
    }

    static func buildOutlineEnrichmentPrompt(
        rawText: String,
        parserResult: ParsedCampaign
    ) -> String {
        let clipped = clip(rawText, max: 4500)
        return """
        Uzupełnij WYŁĄCZNIE pole storyOutline kampanii RPG (1 akapit po polsku).
        Nie zmieniaj liczby scen (\(parserResult.scenes.count)) ani decyzji (\(parserResult.decisions.count)).

        Tytuł: \(parserResult.title)
        Obecny zarys: \(parserResult.storyOutline.prefix(600))

        Tekst kampanii:
        <<<
        \(clipped)
        >>>

        Zarys fabularny:
        """
    }

    static func buildAnalysisPrompt(
        rawText: String,
        parserResult: ParsedCampaign,
        masterBrief: String
    ) -> String {
        let clipped = clip(rawText, max: 5000)
        return """
        Algorytm Mistrza sparsował kampanię z ChatGPT. Zweryfikuj strukturę JSON.
        WAŻNE: w tablicy "decisions" musi być DOKŁADNIE \(parserResult.decisions.count) elementów (parser już je wykrył).
        Nie łącz decyzji w jedną — każda * [DECYZJA N | SCENA M] * to osobny wpis.

        WYNIK PARSERA (źródło prawdy):
        - Tytuł: \(parserResult.title)
        - Sceny: \(parserResult.scenes.count)
        - Decyzje: \(parserResult.decisions.count)
        \(parserResult.decisions.enumerated().map { "  Decyzja \($0.offset + 1): [\($0.element.sceneTitle)]" }.joined(separator: "\n"))

        INDEKS MISTRZA:
        \(masterBrief)

        Zwróć WYŁĄCZNIE poprawny JSON:
        {
          "title": "...",
          "storyOutline": "...",
          "decisions": [ \(parserResult.decisions.count) obiektów ],
          "scenes": [ \(parserResult.scenes.count) obiektów ]
        }

        TEKST KAMPANII:
        <<<
        \(clipped)
        >>>

        JSON:
        """
    }

    static func buildGameplayPrompt(
        campaign: ParsedCampaign,
        masterBrief: String,
        masterNarrative: String,
        sceneIndex: Int,
        decisionIndex: Int?,
        players: [PlayerCharacter],
        selectedChoices: [UUID: String],
        recommendations: [UUID: MasterChoiceRecommendation]
    ) -> String {
        let decisionIdx = decisionIndex ?? sceneIndex
        var parts: [String] = [
            "Kampania: \(campaign.title)",
            "KONTEKST ALGORYTMU MISTRZA:",
            masterBrief,
            "",
            "ANALIZA MISTRZA (dopasowanie wyborów, skutki):",
            masterNarrative,
        ]

        if let decision = campaign.decisions[safe: decisionIdx] {
            parts.append("\nAKTUALNA DECYZJA (\(decision.sceneTitle)): \(decision.question)")
            for (slot, player) in players.enumerated() {
                parts.append("\n\(player.className) — opcje:")
                let details = decision.choiceDetailsByPlayer[safe: slot] ?? []
                if details.isEmpty {
                    for (i, text) in decision.choiceTexts(forPlayerIndex: slot).enumerated() {
                        parts.append("  \(i + 1). \(text)")
                    }
                } else {
                    for (i, choice) in details.enumerated() {
                        var line = "  \(i + 1). \(choice.text)"
                        if !choice.advantage.isEmpty { line += " | Zaleta: \(choice.advantage)" }
                        if !choice.disadvantage.isEmpty { line += " | Wada: \(choice.disadvantage)" }
                        if !choice.effects.isEmpty {
                            line += " | Skutki: \(choice.effects.summaryTokens.joined(separator: ", "))"
                        }
                        parts.append(line)
                    }
                }
                if let text = selectedChoices[player.id] {
                    parts.append("  → WYBRANO: \(text)")
                } else if let rec = recommendations[player.id] {
                    parts.append("  → Rekomendacja Mistrza [\(rec.confidencePercent)%]: \(rec.choiceText)")
                }
            }
        }

        parts.append("\nNapisz interpretację bieżącej chwili rozgrywki po polsku (4–8 zdań). Uwzględnij skutki wyborów i napięcie fabularne.")
        return parts.joined(separator: "\n")
    }

    private static func clip(_ text: String, max: Int) -> String {
        guard text.count > max, let index = text.index(text.startIndex, offsetBy: max, limitedBy: text.endIndex) else {
            return text
        }
        return String(text[..<index]) + "\n...[ucięto]"
    }
}

extension MasterAlgorithmEngine {
    func campaignStructureBrief(for campaign: ParsedCampaign) -> String {
        var lines: [String] = []

        if !campaign.storyOutline.isEmpty {
            lines.append("Zarys: \(campaign.storyOutline.prefix(1200))")
        }

        lines.append("Sceny (\(campaign.scenes.count)):")
        for (index, scene) in campaign.scenes.enumerated() {
            lines.append("  \(index + 1). \(scene.title) — \(scene.narrative.prefix(320))")
        }

        lines.append("Decyzje (\(campaign.decisions.count)):")
        for (index, decision) in campaign.decisions.enumerated() {
            lines.append("  \(index + 1). [\(decision.sceneTitle)] \(decision.question.prefix(220))")
            for (playerIndex, details) in decision.choiceDetailsByPlayer.enumerated() {
                let sample = details.prefix(2).map(\.text).joined(separator: "; ")
                let extra = details.count > 2 ? "… (+\(details.count - 2))" : ""
                lines.append("     Gracz \(playerIndex + 1): \(sample)\(extra)")
            }
        }

        if let index {
            lines.append("Indeks słów kluczowych: \(index.vocabularySize)")
        }

        return lines.joined(separator: "\n")
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
