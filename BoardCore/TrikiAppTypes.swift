//
//  TrikiAppTypes.swift
//  BoardCore
//
//  Typy UI / logów aplikacji — wejście ruchu pochodzi z VeltoKit (`GameInput`).
//

import Foundation
import VeltoKit

struct TrikiFocusButton: Identifiable, Hashable {
    let id: String
    let title: String
}

enum TrikiInferredGestureKind: String, CaseIterable, Sendable {
    case rotateLeft = "Obrót w lewo (oś X)"
    case rotateRight = "Obrót w prawo (oś X)"
    case moveForward = "Przód (oś Y)"
    case moveBackward = "Tył (oś Y)"
    case strafeLeft = "W bok — lewo"
    case strafeRight = "W bok — prawo"
    case bowRelease = "Rzut gestem"
    case swordSwing = "Ruch / swing"
    case speedBurst = "Prędkość"
    case shake = "Potrząśnięcie"
    case physicalButton = "Przycisk fizyczny"
}

extension PointerDirection {
    var polishLabel: String {
        switch self {
        case .center: "środek"
        case .left: "lewo"
        case .right: "prawo"
        case .up: "przód"
        case .down: "tył"
        }
    }
}
