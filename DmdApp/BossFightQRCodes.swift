//
//  BossFightQRCodes.swift
//  DmdApp
//

import Foundation

/// Kody akcji w walce z bossem (9101–9102).
enum BossFightCombatQRCode: String, CaseIterable, Identifiable {
    case attack = "9101"
    case defense = "9102"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .attack: "Atak"
        case .defense: "Obrona"
        }
    }

    var icon: String {
        switch self {
        case .attack: "bolt.fill"
        case .defense: "shield.lefthalf.filled"
        }
    }

    static func parse(_ raw: String) -> BossFightCombatQRCode? {
        if let id = QRCodeParser.normalizedID(from: raw),
           let code = BossFightCombatQRCode(rawValue: id) {
            return code
        }

        let alias = QRCodeParser.normalizedAlias(from: raw)
        switch alias {
        case "9101", "ATAK", "ATTACK", "ATK":
            return .attack
        case "9102", "OBRONA", "DEFENSE", "DEFEND", "DEF":
            return .defense
        default:
            break
        }

        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if trimmed == "DMD://9101" || trimmed == "DMD:9101" { return .attack }
        if trimmed == "DMD://9102" || trimmed == "DMD:9102" { return .defense }
        return nil
    }
}

enum BossFightScanParser {
    static func parseAbility(
        _ raw: String,
        pool: GameplaySessionAbilityPoolState,
        playerID: UUID
    ) -> GameplaySessionAbility? {
        guard let id = QRCodeParser.normalizedID(from: raw) else { return nil }
        return pool.abilities.first { ability in
            ability.numericId == id
                && pool.availability[ability.id] == .held(by: playerID)
        }
    }
}
