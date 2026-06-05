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

enum GameplaySessionAbilityScope: String, Codable, Hashable, CaseIterable {
    case bossFight
    case arenaPvP
    case board

    var label: String {
        switch self {
        case .bossFight: "Walka z bossem"
        case .arenaPvP: "Arena PvP"
        case .board: "Plansza"
        }
    }
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
    var scope: GameplaySessionAbilityScope
    var turnDamage: Int
    var damageTurns: Int
    var boardMaxSpaces: Int
    var statBoostAmount: Int
    var statBoostTurns: Int
    var statBoostTarget: SessionStatBoostTarget

    enum CodingKeys: String, CodingKey {
        case id, numericId, name, effectDescription, elementCategory, kind, scope
        case turnDamage, damageTurns, boardMaxSpaces, statBoostAmount, statBoostTurns, statBoostTarget
    }

    init(
        id: UUID,
        numericId: String,
        name: String,
        effectDescription: String,
        elementCategory: String,
        kind: GameplaySessionAbilityKind,
        scope: GameplaySessionAbilityScope,
        turnDamage: Int,
        damageTurns: Int,
        boardMaxSpaces: Int,
        statBoostAmount: Int,
        statBoostTurns: Int,
        statBoostTarget: SessionStatBoostTarget
    ) {
        self.id = id
        self.numericId = numericId
        self.name = name
        self.effectDescription = effectDescription
        self.elementCategory = elementCategory
        self.kind = kind
        self.scope = scope
        self.turnDamage = turnDamage
        self.damageTurns = damageTurns
        self.boardMaxSpaces = boardMaxSpaces
        self.statBoostAmount = statBoostAmount
        self.statBoostTurns = statBoostTurns
        self.statBoostTarget = statBoostTarget
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        numericId = try container.decode(String.self, forKey: .numericId)
        name = try container.decode(String.self, forKey: .name)
        effectDescription = try container.decode(String.self, forKey: .effectDescription)
        elementCategory = try container.decode(String.self, forKey: .elementCategory)
        kind = try container.decode(GameplaySessionAbilityKind.self, forKey: .kind)
        scope = try container.decodeIfPresent(GameplaySessionAbilityScope.self, forKey: .scope) ?? .board
        turnDamage = try container.decode(Int.self, forKey: .turnDamage)
        damageTurns = try container.decode(Int.self, forKey: .damageTurns)
        boardMaxSpaces = try container.decode(Int.self, forKey: .boardMaxSpaces)
        statBoostAmount = try container.decode(Int.self, forKey: .statBoostAmount)
        statBoostTurns = try container.decode(Int.self, forKey: .statBoostTurns)
        statBoostTarget = try container.decode(SessionStatBoostTarget.self, forKey: .statBoostTarget)
    }

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
        case .boardMove: "Ruch"
        case .temporaryStatBoost: "Wzmocnienie"
        }
    }

    var scopeLabel: String {
        "\(scope.label) · \(kindLabel)"
    }
}

struct PlayerSessionAbilityProgress: Codable, Hashable {
    var collectedAbilityIDs: Set<UUID> = []
}

private enum LegacySessionAbilityAvailability: Codable, Hashable {
    case locked
    case unlocked
    case held(by: UUID)
}

struct GameplaySessionAbilityPoolState: Codable, Hashable {
    static let poolSize = 10

    var abilities: [GameplaySessionAbility]
    var playerProgress: [UUID: PlayerSessionAbilityProgress]

    enum CodingKeys: String, CodingKey {
        case abilities
        case playerProgress
        case availability
    }

    init(abilities: [GameplaySessionAbility], playerProgress: [UUID: PlayerSessionAbilityProgress] = [:]) {
        self.abilities = abilities
        self.playerProgress = playerProgress
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        abilities = try container.decode([GameplaySessionAbility].self, forKey: .abilities)
        if let progress = try container.decodeIfPresent([UUID: PlayerSessionAbilityProgress].self, forKey: .playerProgress) {
            playerProgress = progress
        } else if let legacy = try container.decodeIfPresent(
            [UUID: LegacySessionAbilityAvailability].self,
            forKey: .availability
        ) {
            playerProgress = Self.migrateLegacyAvailability(legacy)
        } else {
            playerProgress = [:]
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(abilities, forKey: .abilities)
        try container.encode(playerProgress, forKey: .playerProgress)
    }

    private static func migrateLegacyAvailability(
        _ availability: [UUID: LegacySessionAbilityAvailability]
    ) -> [UUID: PlayerSessionAbilityProgress] {
        var migrated: [UUID: PlayerSessionAbilityProgress] = [:]
        for (abilityID, state) in availability {
            guard case .held(let playerID) = state else { continue }
            var progress = migrated[playerID] ?? PlayerSessionAbilityProgress()
            progress.collectedAbilityIDs.insert(abilityID)
            migrated[playerID] = progress
        }
        return migrated
    }

    func ability(id: UUID) -> GameplaySessionAbility? {
        abilities.first { $0.id == id }
    }

    mutating func ensurePlayer(_ playerID: UUID) {
        if playerProgress[playerID] == nil {
            playerProgress[playerID] = PlayerSessionAbilityProgress()
        }
    }

    func collectedCount(for playerID: UUID) -> Int {
        playerProgress[playerID]?.collectedAbilityIDs.count ?? 0
    }

    func hasCollected(_ abilityID: UUID, for playerID: UUID) -> Bool {
        playerProgress[playerID]?.collectedAbilityIDs.contains(abilityID) ?? false
    }

    func collectedAbilityIDs(for playerID: UUID) -> [UUID] {
        Array(playerProgress[playerID]?.collectedAbilityIDs ?? []).sorted { $0.uuidString < $1.uuidString }
    }

    func collectedAbilities(for playerID: UUID) -> [GameplaySessionAbility] {
        let ids = playerProgress[playerID]?.collectedAbilityIDs ?? []
        return abilities.filter { ids.contains($0.id) }
    }

    @discardableResult
    mutating func collectRandom(for playerID: UUID, count: Int = 1) -> [GameplaySessionAbility] {
        ensurePlayer(playerID)
        var granted: [GameplaySessionAbility] = []
        for _ in 0..<count {
            let owned = playerProgress[playerID]?.collectedAbilityIDs ?? []
            let candidates = abilities.filter { !owned.contains($0.id) }
            guard let pick = candidates.randomElement() else { break }
            playerProgress[playerID]?.collectedAbilityIDs.insert(pick.id)
            granted.append(pick)
        }
        return granted
    }

    @discardableResult
    mutating func grantRandom(to playerID: UUID) -> GameplaySessionAbility? {
        collectRandom(for: playerID, count: 1).first
    }

    mutating func consume(abilityID: UUID, from playerID: UUID) {
        playerProgress[playerID]?.collectedAbilityIDs.remove(abilityID)
    }

    func heldAbilityIDs(for playerID: UUID) -> [UUID] {
        collectedAbilityIDs(for: playerID)
    }
}

enum GameplaySessionAbilityFactory {
    private struct AbilityBlueprint {
        let kind: GameplaySessionAbilityKind
        let scope: GameplaySessionAbilityScope
    }

    static func makePool(elements: [String]) -> GameplaySessionAbilityPoolState {
        let blueprints: [AbilityBlueprint] = [
            AbilityBlueprint(kind: .turnDamage, scope: .bossFight),
            AbilityBlueprint(kind: .turnDamage, scope: .bossFight),
            AbilityBlueprint(kind: .turnDamage, scope: .arenaPvP),
            AbilityBlueprint(kind: .turnDamage, scope: .arenaPvP),
            AbilityBlueprint(kind: .boardMove, scope: .board),
            AbilityBlueprint(kind: .boardMove, scope: .board),
            AbilityBlueprint(kind: .boardMove, scope: .board),
            AbilityBlueprint(kind: .temporaryStatBoost, scope: .bossFight),
            AbilityBlueprint(kind: .temporaryStatBoost, scope: .arenaPvP),
            AbilityBlueprint(kind: .temporaryStatBoost, scope: .board),
        ].shuffled()

        var usedNames: [String] = []
        var abilities: [GameplaySessionAbility] = []

        for (index, blueprint) in blueprints.enumerated() {
            let element = elements.randomElement() ?? "Standard"
            let name = uniqueName(
                base: "\(nameParts.randomElement()!) \(nameSuffixes.randomElement()!)",
                existing: usedNames,
                suffix: index
            )
            usedNames.append(name)

            abilities.append(
                makeAbility(
                    index: index,
                    name: name,
                    element: element,
                    kind: blueprint.kind,
                    scope: blueprint.scope
                )
            )
        }

        return GameplaySessionAbilityPoolState(abilities: abilities)
    }

    private static func makeAbility(
        index: Int,
        name: String,
        element: String,
        kind: GameplaySessionAbilityKind,
        scope: GameplaySessionAbilityScope
    ) -> GameplaySessionAbility {
        let numericId = String(7_001 + index)
        let elementLabel = element.lowercased()
        let scopeNote = "Działa tylko w kontekście: \(scope.label)."

        switch kind {
        case .turnDamage:
            let instant = Bool.random()
            let burstDamage = Int.random(in: 32...58)
            let turns = instant ? 1 : Int.random(in: 3...5)
            let perTurn = instant ? burstDamage : Int.random(in: 18...34)
            let description: String
            if instant {
                description = "\(name): potężny cios \(elementLabel) — \(burstDamage) obrażeń jednemu celowi. \(scopeNote)"
            } else {
                description = "\(name): przez \(turns) tury co turę zadaje \(perTurn) obrażeń \(elementLabel) wybranemu celowi. \(scopeNote)"
            }
            return GameplaySessionAbility(
                id: UUID(),
                numericId: numericId,
                name: name,
                effectDescription: description,
                elementCategory: element,
                kind: .turnDamage,
                scope: scope,
                turnDamage: perTurn,
                damageTurns: turns,
                boardMaxSpaces: 0,
                statBoostAmount: 0,
                statBoostTurns: 0,
                statBoostTarget: .character
            )

        case .boardMove:
            let spaces = Int.random(in: 3...7)
            let description = "\(name): przesuwa wybranego gracza na planszy o do \(spaces) pól (do przodu lub do tyłu). \(scopeNote)"
            return GameplaySessionAbility(
                id: UUID(),
                numericId: numericId,
                name: name,
                effectDescription: description,
                elementCategory: element,
                kind: .boardMove,
                scope: scope,
                turnDamage: 0,
                damageTurns: 0,
                boardMaxSpaces: spaces,
                statBoostAmount: 0,
                statBoostTurns: 0,
                statBoostTarget: .character
            )

        case .temporaryStatBoost:
            let target = SessionStatBoostTarget.allCases.randomElement() ?? .character
            let amount = Int.random(in: 28...48)
            let turns = Int.random(in: 4...7)
            let description = "\(name): +\(amount) do \(target.label.lowercased()) na \(turns) tur. \(scopeNote)"
            return GameplaySessionAbility(
                id: UUID(),
                numericId: numericId,
                name: name,
                effectDescription: description,
                elementCategory: element,
                kind: .temporaryStatBoost,
                scope: scope,
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
