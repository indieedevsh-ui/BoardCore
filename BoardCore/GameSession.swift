//
//  GameSession.swift
//  BoardCore
//

import Foundation
import Observation

@Observable
final class GameSession {
    var players: [PlayerCharacter] = []

    var canStartGame: Bool {
        players.count >= 2
    }

    func addPlayer(_ player: PlayerCharacter) {
        players.append(player)
    }

    func addOrReplacePlayer(fromSlot slotNumber: Int, player: PlayerCharacter) {
        players.removeAll { $0.lobbySlotNumber == slotNumber }
        players.append(player)
    }

    func removePlayer(id: UUID) {
        players.removeAll { $0.id == id }
    }

    func reset() {
        players.removeAll()
    }
}
