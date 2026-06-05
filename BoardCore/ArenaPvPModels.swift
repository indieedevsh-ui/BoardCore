//
//  ArenaPvPModels.swift
//  BoardCore
//

import Foundation

// MARK: - Fighter

struct ArenaPvPFighter: Identifiable, Equatable {
    let player: PlayerCharacter
    let displayStats: BossFightDisplayStats
    let maxEnergy: Int
    var currentEnergy: Int

    var id: UUID { player.id }

    static func make(
        player: PlayerCharacter,
        baseStats: PlayerRuntimeStats,
        equipment: PlayerEquipmentMap,
        catalog: [CreatedItem]
    ) -> ArenaPvPFighter {
        let effective = PlayerEquipment.effectiveRuntimeStats(
            base: baseStats,
            for: player.id,
            equipment: equipment,
            catalog: catalog
        )
        let bonus = PlayerEquipment.loadoutBonus(
            for: player.id,
            equipment: equipment,
            catalog: catalog
        )
        let display = BossFightDisplayStats(
            health: effective.health,
            strength: effective.strength,
            abilities: effective.abilities,
            armor: min(100, bonus.armor)
        )
        let energy = max(1, Int((Double(effective.health) * 2.5).rounded()))
        return ArenaPvPFighter(
            player: player,
            displayStats: display,
            maxEnergy: energy,
            currentEnergy: energy
        )
    }
}

struct ArenaPvPFighterReveal: Identifiable, Equatable {
    let id = UUID()
    let fighter: ArenaPvPFighter
    let slotLabel: String
}

// MARK: - Combat

enum ArenaPvPFlowPhase: Equatable {
    case scanning
    case combat
    case settlement
}

struct ArenaPvPOutcome: Equatable {
    let winnerID: UUID
    let loserID: UUID
    let transferAmount: Int
    let xpTransfer: Int
}

enum ArenaPvPBallKind: Equatable {
    case bonus
    case penalty
}

enum ArenaPvPTurnStep: Equatable {
    case ballTapping(endsAt: Date)
    case strikePowerReveal(endsAt: Date, abilityWindowOpen: Bool)
    case damageReveal(endsAt: Date, damage: Int, totalPowerPercent: Int)
    case energyDrain(
        endsAt: Date,
        defenderIndex: Int,
        energyBefore: Int,
        energyAfter: Int
    )
}

struct ArenaPvPTapBall: Identifiable, Equatable {
    let id = UUID()
    let normalizedX: Double
    let normalizedY: Double
    let createdAt: Date
    let kind: ArenaPvPBallKind
}

struct ArenaPvPStrikeAbilityBonus: Equatable {
    let abilityID: UUID
    let abilityName: String
    let bonusDamage: Int
    let powerPercentBonus: Int
}

struct ArenaPvPCombatState: Equatable {
    var fighters: [ArenaPvPFighter]
    var activeFighterIndex: Int
    var step: ArenaPvPTurnStep
    var ballPowerPercent: Int
    var punchPowerPercent: Int
    var activeBalls: [ArenaPvPTapBall]
    var lastDamage: Int
    var lastHitSummary: String
    var strikeAbilityBonus: ArenaPvPStrikeAbilityBonus?
    var winnerID: UUID?

    var activeFighter: ArenaPvPFighter {
        fighters[activeFighterIndex]
    }

    var defenderIndex: Int {
        activeFighterIndex == 0 ? 1 : 0
    }

    var defender: ArenaPvPFighter {
        fighters[defenderIndex]
    }

    var isFinished: Bool {
        winnerID != nil
    }
}

enum ArenaPvPCombatEngine {
    static let ballPhaseDuration: TimeInterval = 10
    static let strikePowerRevealDuration: TimeInterval = 2.5
    static let damageRevealDuration: TimeInterval = 2.0
    static let energyDrainDuration: TimeInterval = 1.85
    static let ballPowerPerTap = 5
    static let maxBallPower = 100
    static let ballSpawnInterval: TimeInterval = 0.58
    static let ballLifetime: TimeInterval = 0.85
    static let maxLiveBalls = 6
    static let penaltyBallChance = 0.24
    static let penaltyPowerLoss = 10

    static func makeCombat(fighters: [ArenaPvPFighter], now: Date = Date()) -> ArenaPvPCombatState {
        ArenaPvPCombatState(
            fighters: fighters,
            activeFighterIndex: 0,
            step: .ballTapping(endsAt: now.addingTimeInterval(ballPhaseDuration)),
            ballPowerPercent: 0,
            punchPowerPercent: 0,
            activeBalls: [],
            lastDamage: 0,
            lastHitSummary: "",
            winnerID: nil
        )
    }

    static func tapBall(state: inout ArenaPvPCombatState, ballID: UUID) {
        guard case .ballTapping = state.step else { return }
        guard let ball = state.activeBalls.first(where: { $0.id == ballID }) else { return }
        state.activeBalls.removeAll { $0.id == ballID }
        switch ball.kind {
        case .bonus:
            state.ballPowerPercent = min(maxBallPower, state.ballPowerPercent + ballPowerPerTap)
        case .penalty:
            state.ballPowerPercent = max(0, state.ballPowerPercent - penaltyPowerLoss)
        }
    }

    static func spawnBallsIfNeeded(state: inout ArenaPvPCombatState, now: Date) {
        guard case .ballTapping = state.step else { return }
        guard state.activeBalls.count < maxLiveBalls else { return }
        if let last = state.activeBalls.last,
           now.timeIntervalSince(last.createdAt) < ballSpawnInterval {
            return
        }
        if state.activeBalls.isEmpty || now.timeIntervalSince(state.activeBalls.last!.createdAt) >= ballSpawnInterval {
            let kind: ArenaPvPBallKind = Double.random(in: 0...1) < penaltyBallChance ? .penalty : .bonus
            state.activeBalls.append(
                ArenaPvPTapBall(
                    normalizedX: Double.random(in: 0.12...0.88),
                    normalizedY: Double.random(in: 0.22...0.72),
                    createdAt: now,
                    kind: kind
                )
            )
        }
    }

    static func advanceStepIfNeeded(
        state: inout ArenaPvPCombatState,
        now: Date = Date(),
        arenaAbilityCountForActiveFighter: Int = 0
    ) {
        switch state.step {
        case .ballTapping(let endsAt):
            if now >= endsAt {
                state.punchPowerPercent = state.ballPowerPercent
                let abilityWindowOpen = arenaAbilityCountForActiveFighter > 0
                state.step = .strikePowerReveal(
                    endsAt: now.addingTimeInterval(strikePowerRevealDuration),
                    abilityWindowOpen: abilityWindowOpen
                )
                state.activeBalls = []
            } else {
                spawnBallsIfNeeded(state: &state, now: now)
                state.activeBalls.removeAll { now.timeIntervalSince($0.createdAt) > ballLifetime }
            }
        case .strikePowerReveal(let endsAt, let abilityWindowOpen):
            if !abilityWindowOpen, now >= endsAt {
                skipStrikeAbilityUse(state: &state, now: now)
            }
        case .damageReveal(let endsAt, _, _):
            if now >= endsAt {
                beginEnergyDrain(state: &state, now: now)
            }
        case .energyDrain(let endsAt, _, _, _):
            if now >= endsAt {
                finishEnergyDrain(state: &state, now: now)
            }
        }
    }

    static func strikeAbilityBonus(for ability: GameplaySessionAbility) -> ArenaPvPStrikeAbilityBonus {
        switch ability.kind {
        case .turnDamage:
            let totalDamage = ability.damageTurns <= 1
                ? ability.turnDamage
                : ability.turnDamage * ability.damageTurns
            return ArenaPvPStrikeAbilityBonus(
                abilityID: ability.id,
                abilityName: ability.name,
                bonusDamage: totalDamage,
                powerPercentBonus: 0
            )
        case .temporaryStatBoost:
            return ArenaPvPStrikeAbilityBonus(
                abilityID: ability.id,
                abilityName: ability.name,
                bonusDamage: 0,
                powerPercentBonus: min(maxBallPower, ability.statBoostAmount)
            )
        case .boardMove:
            return ArenaPvPStrikeAbilityBonus(
                abilityID: ability.id,
                abilityName: ability.name,
                bonusDamage: 0,
                powerPercentBonus: min(25, ability.boardMaxSpaces * 4)
            )
        }
    }

    static func confirmStrikeAbility(
        state: inout ArenaPvPCombatState,
        ability: GameplaySessionAbility,
        now: Date
    ) {
        guard case .strikePowerReveal(_, true) = state.step else { return }
        state.strikeAbilityBonus = strikeAbilityBonus(for: ability)
        beginDamageReveal(state: &state, now: now)
    }

    static func skipStrikeAbilityUse(state: inout ArenaPvPCombatState, now: Date) {
        guard case .strikePowerReveal = state.step else { return }
        state.strikeAbilityBonus = nil
        beginDamageReveal(state: &state, now: now)
    }

    static func beginDamageReveal(state: inout ArenaPvPCombatState, now: Date) {
        var strikePower = min(maxBallPower, max(0, state.punchPowerPercent))
        if let bonus = state.strikeAbilityBonus {
            strikePower = min(maxBallPower, strikePower + bonus.powerPercentBonus)
        }
        var damage = damageAmount(attacker: state.activeFighter, totalPowerPercent: strikePower)
        damage += state.strikeAbilityBonus?.bonusDamage ?? 0
        state.lastDamage = damage
        state.step = .damageReveal(
            endsAt: now.addingTimeInterval(damageRevealDuration),
            damage: damage,
            totalPowerPercent: strikePower
        )
    }

    static func arenaAbilities(
        for playerID: UUID,
        in pool: GameplaySessionAbilityPoolState
    ) -> [GameplaySessionAbility] {
        pool.collectedAbilities(for: playerID).filter { $0.scope == .arenaPvP }
    }

    static func beginEnergyDrain(state: inout ArenaPvPCombatState, now: Date) {
        let defenderIndex = state.defenderIndex
        let before = state.fighters[defenderIndex].currentEnergy
        let after = max(0, before - state.lastDamage)
        state.step = .energyDrain(
            endsAt: now.addingTimeInterval(energyDrainDuration),
            defenderIndex: defenderIndex,
            energyBefore: before,
            energyAfter: after
        )
    }

    static func finishEnergyDrain(state: inout ArenaPvPCombatState, now: Date) {
        guard case .energyDrain(_, let defenderIndex, _, let energyAfter) = state.step else { return }

        state.fighters[defenderIndex].currentEnergy = energyAfter
        let attacker = state.activeFighter
        let defenderName = state.defender.player.displayTitle
        state.lastHitSummary = "\(attacker.player.displayTitle) zadaje \(state.lastDamage) obrażeń — \(defenderName): \(energyAfter) energii."

        if energyAfter <= 0 {
            state.winnerID = attacker.id
            return
        }

        beginNextTurn(state: &state, now: now)
    }

    static func displayedEnergy(
        for fighterIndex: Int,
        fighter: ArenaPvPFighter,
        step: ArenaPvPTurnStep,
        now: Date
    ) -> Int {
        if case .energyDrain(let endsAt, let defenderIndex, let before, let after) = step,
           fighterIndex == defenderIndex {
            let duration = energyDrainDuration
            let remaining = max(0, endsAt.timeIntervalSince(now))
            let progress = 1 - min(1, remaining / duration)
            return before + Int(Double(after - before) * progress)
        }
        return fighter.currentEnergy
    }

    static func beginNextTurn(state: inout ArenaPvPCombatState, now: Date) {
        state.activeFighterIndex = state.defenderIndex
        state.ballPowerPercent = 0
        state.punchPowerPercent = 0
        state.activeBalls = []
        state.strikeAbilityBonus = nil
        state.step = .ballTapping(endsAt: now.addingTimeInterval(ballPhaseDuration))
    }

    static func damageAmount(attacker: ArenaPvPFighter, totalPowerPercent: Int) -> Int {
        let power = Double(totalPowerPercent) / 100.0
        let raw = Double(attacker.displayStats.strength) * 0.38 + power * 42.0
        return max(3, Int(raw.rounded()))
    }
}
