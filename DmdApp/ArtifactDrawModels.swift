//
//  ArtifactDrawModels.swift
//  DmdApp
//

import Foundation

enum ArtifactMisfortuneKind: Hashable {
    case statsReduction(health: Int, strength: Int)
    case fundReduction(amount: Int)
    case queueBlock(rounds: Int)

    var title: String {
        switch self {
        case .statsReduction: "Pech — osłabienie"
        case .fundReduction: "Pech — utrata monet"
        case .queueBlock: "Pech — blokada kolejki"
        }
    }

    var summary: String {
        switch self {
        case let .statsReduction(health, strength):
            "−\(health) zdrowia, −\(strength) siły."
        case let .fundReduction(amount):
            "−\(amount) monet."
        case let .queueBlock(rounds):
            "Kolejka zablokowana na \(rounds) \(rounds == 1 ? "turę" : rounds < 5 ? "tury" : "tur")."
        }
    }

    var icon: String {
        switch self {
        case .statsReduction: "arrow.down.circle.fill"
        case .fundReduction: "dollarsign.circle"
        case .queueBlock: "hourglass"
        }
    }
}

enum ArtifactStatBoostTarget: Hashable {
    case strength
    case health

    var label: String {
        switch self {
        case .strength: "Siła"
        case .health: "Zdrowie"
        }
    }

    var icon: String {
        switch self {
        case .strength: "bolt.fill"
        case .health: "heart.fill"
        }
    }
}

enum ArtifactOutcomeKind: Hashable {
    case finances(amount: Int)
    case ability(CreatedAbility)
    case statBoost(target: ArtifactStatBoostTarget, amount: Int)
    case misfortune(ArtifactMisfortuneKind)

    var title: String {
        switch self {
        case .finances: "Skarb monet"
        case .ability: "Nowa zdolność"
        case let .statBoost(target, _): "Wzmocnienie — \(target.label)"
        case let .misfortune(kind): kind.title
        }
    }

    var summary: String {
        switch self {
        case let .finances(amount): "+\(amount) monet."
        case let .ability(ability): ability.name
        case let .statBoost(target, amount): "+\(amount) \(target.label.lowercased())."
        case let .misfortune(kind): kind.summary
        }
    }

    var icon: String {
        switch self {
        case .finances: "dollarsign.circle.fill"
        case .ability: "sparkles"
        case let .statBoost(target, _): target.icon
        case let .misfortune(kind): kind.icon
        }
    }

    var isPositive: Bool {
        if case .misfortune = self { return false }
        return true
    }
}

struct ArtifactOutcome: Identifiable, Hashable {
    let id = UUID()
    let kind: ArtifactOutcomeKind
    let detailMessage: String
    let brushBonusSummary: String?

    var title: String { kind.title }
    var summary: String { kind.summary }
    var icon: String { kind.icon }
    var isPositive: Bool { kind.isPositive }

    init(kind: ArtifactOutcomeKind, detailMessage: String, brushBonusSummary: String? = nil) {
        self.kind = kind
        self.detailMessage = detailMessage
        self.brushBonusSummary = brushBonusSummary
    }
}

struct ArtifactLootOdds {
    let misfortune: Int
    let ability: Int
    let luckyReward: Int

    var summary: String {
        "Szanse: zdolność \(ability)%, nagroda \(luckyReward)% (statystyka lub monety), pech \(misfortune)%"
    }

    static let standard = ArtifactLootOdds(misfortune: 5, ability: 25, luckyReward: 70)

    static func fromCategoryOdds(_ odds: FieldCategoryOdds) -> ArtifactLootOdds {
        ArtifactLootOdds(
            misfortune: odds.misfortunePercent,
            ability: odds.abilityPercent,
            luckyReward: odds.financesPercent + odds.statisticsPercent
        )
    }

    /// Bonus do szansy na zdolność z najlepszego posiadanego pędzla (wg ceny).
    static func forPlayer(
        ownedItemIDs: [UUID],
        catalog: [CreatedItem],
        baseOdds: FieldCategoryOdds = .artifactDefaults()
    ) -> (odds: ArtifactLootOdds, brushName: String?, brushAbilityBonus: Int) {
        let owned = catalog.filter { ownedItemIDs.contains($0.id) }
        guard let bestBrush = owned.filter(\.isBrush).max(by: { lhs, rhs in
            let left = CreatorStats.brushArtifactLuckPercent(for: lhs)
            let right = CreatorStats.brushArtifactLuckPercent(for: rhs)
            if left != right { return left < right }
            return lhs.cost < rhs.cost
        }) else {
            return (fromCategoryOdds(baseOdds), nil, 0)
        }

        let abilityBonus = CreatorStats.brushArtifactLuckPercent(for: bestBrush)
        var odds = fromCategoryOdds(baseOdds)
        odds = ArtifactLootOdds(
            misfortune: odds.misfortune,
            ability: min(95, odds.ability + abilityBonus),
            luckyReward: max(0, 100 - odds.misfortune - min(95, odds.ability + abilityBonus))
        )

        return (odds, bestBrush.name, abilityBonus)
    }

    /// Bonus do szansy na zdolność z najlepszego posiadanego pędzla (wg statystyki %).
    static func forPlayer(ownedItemIDs: [UUID], catalog: [CreatedItem]) -> (odds: ArtifactLootOdds, brushName: String?, brushAbilityBonus: Int) {
        forPlayer(ownedItemIDs: ownedItemIDs, catalog: catalog, baseOdds: .artifactDefaults())
    }
}

enum ArtifactDrawRoller {
    static func roll(
        itemsCatalog: [CreatedItem],
        abilitiesCatalog: [CreatedAbility],
        existingItemIDs: [UUID],
        existingAbilityIDs: [UUID],
        rules: ArtifactGameRules = ArtifactGameRules(),
        pickSessionAbility: (() -> GameplaySessionAbility?)? = nil
    ) -> ArtifactOutcome {
        let lootContext = ArtifactLootOdds.forPlayer(
            ownedItemIDs: existingItemIDs,
            catalog: itemsCatalog,
            baseOdds: rules.categoryOdds
        )
        let odds = lootContext.odds
        let roll = Int.random(in: 0..<100)
        let category = rules.categoryOdds.category(for: roll)

        let brushNote: String? = {
            guard let brushName = lootContext.brushName else {
                return "Bez pędzla — \(ArtifactLootOdds.standard.summary)."
            }
            let bonus = lootContext.brushAbilityBonus
            let bonusText = bonus > 0 ? " (+\(bonus)% szansy na zdolność)" : ""
            return "Pędzel „\(brushName)”\(bonusText) — \(odds.summary)."
        }()

        switch category {
        case .misfortune:
            return misfortuneOutcome(rules: rules, brushBonusSummary: brushNote)
        case .ability:
            if let sessionAbility = pickSessionAbility?() {
                return ArtifactOutcome(
                    kind: .ability(sessionAbility.asCreatedAbility),
                    detailMessage: "Zdolność sesji: \(sessionAbility.name)",
                    brushBonusSummary: brushNote
                )
            }
            if let ability = grantRandomAbility(catalog: abilitiesCatalog, existing: existingAbilityIDs) {
                return ArtifactOutcome(
                    kind: .ability(ability),
                    detailMessage: "Zdolność: \(ability.name)",
                    brushBonusSummary: brushNote
                )
            }
            return luckyFinancesOutcome(rules: rules, brushBonusSummary: brushNote)
        case .finances:
            return luckyFinancesOutcome(rules: rules, brushBonusSummary: brushNote)
        case .statistics:
            return statBoostOutcome(rules: rules, brushBonusSummary: brushNote)
        }
    }

    private static func luckyFinancesOutcome(rules: ArtifactGameRules, brushBonusSummary: String?) -> ArtifactOutcome {
        let amount = Int.random(in: rules.financesMin...max(rules.financesMin, rules.financesMax))
        return ArtifactOutcome(
            kind: .finances(amount: amount),
            detailMessage: "+\(amount) monet",
            brushBonusSummary: brushBonusSummary
        )
    }

    private static func statBoostOutcome(rules: ArtifactGameRules, brushBonusSummary: String?) -> ArtifactOutcome {
        let target: ArtifactStatBoostTarget = Bool.random() ? .strength : .health
        let amount = Int.random(in: rules.statBoostMin...max(rules.statBoostMin, rules.statBoostMax))
        return ArtifactOutcome(
            kind: .statBoost(target: target, amount: amount),
            detailMessage: "+\(amount) \(target.label.lowercased())",
            brushBonusSummary: brushBonusSummary
        )
    }

    private static func misfortuneOutcome(rules: ArtifactGameRules, brushBonusSummary: String? = nil) -> ArtifactOutcome {
        switch Int.random(in: 0..<3) {
        case 0:
            let health = Int.random(in: rules.misfortuneHealthMin...max(rules.misfortuneHealthMin, rules.misfortuneHealthMax))
            let strength = Int.random(in: rules.misfortuneStrengthMin...max(rules.misfortuneStrengthMin, rules.misfortuneStrengthMax))
            let kind = ArtifactMisfortuneKind.statsReduction(health: health, strength: strength)
            return ArtifactOutcome(
                kind: .misfortune(kind),
                detailMessage: "−\(health) zdrowia, −\(strength) siły",
                brushBonusSummary: brushBonusSummary
            )
        case 1:
            let amount = Int.random(in: rules.misfortuneFundMin...max(rules.misfortuneFundMin, rules.misfortuneFundMax))
            let kind = ArtifactMisfortuneKind.fundReduction(amount: amount)
            return ArtifactOutcome(
                kind: .misfortune(kind),
                detailMessage: "−\(amount) monet",
                brushBonusSummary: brushBonusSummary
            )
        default:
            let rounds = Int.random(in: rules.misfortuneQueueBlockMin...max(rules.misfortuneQueueBlockMin, rules.misfortuneQueueBlockMax))
            let kind = ArtifactMisfortuneKind.queueBlock(rounds: rounds)
            return ArtifactOutcome(
                kind: .misfortune(kind),
                detailMessage: "Blokada kolejki na \(rounds) tury",
                brushBonusSummary: brushBonusSummary
            )
        }
    }

    private static func grantRandomAbility(
        catalog: [CreatedAbility],
        existing: [UUID]
    ) -> CreatedAbility? {
        PlayerAbilityGranting.grantRandom(catalog: catalog, existingIDs: existing)
    }
}

enum ArtifactDrawApplier {
    struct ApplyResult {
        let detailMessage: String
        let grantedItemID: UUID?
        let grantedAbilityID: UUID?
        let removedItemID: UUID?
    }

    static func apply(
        outcome: ArtifactOutcome,
        stats: inout PlayerRuntimeStats,
        abilityIDs: inout [UUID],
        itemIDs: inout [UUID],
        queueBlockRounds: inout Int
    ) -> ApplyResult {
        var grantedItemID: UUID?
        var grantedAbilityID: UUID?
        let removedItemID: UUID? = nil

        switch outcome.kind {
        case let .finances(amount):
            stats.finances = min(9999, stats.finances + amount)
        case let .ability(ability):
            if !abilityIDs.contains(ability.id) {
                abilityIDs.append(ability.id)
            }
            grantedAbilityID = ability.id
        case let .statBoost(target, amount):
            switch target {
            case .strength:
                stats.strength = min(100, stats.strength + amount)
            case .health:
                stats.health = min(100, stats.health + amount)
            }
        case let .misfortune(kind):
            switch kind {
            case let .statsReduction(health, strength):
                stats.health = max(0, stats.health - health)
                stats.strength = max(0, stats.strength - strength)
            case let .fundReduction(amount):
                stats.finances = max(0, stats.finances - amount)
            case let .queueBlock(rounds):
                queueBlockRounds += rounds
            }
        }

        return ApplyResult(
            detailMessage: outcome.detailMessage,
            grantedItemID: grantedItemID,
            grantedAbilityID: grantedAbilityID,
            removedItemID: removedItemID
        )
    }
}
