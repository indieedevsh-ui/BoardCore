//
//  StrengthDamageTests.swift
//  DmdAppTests
//

import Foundation
import Testing
@testable import DmdApp

struct StrengthDamageTests {

    @Test func startingStrengthIsTwenty() {
        #expect(PlayerRuntimeStats.startingStrength == 20)
        #expect(PlayerRuntimeStats.defaultStarting.strength == 20)
    }

    @Test func clashDamageEqualsStrength() {
        let stats = BossFightDisplayStats(health: 100, strength: 20, abilities: 0, armor: 0)
        #expect(BossFightCombatEngine.damageWhenPlayerWins(stats: stats) == 20)
        #expect(BossFightCombatEngine.damageToBossWhenPlayerWins(move: .defense, stats: stats) == 20)
        #expect(BossFightCombatEngine.damageToBossWhenPlayerWins(move: .strongAttack, stats: stats) == 20)
    }

    @Test func bossCombatStrengthByDifficulty() {
        #expect(BossDifficulty.easy.combatStrength == 15)
        #expect(BossDifficulty.medium.combatStrength == 25)
        #expect(BossDifficulty.hard.combatStrength == 35)
        let boss = BossDefinition(difficulty: .medium)
        #expect(BossFightCombatEngine.damageWhenBossWins(boss: boss, move: .attack) == 25)
        #expect(BossFightCombatEngine.damageWhenBossWins(boss: boss, move: .strongAttack) == 25)
        #expect(BossFightCombatEngine.timeoutDamage(for: boss) == 75)
    }

    @Test func armorHealthBonusClamped() {
        var stats = CreatorStats(health: 8)
        #expect(stats.armorHealthBonus == 10)
        stats.health = 55
        #expect(stats.armorHealthBonus == 55)
    }

    @Test func weaponStrengthBonusClamped() {
        var stats = CreatorStats(strength: 5)
        #expect(stats.weaponStrengthBonus == 10)
        stats.strength = 80
        #expect(stats.weaponStrengthBonus == 80)
        stats.strength = 45
        #expect(stats.weaponStrengthBonus == 45)
    }

    @Test func loadoutWeaponAddsOnlyStrengthArmorOnlyHealth() {
        let weaponID = UUID()
        let armorID = UUID()
        let weapon = CreatedItem(
            id: weaponID,
            numericId: "9001",
            name: "Miecz",
            cost: 10,
            stats: CreatorStats(strength: 36),
            itemKind: .weapon
        )
        let armor = CreatedItem(
            id: armorID,
            numericId: "9002",
            name: "Zbroja",
            cost: 10,
            stats: CreatorStats(health: 25),
            itemKind: .armor
        )
        let playerID = UUID()
        var equipment: PlayerEquipmentMap = [
            playerID: [
                CreatorItemKind.weapon.rawValue: weaponID,
                CreatorItemKind.armor.rawValue: armorID,
            ],
        ]
        let bonus = PlayerEquipment.loadoutBonus(
            for: playerID,
            equipment: equipment,
            catalog: [weapon, armor]
        )
        #expect(bonus.strength == 36)
        #expect(bonus.health == 25)
        #expect(bonus.armor == 0)

        let base = PlayerRuntimeStats(finances: 100, health: 50, strength: 10, abilities: 0)
        let effective = PlayerEquipment.effectiveRuntimeStats(
            base: base,
            for: playerID,
            equipment: equipment,
            catalog: [weapon, armor]
        )
        #expect(effective.strength == 46)
        #expect(effective.health == 75)
    }
}
