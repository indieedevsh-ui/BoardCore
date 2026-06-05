//
//  SpecialCardModels.swift
//  BoardCore
//

import Foundation

enum SpecialCardEffectKind: Hashable, Codable {
    case financesDelta(Int)
    case healthDelta(Int)
    case strengthDelta(Int)
    case tripleStatBoost(Int)
    case grantRandomAbility
    case grantRandomItem
    case grantDoubleAbility
    case healthPercentBonus(Double)
    case treasuryAndItem
    case combinedDrain(health: Int, strength: Int, finances: Int)
    case plunder(finances: Int)
    case removeRandomAbility
    case removeRandomItem
    case queueBlock(rounds: Int)
}

struct SpecialCardDefinition: Identifiable, Hashable, Codable {
    let id: String
    var title: String
    var summary: String
    var icon: String
    var isPositive: Bool
    var effect: SpecialCardEffectKind

    static let positiveDeck: [SpecialCardDefinition] = [
        .init(id: "pos_finances", title: "Skarb Mennicy", summary: "+25 do finansów.", icon: "dollarsign.circle.fill", isPositive: true, effect: .financesDelta(25)),
        .init(id: "pos_health", title: "Eliksir Witalności", summary: "+15 zdrowia.", icon: "heart.fill", isPositive: true, effect: .healthDelta(15)),
        .init(id: "pos_strength", title: "Moc Bohatera", summary: "+12 siły.", icon: "bolt.fill", isPositive: true, effect: .strengthDelta(12)),
        .init(id: "pos_ability", title: "Dar Mistrza", summary: "Losowa zdolność z kreatora.", icon: "sparkles", isPositive: true, effect: .grantRandomAbility),
        .init(id: "pos_item", title: "Skrzynia Łupów", summary: "Losowy przedmiot z kreatora.", icon: "bag.fill", isPositive: true, effect: .grantRandomItem),
        .init(id: "pos_gold", title: "Deszcz Złota", summary: "+150 monet.", icon: "banknote.fill", isPositive: true, effect: .financesDelta(150)),
        .init(id: "pos_triple", title: "Harmonia Statystyk", summary: "+8 finanse, zdrowie i siła.", icon: "chart.line.uptrend.xyaxis", isPositive: true, effect: .tripleStatBoost(8)),
        .init(id: "pos_double_ability", title: "Podwójna Inicjacja", summary: "Dwie losowe zdolności.", icon: "sparkles.rectangle.stack.fill", isPositive: true, effect: .grantDoubleAbility),
        .init(id: "pos_regen", title: "Regeneracja", summary: "+25% aktualnego zdrowia.", icon: "leaf.fill", isPositive: true, effect: .healthPercentBonus(0.25)),
        .init(id: "pos_treasure", title: "Legendarny Skarb", summary: "+200 monet i losowy przedmiot.", icon: "gift.fill", isPositive: true, effect: .treasuryAndItem),
    ]

    static let negativeDeck: [SpecialCardDefinition] = [
        .init(id: "neg_finances", title: "Podatek Losu", summary: "−20 finansów.", icon: "dollarsign.circle", isPositive: false, effect: .financesDelta(-20)),
        .init(id: "neg_health", title: "Klątwa Osłabienia", summary: "−15 zdrowia.", icon: "heart.slash.fill", isPositive: false, effect: .healthDelta(-15)),
        .init(id: "neg_strength", title: "Zmęczenie", summary: "−12 siły.", icon: "bolt.slash.fill", isPositive: false, effect: .strengthDelta(-12)),
        .init(id: "neg_lose_ability", title: "Amnezja", summary: "Tracisz losową zdolność.", icon: "sparkles.slash", isPositive: false, effect: .removeRandomAbility),
        .init(id: "neg_lose_item", title: "Kradzież", summary: "Tracisz losowy przedmiot.", icon: "bag.badge.minus", isPositive: false, effect: .removeRandomItem),
        .init(id: "neg_gold", title: "Bankructwo", summary: "−100 monet.", icon: "creditcard.trianglebadge.exclamationmark", isPositive: false, effect: .financesDelta(-100)),
        .init(id: "neg_drain", title: "Osłabienie", summary: "−10 zdrowia, −10 siły, −30 monet.", icon: "arrow.down.circle.fill", isPositive: false, effect: .combinedDrain(health: 10, strength: 10, finances: 30)),
        .init(id: "neg_block_2", title: "Spowolnienie", summary: "Kolejka zablokowana na 2 tury.", icon: "hourglass", isPositive: false, effect: .queueBlock(rounds: 2)),
        .init(id: "neg_block_3", title: "Paraliż", summary: "Kolejka zablokowana na 3 tury.", icon: "lock.fill", isPositive: false, effect: .queueBlock(rounds: 3)),
        .init(id: "neg_plunder", title: "Plądrowanie", summary: "−50 monet i utrata przedmiotu.", icon: "exclamationmark.triangle.fill", isPositive: false, effect: .plunder(finances: 50)),
    ]

    static var allCards: [SpecialCardDefinition] { defaultDeck() }

    static func defaultDeck() -> [SpecialCardDefinition] { positiveDeck + negativeDeck }

    static func randomDraw(rules: SpecialCardGameRules = SpecialCardGameRules()) -> SpecialCardDefinition {
        let deck = rules.customCards.isEmpty ? defaultDeck() : rules.customCards
        guard !deck.isEmpty else { return positiveDeck[0] }

        let roll = Int.random(in: 0..<100)
        let category = rules.categoryOdds.category(for: roll)
        let pool = deck.filter { $0.matches(category: category) }
        return (pool.isEmpty ? deck : pool).randomElement() ?? deck[0]
    }

    static func randomDraw() -> SpecialCardDefinition {
        randomDraw(rules: SpecialCardGameRules())
    }

    func matches(category: FieldCategoryOdds.FieldLootCategory) -> Bool {
        switch category {
        case .ability:
            switch effect {
            case .grantRandomAbility, .grantDoubleAbility: return true
            default: return false
            }
        case .finances:
            switch effect {
            case .financesDelta, .treasuryAndItem, .plunder: return true
            default: return false
            }
        case .statistics:
            switch effect {
            case .healthDelta, .strengthDelta, .tripleStatBoost, .healthPercentBonus, .combinedDrain: return true
            default: return false
            }
        case .misfortune:
            if !isPositive { return true }
            switch effect {
            case .removeRandomAbility, .removeRandomItem, .queueBlock, .plunder, .combinedDrain: return true
            default: return false
            }
        }
    }
}

struct SpecialCardApplyResult {
    let card: SpecialCardDefinition
    let detailMessage: String
}

enum SpecialCardApplier {
    typealias AbilityGrantHandler = (inout [UUID]) -> CreatedAbility?

    static func apply(
        card: SpecialCardDefinition,
        stats: inout PlayerRuntimeStats,
        abilityIDs: inout [UUID],
        itemIDs: inout [UUID],
        queueBlockRounds: inout Int,
        abilitiesCatalog: [CreatedAbility],
        itemsCatalog: [CreatedItem],
        grantAbility: AbilityGrantHandler? = nil
    ) -> SpecialCardApplyResult {
        var details: [String] = []

        switch card.effect {
        case .financesDelta(let delta):
            stats.finances = max(0, stats.finances + delta)
            details.append(delta >= 0 ? "+\(delta) finanse" : "\(delta) finanse")
        case .healthDelta(let delta):
            stats.health = min(100, max(0, stats.health + delta))
            details.append(delta >= 0 ? "+\(delta) zdrowie" : "\(delta) zdrowie")
        case .strengthDelta(let delta):
            stats.strength = min(100, max(0, stats.strength + delta))
            details.append(delta >= 0 ? "+\(delta) siła" : "\(delta) siła")
        case .tripleStatBoost(let amount):
            stats.finances = min(9999, stats.finances + amount)
            stats.health = min(100, stats.health + amount)
            stats.strength = min(100, stats.strength + amount)
            details.append("+\(amount) finanse, zdrowie, siła")
        case .grantRandomAbility:
            if let customGrant = grantAbility, let ability = customGrant(&abilityIDs) {
                details.append("Zdolność: \(ability.name)")
            } else if let ability = grantFromCatalog(catalog: abilitiesCatalog, existing: &abilityIDs) {
                details.append("Zdolność: \(ability.name)")
            } else {
                details.append("Brak zdolności w puli")
            }
        case .grantRandomItem:
            if let item = grantItem(catalog: itemsCatalog, existing: &itemIDs) {
                details.append("Przedmiot: \(item.name)")
            } else {
                details.append("Brak przedmiotów w katalogu")
            }
        case .grantDoubleAbility:
            var names: [String] = []
            for _ in 0..<2 {
                if let customGrant = grantAbility, let ability = customGrant(&abilityIDs) {
                    names.append(ability.name)
                } else if let ability = grantFromCatalog(catalog: abilitiesCatalog, existing: &abilityIDs) {
                    names.append(ability.name)
                }
            }
            details.append(names.isEmpty ? "Brak zdolności" : "Zdolności: \(names.joined(separator: ", "))")
        case .healthPercentBonus(let fraction):
            let bonus = max(1, Int(Double(stats.health) * fraction))
            stats.health = min(100, stats.health + bonus)
            details.append("+\(bonus) zdrowia")
        case .treasuryAndItem:
            stats.finances += 200
            details.append("+200 monet")
            if let item = grantItem(catalog: itemsCatalog, existing: &itemIDs) {
                details.append("Przedmiot: \(item.name)")
            }
        case .combinedDrain(let health, let strength, let finances):
            stats.health = max(0, stats.health - health)
            stats.strength = max(0, stats.strength - strength)
            stats.finances = max(0, stats.finances - finances)
            if health > 0 { details.append("−\(health) zdrowia") }
            if strength > 0 { details.append("−\(strength) siła") }
            if finances > 0 { details.append("−\(finances) monet") }
        case .plunder(let finances):
            stats.finances = max(0, stats.finances - finances)
            details.append("−\(finances) monet")
            if let removed = removeRandom(from: &itemIDs, catalog: itemsCatalog) {
                details.append("Utracono: \(removed.name)")
            }
        case .removeRandomAbility:
            if let removed = removeRandom(from: &abilityIDs, catalog: abilitiesCatalog) {
                details.append("Utracono zdolność: \(removed.name)")
            } else {
                details.append("Brak zdolności do utraty")
            }
        case .removeRandomItem:
            if let removed = removeRandom(from: &itemIDs, catalog: itemsCatalog) {
                details.append("Utracono przedmiot: \(removed.name)")
            } else {
                details.append("Brak przedmiotów do utraty")
            }
        case .queueBlock(let rounds):
            queueBlockRounds += rounds
            details.append("Kolejka zablokowana na \(rounds) tury")
        }

        return SpecialCardApplyResult(card: card, detailMessage: details.joined(separator: " · "))
    }

    private static func grantFromCatalog(
        catalog: [CreatedAbility],
        existing: inout [UUID]
    ) -> CreatedAbility? {
        guard let ability = PlayerAbilityGranting.grantRandom(catalog: catalog, existingIDs: existing) else {
            return nil
        }
        if !existing.contains(ability.id) {
            existing.append(ability.id)
        }
        return ability
    }

    private static func grantItem(
        catalog: [CreatedItem],
        existing: inout [UUID]
    ) -> CreatedItem? {
        let ownedNumericIDs = Set(
            existing.compactMap { id in catalog.first { $0.id == id }?.numericId }
        )
        let available = catalog.filter {
            !existing.contains($0.id) && !ownedNumericIDs.contains($0.numericId)
        }
        guard let item = available.randomElement() else { return nil }
        existing.append(item.id)
        return item
    }

    private static func removeRandom<T: Identifiable>(
        from ids: inout [UUID],
        catalog: [T]
    ) -> T? where T.ID == UUID {
        guard !ids.isEmpty, let removeID = ids.randomElement(),
              let item = catalog.first(where: { $0.id == removeID })
        else { return nil }
        ids.removeAll { $0 == removeID }
        return item
    }
}
