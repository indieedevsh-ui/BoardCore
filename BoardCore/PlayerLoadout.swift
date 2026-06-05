//
//  PlayerLoadout.swift
//  BoardCore
//

import Foundation

/// Zawartość założonego ekwipunku gracza (broń + pancerz).
struct PlayerLoadout: Codable, Equatable {
    var weaponNumericID: String?
    var armorNumericID: String?
    /// Legacy — odczyt ze starych zapisów.
    var helmetNumericID: String?
    var shieldNumericID: String?

    var isEmpty: Bool {
        weaponNumericID == nil && armorItemNumericID == nil
    }

    /// Pancerz (w tym dawne hełm/tarcza w zapisie).
    var armorItemNumericID: String? {
        armorNumericID ?? helmetNumericID ?? shieldNumericID
    }
}
