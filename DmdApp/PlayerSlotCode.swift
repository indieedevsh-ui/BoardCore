//
//  PlayerSlotCode.swift
//  DmdApp
//

import Foundation

/// Sloty lobby graczy 1–4. Każdy ma własny kod QR (4001–4004).
enum PlayerSlotCode: Int, CaseIterable, Identifiable {
    case player1 = 1
    case player2 = 2
    case player3 = 3
    case player4 = 4

    var id: Int { rawValue }

    var displayName: String { "Gracz \(rawValue)" }

    var qrID: String { String(4_000 + rawValue) }

    static func fromScannedCode(_ raw: String) -> PlayerSlotCode? {
        if let id = QRCodeParser.normalizedID(from: raw), let slot = fromNumericID(id) {
            return slot
        }

        let alias = QRCodeParser.normalizedAlias(from: raw)
        switch alias {
        case "GRACZ1", "PLAYER1": return .player1
        case "GRACZ2", "PLAYER2": return .player2
        case "GRACZ3", "PLAYER3": return .player3
        case "GRACZ4", "PLAYER4": return .player4
        default:
            break
        }

        if alias.hasPrefix("GRACZ"), let last = alias.last, let number = Int(String(last)), (1...4).contains(number) {
            return PlayerSlotCode(rawValue: number)
        }
        if alias.hasPrefix("PLAYER"), let last = alias.last, let number = Int(String(last)), (1...4).contains(number) {
            return PlayerSlotCode(rawValue: number)
        }

        return nil
    }

    private static func fromNumericID(_ id: String) -> PlayerSlotCode? {
        guard id.hasPrefix("400"), let value = Int(id), (4_001...4_004).contains(value) else {
            return nil
        }
        return PlayerSlotCode(rawValue: value - 4_000)
    }
}
