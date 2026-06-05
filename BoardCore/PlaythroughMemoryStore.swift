//
//  PlaythroughMemoryStore.swift
//  BoardCore
//

import Foundation
import Observation

/// Zapamiętuje wybory graczy w trakcie rozgrywki (per kampania, per scena/decyzja).
struct PlaythroughMemory: Codable, Hashable {
    var campaignTitle: String
    /// decisionIndex → playerSlot → choiceIndex (0-based), klucze jako String w JSON
    var selections: [String: [String: Int]]

    init(campaignTitle: String, selections: [String: [String: Int]] = [:]) {
        self.campaignTitle = campaignTitle
        self.selections = selections
    }

    func choiceIndex(decisionIndex: Int, playerSlot: Int) -> Int? {
        selections[String(decisionIndex)]?[String(playerSlot)]
    }

    mutating func record(decisionIndex: Int, playerSlot: Int, choiceIndex: Int) {
        let decisionKey = String(decisionIndex)
        var perDecision = selections[decisionKey] ?? [:]
        perDecision[String(playerSlot)] = choiceIndex
        selections[decisionKey] = perDecision
    }

    var decisionIndices: [Int] {
        selections.keys.compactMap(Int.init).sorted()
    }
}

@MainActor
@Observable
final class PlaythroughMemoryStore {
    private static let storageKey = "playthroughMemory"

    private(set) var memory = PlaythroughMemory(campaignTitle: "")

    func load(for campaign: ParsedCampaign) {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode(PlaythroughMemory.self, from: data),
              decoded.campaignTitle == campaign.title
        else {
            memory = PlaythroughMemory(campaignTitle: campaign.title)
            return
        }
        memory = decoded
    }

    func record(
        campaign: ParsedCampaign,
        decisionIndex: Int,
        playerSlot: Int,
        choiceIndex: Int,
        choiceText: String
    ) {
        if memory.campaignTitle != campaign.title {
            memory = PlaythroughMemory(campaignTitle: campaign.title)
        }
        memory.record(decisionIndex: decisionIndex, playerSlot: playerSlot, choiceIndex: choiceIndex)
        persist()
        _ = choiceText
    }

    func reset(for campaign: ParsedCampaign? = nil) {
        memory = PlaythroughMemory(campaignTitle: campaign?.title ?? "")
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(memory) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}
