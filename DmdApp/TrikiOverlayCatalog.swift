//
//  TrikiOverlayCatalog.swift
//  DmdApp
//

import SwiftUI

// MARK: - Power Path

enum PowerPathTrikiTarget: Hashable {
    case exitGame
    case dismissReveal
    case back
    case openSide(PowerPathSide)
    case openCustomPath(UUID)
    case unlockSide(PowerPathSide)
    case unlockSkill(PowerPathSkillID, PowerPathSide)
    case applyCurse
    case unlockCustomPath(UUID)
    case unlockCustomUpgrade(pathID: UUID, upgradeID: UUID)
}

struct PowerPathTrikiRow: Identifiable, Hashable {
    let target: PowerPathTrikiTarget
    let title: String

    var id: String {
        switch target {
        case .exitGame: "exit"
        case .dismissReveal: "dismiss-reveal"
        case .back: "back"
        case .openSide(let side): "open-\(side.rawValue)"
        case .openCustomPath(let id): "browse-\(id.uuidString)"
        case .unlockSide(let side): "unlock-side-\(side.rawValue)"
        case .unlockSkill(let skill, _): "skill-\(skill.rawValue)"
        case .applyCurse: "curse"
        case .unlockCustomPath(let id): "unlock-custom-\(id.uuidString)"
        case .unlockCustomUpgrade(let pathID, let upgradeID):
            "upgrade-\(pathID.uuidString)-\(upgradeID.uuidString)"
        }
    }
}

// MARK: - Ekwipunek

enum EquipmentTrikiTarget: Hashable {
    case toggleEquip(UUID)
    case exit
}

struct EquipmentTrikiRow: Identifiable, Hashable {
    let target: EquipmentTrikiTarget
    let title: String

    var id: String {
        switch target {
        case .toggleEquip(let itemID): "item-\(itemID.uuidString)"
        case .exit: "exit"
        }
    }
}

// MARK: - Podświetlenie

struct TrikiSelectableHighlightModifier: ViewModifier {
    @Environment(AppSettings.self) private var settings

    let isSelected: Bool
    let chargeProgress: Double

    func body(content: Content) -> some View {
        content.overlay {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(settings.accentColor.opacity(isSelected ? chargeProgress * 0.44 : 0))
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isSelected ? settings.accentColor.opacity(0.5 + chargeProgress * 0.45) : .clear,
                        lineWidth: isSelected ? (2.0 + chargeProgress * 1.5) : 0
                    )
            }
            .shadow(
                color: isSelected ? settings.accentColor.opacity(0.35 + chargeProgress * 0.5) : .clear,
                radius: 6 + chargeProgress * 12
            )
            .animation(.easeOut(duration: 0.12), value: chargeProgress)
            .animation(.easeInOut(duration: 0.16), value: isSelected)
        }
    }
}

extension View {
    func trikiSelectableHighlight(isSelected: Bool, chargeProgress: Double = 0) -> some View {
        modifier(TrikiSelectableHighlightModifier(isSelected: isSelected, chargeProgress: chargeProgress))
    }
}
