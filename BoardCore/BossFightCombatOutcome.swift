//
//  BossFightCombatOutcome.swift
//  BoardCore
//

import Foundation

struct BossFightCombatOutcome: Equatable {
    let victory: Bool
    let mainPlayerID: UUID
    let supporterIDs: [UUID]
    let mainPlayerFinalHealth: Int
    let bossDifficulty: BossDifficulty
}

struct BossFightSupportJoinPresentation: Identifiable, Equatable {
    let id = UUID()
    let playerName: String
    let addedHealth: Int
    let addedStrength: Int
    let addedArmor: Int
}
