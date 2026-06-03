//
//  SlotCharacterModels.swift
//  DmdApp
//

import Foundation
import SwiftUI
import UIKit

/// Kod QR postaci przypisanej do slotu lobby (6001–6004).
enum SlotCharacterQR {
    static func code(for slot: Int) -> String {
        String(6_000 + slot)
    }

    static func slot(fromScannedCode raw: String) -> Int? {
        guard let id = QRCodeParser.normalizedID(from: raw),
              let value = Int(id),
              (6_001...6_004).contains(value)
        else { return nil }
        return value - 6_000
    }
}

/// Kolor poświaty tła podczas tury gracza.
struct PlayerGlowColor: Codable, Hashable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var opacity: Double

    static let legacyGlowSentinel: Double = -1

    var swiftUIColor: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }

    var animationKey: String {
        "\(red)-\(green)-\(blue)-\(opacity)"
    }

    var accentColor: Color {
        AppSettings.buttonTint(fromGlow: swiftUIColor)
    }

    /// Kolor gracza z zapisu postaci, slotu lobby lub ustawień aplikacji.
    static func resolve(
        storedGlow: PlayerGlowColor?,
        lobbySlotNumber: Int?,
        slotStore: PlayerSlotStore,
        settings: AppSettings
    ) -> PlayerGlowColor {
        if let storedGlow {
            return storedGlow
        }
        if let slot = lobbySlotNumber,
           let record = slotStore.characterRecord(for: slot) {
            return record.needsSlotDefaultGlow
                ? defaultForSlot(slot)
                : record.glowColor
        }
        if let slot = lobbySlotNumber {
            return defaultForSlot(slot)
        }
        return fromSettings(settings)
    }

    init(red: Double, green: Double, blue: Double, opacity: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.opacity = max(AppSettings.minimumBackgroundOpacity, opacity)
    }

    static func defaultForSlot(_ slot: Int) -> PlayerGlowColor {
        switch slot {
        case 1:
            return PlayerGlowColor(red: 0.22, green: 0.48, blue: 0.95, opacity: 1)
        case 2:
            return PlayerGlowColor(red: 0.62, green: 0.28, blue: 0.92, opacity: 1)
        case 3:
            return PlayerGlowColor(red: 0.95, green: 0.52, blue: 0.18, opacity: 1)
        case 4:
            return PlayerGlowColor(red: 0.18, green: 0.78, blue: 0.48, opacity: 1)
        default:
            return PlayerGlowColor(red: 0.35, green: 0.55, blue: 0.95, opacity: 1)
        }
    }

    static func fromSettings(_ settings: AppSettings) -> PlayerGlowColor {
        PlayerGlowColor(
            red: settings.backgroundRed,
            green: settings.backgroundGreen,
            blue: settings.backgroundBlue,
            opacity: settings.backgroundOpacity
        )
    }

    mutating func applySwiftUIColor(_ color: Color) {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        if uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            self = PlayerGlowColor(
                red: Double(red),
                green: Double(green),
                blue: Double(blue),
                opacity: Double(alpha)
            )
            return
        }

        guard
            let rgb = uiColor.cgColor.converted(
                to: CGColorSpaceCreateDeviceRGB(),
                intent: .defaultIntent,
                options: nil
            )?.components
        else { return }

        switch rgb.count {
        case 2:
            self = PlayerGlowColor(
                red: Double(rgb[0]),
                green: Double(rgb[0]),
                blue: Double(rgb[0]),
                opacity: Double(rgb[1])
            )
        default:
            self = PlayerGlowColor(
                red: Double(rgb[0]),
                green: Double(rgb[1]),
                blue: Double(rgb[2]),
                opacity: Double(rgb.count > 3 ? rgb[3] : 1)
            )
        }
    }

    var needsSlotDefaultGlow: Bool {
        red == Self.legacyGlowSentinel
    }
}

enum SlotCharacterAppearanceKind: String, Codable {
    case photo
    case icon
}

struct SlotCharacterRecord: Codable, Hashable {
    var name: String
    var advantage: String
    var flaw: String
    var appearanceKind: SlotCharacterAppearanceKind
    var profileIconID: String?
    var imageFileName: String?
    var glowRed: Double
    var glowGreen: Double
    var glowBlue: Double
    var glowOpacity: Double

    var glowColor: PlayerGlowColor {
        get {
            PlayerGlowColor(red: glowRed, green: glowGreen, blue: glowBlue, opacity: glowOpacity)
        }
        set {
            glowRed = newValue.red
            glowGreen = newValue.green
            glowBlue = newValue.blue
            glowOpacity = newValue.opacity
        }
    }

    var qrCode: String {
        get { _qrCode ?? "" }
        set { _qrCode = newValue }
    }

    private var _qrCode: String?

    var profileIcon: PlayerProfileIcon? {
        PlayerProfileIcon.from(id: profileIconID)
    }

    var usesPhoto: Bool {
        appearanceKind == .photo && imageFileName != nil
    }

    var usesIcon: Bool {
        appearanceKind == .icon && profileIcon != nil
    }

    init(
        name: String,
        advantage: String = "",
        flaw: String = "",
        appearanceKind: SlotCharacterAppearanceKind = .icon,
        profileIconID: String? = nil,
        imageFileName: String? = nil,
        qrCode: String = "",
        glowColor: PlayerGlowColor? = nil
    ) {
        self.name = name
        self.advantage = advantage
        self.flaw = flaw
        self.appearanceKind = appearanceKind
        self.profileIconID = profileIconID
        self.imageFileName = imageFileName
        self._qrCode = qrCode.isEmpty ? nil : qrCode
        let glow = glowColor ?? PlayerGlowColor(
            red: PlayerGlowColor.legacyGlowSentinel,
            green: 0,
            blue: 0,
            opacity: 1
        )
        glowRed = glow.red
        glowGreen = glow.green
        glowBlue = glow.blue
        glowOpacity = glow.opacity
    }

    enum CodingKeys: String, CodingKey {
        case name, advantage, flaw, appearanceKind, profileIconID, imageFileName, qrCode
        case glowRed, glowGreen, glowBlue, glowOpacity
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        advantage = try container.decode(String.self, forKey: .advantage)
        flaw = try container.decode(String.self, forKey: .flaw)
        imageFileName = try container.decodeIfPresent(String.self, forKey: .imageFileName)
        _qrCode = try container.decodeIfPresent(String.self, forKey: .qrCode)
        if let kind = try container.decodeIfPresent(SlotCharacterAppearanceKind.self, forKey: .appearanceKind) {
            appearanceKind = kind
            profileIconID = try container.decodeIfPresent(String.self, forKey: .profileIconID)
        } else if imageFileName != nil {
            appearanceKind = .photo
            profileIconID = nil
        } else {
            appearanceKind = .icon
            profileIconID = nil
        }
        if let red = try container.decodeIfPresent(Double.self, forKey: .glowRed) {
            glowRed = red
            glowGreen = try container.decode(Double.self, forKey: .glowGreen)
            glowBlue = try container.decode(Double.self, forKey: .glowBlue)
            glowOpacity = try container.decode(Double.self, forKey: .glowOpacity)
        } else {
            glowRed = PlayerGlowColor.legacyGlowSentinel
            glowGreen = 0
            glowBlue = 0
            glowOpacity = 1
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(advantage, forKey: .advantage)
        try container.encode(flaw, forKey: .flaw)
        try container.encode(appearanceKind, forKey: .appearanceKind)
        try container.encodeIfPresent(profileIconID, forKey: .profileIconID)
        try container.encodeIfPresent(imageFileName, forKey: .imageFileName)
        try container.encodeIfPresent(_qrCode, forKey: .qrCode)
        guard !needsSlotDefaultGlow else { return }
        try container.encode(glowRed, forKey: .glowRed)
        try container.encode(glowGreen, forKey: .glowGreen)
        try container.encode(glowBlue, forKey: .glowBlue)
        try container.encode(glowOpacity, forKey: .glowOpacity)
    }

    var needsSlotDefaultGlow: Bool {
        glowColor.needsSlotDefaultGlow
    }

    mutating func applyDefaultGlow(forSlot slot: Int) {
        glowColor = PlayerGlowColor.defaultForSlot(slot)
    }
}

enum CharacterTraitStats {
    static let fixedHealth = 100
    static let fixedFinances = 100
    static let lobbyBaselineStrength = PlayerRuntimeStats.startingStrength
    static let lobbyBaselineAbilities = 0

    static func strength(advantage: String, flaw: String) -> Int {
        guard !advantage.isEmpty, !flaw.isEmpty else {
            return lobbyBaselineStrength
        }
        var value = PlayerRuntimeStats.startingStrength
        value += advantageStrengthBonus[advantage] ?? 0
        value -= flawStrengthPenalty[flaw] ?? 0
        return clamp(value)
    }

    /// Mana / zdolność do posługiwania się mocami.
    static func abilities(advantage: String, flaw: String) -> Int {
        guard !advantage.isEmpty, !flaw.isEmpty else {
            return lobbyBaselineAbilities
        }
        var value = 50
        value += advantageAbilityBonus[advantage] ?? 0
        value -= flawAbilityPenalty[flaw] ?? 0
        return clamp(value)
    }

    static func isStrongAbility(_ abilityName: String) -> Bool {
        let lowered = abilityName.lowercased()
        return lowered.contains("potężn") || lowered.contains("mocn") || lowered.contains("wielk")
            || lowered.contains("siln") || lowered.contains("epic") || lowered.contains("ultimate")
    }

    static func abilityEffectTurns(for abilityName: String) -> Int {
        isStrongAbility(abilityName) ? 5 : 2
    }

    static func abilityPowerRange(for abilityName: String) -> ClosedRange<Int> {
        isStrongAbility(abilityName) ? 70...100 : 30...50
    }

    static func scaledAbilityEffects(
        _ base: CampaignChoiceEffects,
        abilityName: String,
        playerAbilityStat: Int
    ) -> (effects: CampaignChoiceEffects, powerPercent: Int, effectTurns: Int) {
        let powerPercent = Int.random(in: abilityPowerRange(for: abilityName))
        let scale = Double(powerPercent) / 100.0 * Double(max(playerAbilityStat, 1)) / 100.0
        let turns = abilityEffectTurns(for: abilityName)

        var effects = base
        effects.strength = Int(Double(base.strength) * scale)
        effects.coins = Int(Double(base.coins) * scale)
        effects.abilities = Int(Double(base.abilities) * scale)
        effects.health = Int(Double(base.health) * scale)
        effects.mana = Int(Double(base.mana) * scale)
        effects.boardMove = Int(Double(base.boardMove) * scale)
        effects.blockRounds = effects.blockRounds == 0 ? turns : min(effects.blockRounds, turns)

        return (effects, powerPercent, turns)
    }

    private static let advantageStrengthBonus: [String: Int] = [
        "Wysoka siła": 30,
        "Zwinność": 12,
        "Inteligencja": 5,
        "Magia": 5,
        "Odporność na magię": 10,
        "Leczenie": 8,
        "Trafienia krytyczne": 18,
        "Wysoka wytrzymałość": 22,
    ]

    private static let flawStrengthPenalty: [String: Int] = [
        "Niska wytrzymałość": 12,
        "Słaba obrona": 8,
        "Brak magii": 5,
        "Niska mobilność": 10,
        "Słaba magia": 5,
        "Krucha budowa": 18,
        "Niska inteligencja": 5,
        "Słaby w walce wręcz": 22,
    ]

    private static let advantageAbilityBonus: [String: Int] = [
        "Wysoka siła": 5,
        "Zwinność": 10,
        "Inteligencja": 25,
        "Magia": 30,
        "Odporność na magię": 18,
        "Leczenie": 22,
        "Trafienia krytyczne": 12,
        "Wysoka wytrzymałość": 8,
    ]

    private static let flawAbilityPenalty: [String: Int] = [
        "Niska wytrzymałość": 8,
        "Słaba obrona": 5,
        "Brak magii": 28,
        "Niska mobilność": 8,
        "Słaba magia": 25,
        "Krucha budowa": 10,
        "Niska inteligencja": 22,
        "Słaby w walce wręcz": 8,
    ]

    private static func clamp(_ value: Int) -> Int {
        min(100, max(0, value))
    }
}
