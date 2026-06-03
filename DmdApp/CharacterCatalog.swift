//
//  CharacterCatalog.swift
//  DmdApp
//

import Foundation

enum QRCharacterCode: String, CaseIterable {
    case mage = "1001"
    case elf = "1002"
    case knight = "1003"
    case orc = "1004"

    var className: String {
        switch self {
        case .mage: "Mag"
        case .elf: "Elf"
        case .knight: "Rycerz"
        case .orc: "Ork"
        }
    }

    var advantages: [String] {
        switch self {
        case .mage: ["Wysoka inteligencja", "Magia elementarna"]
        case .elf: ["Zwinność", "Trafienia krytyczne"]
        case .knight: ["Wysoka obrona", "Mistrzostwo w walce"]
        case .orc: ["Ogromna siła", "Wysoka wytrzymałość"]
        }
    }

    var flaws: [String] {
        switch self {
        case .mage: ["Niska wytrzymałość", "Słaba obrona"]
        case .elf: ["Krucha budowa", "Słaby w walce wręcz"]
        case .knight: ["Niska mobilność", "Brak magii"]
        case .orc: ["Niska inteligencja", "Słaba magia"]
        }
    }

    var mainWeapon: String {
        switch self {
        case .mage: "Różdżka magiczna"
        case .elf: "Łuk elficki"
        case .knight: "Miecz dwuręczny"
        case .orc: "Topór bojowy"
        }
    }

    static func fromScannedCode(_ raw: String) -> QRCharacterCode? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.uppercased()
            .replacingOccurrences(of: "FISZKI:", with: "")
            .replacingOccurrences(of: "FISZKI-", with: "")

        if let match = QRCharacterCode(rawValue: normalized) {
            return match
        }

        switch normalized {
        case "MAG", "MAGE": return .mage
        case "ELF": return .elf
        case "RYCERZ", "KNIGHT": return .knight
        case "ORK", "ORC": return .orc
        default: return nil
        }
    }
}

enum CharacterOptions {
    static let advantages = [
        "Wysoka siła",
        "Zwinność",
        "Inteligencja",
        "Magia",
        "Odporność na magię",
        "Leczenie",
        "Trafienia krytyczne",
        "Wysoka wytrzymałość",
    ]

    static let flaws = [
        "Niska wytrzymałość",
        "Słaba obrona",
        "Brak magii",
        "Niska mobilność",
        "Słaba magia",
        "Krucha budowa",
        "Niska inteligencja",
        "Słaby w walce wręcz",
    ]

    static let weapons = [
        "Miecz",
        "Łuk",
        "Różdżka magiczna",
        "Topór",
        "Sztylet",
        "Kopia",
        "Kij bojowy",
        "Arbalet",
    ]

    /// Pary sprzecznych zalet i wad (np. Inteligencja ↔ Niska inteligencja).
    private static let traitConflictPairs: [(String, String)] = [
        ("Inteligencja", "Niska inteligencja"),
        ("Magia", "Brak magii"),
        ("Magia", "Słaba magia"),
        ("Wysoka wytrzymałość", "Niska wytrzymałość"),
        ("Wysoka siła", "Słaby w walce wręcz"),
        ("Zwinność", "Niska mobilność"),
        ("Odporność na magię", "Słaba magia"),
        ("Leczenie", "Krucha budowa"),
    ]

    static func conflictingTrait(for trait: String) -> String? {
        for pair in traitConflictPairs {
            if trait == pair.0 { return pair.1 }
            if trait == pair.1 { return pair.0 }
        }
        return nil
    }

    static func isTraitBlocked(_ trait: String, bySelected otherSelection: Set<String>) -> Bool {
        guard let conflict = conflictingTrait(for: trait) else { return false }
        return otherSelection.contains(conflict)
    }
}

struct PlayerCharacter: Identifiable, Hashable, Codable {
    let id: UUID
    let className: String
    let advantages: [String]
    let flaws: [String]
    let mainWeapon: String
    let qrCode: String?
    let raceName: String?
    let creatorStats: CreatorStats?
    /// Slot lobby (1–4), gdy gracz dodany przez kod gracza 4001–4004.
    let lobbySlotNumber: Int?
    /// Kolor poświaty tła podczas tury tego gracza.
    let glowColor: PlayerGlowColor?
    /// Ikona awatara z lobby (gdy gracz nie używa zdjęcia).
    let profileIconID: String?

    /// Frakcja gracza — domyślnie nazwa klasy postaci.
    var factionName: String { className }

    var displayTitle: String {
        if let lobbySlotNumber {
            return "Gracz \(lobbySlotNumber) — \(characterSubtitle)"
        }
        return characterSubtitle
    }

    private var characterSubtitle: String {
        if let raceName, !raceName.isEmpty {
            return "\(className) (\(raceName))"
        }
        return className
    }

    init(
        id: UUID = UUID(),
        className: String,
        advantages: [String],
        flaws: [String],
        mainWeapon: String,
        qrCode: String? = nil,
        raceName: String? = nil,
        creatorStats: CreatorStats? = nil,
        lobbySlotNumber: Int? = nil,
        glowColor: PlayerGlowColor? = nil,
        profileIconID: String? = nil
    ) {
        self.id = id
        self.className = className
        self.advantages = advantages
        self.flaws = flaws
        self.mainWeapon = mainWeapon
        self.qrCode = qrCode
        self.raceName = raceName
        self.creatorStats = creatorStats
        self.lobbySlotNumber = lobbySlotNumber
        self.glowColor = glowColor
        self.profileIconID = profileIconID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        className = try container.decode(String.self, forKey: .className)
        advantages = try container.decode([String].self, forKey: .advantages)
        flaws = try container.decode([String].self, forKey: .flaws)
        mainWeapon = try container.decode(String.self, forKey: .mainWeapon)
        qrCode = try container.decodeIfPresent(String.self, forKey: .qrCode)
        raceName = try container.decodeIfPresent(String.self, forKey: .raceName)
        creatorStats = try container.decodeIfPresent(CreatorStats.self, forKey: .creatorStats)
        lobbySlotNumber = try container.decodeIfPresent(Int.self, forKey: .lobbySlotNumber)
        glowColor = try container.decodeIfPresent(PlayerGlowColor.self, forKey: .glowColor)
        profileIconID = try container.decodeIfPresent(String.self, forKey: .profileIconID)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(className, forKey: .className)
        try container.encode(advantages, forKey: .advantages)
        try container.encode(flaws, forKey: .flaws)
        try container.encode(mainWeapon, forKey: .mainWeapon)
        try container.encodeIfPresent(qrCode, forKey: .qrCode)
        try container.encodeIfPresent(raceName, forKey: .raceName)
        try container.encodeIfPresent(creatorStats, forKey: .creatorStats)
        try container.encodeIfPresent(lobbySlotNumber, forKey: .lobbySlotNumber)
        try container.encodeIfPresent(glowColor, forKey: .glowColor)
        try container.encodeIfPresent(profileIconID, forKey: .profileIconID)
    }

    var profileIcon: PlayerProfileIcon? {
        PlayerProfileIcon.from(id: profileIconID)
    }

    private enum CodingKeys: String, CodingKey {
        case id, className, advantages, flaws, mainWeapon, qrCode, raceName, creatorStats, lobbySlotNumber, glowColor, profileIconID
    }

    static func fromQRCode(_ code: QRCharacterCode, lobbySlotNumber: Int? = nil) -> PlayerCharacter {
        PlayerCharacter(
            className: code.className,
            advantages: code.advantages,
            flaws: code.flaws,
            mainWeapon: code.mainWeapon,
            qrCode: code.rawValue,
            lobbySlotNumber: lobbySlotNumber
        )
    }

    static func fromCreated(
        _ character: CreatedCharacter,
        mainWeapon: String = "Miecz",
        lobbySlotNumber: Int? = nil
    ) -> PlayerCharacter {
        PlayerCharacter(
            className: character.name,
            advantages: character.advantages,
            flaws: character.flaws,
            mainWeapon: mainWeapon,
            qrCode: character.numericId,
            raceName: character.raceName,
            creatorStats: character.stats,
            lobbySlotNumber: lobbySlotNumber
        )
    }

    static func fromSlotCharacter(_ record: SlotCharacterRecord, slot: Int) -> PlayerCharacter {
        PlayerCharacter(
            className: record.name,
            advantages: record.advantage.isEmpty ? [] : [record.advantage],
            flaws: record.flaw.isEmpty ? [] : [record.flaw],
            mainWeapon: "Miecz",
            qrCode: SlotCharacterQR.code(for: slot),
            lobbySlotNumber: slot,
            glowColor: record.needsSlotDefaultGlow ? PlayerGlowColor.defaultForSlot(slot) : record.glowColor,
            profileIconID: record.profileIconID
        )
    }
}
