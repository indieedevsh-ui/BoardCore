//
//  CreatorModels.swift
//  DmdApp
//

import Foundation

enum CreatorItemKind: String, Codable, CaseIterable, Identifiable {
    case weapon
    /// Zachowane w zapisach — traktowane jak `armor`.
    case helmet
    case armor
    /// Zachowane w zapisach — traktowane jak `armor`.
    case shield
    case brush

    var id: String { rawValue }

    /// Sloty ekwipunku w grze: tylko broń i pancerz.
    static var equippableCases: [CreatorItemKind] {
        [.weapon, .armor]
    }

    /// Kategorie w kreatorze (bez legacy hełm/tarcza).
    static var formSelectableCases: [CreatorItemKind] {
        [.weapon, .armor, .brush]
    }

    var isEquippable: Bool {
        switch equipmentSlotKind {
        case .weapon, .armor: true
        case .brush, .helmet, .shield: false
        }
    }

    /// Rodzaj używany do slotu założenia (hełm i tarcza → pancerz).
    var equipmentSlotKind: CreatorItemKind {
        switch self {
        case .helmet, .shield, .armor: .armor
        case .weapon: .weapon
        case .brush: .brush
        }
    }

    var displayName: String {
        switch equipmentSlotKind {
        case .weapon: "Broń"
        case .armor: "Pancerz"
        case .brush: "Pędzel"
        case .helmet, .shield: "Pancerz"
        }
    }

    var icon: String {
        switch equipmentSlotKind {
        case .weapon: "bolt.fill"
        case .armor: "figure.stand"
        case .brush: "paintbrush.pointed.fill"
        case .helmet, .shield: "figure.stand"
        }
    }

    var artifactHint: String? {
        switch self {
        case .brush:
            "Im wyższy koszt pędzla, tym lepsze szanse na łup z artefaktów (do 70% szczęśliwego losu)."
        default:
            "Można założyć jedną broń i jeden pancerz (w tym hełmy i tarcze liczą się jako pancerz)."
        }
    }

    /// Uzupełnia błędnie przypisany rodzaj (np. pancerz oznaczony jako broń) na podstawie nazwy.
    static func resolved(stored: CreatorItemKind, name: String) -> CreatorItemKind {
        let lower = name.lowercased()
        if lower.contains("pędzel") || lower.contains("pedzel") { return .brush }
        if lower.contains("pancerz") || lower.contains("zbroj") || lower.contains("kolczug")
            || lower.contains("helm") || lower.contains("hełm") || lower.contains("tarcz") {
            return .armor
        }
        if lower.contains("miecz") || lower.contains("łuk") || lower.contains("luk")
            || lower.contains("sztylet") || lower.contains("topór") || lower.contains("topor")
            || lower.contains("kostur") || lower.contains("arbalet") || lower.contains("broń")
            || lower.contains("bron") {
            return .weapon
        }

        switch stored.equipmentSlotKind {
        case .armor, .helmet, .shield:
            return .armor
        case .weapon:
            return .weapon
        case .brush:
            return .brush
        case .helmet, .shield:
            return .armor
        }
    }

    static func inferredFromGeneratedKindWord(_ kindWord: String, isBrush: Bool) -> CreatorItemKind {
        if isBrush { return .brush }
        return resolved(stored: .weapon, name: kindWord)
    }
}

struct CreatorStats: Codable, Hashable {
    static let weaponStrengthRange = 10...80
    static let armorHealthRange = 10...80

    var finances: Int = 50
    var health: Int = 70
    var strength: Int = 50
    var mana: Int = 50

    static func random(itemKind: CreatorItemKind? = nil) -> CreatorStats {
        let strengthValue: Int
        let healthValue: Int
        if itemKind == .weapon {
            strengthValue = Int.random(in: weaponStrengthRange)
            healthValue = Int.random(in: 35...90)
        } else if itemKind == .armor {
            strengthValue = Int.random(in: 35...90)
            healthValue = Int.random(in: armorHealthRange)
        } else {
            strengthValue = Int.random(in: 35...90)
            healthValue = Int.random(in: 35...90)
        }
        return CreatorStats(
            finances: Int.random(in: 35...90),
            health: healthValue,
            strength: strengthValue,
            mana: Int.random(in: 35...90)
        )
    }

    /// Statystyki skorelowane z ceną — droższa broń/pancerz daje wyższy bonus.
    static func forGeneratedBatchItem(
        cost: Int,
        itemKind: CreatorItemKind,
        costRange: ClosedRange<Int>
    ) -> CreatorStats {
        let tier = costTier(cost: cost, in: costRange)
        switch itemKind.equipmentSlotKind {
        case .weapon:
            return CreatorStats(
                finances: 50,
                health: 50,
                strength: valueForTier(tier, in: weaponStrengthRange),
                mana: 50
            )
        case .armor:
            return CreatorStats(
                finances: 50,
                health: valueForTier(tier, in: armorHealthRange),
                strength: 50,
                mana: 50
            )
        default:
            return CreatorStats(
                finances: Int.random(in: 35...90),
                health: Int.random(in: 35...90),
                strength: Int.random(in: 35...90),
                mana: Int.random(in: 35...90)
            )
        }
    }

    private static func costTier(cost: Int, in range: ClosedRange<Int>) -> Double {
        guard range.upperBound > range.lowerBound else { return 1 }
        let clamped = min(max(cost, range.lowerBound), range.upperBound)
        return Double(clamped - range.lowerBound) / Double(range.upperBound - range.lowerBound)
    }

    private static func valueForTier(_ tier: Double, in range: ClosedRange<Int>) -> Int {
        let value = Double(range.lowerBound) + tier * Double(range.upperBound - range.lowerBound)
        return Int(value.rounded())
    }

    private enum CodingKeys: String, CodingKey {
        case finances, health, strength, mana, abilities
    }

    init(finances: Int = 50, health: Int = 70, strength: Int = 50, mana: Int = 50) {
        self.finances = finances
        self.health = health
        self.strength = strength
        self.mana = mana
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        finances = try container.decodeIfPresent(Int.self, forKey: .finances) ?? 50
        health = try container.decodeIfPresent(Int.self, forKey: .health) ?? 70
        strength = try container.decodeIfPresent(Int.self, forKey: .strength) ?? 50
        mana = try container.decodeIfPresent(Int.self, forKey: .mana)
            ?? container.decodeIfPresent(Int.self, forKey: .abilities)
            ?? 50
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(finances, forKey: .finances)
        try container.encode(health, forKey: .health)
        try container.encode(strength, forKey: .strength)
        try container.encode(mana, forKey: .mana)
    }

    /// Bonus ekwipunku w sklepie: broń → siła, pancerz → zdrowie.
    func shopEquipBonus(for itemKind: CreatorItemKind) -> (icon: String, label: String, bonus: Int)? {
        switch itemKind.equipmentSlotKind {
        case .weapon:
            ("bolt.fill", "Siła", weaponStrengthBonus)
        case .armor:
            ("heart.fill", "Zdrowie", armorHealthBonus)
        default:
            nil
        }
    }

    /// Wiersze statystyk przedmiotu do podglądu w sklepie (neutral = 50).
    func itemShopStatRows(for itemKind: CreatorItemKind) -> [(label: String, icon: String, value: Int, bonus: Int)] {
        let damageBonus = itemKind == .weapon ? weaponStrengthBonus : strengthBonus
        let healthRowBonus = itemKind == .armor ? armorHealthBonus : health - 50
        return [
            ("Obrażenia", "bolt.fill", strength, damageBonus),
            ("Zdrowie", "heart.fill", health, healthRowBonus),
            ("Mana", "sparkles", mana, mana - 50),
            ("Finanse", "dollarsign.circle.fill", finances, finances - 50),
        ]
    }

    var healthBonus: Int { max(0, health - 50) }
    var strengthBonus: Int { max(0, strength - 50) }
    var manaBonus: Int { max(0, mana - 50) }

    /// Bonus siły z broni: +10…+80 (pole strength przechowuje wartość bonusu).
    var weaponStrengthBonus: Int {
        if Self.weaponStrengthRange.contains(strength) {
            return strength
        }
        return min(Self.weaponStrengthRange.upperBound, max(Self.weaponStrengthRange.lowerBound, strengthBonus + 10))
    }

    /// Bonus zdrowia ze zbroi: +10…+80 (pole health przechowuje wartość bonusu).
    var armorHealthBonus: Int {
        if Self.armorHealthRange.contains(health) {
            return health
        }
        return min(Self.armorHealthRange.upperBound, max(Self.armorHealthRange.lowerBound, healthBonus + 10))
    }
}

struct CreatedCharacter: Identifiable, Codable, Hashable {
    let id: UUID
    var numericId: String
    var name: String
    var raceName: String
    var advantages: [String]
    var flaws: [String]
    var stats: CreatorStats
    var imageFileName: String?
    var buildPrompt: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        numericId: String,
        name: String,
        raceName: String,
        advantages: [String],
        flaws: [String],
        stats: CreatorStats,
        imageFileName: String? = nil,
        buildPrompt: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.numericId = numericId
        self.name = name
        self.raceName = raceName
        self.advantages = advantages
        self.flaws = flaws
        self.stats = stats
        self.imageFileName = imageFileName
        self.buildPrompt = buildPrompt
        self.createdAt = createdAt
    }
}

struct CreatedItem: Identifiable, Codable, Hashable {
    let id: UUID
    var numericId: String
    var name: String
    var cost: Int
    var stats: CreatorStats
    var itemKind: CreatorItemKind
    var imageFileName: String?
    var buildPrompt: String?
    var createdAt: Date

    var isBrush: Bool { itemKind == .brush }

    var resolvedItemKind: CreatorItemKind {
        CreatorItemKind.resolved(stored: itemKind, name: name).equipmentSlotKind
    }

    static func numericIDsMatch(_ lhs: String, _ rhs: String) -> Bool {
        let leftDigits = lhs.filter(\.isNumber)
        let rightDigits = rhs.filter(\.isNumber)
        if leftDigits.isEmpty || rightDigits.isEmpty {
            return lhs.trimmingCharacters(in: .whitespacesAndNewlines)
                == rhs.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return leftDigits == rightDigits
    }

    static func first(in catalog: [CreatedItem], matchingNumericID id: String) -> CreatedItem? {
        catalog.first { numericIDsMatch($0.numericId, id) }
    }

    init(
        id: UUID = UUID(),
        numericId: String,
        name: String,
        cost: Int,
        stats: CreatorStats,
        itemKind: CreatorItemKind = .weapon,
        imageFileName: String? = nil,
        buildPrompt: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.numericId = numericId
        self.name = name
        self.cost = cost
        self.stats = stats
        self.itemKind = itemKind
        self.imageFileName = imageFileName
        self.buildPrompt = buildPrompt
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        numericId = try container.decode(String.self, forKey: .numericId)
        name = try container.decode(String.self, forKey: .name)
        cost = try container.decode(Int.self, forKey: .cost)
        stats = try container.decode(CreatorStats.self, forKey: .stats)
        itemKind = try container.decodeIfPresent(CreatorItemKind.self, forKey: .itemKind) ?? .weapon
        imageFileName = try container.decodeIfPresent(String.self, forKey: .imageFileName)
        buildPrompt = try container.decodeIfPresent(String.self, forKey: .buildPrompt)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
}

struct CreatedAbility: Identifiable, Codable, Hashable {
    let id: UUID
    var numericId: String
    var name: String
    var effectDescription: String
    var elementCategory: String
    var buildPrompt: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        numericId: String,
        name: String,
        effectDescription: String,
        elementCategory: String,
        buildPrompt: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.numericId = numericId
        self.name = name
        self.effectDescription = effectDescription
        self.elementCategory = elementCategory
        self.buildPrompt = buildPrompt
        self.createdAt = createdAt
    }
}

struct CreatedRace: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var advantages: [String]
    var flaws: [String]
    var stats: CreatorStats
    var buildPrompt: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        advantages: [String],
        flaws: [String],
        stats: CreatorStats,
        buildPrompt: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.advantages = advantages
        self.flaws = flaws
        self.stats = stats
        self.buildPrompt = buildPrompt
        self.createdAt = createdAt
    }
}

struct CreatedElement: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var advantages: String
    var disadvantages: String
    var buildPrompt: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        advantages: String,
        disadvantages: String,
        buildPrompt: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.advantages = advantages
        self.disadvantages = disadvantages
        self.buildPrompt = buildPrompt
        self.createdAt = createdAt
    }
}

struct CreatedPowerUpgrade: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var summary: String
    var xpCost: Int
    var tier: Int
    var influence: PowerUpgradeInfluence
    var boardEffect: PowerUpgradeBoardEffect
    var bossFightEffect: PowerUpgradeBossFightEffect
    var playersEffect: PowerUpgradePlayersEffect
    var gameplayEffect: PowerUpgradeGameplayEffect

    init(
        id: UUID = UUID(),
        name: String,
        summary: String,
        xpCost: Int,
        tier: Int = 1,
        influence: PowerUpgradeInfluence = .gameplay,
        boardEffect: PowerUpgradeBoardEffect = .default,
        bossFightEffect: PowerUpgradeBossFightEffect = .default,
        playersEffect: PowerUpgradePlayersEffect = .default,
        gameplayEffect: PowerUpgradeGameplayEffect = .default
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.xpCost = max(0, xpCost)
        self.tier = max(1, tier)
        self.influence = influence
        self.boardEffect = boardEffect
        self.bossFightEffect = bossFightEffect
        self.playersEffect = playersEffect
        self.gameplayEffect = gameplayEffect
    }

    enum CodingKeys: String, CodingKey {
        case id, name, summary, xpCost, tier, influence
        case boardEffect, bossFightEffect, playersEffect, gameplayEffect
        case healthBonus, strengthBonus, coinsBonus
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        summary = try container.decode(String.self, forKey: .summary)
        xpCost = try container.decode(Int.self, forKey: .xpCost)
        tier = max(1, try container.decodeIfPresent(Int.self, forKey: .tier) ?? 1)

        if let influence = try container.decodeIfPresent(PowerUpgradeInfluence.self, forKey: .influence) {
            self.influence = influence
            boardEffect = try container.decodeIfPresent(PowerUpgradeBoardEffect.self, forKey: .boardEffect) ?? .default
            bossFightEffect = try container.decodeIfPresent(PowerUpgradeBossFightEffect.self, forKey: .bossFightEffect) ?? .default
            playersEffect = try container.decodeIfPresent(PowerUpgradePlayersEffect.self, forKey: .playersEffect) ?? .default
            gameplayEffect = try container.decodeIfPresent(PowerUpgradeGameplayEffect.self, forKey: .gameplayEffect) ?? .default
        } else {
            influence = .gameplay
            boardEffect = .default
            bossFightEffect = .default
            playersEffect = .default
            gameplayEffect = PowerUpgradeGameplayEffect(
                healthBonus: try container.decodeIfPresent(Int.self, forKey: .healthBonus) ?? 0,
                strengthBonus: try container.decodeIfPresent(Int.self, forKey: .strengthBonus) ?? 0,
                coinsBonus: try container.decodeIfPresent(Int.self, forKey: .coinsBonus) ?? 0,
                xpBonus: 0
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(summary, forKey: .summary)
        try container.encode(xpCost, forKey: .xpCost)
        try container.encode(tier, forKey: .tier)
        try container.encode(influence, forKey: .influence)
        try container.encode(boardEffect, forKey: .boardEffect)
        try container.encode(bossFightEffect, forKey: .bossFightEffect)
        try container.encode(playersEffect, forKey: .playersEffect)
        try container.encode(gameplayEffect, forKey: .gameplayEffect)
    }

    var healthBonus: Int {
        get { gameplayEffect.healthBonus }
        set { gameplayEffect.healthBonus = newValue }
    }

    var strengthBonus: Int {
        get { gameplayEffect.strengthBonus }
        set { gameplayEffect.strengthBonus = newValue }
    }

    var coinsBonus: Int {
        get { gameplayEffect.coinsBonus }
        set { gameplayEffect.coinsBonus = newValue }
    }

    var effectSummary: String {
        switch influence {
        case .board:
            switch boardEffect.mode {
            case .moveForward:
                return "Plansza: +\(boardEffect.spaces) \(boardEffect.spaces == 1 ? "pole" : "pola")"
            case .moveBackward:
                return "Plansza: −\(boardEffect.spaces) \(boardEffect.spaces == 1 ? "pole" : "pola")"
            case .anyField:
                return "Plansza: dowolne pole"
            }
        case .bossFight:
            var parts: [String] = []
            if bossFightEffect.previewBossMoveEnabled {
                parts.append("Podgląd ruchu co \(bossFightEffect.previewEveryTurns) tur · \(bossFightEffect.previewUsesPerEncounter)×/starcie")
            }
            if bossFightEffect.immortalEnabled {
                parts.append("Nieśmiertelny +\(bossFightEffect.immortalHealthRestore) co \(bossFightEffect.immortalEveryBattles) bitw")
            }
            return parts.isEmpty ? "Walka z bossem: —" : parts.joined(separator: " · ")
        case .players:
            var parts: [String] = []
            if playersEffect.robPlayerEnabled {
                var stats: [String] = []
                if playersEffect.robTargetsFinances { stats.append("fundusze") }
                if playersEffect.robTargetsStrength { stats.append("siła") }
                if playersEffect.robTargetsHealth { stats.append("zdrowie") }
                let statLabel = stats.isEmpty ? "statystyki" : stats.joined(separator: ", ")
                parts.append("Okradnij \(playersEffect.robPercent)% (\(statLabel))")
            }
            if playersEffect.blockMoveEnabled {
                let scope = playersEffect.blockMoveScope == .allPlayers ? "wszyscy" : "jeden gracz"
                parts.append("Zablokuj ruch \(playersEffect.blockMoveTurns) tur (\(scope))")
            }
            if playersEffect.removePlayerEnabled {
                parts.append("Usuń \(playersEffect.removePlayerCount) graczy")
            }
            return parts.isEmpty ? "Gracze: —" : parts.joined(separator: " · ")
        case .gameplay:
            return gameplayEffect.summaryLine
        }
    }

    var bonusSummary: String { effectSummary }
}

struct CreatedPowerPath: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var iconSymbol: String
    var glowRed: Double
    var glowGreen: Double
    var glowBlue: Double
    var glowOpacity: Double
    var isBuiltIn: Bool
    var upgrades: [CreatedPowerUpgrade]
    var buildPrompt: String?
    var createdAt: Date

    var glowColor: PlayerGlowColor {
        get { PlayerGlowColor(red: glowRed, green: glowGreen, blue: glowBlue, opacity: glowOpacity) }
        set {
            glowRed = newValue.red
            glowGreen = newValue.green
            glowBlue = newValue.blue
            glowOpacity = newValue.opacity
        }
    }

    init(
        id: UUID = UUID(),
        name: String,
        iconSymbol: String = "sparkles",
        glowColor: PlayerGlowColor,
        isBuiltIn: Bool = false,
        upgrades: [CreatedPowerUpgrade] = [],
        buildPrompt: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.iconSymbol = iconSymbol
        glowRed = glowColor.red
        glowGreen = glowColor.green
        glowBlue = glowColor.blue
        glowOpacity = glowColor.opacity
        self.isBuiltIn = isBuiltIn
        self.upgrades = upgrades
        self.buildPrompt = buildPrompt
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id, name, iconSymbol, glowRed, glowGreen, glowBlue, glowOpacity, isBuiltIn, upgrades, buildPrompt, createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        iconSymbol = try container.decodeIfPresent(String.self, forKey: .iconSymbol) ?? "sparkles"
        glowRed = try container.decode(Double.self, forKey: .glowRed)
        glowGreen = try container.decode(Double.self, forKey: .glowGreen)
        glowBlue = try container.decode(Double.self, forKey: .glowBlue)
        glowOpacity = try container.decode(Double.self, forKey: .glowOpacity)
        isBuiltIn = try container.decodeIfPresent(Bool.self, forKey: .isBuiltIn) ?? false
        upgrades = try container.decodeIfPresent([CreatedPowerUpgrade].self, forKey: .upgrades) ?? []
        buildPrompt = try container.decodeIfPresent(String.self, forKey: .buildPrompt)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
}

struct CreatorCatalog: Codable {
    var characters: [CreatedCharacter] = []
    var items: [CreatedItem] = []
    var abilities: [CreatedAbility] = []
    var powerPaths: [CreatedPowerPath] = []
    var races: [CreatedRace] = []
    var elements: [CreatedElement] = []
    var gameRules: GameRulesConfiguration = .defaults()

    static let defaultRaceNames = ["Człowiek", "Elf", "Krasnolud", "Ork", "Niziołek"]
    static let defaultElementNames = [
        "Ogień", "Woda", "Ziemia", "Powietrze", "Światło", "Ciemność", "Burza", "Lód", "Natura", "Standard",
    ]

    static func defaultElements() -> [CreatedElement] {
        [
            CreatedElement(name: "Ogień", advantages: "Wysokie obrażenia, presja na wroga", disadvantages: "Słaba obrona, wyczerpanie many"),
            CreatedElement(name: "Woda", advantages: "Leczenie, kontrola pola", disadvantages: "Niska siła bezpośrednia"),
            CreatedElement(name: "Ziemia", advantages: "Wysoka wytrzymałość, stabilność", disadvantages: "Niska mobilność"),
            CreatedElement(name: "Powietrze", advantages: "Zwinność, uniki", disadvantages: "Krucha przy trafieniu"),
            CreatedElement(name: "Standard", advantages: "Uniwersalność, brak słabości żywiołu", disadvantages: "Brak bonusu żywiołowego"),
        ]
    }

    /// Domyślny katalog kreatora — bez wpisów użytkownika.
    static func restoredDefaults() -> CreatorCatalog {
        CreatorCatalog(
            characters: [],
            items: [],
            abilities: [],
            powerPaths: CreatorPowerPathSeed.defaultPaths(),
            races: [],
            elements: defaultElements(),
            gameRules: .defaults()
        )
    }
}

enum CreatorIDPool {
    case character
    case item
    case ability
    case power

    var range: ClosedRange<Int> {
        switch self {
        case .character: 3001...3999
        case .item: 4001...4999
        case .ability: 5001...5999
        case .power: 7001...7999
        }
    }
}

enum CreatorIDGenerator {
    static func randomUnique(pool: CreatorIDPool, reserved: Set<String>) -> String {
        for _ in 0..<10_000 {
            let candidate = String(Int.random(in: pool.range))
            if !reserved.contains(candidate) {
                return candidate
            }
        }
        return String(Int.random(in: pool.range)) + "-" + UUID().uuidString.prefix(4)
    }
}
