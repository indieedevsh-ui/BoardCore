//
//  BossFightModels.swift
//  DmdApp
//

import Foundation

enum BossDifficulty: String, CaseIterable, Identifiable {
    case easy
    case medium
    case hard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .easy: "Łatwy"
        case .medium: "Średni"
        case .hard: "Trudny"
        }
    }

    var subtitle: String {
        switch self {
        case .easy: "Mniej HP, bez zdolności specjalnej"
        case .medium: "Więcej HP, 1 zdolność specjalna (przebija wszystko)"
        case .hard: "Najwyższe HP, 1 zdolność specjalna (przebija wszystko)"
        }
    }

    var icon: String {
        switch self {
        case .easy: "leaf.fill"
        case .medium: "flame.fill"
        case .hard: "tornado"
        }
    }

    var maxHP: Int {
        switch self {
        case .easy: 80
        case .medium: 130
        case .hard: 200
        }
    }

    /// Siła bossa = obrażenia przy przebiciu (łatwy 10, średni 25, trudny 35).
    var combatStrength: Int {
        switch self {
        case .easy: 15
        case .medium: 25
        case .hard: 35
        }
    }

    @available(*, deprecated, message: "Użyj combatStrength")
    var baseDamage: Int { combatStrength }

    /// Zdolność specjalna bossa (przebija każdy ruch) — max 1 na walkę.
    var maxSpecialAbilityUses: Int {
        switch self {
        case .easy: 0
        case .medium, .hard: 1
        }
    }

    /// Szansa na świadomy wybór ruchu (bez znajomości ruchu gracza).
    var intentionalMoveChance: Double {
        switch self {
        case .easy: 0.60
        case .medium: 0.70
        case .hard: 0.85
        }
    }

    /// Łączna pula monet za zwycięstwo (dzielona między uczestników walki).
    var victoryCoinPool: Int {
        switch self {
        case .easy: 60
        case .medium: 120
        case .hard: 180
        }
    }
}

struct BossDefinition: Identifiable, Equatable {
    let difficulty: BossDifficulty

    var id: String { difficulty.rawValue }
    var title: String { "Boss — \(difficulty.title)" }
    var maxHP: Int { difficulty.maxHP }
    var combatStrength: Int { difficulty.combatStrength }
    var baseDamage: Int { combatStrength }
}

struct BossFightDisplayStats: Equatable {
    var health: Int
    var strength: Int
    var abilities: Int
    var armor: Int

    static let zero = BossFightDisplayStats(health: 0, strength: 0, abilities: 0, armor: 0)
}

/// Bonusy z założonego ekwipunku (slot QR: W/H/A/S).
struct EquipmentLoadoutBonus: Equatable {
    var health: Int
    var strength: Int
    var armor: Int

    static let zero = EquipmentLoadoutBonus(health: 0, strength: 0, armor: 0)

    static func - (lhs: EquipmentLoadoutBonus, rhs: EquipmentLoadoutBonus) -> EquipmentLoadoutBonus {
        EquipmentLoadoutBonus(
            health: lhs.health - rhs.health,
            strength: lhs.strength - rhs.strength,
            armor: lhs.armor - rhs.armor
        )
    }
}

private enum LoadoutEquipmentSlot {
    case weapon
    case armor

    func apply(item: CreatedItem, into bonus: inout EquipmentLoadoutBonus) {
        let stats = item.stats
        let kind = item.resolvedItemKind

        switch self {
        case .weapon:
            guard kind == .weapon else { return }
            bonus.strength += stats.weaponStrengthBonus

        case .armor:
            guard kind == .armor else { return }
            bonus.health += stats.armorHealthBonus
        }
    }
}

enum BossFightStatsCalculator {
    static func bonus(from loadout: PlayerLoadout, catalog: [CreatedItem]) -> EquipmentLoadoutBonus {
        var bonus = EquipmentLoadoutBonus.zero

        if let id = loadout.weaponNumericID,
           let item = CreatedItem.first(in: catalog, matchingNumericID: id) {
            LoadoutEquipmentSlot.weapon.apply(item: item, into: &bonus)
        }
        if let id = loadout.armorItemNumericID,
           let item = CreatedItem.first(in: catalog, matchingNumericID: id) {
            LoadoutEquipmentSlot.armor.apply(item: item, into: &bonus)
        }

        return bonus
    }

    static func displayStats(
        base: PlayerRuntimeStats,
        loadoutBonus bonus: EquipmentLoadoutBonus,
        capped: Bool = true
    ) -> BossFightDisplayStats {
        let health = base.health + bonus.health
        let strength = base.strength + bonus.strength
        let armor = bonus.armor
        if capped {
            return BossFightDisplayStats(
                health: min(100, health),
                strength: min(100, strength),
                abilities: base.abilities,
                armor: min(100, armor)
            )
        }
        return BossFightDisplayStats(
            health: max(0, health),
            strength: max(0, strength),
            abilities: base.abilities,
            armor: max(0, armor)
        )
    }

    static func combinedCombatStats(
        mainBase: PlayerRuntimeStats,
        mainLoadoutBonus: EquipmentLoadoutBonus,
        supporters: [(base: PlayerRuntimeStats, loadoutBonus: EquipmentLoadoutBonus)]
    ) -> BossFightDisplayStats {
        var total = displayStats(base: mainBase, loadoutBonus: mainLoadoutBonus, capped: false)
        for supporter in supporters {
            let stats = displayStats(
                base: supporter.base,
                loadoutBonus: supporter.loadoutBonus,
                capped: false
            )
            total.health += stats.health
            total.strength += stats.strength
            total.armor += stats.armor
            total.abilities = max(total.abilities, stats.abilities)
        }
        return total
    }

    static func financeRewardSplit(totalPool: Int, supporterCount: Int) -> (mainShare: Int, supporterShare: Int) {
        guard supporterCount > 0 else {
            return (totalPool, 0)
        }
        let mainShare = Int((Double(totalPool) * 0.8).rounded())
        let supporterShare = Int((Double(totalPool) * 0.2).rounded())
        return (mainShare, supporterShare)
    }

    static func runtimeStats(base: PlayerRuntimeStats, loadoutBonus bonus: EquipmentLoadoutBonus) -> PlayerRuntimeStats {
        var stats = base
        stats.health = min(100, base.health + bonus.health)
        stats.strength = min(100, base.strength + bonus.strength)
        return stats
    }
}

// MARK: - Walka RPS (atak / obrona / mocny atak)

enum BossClashMove: String, CaseIterable, Equatable, Identifiable {
    case attack
    case defense
    case strongAttack
    case specialAbility

    var id: String { rawValue }

    static let playerSelectable: [BossClashMove] = [.attack, .defense, .strongAttack]
    static let basicMoves: [BossClashMove] = [.attack, .defense, .strongAttack]

    var title: String {
        switch self {
        case .attack: "Atak"
        case .defense: "Obrona"
        case .strongAttack: "Mocny atak"
        case .specialAbility: "Zdolność"
        }
    }

    var icon: String {
        switch self {
        case .attack: "bolt.fill"
        case .defense: "shield.lefthalf.filled"
        case .strongAttack: "flame.fill"
        case .specialAbility: "sparkles"
        }
    }

    var beatsHint: String {
        switch self {
        case .attack: "Przebija mocny atak"
        case .defense: "Przebija atak"
        case .strongAttack: "Przebija obronę"
        case .specialAbility: "Przebija każdy ruch"
        }
    }
}

enum BossClashWinner: Equatable {
    case player
    case boss
    case draw
}

struct BossClashResult: Equatable {
    let playerMove: BossClashMove
    let bossMove: BossClashMove
    let winner: BossClashWinner
    let damageToBoss: Int
    let damageToPlayer: Int
    let summary: String
}

enum BossCombatRoundPhase: Equatable {
    /// Gracz ma 10 s na wybór; `endsAt` kończy odliczanie.
    case reacting(endsAt: Date)
    /// Pokazanie obu ruchów i wyniku starcia.
    case revealing
}

struct BossCombatSession: Equatable {
    static let reactionDuration: TimeInterval = 6
    static let revealDisplayDuration: TimeInterval = 4
    static let timeoutBossDamageMultiplier = 3

    var boss: BossDefinition
    var bossCurrentHP: Int
    var playerCurrentHP: Int
    var frozenStats: BossFightDisplayStats
    var roundNumber: Int
    var phase: BossCombatRoundPhase
    /// Wybór gracza (zablokowany po kliknięciu, widoczny po starciu).
    var playerMove: BossClashMove?
    /// Ruch bossa — wybrany na początku rundy, ukryty do końca odliczania.
    var bossMove: BossClashMove
    var bossSpecialAbility: GameplaySessionAbility?
    var bossSpecialUsed: Bool
    var lastClash: BossClashResult?
    var combatLog: [String]

    var bossHPProgress: Double {
        guard boss.maxHP > 0 else { return 0 }
        return Double(bossCurrentHP) / Double(boss.maxHP)
    }

    var playerHPProgress: Double {
        guard frozenStats.health > 0 else { return 0 }
        return Double(playerCurrentHP) / Double(frozenStats.health)
    }

    var isFinished: Bool {
        bossCurrentHP <= 0 || playerCurrentHP <= 0
    }

    var victory: Bool {
        bossCurrentHP <= 0 && playerCurrentHP > 0
    }

    var isReacting: Bool {
        if case .reacting = phase { return true }
        return false
    }

    var reactionEndsAt: Date? {
        if case .reacting(let endsAt) = phase { return endsAt }
        return nil
    }

    var bossSpecialDisplayName: String {
        bossSpecialAbility?.name ?? "Zdolność bossa"
    }
}

enum BossFightCombatEngine {
    static func isBossSpecialEligible(_ ability: GameplaySessionAbility) -> Bool {
        switch ability.kind {
        case .turnDamage: true
        case .temporaryStatBoost: ability.statBoostAmount > 0
        case .boardMove: false
        }
    }

    static func makeSession(
        boss: BossDefinition,
        partyStats: BossFightDisplayStats,
        bossSpecial: GameplaySessionAbility?
    ) -> BossCombatSession {
        let now = Date()
        var session = BossCombatSession(
            boss: boss,
            bossCurrentHP: boss.maxHP,
            playerCurrentHP: partyStats.health,
            frozenStats: partyStats,
            roundNumber: 0,
            phase: .reacting(endsAt: now),
            playerMove: nil,
            bossMove: .attack,
            bossSpecialAbility: boss.difficulty.maxSpecialAbilityUses > 0 ? bossSpecial : nil,
            bossSpecialUsed: false,
            lastClash: nil,
            combatLog: ["Walka — wybierz ruch w 6 sekund!"]
        )
        beginRound(session: &session, now: now)
        return session
    }

    static func beginRound(session: inout BossCombatSession, now: Date = Date()) {
        session.roundNumber += 1
        session.playerMove = nil
        session.lastClash = nil
        session.bossMove = pickBossMove(for: session)
        session.phase = .reacting(endsAt: now.addingTimeInterval(BossCombatSession.reactionDuration))
        session.combatLog.append("Runda \(session.roundNumber) — wybierz ruch!")
    }

    static func lockPlayerMove(_ move: BossClashMove, session: inout BossCombatSession) {
        guard session.isReacting else { return }
        session.playerMove = move
        session.combatLog.append("Wybrałeś: \(move.title). Czekaj na koniec odliczania…")
    }

    static func resolveRound(session: inout BossCombatSession) -> BossClashResult {
        if session.playerMove == nil {
            return resolveNoReactionRound(session: &session)
        }

        let playerMove = session.playerMove!
        let result = clashResult(
            player: playerMove,
            boss: session.bossMove,
            session: session
        )

        session.bossCurrentHP = max(0, session.bossCurrentHP - result.damageToBoss)
        session.playerCurrentHP = max(0, session.playerCurrentHP - result.damageToPlayer)

        if session.bossMove == .specialAbility {
            session.bossSpecialUsed = true
        }

        session.lastClash = result
        session.phase = .revealing
        session.combatLog.append(result.summary)

        if session.bossCurrentHP <= 0 {
            session.combatLog.append("Boss pokonany!")
        } else if session.playerCurrentHP <= 0 {
            session.combatLog.append("Drużyna upadła w walce.")
        }

        return result
    }

    static func clashResult(
        player: BossClashMove,
        boss: BossClashMove,
        session: BossCombatSession
    ) -> BossClashResult {
        let winner = resolveWinner(player: player, boss: boss)
        let damageToBoss: Int
        let damageToPlayer: Int

        switch winner {
        case .player:
            damageToBoss = damageWhenPlayerWins(stats: session.frozenStats)
            damageToPlayer = 0
        case .boss:
            damageToBoss = 0
            damageToPlayer = damageWhenBossWins(boss: session.boss, move: boss)
        case .draw:
            damageToBoss = 0
            damageToPlayer = 0
        }

        let summary = clashSummary(
            player: player,
            boss: boss,
            winner: winner,
            damageToBoss: damageToBoss,
            damageToPlayer: damageToPlayer,
            bossSpecialName: session.bossSpecialDisplayName
        )

        return BossClashResult(
            playerMove: player,
            bossMove: boss,
            winner: winner,
            damageToBoss: damageToBoss,
            damageToPlayer: damageToPlayer,
            summary: summary
        )
    }

    static func resolveWinner(player: BossClashMove, boss: BossClashMove) -> BossClashWinner {
        if boss == .specialAbility { return .boss }
        if player == boss { return .draw }
        switch (player, boss) {
        case (.defense, .attack), (.strongAttack, .defense), (.attack, .strongAttack):
            return .player
        default:
            return .boss
        }
    }

    static func pickBossMove(for session: BossCombatSession) -> BossClashMove {
        var rng = SystemRandomNumberGenerator()
        return pickBossMove(for: session, rng: &rng)
    }

    static func pickBossMove<R: RandomNumberGenerator>(
        for session: BossCombatSession,
        rng: inout R
    ) -> BossClashMove {
        let difficulty = session.boss.difficulty
        let intentional = Double.random(in: 0..<1, using: &rng) < difficulty.intentionalMoveChance

        if intentional {
            if canUseSpecial(session: session),
               shouldUseSpecialNow(session: session, rng: &rng) {
                return .specialAbility
            }
            return bestBasicMoveAgainstUnknownPlayer(session: session)
        }

        return BossClashMove.basicMoves.randomElement(using: &rng) ?? .attack
    }

    private static func canUseSpecial(session: BossCombatSession) -> Bool {
        session.boss.difficulty.maxSpecialAbilityUses > 0
            && session.bossSpecialAbility != nil
            && !session.bossSpecialUsed
    }

    private static func shouldUseSpecialNow<R: RandomNumberGenerator>(
        session: BossCombatSession,
        rng: inout R
    ) -> Bool {
        let bossHPPercent = session.boss.maxHP > 0
            ? Double(session.bossCurrentHP) / Double(session.boss.maxHP)
            : 1
        let playerThreat = estimatedPlayerDamage(.strongAttack, stats: session.frozenStats)

        if playerThreat >= session.bossCurrentHP { return true }
        if bossHPPercent < 0.4 { return Double.random(in: 0..<1, using: &rng) < 0.55 }
        if session.playerCurrentHP > session.boss.combatStrength * 2 {
            return Double.random(in: 0..<1, using: &rng) < 0.35
        }
        return Double.random(in: 0..<1, using: &rng) < 0.12
    }

    private static func bestBasicMoveAgainstUnknownPlayer(session: BossCombatSession) -> BossClashMove {
        var bestMove = BossClashMove.attack
        var bestScore = -Double.infinity

        for bossMove in BossClashMove.basicMoves {
            var score = 0.0
            for playerMove in BossClashMove.playerSelectable {
                let outcome = resolveWinner(player: playerMove, boss: bossMove)
                switch outcome {
                case .boss:
                    score += Double(damageWhenBossWins(boss: session.boss, move: bossMove))
                case .player:
                    score -= Double(damageWhenPlayerWins(stats: session.frozenStats))
                case .draw:
                    break
                }
            }
            score /= Double(BossClashMove.playerSelectable.count)
            if score > bestScore {
                bestScore = score
                bestMove = bossMove
            }
        }
        return bestMove
    }

    private static func estimatedPlayerDamage(_ move: BossClashMove, stats: BossFightDisplayStats) -> Int {
        _ = move
        return damageWhenPlayerWins(stats: stats)
    }

    /// Brak wyboru w czasie — boss zawsze zadaje potrójne obrażenia (3× siła bossa).
    private static func resolveNoReactionRound(session: inout BossCombatSession) -> BossClashResult {
        let bossMove = session.bossMove
        let damage = timeoutDamage(for: session.boss)
        session.playerMove = nil

        session.playerCurrentHP = max(0, session.playerCurrentHP - damage)
        if session.bossMove == .specialAbility {
            session.bossSpecialUsed = true
        }

        let summary = "Brak reakcji! Boss — potrójne uderzenie (−\(damage) HP drużyny)."
        let result = BossClashResult(
            playerMove: .attack,
            bossMove: bossMove,
            winner: .boss,
            damageToBoss: 0,
            damageToPlayer: damage,
            summary: summary
        )

        session.lastClash = result
        session.phase = .revealing
        session.combatLog.append(summary)

        if session.playerCurrentHP <= 0 {
            session.combatLog.append("Drużyna upadła w walce.")
        }

        return result
    }

    static func timeoutDamage(for boss: BossDefinition) -> Int {
        max(1, boss.combatStrength * BossCombatSession.timeoutBossDamageMultiplier)
    }

    /// Każde przebicie gracza zadaje obrażenia równe sile drużyny.
    static func damageWhenPlayerWins(stats: BossFightDisplayStats) -> Int {
        max(1, stats.strength)
    }

    static func damageToBossWhenPlayerWins(move: BossClashMove, stats: BossFightDisplayStats) -> Int {
        _ = move
        return damageWhenPlayerWins(stats: stats)
    }

    /// Każde przebicie bossa zadaje obrażenia równe sile bossa (niezależnie od rodzaju ruchu).
    static func damageWhenBossWins(boss: BossDefinition, move: BossClashMove) -> Int {
        _ = move
        return max(1, boss.combatStrength)
    }

    static func damageToPlayerWhenBossWins(move: BossClashMove, boss: BossDefinition, armor: Int) -> Int {
        _ = armor
        return damageWhenBossWins(boss: boss, move: move)
    }

    private static func clashSummary(
        player: BossClashMove,
        boss: BossClashMove,
        winner: BossClashWinner,
        damageToBoss: Int,
        damageToPlayer: Int,
        bossSpecialName: String
    ) -> String {
        let bossLabel = boss == .specialAbility ? bossSpecialName : boss.title
        switch winner {
        case .draw:
            return "Remis: \(player.title) vs \(bossLabel) — bez obrażeń."
        case .player:
            return "\(player.title) przebija \(bossLabel)! Boss −\(damageToBoss) HP."
        case .boss:
            return "\(bossLabel) przebija \(player.title)! Drużyna −\(damageToPlayer) HP."
        }
    }
}
