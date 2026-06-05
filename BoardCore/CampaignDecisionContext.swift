//
//  CampaignDecisionContext.swift
//  BoardCore
//

import Foundation

struct ContextualizedStartField: Equatable {
    var scene: CampaignScene?
    var decisionQuestion: String
    var choiceLabels: [String]
    var priorInfluenceLines: [String]
}

extension ParsedCampaign {
    func contextualizedStartField(
        playerSceneIndex: Int,
        currentDecisionIndex: Int,
        playerIndex: Int,
        memory: PlaythroughMemory
    ) -> ContextualizedStartField {
        let baseScene = scenes[safe: playerSceneIndex]
        let mappedDecisionIndex = resolvedDecisionIndex(
            forSceneIndex: playerSceneIndex,
            fallback: currentDecisionIndex
        )
        let baseDecision = decisions[safe: mappedDecisionIndex]

        let priorLines = priorPlayerInfluenceLines(
            decisionIndex: mappedDecisionIndex,
            beforePlayer: playerIndex,
            memory: memory
        )

        var narrative = baseScene?.narrative ?? ""
        if !priorLines.isEmpty {
            narrative += "\n\n— Reakcja na działania sojuszników —\n"
            narrative += priorLines.joined(separator: "\n")
        }

        var question = baseDecision?.question ?? ""
        if let latest = priorLines.last {
            question = "W cieniu wcześniejszego wyboru: \(latest)\n\n\(question)"
        }

        let contextualScene: CampaignScene?
        if let baseScene {
            contextualScene = CampaignScene(
                id: baseScene.id,
                title: baseScene.title,
                narrative: narrative,
                sceneTag: baseScene.sceneTag
            )
        } else {
            contextualScene = nil
        }

        let labels = choiceLabels(forPlayerIndex: playerIndex, decisionIndex: mappedDecisionIndex)

        return ContextualizedStartField(
            scene: contextualScene,
            decisionQuestion: question,
            choiceLabels: labels,
            priorInfluenceLines: priorLines
        )
    }

    func priorPlayerInfluenceLines(
        decisionIndex: Int,
        beforePlayer playerIndex: Int,
        memory: PlaythroughMemory
    ) -> [String] {
        guard playerIndex > 0 else { return [] }

        var lines: [String] = []
        for slot in 0..<playerIndex {
            guard let choiceIdx = memory.choiceIndex(decisionIndex: decisionIndex, playerSlot: slot) else {
                continue
            }
            guard let choice = decision(at: decisionIndex)?
                .choiceDetail(forPlayerIndex: slot, choiceIndex: choiceIdx)
            else { continue }

            var line = "Gracz \(slot + 1) wybrał: „\(choice.text)”"
            if !choice.disadvantage.isEmpty {
                line += " — skutek: \(choice.disadvantage)"
            } else if !choice.advantage.isEmpty {
                line += " — korzyść: \(choice.advantage)"
            }
            lines.append(line)
        }
        return lines
    }

    func isAtFinalStoryStep(decisionRound: Int) -> Bool {
        guard !decisions.isEmpty else { return false }
        return decisionRound >= decisions.count - 1
    }

    private func decision(at index: Int) -> CampaignDecision? {
        decisions.indices.contains(index) ? decisions[index] : nil
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
