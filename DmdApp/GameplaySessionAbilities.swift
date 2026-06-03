//
//  GameplaySessionAbilities.swift
//  DmdApp
//

import Foundation

enum GameplaySessionAbilityKind: String, Codable, Hashable, CaseIterable {
    case turnDamage
    case boardMove
    case temporaryStatBoost
}

enum SessionStatBoostTarget: String, Codable, Hashable, CaseIterable {
    case character
    case weapon
    case brush

    var label: String {
        switch self {
        case .character: "Postać"
        case .weapon: "Broń"
        case .brush: "Pędzel"
        }
    }
}

struct GameplaySessionAbility: Identifiable, Codable, Hashable {
    let id: UUID
    var numericId: String
    var name: String
    var effectDescription: String
    var elementCategory: String
    var kind: GameplaySessionAbilityKind
    var turnDamage: Int
    var damageTurns: Int
    var boardMaxSpaces: Int
    var statBoostAmount: Int
    var statBoostTurns: Int
    var statBoostTarget: SessionStatBoostTarget

    var asCreatedAbility: CreatedAbility {
        CreatedAbility(
            id: id,
            numericId: numericId,
            name: name,
            effectDescription: effectDescription,
            elementCategory: elementCategory
        )
    }

    var kindLabel: String {
        switch kind {
        case .turnDamage: "Obrażenia"
        case .boardMove: "Plansza"
        case .temporaryStatBoost: "Wzmocnienie"
        }
    }
}

enum SessionAbilityAvailability: Codable, Hashable {
    case locked
    case unlocked
    case held(by: UUID)
}

struct GameplaySessionAbilityPoolState: Codable, Hashable {
    static let poolSize = 10

    var abilities: [GameplaySessionAbility]
    var availability: [UUID: SessionAbilityAvailability]

    var unlockedCount: Int {
        availability.values.filter {
            if case .unlocked = $0 { return true }
            return false
        }.count
    }

    var lockedCount: Int {
        availability.values.filter {
            if case .locked = $0 { return true }
            return false
        }.count
    }

    func ability(id: UUID) -> GameplaySessionAbility? {
        abilities.first { $0.id == id }
    }

    mutating func unlockRandom(count: Int = 1) -> [GameplaySessionAbility] {
        var unlocked: [GameplaySessionAbility] = []
        for _ in 0..<count {
            let locked = abilities.filter {
                if case .locked = availability[$0.id, default: .locked] { return true }
                return false
            }
            guard let pick = locked.randomElement() else { break }
            availability[pick.id] = .unlocked
            unlocked.append(pick)
        }
        return unlocked
    }

    @discardableResult
    mutating func grantRandom(to playerID: UUID) -> GameplaySessionAbility? {
        if unlockedCount == 0 {
            _ = unlockRandom()
        }

        let grantable = abilities.filter {
            availability[$0.id, default: .locked] == .unlocked
        }
        guard let pick = grantable.randomElement() else { return nil }
        availability[pick.id] = .held(by: playerID)
        return pick
    }

    mutating func consume(abilityID: UUID, from playerID: UUID) {
        guard case .held(by: playerID) = availability[abilityID, default: .locked] else { return }
        availability[abilityID] = .locked
    }

    func heldAbilityIDs(for playerID: UUID) -> [UUID] {
        abilities.compactMap { ability in
            if case .held(by: playerID) = availability[ability.id, default: .locked] {
                return ability.id
            }
            return nil
        }
    }
}

enum GameplaySessionAbilityFactory {
    static func makePool(elements: [String]) -> GameplaySessionAbilityPoolState {
        let kinds: [GameplaySessionAbilityKind] = [
            .turnDamage, .turnDamage, .turnDamage, .turnDamage,
            .boardMove, .boardMove, .boardMove,
            .temporaryStatBoost, .temporaryStatBoost, .temporaryStatBoost,
        ].shuffled()

        var usedNames: [String] = []
        var abilities: [GameplaySessionAbility] = []

        for (index, kind) in kinds.enumerated() {
            let element = elements.randomElement() ?? "Standard"
            let name = uniqueName(
                base: "\(nameParts.randomElement()!) \(nameSuffixes.randomElement()!)",
                existing: usedNames,
                suffix: index
            )
            usedNames.append(name)

            let ability = makeAbility(
                index: index,
                name: name,
                element: element,
                kind: kind
            )
            abilities.append(ability)
        }

        let availability = Dictionary(uniqueKeysWithValues: abilities.map { ($0.id, SessionAbilityAvailability.locked) })
        return GameplaySessionAbilityPoolState(abilities: abilities, availability: availability)
    }

    private static func makeAbility(
        index: Int,
        name: String,
        element: String,
        kind: GameplaySessionAbilityKind
    ) -> GameplaySessionAbility {
        let numericId = String(7_001 + index)
        let elementLabel = element.lowercased()

        switch kind {
        case .turnDamage:
            let instant = Bool.random()
            let damage = Int.random(in: 10...35)
            let turns = instant ? 1 : Int.random(in: 2...4)
            let perTurn = instant ? damage : Int.random(in: 6...18)
            let description: String
            if instant {
                description = "\(name): zadaje \(damage) obrażeń \(elementLabel) jednemu wybranemu przeciwnikowi w tej turze (tylko cel, bez strefy)."
            } else {
                description = "\(name): co turę przez \(turns) tury zadaje \(perTurn) obrażeń \(elementLabel) jednemu wybranemu graczowi."
            }
            return GameplaySessionAbility(
                id: UUID(),
                numericId: numericId,
                name: name,
                effectDescription: description,
                elementCategory: element,
                kind: .turnDamage,
                turnDamage: perTurn,
                damageTurns: turns,
                boardMaxSpaces: 0,
                statBoostAmount: 0,
                statBoostTurns: 0,
                statBoostTarget: .character
            )

        case .boardMove:
            let spaces = Int.random(in: 1...4)
            let description = "\(name): przesuń wybranego uczestnika na planszy o 1–\(spaces) pól do tyłu, do przodu lub w wybranym kierunku (pojedynczy cel)."
            return GameplaySessionAbility(
                id: UUID(),
                numericId: numericId,
                name: name,
                effectDescription: description,
                elementCategory: element,
                kind: .boardMove,
                turnDamage: 0,
                damageTurns: 0,
                boardMaxSpaces: spaces,
                statBoostAmount: 0,
                statBoostTurns: 0,
                statBoostTarget: .character
            )

        case .temporaryStatBoost:
            let target = SessionStatBoostTarget.allCases.randomElement() ?? .character
            let amount = Int.random(in: 8...20)
            let turns = Int.random(in: 2...4)
            let description = "\(name): tymczasowo +\(amount) do \(target.label.lowercased()) na \(turns) tury (jednorazowe użycie)."
            return GameplaySessionAbility(
                id: UUID(),
                numericId: numericId,
                name: name,
                effectDescription: description,
                elementCategory: element,
                kind: .temporaryStatBoost,
                turnDamage: 0,
                damageTurns: 0,
                boardMaxSpaces: 0,
                statBoostAmount: amount,
                statBoostTurns: turns,
                statBoostTarget: target
            )
        }
    }

    private static let nameParts = [
        "Iskra", "Cios", "Fala", "Runa", "Cień", "Płomień", "Lód", "Błysk", "Zew", "Gniew",
    ]

    private static let nameSuffixes = [
        "Pojedynczy", "Precyzji", "Taktyki", "Manewru", "Impulsu", "Ciosu", "Przesunięcia",
    ]

    private static func uniqueName(base: String, existing: [String], suffix: Int) -> String {
        if !existing.contains(base) { return base }
        let candidate = "\(base) \(suffix + 1)"
        if !existing.contains(candidate) { return candidate }
        return "\(base) #\(suffix + 1)"
    }
}

struct ActiveTurnDamageEffect: Identifiable, Codable, Hashable {
    let id: UUID
    let targetPlayerID: UUID
    let sourceName: String
    var damagePerTurn: Int
    var turnsRemaining: Int

    init(
        id: UUID = UUID(),
        targetPlayerID: UUID,
        sourceName: String,
        damagePerTurn: Int,
        turnsRemaining: Int
    ) {
        self.id = id
        self.targetPlayerID = targetPlayerID
        self.sourceName = sourceName
        self.damagePerTurn = damagePerTurn
        self.turnsRemaining = turnsRemaining
    }
}

struct ActiveTemporaryBoost: Identifiable, Codable, Hashable {
    let id: UUID
    let target: SessionStatBoostTarget
    var turnsRemaining: Int
    var strengthDelta: Int
    var abilitiesDelta: Int
    var healthDelta: Int

    init(
        id: UUID = UUID(),
        target: SessionStatBoostTarget,
        turnsRemaining: Int,
        strengthDelta: Int = 0,
        abilitiesDelta: Int = 0,
        healthDelta: Int = 0
    ) {
        self.id = id
        self.target = target
        self.turnsRemaining = turnsRemaining
        self.strengthDelta = strengthDelta
        self.abilitiesDelta = abilitiesDelta
        self.healthDelta = healthDelta
    }
}

enum SessionAbilityExecutor {
    static func applyTurnDamageActivation(
        ability: GameplaySessionAbility,
        targetPlayerID: UUID,
        stats: inout [UUID: PlayerRuntimeStats],
        activeEffects: inout [ActiveTurnDamageEffect]
    ) -> String {
        guard var targetStats = stats[targetPlayerID] else {
            return "Brak statystyk celu."
        }

        if ability.damageTurns <= 1 {
            targetStats.health = max(0, targetStats.health - ability.turnDamage)
            stats[targetPlayerID] = targetStats
            return "−\(ability.turnDamage) zdrowia celu (obrażenia turowe, jeden przeciwnik)."
        }

        activeEffects.append(
            ActiveTurnDamageEffect(
                targetPlayerID: targetPlayerID,
                sourceName: ability.name,
                damagePerTurn: ability.turnDamage,
                turnsRemaining: ability.damageTurns
            )
        )
        targetStats.health = max(0, targetStats.health - ability.turnDamage)
        stats[targetPlayerID] = targetStats
        return "−\(ability.turnDamage) zdrowia teraz · \(ability.damageTurns) tury po \(ability.turnDamage) obrażeń (cel pojedynczy)."
    }

    static func applyBoardMove(
        targetPlayerID: UUID,
        spaces: Int,
        positions: inout [UUID: Int]
    ) -> String {
        let current = positions[targetPlayerID, default: 0]
        let updated = max(0, current + spaces)
        positions[targetPlayerID] = updated
        if spaces >= 0 {
            return "Plansza: +\(spaces) pól (pozycja \(updated))."
        }
        return "Plansza: \(spaces) pól (pozycja \(updated))."
    }

    static func applyTemporaryBoost(
        ability: GameplaySessionAbility,
        targetPlayerID: UUID,
        stats: inout [UUID: PlayerRuntimeStats],
        boosts: inout [ActiveTemporaryBoost]
    ) -> String {
        guard var targetStats = stats[targetPlayerID] else {
            return "Brak statystyk celu."
        }

        var boost = ActiveTemporaryBoost(
            target: ability.statBoostTarget,
            turnsRemaining: ability.statBoostTurns
        )

        switch ability.statBoostTarget {
        case .character:
            boost.strengthDelta = ability.statBoostAmount / 2
            boost.healthDelta = ability.statBoostAmount
            targetStats.health = min(100, targetStats.health + ability.statBoostAmount)
            targetStats.strength = min(100, targetStats.strength + ability.statBoostAmount / 2)
        case .weapon:
            boost.strengthDelta = ability.statBoostAmount
            targetStats.strength = min(100, targetStats.strength + ability.statBoostAmount)
        case .brush:
            boost.strengthDelta = ability.statBoostAmount / 2
            targetStats.strength = min(100, targetStats.strength + ability.statBoostAmount / 2)
        }

        stats[targetPlayerID] = targetStats
        boosts.append(boost)
        return "+\(ability.statBoostAmount) do \(ability.statBoostTarget.label.lowercased()) na \(ability.statBoostTurns) tury."
    }

    static func processTurnStart(
        for playerID: UUID,
        stats: inout [UUID: PlayerRuntimeStats],
        turnDamageEffects: inout [ActiveTurnDamageEffect],
        temporaryBoosts: inout [ActiveTemporaryBoost]
    ) -> [String] {
        var messages: [String] = []

        for index in turnDamageEffects.indices.reversed() {
            guard turnDamageEffects[index].targetPlayerID == playerID else { continue }
            let effect = turnDamageEffects[index]
            if var targetStats = stats[playerID] {
                targetStats.health = max(0, targetStats.health - effect.damagePerTurn)
                stats[playerID] = targetStats
                messages.append("Obrażenia z „\(effect.sourceName)”: −\(effect.damagePerTurn) zdrowia.")
            }
            turnDamageEffects[index].turnsRemaining -= 1
            if turnDamageEffects[index].turnsRemaining <= 0 {
                turnDamageEffects.remove(at: index)
            }
        }

        for index in temporaryBoosts.indices.reversed() {
            temporaryBoosts[index].turnsRemaining -= 1
            if temporaryBoosts[index].turnsRemaining <= 0 {
                let expired = temporaryBoosts.remove(at: index)
                if var targetStats = stats[playerID] {
                    targetStats.strength = max(0, targetStats.strength - expired.strengthDelta)
                    targetStats.health = max(0, targetStats.health - expired.healthDelta)
                    stats[playerID] = targetStats
                    messages.append("Wygasł bonus \(expired.target.label.lowercased()).")
                }
            }
        }

        return messages
    }
}
