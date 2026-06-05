//
//  GameplayLiveCatalogSync.swift
//  BoardCore
//

import Foundation

enum GameplayLiveCatalogSync {
    static func mergedAbilityCatalog(
        creatorAbilities: [CreatedAbility],
        sessionPool: GameplaySessionAbilityPoolState
    ) -> [CreatedAbility] {
        var combined = creatorAbilities
        let existingIDs = Set(combined.map(\.id))
        for sessionAbility in sessionPool.abilities {
            guard !existingIDs.contains(sessionAbility.id) else { continue }
            combined.append(sessionAbility.asCreatedAbility)
        }
        return combined
    }

    static func validAbilityIDs(
        creatorAbilities: [CreatedAbility],
        sessionPool: GameplaySessionAbilityPoolState
    ) -> Set<UUID> {
        Set(mergedAbilityCatalog(creatorAbilities: creatorAbilities, sessionPool: sessionPool).map(\.id))
    }

    static func validItemIDs(items: [CreatedItem]) -> Set<UUID> {
        Set(items.map(\.id))
    }

    static func validPowerPathIDs(paths: [CreatedPowerPath]) -> Set<UUID> {
        Set(paths.map(\.id))
    }

    static func validUpgradeIDs(paths: [CreatedPowerPath]) -> Set<UUID> {
        Set(paths.flatMap(\.upgrades).map(\.id))
    }

    static func pruneGrantedAbilities(
        _ map: inout [UUID: [UUID]],
        validIDs: Set<UUID>
    ) {
        for key in map.keys {
            map[key] = map[key]?.filter { validIDs.contains($0) }
            if map[key]?.isEmpty == true { map.removeValue(forKey: key) }
        }
    }

    static func pruneGrantedItems(
        _ map: inout [UUID: [UUID]],
        validIDs: Set<UUID>
    ) {
        for key in map.keys {
            map[key] = map[key]?.filter { validIDs.contains($0) }
            if map[key]?.isEmpty == true { map.removeValue(forKey: key) }
        }
    }

    static func pruneEquipment(
        _ equipment: inout PlayerEquipmentMap,
        validItemIDs: Set<UUID>
    ) {
        for playerID in equipment.keys {
            guard var slots = equipment[playerID] else { continue }
            for key in slots.keys {
                if let itemID = slots[key], !validItemIDs.contains(itemID) {
                    slots.removeValue(forKey: key)
                }
            }
            if slots.isEmpty {
                equipment.removeValue(forKey: playerID)
            } else {
                equipment[playerID] = slots
            }
        }
    }

    static func prunePowerPathProgress(
        _ map: inout [UUID: PlayerPowerPathProgress],
        validPathIDs: Set<UUID>,
        validUpgradeIDs: Set<UUID>
    ) {
        for playerID in map.keys {
            var progress = map[playerID] ?? PlayerPowerPathProgress()
            if let customID = progress.chosenCustomPathID, !validPathIDs.contains(customID) {
                progress.chosenCustomPathID = nil
                progress.unlockedCustomUpgradeIDs = []
            }
            progress.unlockedCustomUpgradeIDs = progress.unlockedCustomUpgradeIDs.filter {
                validUpgradeIDs.contains($0)
            }
            map[playerID] = progress
        }
    }
}

enum PowerUpgradeEffectApplier {
    static func applyOnUnlock(_ upgrade: CreatedPowerUpgrade, stats: inout PlayerRuntimeStats) {
        guard upgrade.influence == .gameplay else { return }
        let effect = upgrade.gameplayEffect
        stats.health = min(100, max(0, stats.health + effect.healthBonus))
        stats.strength = min(100, max(0, stats.strength + effect.strengthBonus))
        stats.finances = min(9999, max(0, stats.finances + effect.coinsBonus))
    }
}

enum CustomPowerPathEngine {
    static func unlockCustomPath(
        pathID: UUID,
        playerID: UUID,
        progress: inout [UUID: PlayerPowerPathProgress]
    ) -> String? {
        var playerProgress = progress[playerID] ?? PlayerPowerPathProgress()
        if playerProgress.hasChosenPath {
            if playerProgress.chosenCustomPathID == pathID {
                return "Ta ścieżka jest już aktywna."
            }
            return "Możesz mieć tylko jedną ścieżkę mocy."
        }
        playerProgress.chosenCustomPathID = pathID
        playerProgress.chosenSide = nil
        progress[playerID] = playerProgress
        return "Odblokowano własną ścieżkę mocy."
    }

    static func unlockCustomUpgrade(
        path: CreatedPowerPath,
        upgradeID: UUID,
        playerID: UUID,
        progress: inout [UUID: PlayerPowerPathProgress],
        runtimeStats: inout PlayerRuntimeStats?
    ) -> String? {
        var playerProgress = progress[playerID] ?? PlayerPowerPathProgress()
        guard playerProgress.chosenCustomPathID == path.id else {
            return "Najpierw odblokuj tę ścieżkę mocy."
        }
        guard let upgrade = path.upgrades.first(where: { $0.id == upgradeID }) else {
            return "Nie znaleziono ulepszenia."
        }
        guard !playerProgress.unlockedCustomUpgradeIDs.contains(upgradeID) else {
            return "Ulepszenie jest już odblokowane."
        }
        guard playerProgress.experiencePoints >= upgrade.xpCost else {
            return "Potrzebujesz \(upgrade.xpCost) XP (masz \(playerProgress.experiencePoints))."
        }
        let prerequisites = path.upgrades.filter { $0.tier < upgrade.tier }.map(\.id)
        guard prerequisites.allSatisfy({ playerProgress.unlockedCustomUpgradeIDs.contains($0) }) else {
            return "Najpierw odblokuj wcześniejsze ulepszenie."
        }

        playerProgress.experiencePoints -= upgrade.xpCost
        playerProgress.unlockedCustomUpgradeIDs.insert(upgradeID)
        if var stats = runtimeStats {
            PowerUpgradeEffectApplier.applyOnUnlock(upgrade, stats: &stats)
            runtimeStats = stats
        }
        progress[playerID] = playerProgress
        return "Odblokowano: \(upgrade.name)."
    }
}
