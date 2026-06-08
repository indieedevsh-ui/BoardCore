//
//  QRGameEventCode.swift
//  BoardCore
//

import Foundation

/// Kody QR zdarzeń w rozgrywce (zakres 2001–2007).
/// W generatorze QR wpisz sam numer, np. `2001`.
enum QRGameEventCode: String, CaseIterable, Identifiable {
    case startField = "2001"
    case artifact = "2002"
    case bossFight = "2003"
    case shop = "2004"
    case specialCard = "2005"
    case arenaPvP = "2006"
    case xpShop = "2007"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .startField: "Pole start"
        case .artifact: "Artefakt"
        case .bossFight: "Walka z bossem"
        case .shop: "Sklepik handlowy"
        case .specialCard: "Karta specjalna"
        case .arenaPvP: "Arena PvP"
        case .xpShop: "Sklepik XP"
        }
    }

    var icon: String {
        switch self {
        case .startField: "flag.checkered"
        case .artifact: "sparkles"
        case .bossFight: "shield.lefthalf.filled"
        case .shop: "cart.fill"
        case .specialCard: "rectangle.on.rectangle.angled"
        case .arenaPvP: "figure.boxing"
        case .xpShop: "star.circle.fill"
        }
    }

    var effectDescription: String {
        switch self {
        case .startField:
            "Pole start — bezpieczna strefa. Odnawiasz siły i możesz zaplanować następny ruch."
        case .artifact:
            "Artefakt — losowa nagroda. Pędzel: +5% / +10% / +15% szansy na zdolność (cena 1–100 / 100–150 / 150–200 monet)."
        case .bossFight:
            "Walka z bossem — rozpoczyna się starcie z potężnym przeciwnikiem tej sceny."
        case .shop:
            "Sklepik handlowy — kupuj i sprzedawaj przedmioty z kreatora."
        case .specialCard:
            "Karta specjalna — losujesz efekt pozytywny lub negatywny z puli 20 kart."
        case .arenaPvP:
            "Arena PvP — skan AR dwóch graczy (4001–4004), walka na energię (zdrowie × 2,5)."
        case .xpShop:
            "Sklepik XP — wydaj punkty doświadczenia na losową zdolność lub zakład 50 na 50."
        }
    }

    static func fromScannedCode(_ raw: String) -> QRGameEventCode? {
        QRCodeParser.normalizedID(from: raw).flatMap { QRGameEventCode(rawValue: $0) }
            ?? aliasMatch(QRCodeParser.normalizedAlias(from: raw))
    }

    private static func aliasMatch(_ alias: String) -> QRGameEventCode? {
        switch alias {
        case "START", "POLESTART", "POLE-START", "POLE_START": return .startField
        case "ARTEFAKT", "ARTIFACT", "ITEM": return .artifact
        case "BOSS", "WALKABOSSEM", "WALKA-BOSSEM": return .bossFight
        case "SKLEP", "SHOP", "HANDLOWY", "SKLEPIK": return .shop
        case "KARTA", "SPECIAL", "KARTA-SPECJALNA", "SPECIALCARD": return .specialCard
        case "ARENA", "PVP", "ARENAPVP", "ARENA-PVP": return .arenaPvP
        case "SKLEPIKXP", "XPSHOP", "XP-SHOP", "SKLEPXP": return .xpShop
        default: return nil
        }
    }
}

enum QRCodeParser {
    enum Parsed {
        case character(QRCharacterCode)
        case gameEvent(QRGameEventCode)
        case unknown(String)
    }

    static func parse(_ raw: String) -> Parsed {
        let id = normalizedID(from: raw)
        let alias = normalizedAlias(from: raw)

        if let id, let character = QRCharacterCode(rawValue: id) {
            return .character(character)
        }
        if let id, let event = QRGameEventCode(rawValue: id) {
            return .gameEvent(event)
        }
        if let character = QRCharacterCode.fromScannedCode(raw) {
            return .character(character)
        }
        if let event = QRGameEventCode.fromScannedCode(raw) {
            return .gameEvent(event)
        }
        if let match = matchCharacterAlias(alias) {
            return .character(match)
        }
        return .unknown(raw.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    static func normalizedID(from raw: String) -> String? {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        for prefix in ["DMD:", "DMD-", "FISZKI:", "FISZKI-", "GRA:", "GRA-", "EVENT:", "EVENT-"] {
            if value.hasPrefix(prefix) {
                value = String(value.dropFirst(prefix.count))
            }
        }
        let digits = value.filter(\.isNumber)
        guard !digits.isEmpty else { return nil }
        return digits
    }

    static func normalizedAlias(from raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
    }

    private static func matchCharacterAlias(_ alias: String) -> QRCharacterCode? {
        switch alias {
        case "MAG", "MAGE": return .mage
        case "ELF": return .elf
        case "RYCERZ", "KNIGHT": return .knight
        case "ORK", "ORC": return .orc
        default: return nil
        }
    }
}
