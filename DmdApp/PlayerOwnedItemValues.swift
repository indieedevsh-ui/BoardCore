//
//  PlayerOwnedItemValues.swift
//  DmdApp
//

import Foundation

enum PlayerOwnedItemValues {
    typealias ValueMap = [UUID: [UUID: Int]]

    static func effectiveValue(
        catalogCost: Int,
        playerID: UUID,
        itemID: UUID,
        values: ValueMap
    ) -> Int {
        values[playerID]?[itemID] ?? catalogCost
    }

    static func setValue(
        _ value: Int,
        playerID: UUID,
        itemID: UUID,
        values: inout ValueMap
    ) {
        var playerValues = values[playerID] ?? [:]
        playerValues[itemID] = max(1, value)
        values[playerID] = playerValues
    }

    static func removeItem(playerID: UUID, itemID: UUID, values: inout ValueMap) {
        values[playerID]?.removeValue(forKey: itemID)
        if values[playerID]?.isEmpty == true {
            values.removeValue(forKey: playerID)
        }
    }

    static func removePlayer(_ playerID: UUID, values: inout ValueMap) {
        values.removeValue(forKey: playerID)
    }

    /// Co turę każdy posiadany przedmiot losowo rośnie lub maleje o 1 monetę.
    static func fluctuateOnTurnAdvance(
        ownership: [UUID: [UUID]],
        itemsCatalog: [CreatedItem],
        values: inout ValueMap
    ) {
        for (playerID, itemIDs) in ownership {
            for itemID in itemIDs {
                let catalogCost = itemsCatalog.first { $0.id == itemID }?.cost ?? 1
                let current = effectiveValue(
                    catalogCost: catalogCost,
                    playerID: playerID,
                    itemID: itemID,
                    values: values
                )
                let delta = Bool.random() ? 1 : -1
                setValue(current + delta, playerID: playerID, itemID: itemID, values: &values)
            }
        }
    }
}
