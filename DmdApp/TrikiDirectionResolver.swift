//
//  TrikiDirectionResolver.swift
//  DmdApp
//

import Foundation

/// Kierunek wskaźnika z histerezą — szybsza reakcja na zmianę strony bez „przyklejania”.
enum TrikiResolvedDirection: Equatable {
    case center
    case left
    case right

    var label: String {
        switch self {
        case .center: "środek"
        case .left: "lewo"
        case .right: "prawo"
        }
    }
}

enum TrikiDirectionResolver {
    /// Wejście w kierunek (niższe = szybsza reakcja).
    static let enterThreshold: Double = 0.09
    /// Powrót do środka / zmiana strony (mniejsze = szybsze puszczenie).
    static let exitThreshold: Double = 0.04

    static func resolve(posX: Double, previous: TrikiResolvedDirection) -> TrikiResolvedDirection {
        switch previous {
        case .center:
            if posX <= -enterThreshold { return .left }
            if posX >= enterThreshold { return .right }
            return .center
        case .left:
            if posX >= enterThreshold { return .right }
            if posX > -exitThreshold { return .center }
            return .left
        case .right:
            if posX <= -enterThreshold { return .left }
            if posX < exitThreshold { return .center }
            return .right
        }
    }
}
