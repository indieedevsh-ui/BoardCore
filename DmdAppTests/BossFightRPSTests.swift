//
//  BossFightRPSTests.swift
//  DmdAppTests
//

import Testing
@testable import DmdApp

struct BossFightRPSTests {

  @Test func clashRules() {
    #expect(BossFightCombatEngine.resolveWinner(player: .defense, boss: .attack) == .player)
    #expect(BossFightCombatEngine.resolveWinner(player: .strongAttack, boss: .defense) == .player)
    #expect(BossFightCombatEngine.resolveWinner(player: .attack, boss: .strongAttack) == .player)

    #expect(BossFightCombatEngine.resolveWinner(player: .attack, boss: .defense) == .boss)
    #expect(BossFightCombatEngine.resolveWinner(player: .defense, boss: .strongAttack) == .boss)
    #expect(BossFightCombatEngine.resolveWinner(player: .strongAttack, boss: .attack) == .boss)

    #expect(BossFightCombatEngine.resolveWinner(player: .attack, boss: .attack) == .draw)
    #expect(BossFightCombatEngine.resolveWinner(player: .attack, boss: .specialAbility) == .boss)
  }

  @Test func bossIntentionalChanceByDifficulty() {
    #expect(BossDifficulty.easy.intentionalMoveChance == 0.60)
    #expect(BossDifficulty.medium.intentionalMoveChance == 0.70)
    #expect(BossDifficulty.hard.intentionalMoveChance == 0.85)
    #expect(BossDifficulty.easy.maxSpecialAbilityUses == 0)
    #expect(BossDifficulty.medium.maxSpecialAbilityUses == 1)
  }
}
