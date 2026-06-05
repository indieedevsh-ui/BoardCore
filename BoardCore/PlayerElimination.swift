//
//  PlayerElimination.swift
//  BoardCore
//

import Foundation

enum PlayerElimination {
    static let startingHealth = 100

    /// Dzieli monety wyeliminowanego gracza między pozostałych.
    /// Reszta z dzielenia trafia do słabszych graczy (niższa siła).
    static func distributeLoot(
        amount: Int,
        among players: [PlayerCharacter],
        stats: [UUID: PlayerRuntimeStats]
    ) -> [UUID: Int] {
        guard amount > 0, !players.isEmpty else { return [:] }

        if players.count == 1 {
            return [players[0].id: amount]
        }

        let baseShare = amount / players.count
        var remainder = amount % players.count

        let weakestFirst = players.sorted {
            strength(for: $0.id, in: stats) < strength(for: $1.id, in: stats)
        }

        var shares: [UUID: Int] = [:]
        for player in weakestFirst {
            shares[player.id] = baseShare
        }

        for player in weakestFirst where remainder > 0 {
            shares[player.id, default: 0] += 1
            remainder -= 1
        }

        return shares
    }

    static func lootSummary(
        shares: [UUID: Int],
        players: [PlayerCharacter],
        stats: [UUID: PlayerRuntimeStats]
    ) -> String {
        guard !shares.isEmpty else { return "Brak łupów do podziału." }

        let parts = players.compactMap { player -> String? in
            guard let share = shares[player.id], share > 0 else { return nil }
            return "\(player.displayTitle): +\(share)"
        }
        return parts.joined(separator: " · ")
    }

    private static func strength(for playerID: UUID, in stats: [UUID: PlayerRuntimeStats]) -> Int {
        stats[playerID]?.strength ?? 0
    }
}
