//
//  AbilityEffectResolver.swift
//  BoardCore
//

import Foundation

struct AbilityEffectResolution: Equatable {
    let effects: CampaignChoiceEffects
    let summary: String
    let source: String
}

enum AbilityEffectResolver {
    /// Szybka interpretacja opisu (Algorytm Mistrza — słowa kluczowe).
    static func resolveWithMaster(description: String, abilityName: String) -> AbilityEffectResolution {
        let effects = MasterAlgorithmEngine.parseAbilityEffects(from: description)
        let summary = MasterAlgorithmEngine.describeAbilityEffects(effects, abilityName: abilityName)
        return AbilityEffectResolution(
            effects: effects,
            summary: summary,
            source: "Algorytm Mistrza"
        )
    }

    /// Interpretacja przez Llama 7B (JSON ze skutkami).
    static func resolveWithLLM(
        description: String,
        abilityName: String,
        elementCategory: String,
        llm: CampaignLLMService
    ) async -> AbilityEffectResolution? {
        let prompt = """
        Zdolność RPG: "\(abilityName)" (żywioł: \(elementCategory)).
        Opis działania: \(description)

        Na podstawie opisu określ skutki w grze. Zwróć WYŁĄCZNIE JSON (bez markdown):
        {"strength":0,"coins":0,"abilities":0,"health":0,"mana":0,"boardMove":0,"blockRounds":0}
        Użyj liczb całkowych (-30..30 dla statów, 0 jeśli brak skutku).
        """
        do {
            let raw = try await llm.generateText(
                prompt: prompt,
                systemPrompt: "Jesteś silnikiem skutków zdolności RPG. Odpowiadasz wyłącznie poprawnym JSON.",
                maxTokens: 180
            )
            guard let effects = parseEffectsJSON(from: raw) else { return nil }
            let summary = MasterAlgorithmEngine.describeAbilityEffects(effects, abilityName: abilityName)
            return AbilityEffectResolution(
                effects: effects,
                summary: summary,
                source: "Llama 7B"
            )
        } catch {
            return nil
        }
    }

    /// Mistrz + opcjonalnie Llama; przy braku LLM tylko heurystyka.
    static func resolve(
        ability: CreatedAbility,
        llm: CampaignLLMService?
    ) async -> AbilityEffectResolution {
        let master = resolveWithMaster(description: ability.effectDescription, abilityName: ability.name)
        guard let llm, llm.isReady else { return master }

        if let llmResult = await resolveWithLLM(
            description: ability.effectDescription,
            abilityName: ability.name,
            elementCategory: ability.elementCategory,
            llm: llm
        ), !llmResult.effects.isEmpty {
            return AbilityEffectResolution(
                effects: mergeEffects(master: master.effects, llm: llmResult.effects),
                summary: llmResult.summary,
                source: "Llama 7B + Mistrz"
            )
        }
        return master
    }

    private static func mergeEffects(
        master: CampaignChoiceEffects,
        llm: CampaignChoiceEffects
    ) -> CampaignChoiceEffects {
        var merged = llm
        if merged.isEmpty { merged = master }
        if merged.strength == 0, master.strength != 0 { merged.strength = master.strength }
        if merged.health == 0, master.health != 0 { merged.health = master.health }
        if merged.coins == 0, master.coins != 0 { merged.coins = master.coins }
        if merged.abilities == 0, master.abilities != 0 { merged.abilities = master.abilities }
        if merged.mana == 0, master.mana != 0 { merged.mana = master.mana }
        return merged
    }

    private static func parseEffectsJSON(from raw: String) -> CampaignChoiceEffects? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let jsonStart = trimmed.firstIndex(of: "{")
        let jsonEnd = trimmed.lastIndex(of: "}")
        guard let jsonStart, let jsonEnd, jsonStart < jsonEnd else { return nil }
        let slice = String(trimmed[jsonStart...jsonEnd])
        guard let data = slice.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        return CampaignChoiceEffects(
            strength: intValue(object["strength"]),
            coins: intValue(object["coins"]),
            abilities: intValue(object["abilities"]),
            boardMove: intValue(object["boardMove"]),
            blockRounds: intValue(object["blockRounds"]),
            health: intValue(object["health"]),
            mana: intValue(object["mana"])
        )
    }

    private static func intValue(_ value: Any?) -> Int {
        if let int = value as? Int { return int }
        if let double = value as? Double { return Int(double) }
        if let string = value as? String { return Int(string) ?? 0 }
        return 0
    }
}

enum PlayerAbilityGranting {
    /// Losuje zdolność z katalogu kreatora (nie duplikuje już przyznanych).
    static func grantRandom(
        catalog: [CreatedAbility],
        existingIDs: [UUID]
    ) -> CreatedAbility? {
        let available = catalog.filter { !existingIDs.contains($0.id) }
        return (available.isEmpty ? catalog : available).randomElement()
    }
}
