//
//  PowerUpgradeEffectModels.swift
//  DmdApp
//

import Foundation

/// Obszar wpływu ulepszenia mocy w kreatorze.
enum PowerUpgradeInfluence: String, CaseIterable, Codable, Identifiable, Hashable {
    case board
    case bossFight
    case players
    case gameplay

    var id: String { rawValue }

    var title: String {
        switch self {
        case .board: "Plansza"
        case .bossFight: "Walka z bossem"
        case .players: "Gracze"
        case .gameplay: "Rozgrywka"
        }
    }

    var icon: String {
        switch self {
        case .board: "map.fill"
        case .bossFight: "figure.stand.line.dotted.figure.stand"
        case .players: "person.3.fill"
        case .gameplay: "chart.bar.fill"
        }
    }
}

enum PowerUpgradeBoardMode: String, CaseIterable, Codable, Hashable, Identifiable {
    case moveForward
    case moveBackward
    case anyField

    var id: String { rawValue }

    var title: String {
        switch self {
        case .moveForward: "Do przodu"
        case .moveBackward: "Do tyłu"
        case .anyField: "Dowolne pole"
        }
    }
}

struct PowerUpgradeBoardEffect: Codable, Hashable {
    var mode: PowerUpgradeBoardMode
    var spaces: Int

    static let `default` = PowerUpgradeBoardEffect(mode: .moveForward, spaces: 1)
}

enum PowerUpgradeBlockMoveScope: String, CaseIterable, Codable, Hashable, Identifiable {
    case allPlayers
    case singlePlayer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .allPlayers: "Wszyscy gracze"
        case .singlePlayer: "Jeden gracz"
        }
    }
}

struct PowerUpgradeBossFightEffect: Codable, Hashable {
    var previewBossMoveEnabled: Bool
    var previewEveryTurns: Int
    var previewUsesPerEncounter: Int

    var immortalEnabled: Bool
    var immortalHealthRestore: Int
    var immortalEveryBattles: Int

    static let `default` = PowerUpgradeBossFightEffect(
        previewBossMoveEnabled: false,
        previewEveryTurns: 3,
        previewUsesPerEncounter: 1,
        immortalEnabled: false,
        immortalHealthRestore: 25,
        immortalEveryBattles: 1
    )
}

struct PowerUpgradePlayersEffect: Codable, Hashable {
    var robPlayerEnabled: Bool
    var robPercent: Int
    var robTargetsFinances: Bool
    var robTargetsStrength: Bool
    var robTargetsHealth: Bool

    var blockMoveEnabled: Bool
    var blockMoveTurns: Int
    var blockMoveScope: PowerUpgradeBlockMoveScope

    var removePlayerEnabled: Bool
    var removePlayerCount: Int

    static let `default` = PowerUpgradePlayersEffect(
        robPlayerEnabled: false,
        robPercent: 10,
        robTargetsFinances: true,
        robTargetsStrength: false,
        robTargetsHealth: false,
        blockMoveEnabled: false,
        blockMoveTurns: 1,
        blockMoveScope: .singlePlayer,
        removePlayerEnabled: false,
        removePlayerCount: 1
    )
}

struct PowerUpgradeGameplayEffect: Codable, Hashable {
    var healthBonus: Int
    var strengthBonus: Int
    var coinsBonus: Int
    var xpBonus: Int

    static let `default` = PowerUpgradeGameplayEffect(
        healthBonus: 0,
        strengthBonus: 0,
        coinsBonus: 0,
        xpBonus: 0
    )

    var hasAnyBonus: Bool {
        healthBonus != 0 || strengthBonus != 0 || coinsBonus != 0 || xpBonus != 0
    }

    var summaryLine: String {
        var parts: [String] = []
        if healthBonus != 0 { parts.append("❤️ \(healthBonus > 0 ? "+" : "")\(healthBonus)") }
        if strengthBonus != 0 { parts.append("💪 \(strengthBonus > 0 ? "+" : "")\(strengthBonus)") }
        if coinsBonus != 0 { parts.append("🪙 \(coinsBonus > 0 ? "+" : "")\(coinsBonus)") }
        if xpBonus != 0 { parts.append("✨ \(xpBonus > 0 ? "+" : "")\(xpBonus) XP") }
        return parts.isEmpty ? "Rozgrywka: —" : parts.joined(separator: " · ")
    }
}
