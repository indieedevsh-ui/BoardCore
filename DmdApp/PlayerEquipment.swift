//
//  PlayerEquipment.swift
//  DmdApp
//

import Foundation

/// playerID → rodzaj slotu (CreatorItemKind.rawValue) → ID przedmiotu z katalogu.
typealias PlayerEquipmentMap = [UUID: [String: UUID]]

enum PlayerEquipment {
    enum EquipError: Error, Equatable {
        case notOwned
        case notEquippable
    }

    static func equippedItemID(
        for kind: CreatorItemKind,
        playerID: UUID,
        equipment: PlayerEquipmentMap
    ) -> UUID? {
        equipment[playerID]?[kind.rawValue]
    }

    static func isEquipped(_ item: CreatedItem, playerID: UUID, equipment: PlayerEquipmentMap) -> Bool {
        let kind = item.resolvedItemKind
        return equippedItemID(for: kind, playerID: playerID, equipment: equipment) == item.id
    }

    static func equippedItems(
        for playerID: UUID,
        equipment: PlayerEquipmentMap,
        catalog: [CreatedItem]
    ) -> [CreatedItem] {
        guard let slots = equipment[playerID] else { return [] }
        return CreatorItemKind.equippableCases.compactMap { kind in
            guard let itemID = slots[kind.rawValue] else { return nil }
            return catalog.first { $0.id == itemID }
        }
    }

    /// Przenosi stare sloty hełm/tarcza do pancerza (jeden slot pancerza na gracza).
    static func normalizeLegacyEquipmentSlots(in equipment: inout PlayerEquipmentMap) {
        let legacyKeys = [
            CreatorItemKind.helmet.rawValue,
            CreatorItemKind.shield.rawValue,
        ]
        let armorKey = CreatorItemKind.armor.rawValue

        for playerID in equipment.keys {
            guard var slots = equipment[playerID] else { continue }
            for legacyKey in legacyKeys {
                guard let itemID = slots[legacyKey] else { continue }
                if slots[armorKey] == nil {
                    slots[armorKey] = itemID
                }
                slots.removeValue(forKey: legacyKey)
            }
            equipment[playerID] = slots.isEmpty ? nil : slots
            if equipment[playerID]?.isEmpty == true {
                equipment.removeValue(forKey: playerID)
            }
        }
    }

    static func loadout(
        for playerID: UUID,
        equipment: PlayerEquipmentMap,
        catalog: [CreatedItem]
    ) -> PlayerLoadout {
        var loadout = PlayerLoadout()
        guard let slots = equipment[playerID] else { return loadout }

        if let itemID = slots[CreatorItemKind.weapon.rawValue],
           let item = catalog.first(where: { $0.id == itemID }) {
            loadout.weaponNumericID = item.numericId
        }

        let armorKeys = [
            CreatorItemKind.armor.rawValue,
            CreatorItemKind.helmet.rawValue,
            CreatorItemKind.shield.rawValue,
        ]
        for key in armorKeys {
            guard let itemID = slots[key],
                  let item = catalog.first(where: { $0.id == itemID }) else { continue }
            loadout.armorNumericID = item.numericId
            break
        }
        return loadout
    }

    static func loadoutBonus(
        for playerID: UUID,
        equipment: PlayerEquipmentMap,
        catalog: [CreatedItem]
    ) -> EquipmentLoadoutBonus {
        BossFightStatsCalculator.bonus(
            from: loadout(for: playerID, equipment: equipment, catalog: catalog),
            catalog: catalog
        )
    }

    /// Statystyki widoczne w grze i w walce z bossem (baza + broń / pancerz).
    static func effectiveRuntimeStats(
        base: PlayerRuntimeStats,
        for playerID: UUID,
        equipment: PlayerEquipmentMap,
        catalog: [CreatedItem]
    ) -> PlayerRuntimeStats {
        let bonus = loadoutBonus(for: playerID, equipment: equipment, catalog: catalog)
        var stats = base
        stats.health = min(100, max(0, stats.health + bonus.health))
        stats.strength = min(100, max(0, stats.strength + bonus.strength))
        return stats
    }

    @discardableResult
    static func equip(
        _ item: CreatedItem,
        for playerID: UUID,
        ownedItemIDs: [UUID],
        equipment: inout PlayerEquipmentMap
    ) -> Result<Void, EquipError> {
        let kind = item.resolvedItemKind
        guard kind.isEquippable else { return .failure(.notEquippable) }
        let slotKind = kind.equipmentSlotKind
        guard ownedItemIDs.contains(item.id) else { return .failure(.notOwned) }

        var slots = equipment[playerID] ?? [:]
        for legacyKey in [CreatorItemKind.helmet.rawValue, CreatorItemKind.shield.rawValue] {
            slots.removeValue(forKey: legacyKey)
        }
        slots[slotKind.rawValue] = item.id
        equipment[playerID] = slots
        return .success(())
    }

    static func unequip(
        kind: CreatorItemKind,
        for playerID: UUID,
        equipment: inout PlayerEquipmentMap
    ) {
        let slotKind = kind.equipmentSlotKind
        equipment[playerID]?[slotKind.rawValue] = nil
        if slotKind == .armor {
            equipment[playerID]?[CreatorItemKind.helmet.rawValue] = nil
            equipment[playerID]?[CreatorItemKind.shield.rawValue] = nil
        }
        if equipment[playerID]?.isEmpty == true {
            equipment.removeValue(forKey: playerID)
        }
    }

    static func toggleEquip(
        _ item: CreatedItem,
        for playerID: UUID,
        ownedItemIDs: [UUID],
        equipment: inout PlayerEquipmentMap
    ) -> Result<Bool, EquipError> {
        if isEquipped(item, playerID: playerID, equipment: equipment) {
            unequip(kind: item.resolvedItemKind, for: playerID, equipment: &equipment)
            return .success(false)
        }
        switch equip(item, for: playerID, ownedItemIDs: ownedItemIDs, equipment: &equipment) {
        case .success:
            return .success(true)
        case .failure(let error):
            return .failure(error)
        }
    }

    static func decode(from snapshot: [String: [String: UUID]]) -> PlayerEquipmentMap {
        var map: PlayerEquipmentMap = [:]
        for (playerKey, slots) in snapshot {
            guard let playerID = UUID(uuidString: playerKey) else { continue }
            map[playerID] = slots
        }
        normalizeLegacyEquipmentSlots(in: &map)
        return map
    }

    static func encode(_ equipment: PlayerEquipmentMap) -> [String: [String: UUID]] {
        Dictionary(uniqueKeysWithValues: equipment.map { ($0.key.uuidString, $0.value) })
    }
}
