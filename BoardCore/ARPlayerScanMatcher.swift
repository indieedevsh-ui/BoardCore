//
//  ARPlayerScanMatcher.swift
//  BoardCore
//

import Foundation

enum ARPlayerScanMatcher {
    /// Rozpoznaje kody graczy 4001–4004 / „gracz 1–4” w trybie AR.
    static func lobbySlot(from payload: String) -> PlayerSlotCode? {
        PlayerSlotCode.fromScannedCode(payload)
    }

    /// Rozpoznaje kody graczy 4001–4004 / „gracz 1–4” w trybie AR (z dopasowaniem do listy graczy).
    static func lobbyPlayer(for payload: String, in players: [PlayerCharacter]) -> PlayerCharacter? {
        guard let slot = PlayerSlotCode.fromScannedCode(payload) else { return nil }
        return players.first { $0.lobbySlotNumber == slot.rawValue }
    }

    /// Rozpoznaje skan w trybie AR: kody graczy 4001–4004 / „gracz 1–4”, kody postaci 6001–6004 oraz legacy QR postaci.
    static func player(for payload: String, in players: [PlayerCharacter]) -> PlayerCharacter? {
        if let slot = PlayerSlotCode.fromScannedCode(payload) {
            if let match = players.first(where: { $0.lobbySlotNumber == slot.rawValue }) {
                return match
            }
        }

        if let slot = SlotCharacterQR.slot(fromScannedCode: payload) {
            if let match = players.first(where: { $0.lobbySlotNumber == slot }) {
                return match
            }
        }

        if case .character(let code) = QRCodeParser.parse(payload) {
            if let match = players.first(where: { $0.qrCode == code.rawValue }) {
                return match
            }
        }

        if let id = QRCodeParser.normalizedID(from: payload) {
            if let match = players.first(where: { $0.qrCode == id }) {
                return match
            }
        }

        return nil
    }
}
