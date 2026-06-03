//
//  GameRulesModels.swift
//  DmdApp
//

import Foundation

/// Szanse kategorii losowania (suma powinna wynosić 100).
struct FieldCategoryOdds: Codable, Hashable {
    var abilityPercent: Int
    var financesPercent: Int
    var statisticsPercent: Int
    var misfortunePercent: Int

    static func artifactDefaults() -> FieldCategoryOdds {
        FieldCategoryOdds(abilityPercent: 25, financesPercent: 35, statisticsPercent: 35, misfortunePercent: 5)
    }

    static func specialCardDefaults() -> FieldCategoryOdds {
        FieldCategoryOdds(abilityPercent: 10, financesPercent: 30, statisticsPercent: 30, misfortunePercent: 30)
    }

    func category(for roll: Int) -> FieldLootCategory {
        let total = max(1, abilityPercent + financesPercent + statisticsPercent + misfortunePercent)
        let mis = misfortunePercent * 100 / total
        let ab = abilityPercent * 100 / total
        let fin = financesPercent * 100 / total
        let clamped = min(99, max(0, roll))
        if clamped < mis { return .misfortune }
        if clamped < mis + ab { return .ability }
        if clamped < mis + ab + fin { return .finances }
        return .statistics
    }

    enum FieldLootCategory {
        case ability, finances, statistics, misfortune
    }
}

struct StartFieldGameRules: Codable, Hashable {
    var passCoins: Int = 50
    var stayAtFullHealthCoins: Int = 10
    var stayAtFullHealthXP: Int = 5
    var maxHealth: Int = 100
    var stayHealPercentOfCurrent: Int = 20
    var xpPerVisit: Int = 10
    var powerPathEveryVisits: Int = 2
}

struct ShopGameRules: Codable, Hashable {
    var maxOffers: Int = 6
}

struct BossFightGameRules: Codable, Hashable {
    var scanHealthDelta: Int = -12
    var scanStrengthDelta: Int = 5
    var victoryFinanceMainPercent: Int = 80
    var victoryFinanceSupportPercent: Int = 20
    var xpEasy: Int = 20
    var xpMedium: Int = 40
    var xpHard: Int = 80
}

struct ArtifactGameRules: Codable, Hashable {
    var categoryOdds: FieldCategoryOdds = .artifactDefaults()
    var financesMin: Int = 20
    var financesMax: Int = 150
    var statBoostMin: Int = 5
    var statBoostMax: Int = 10
    var misfortuneHealthMin: Int = 8
    var misfortuneHealthMax: Int = 15
    var misfortuneStrengthMin: Int = 8
    var misfortuneStrengthMax: Int = 12
    var misfortuneFundMin: Int = 20
    var misfortuneFundMax: Int = 50
    var misfortuneQueueBlockMin: Int = 1
    var misfortuneQueueBlockMax: Int = 2
    var drawXP: Int = 10
}

struct SpecialCardGameRules: Codable, Hashable {
    var categoryOdds: FieldCategoryOdds = .specialCardDefaults()
    var positiveXP: Int = 20
    var negativeXP: Int = 10
    var customCards: [SpecialCardDefinition] = SpecialCardDefinition.defaultDeck()
}

enum TrikiGestureAction: String, CaseIterable, Codable, Hashable, Identifiable {
    case none
    case listDown
    case listUp
    case selectOption
    case skipTurn
    case saveGame
    case showItems
    case showOwnStats
    case useStealAbility
    case attack
    case defense
    case strongAttack

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: "Nic"
        case .listDown: "Zejście listy na dół"
        case .listUp: "Zejście listy do góry"
        case .selectOption: "Wybranie opcji"
        case .skipTurn: "Pominięcie tury"
        case .saveGame: "Zapisanie gry"
        case .showItems: "Pokazanie ekwipunku"
        case .showOwnStats: "Pokazanie swoich statystyk"
        case .useStealAbility: "Użycie zdolności okradania"
        case .attack: "Atak"
        case .defense: "Obrona"
        case .strongAttack: "Mocny atak"
        }
    }
}

struct TrikiGestureRules: Codable, Hashable {
    /// Pochylenie / przesunięcie — w grze obsługiwane przez krótki klik fizyczny.
    var slide: TrikiGestureAction = .none
    var rotateLeft: TrikiGestureAction = .none
    var rotateRight: TrikiGestureAction = .none
    /// Fizyczny przycisk: krótki klik i długie przytrzymanie są w GameView; tu tylko gesty z reguł DevCentrum.
    var click: TrikiGestureAction = .none
    var shake: TrikiGestureAction = .none

    enum CodingKeys: String, CodingKey {
        case slide, rotateLeft, rotateRight, click, shake
    }

    init(
        slide: TrikiGestureAction = .listDown,
        rotateLeft: TrikiGestureAction = .none,
        rotateRight: TrikiGestureAction = .none,
        click: TrikiGestureAction = .selectOption,
        shake: TrikiGestureAction = .none
    ) {
        self.slide = slide
        self.rotateLeft = rotateLeft
        self.rotateRight = rotateRight
        self.click = click
        self.shake = shake
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        slide = try container.decodeIfPresent(TrikiGestureAction.self, forKey: .slide) ?? .listDown
        rotateLeft = try container.decodeIfPresent(TrikiGestureAction.self, forKey: .rotateLeft) ?? .none
        rotateRight = try container.decodeIfPresent(TrikiGestureAction.self, forKey: .rotateRight) ?? .none
        click = try container.decodeIfPresent(TrikiGestureAction.self, forKey: .click) ?? .selectOption
        shake = try container.decodeIfPresent(TrikiGestureAction.self, forKey: .shake) ?? .none
        // Wcześniej listę obsługiwało potrząśnięcie — przenieś na pochylenie do przodu.
        if slide == .none, shake == .listDown {
            slide = .listDown
            shake = .none
        }
    }
}

struct GameRulesConfiguration: Codable, Hashable {
    var startField: StartFieldGameRules = StartFieldGameRules()
    var shop: ShopGameRules = ShopGameRules()
    var bossFight: BossFightGameRules = BossFightGameRules()
    var artifact: ArtifactGameRules = ArtifactGameRules()
    var specialCard: SpecialCardGameRules = SpecialCardGameRules()
    var trikiGestures: TrikiGestureRules = TrikiGestureRules()

    enum CodingKeys: String, CodingKey {
        case startField
        case shop
        case bossFight
        case artifact
        case specialCard
        case trikiGestures
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        startField = try container.decodeIfPresent(StartFieldGameRules.self, forKey: .startField) ?? StartFieldGameRules()
        shop = try container.decodeIfPresent(ShopGameRules.self, forKey: .shop) ?? ShopGameRules()
        bossFight = try container.decodeIfPresent(BossFightGameRules.self, forKey: .bossFight) ?? BossFightGameRules()
        artifact = try container.decodeIfPresent(ArtifactGameRules.self, forKey: .artifact) ?? ArtifactGameRules()
        specialCard = try container.decodeIfPresent(SpecialCardGameRules.self, forKey: .specialCard) ?? SpecialCardGameRules()
        trikiGestures = try container.decodeIfPresent(TrikiGestureRules.self, forKey: .trikiGestures) ?? TrikiGestureRules()
    }

    static func defaults() -> GameRulesConfiguration { GameRulesConfiguration() }
}

@MainActor
enum GameRulesRuntime {
    private(set) static var current: GameRulesConfiguration = .defaults()

    static func update(_ rules: GameRulesConfiguration) {
        current = rules
    }
}

enum GameRulesFieldKind: String, CaseIterable, Identifiable {
    case startField
    case shop
    case bossFight
    case artifact
    case specialCard
    case trikiGestures

    var id: String { rawValue }

    var title: String {
        switch self {
        case .startField: "Pole Startowe"
        case .shop: "Sklepik Handlowy"
        case .bossFight: "Walka z Bossem"
        case .artifact: "Artefakt"
        case .specialCard: "Karta Specjalna"
        case .trikiGestures: "Gesty Triki"
        }
    }

    var icon: String {
        switch self {
        case .startField: "flag.checkered"
        case .shop: "cart.fill"
        case .bossFight: "figure.stand.line.dotted.figure.stand"
        case .artifact: "sparkles.rectangle.stack.fill"
        case .specialCard: "rectangle.on.rectangle.angled"
        case .trikiGestures: "dot.radiowaves.left.and.right"
        }
    }

    var themeColor: (red: Double, green: Double, blue: Double) {
        switch self {
        case .startField: (0.28, 0.72, 0.48)
        case .shop: (1.0, 0.72, 0.28)
        case .bossFight: (0.92, 0.32, 0.38)
        case .artifact: (0.55, 0.38, 0.98)
        case .specialCard: (0.38, 0.62, 0.95)
        case .trikiGestures: (0.2, 0.85, 0.9)
        }
    }
}
