//
//  CreatorPowerPathSeed.swift
//  BoardCore
//

import Foundation

enum CreatorPowerPathSeed {
    static func defaultPaths() -> [CreatedPowerPath] {
        [
            CreatedPowerPath(
                name: "Mroczni użytkownicy",
                iconSymbol: "moon.stars.fill",
                glowColor: PlayerGlowColor(red: 0.42, green: 0.22, blue: 0.72, opacity: 1),
                isBuiltIn: true,
                upgrades: darkUpgrades,
                buildPrompt: "Ścieżka mroku z kradzieżą monet, klątwą i cieniem."
            ),
            CreatedPowerPath(
                name: "Bohaterowie słońca",
                iconSymbol: "sun.max.fill",
                glowColor: PlayerGlowColor(red: 0.98, green: 0.78, blue: 0.22, opacity: 1),
                isBuiltIn: true,
                upgrades: lightUpgrades,
                buildPrompt: "Ścieżka światła z ochroną, dobroczynnością i uzdrowieniem."
            ),
        ]
    }

    private static var darkUpgrades: [CreatedPowerUpgrade] {
        PowerPathSkillID.skills(for: .dark).map { skill in
            CreatedPowerUpgrade(
                name: skill.title,
                summary: skill.summary,
                xpCost: skill.xpCost,
                tier: skill.tier,
                influence: .gameplay,
                gameplayEffect: PowerUpgradeGameplayEffect(
                    healthBonus: PowerPathEngine.skillUnlockHealthBonus,
                    strengthBonus: PowerPathEngine.skillUnlockStrengthBonus,
                    coinsBonus: 0,
                    xpBonus: 0
                )
            )
        }
    }

    private static var lightUpgrades: [CreatedPowerUpgrade] {
        PowerPathSkillID.skills(for: .light).map { skill in
            CreatedPowerUpgrade(
                name: skill.title,
                summary: skill.summary,
                xpCost: skill.xpCost,
                tier: skill.tier,
                influence: .gameplay,
                gameplayEffect: PowerUpgradeGameplayEffect(
                    healthBonus: PowerPathEngine.skillUnlockHealthBonus,
                    strengthBonus: PowerPathEngine.skillUnlockStrengthBonus,
                    coinsBonus: 0,
                    xpBonus: 0
                )
            )
        }
    }
}
