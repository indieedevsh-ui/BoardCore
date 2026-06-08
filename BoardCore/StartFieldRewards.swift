//
//  StartFieldRewards.swift
//  BoardCore
//

import Foundation

enum StartFieldRewards {
    static var passCoins: Int { GameRulesRuntime.current.startField.passCoins }
    static var stayAtFullHealthCoins: Int { GameRulesRuntime.current.startField.stayAtFullHealthCoins }
    static var stayAtFullHealthXP: Int { GameRulesRuntime.current.startField.stayAtFullHealthXP }
    static var maxHealth: Int { GameRulesRuntime.current.startField.maxHealth }
    static var stayHealPercentOfCurrent: Int { GameRulesRuntime.current.startField.stayHealPercentOfCurrent }
}
