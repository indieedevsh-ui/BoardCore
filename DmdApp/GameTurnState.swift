//
//  GameTurnState.swift
//  DmdApp
//

import Foundation
import Observation

struct GameEventLogEntry: Identifiable, Hashable, Codable {
    let id: UUID
    let round: Int
    let playerNumber: Int
    let playerName: String
    let message: String

    init(
        id: UUID = UUID(),
        round: Int,
        playerNumber: Int,
        playerName: String,
        message: String
    ) {
        self.id = id
        self.round = round
        self.playerNumber = playerNumber
        self.playerName = playerName
        self.message = message
    }
}

@Observable
final class GameTurnState {
    private(set) var currentPlayerIndex = 0
    private(set) var roundNumber = 1
    private(set) var turnAdvanceCount = 0
    private(set) var eventLog: [GameEventLogEntry] = []
    private(set) var lastTurnMessage = ""

    var currentPlayerNumber: Int { currentPlayerIndex + 1 }

    func currentPlayer(in players: [PlayerCharacter]) -> PlayerCharacter? {
        players[safe: currentPlayerIndex]
    }

    func reset() {
        currentPlayerIndex = 0
        roundNumber = 1
        turnAdvanceCount = 0
        eventLog = []
        lastTurnMessage = ""
    }

    func restore(currentPlayerIndex: Int, roundNumber: Int, eventLog: [GameEventLogEntry], lastTurnMessage: String) {
        self.currentPlayerIndex = currentPlayerIndex
        self.roundNumber = max(1, roundNumber)
        self.eventLog = eventLog
        self.lastTurnMessage = lastTurnMessage
    }

    func clampCurrentPlayerIndex(activePlayerCount: Int) {
        guard activePlayerCount > 0 else {
            currentPlayerIndex = 0
            return
        }
        currentPlayerIndex = min(max(currentPlayerIndex, 0), activePlayerCount - 1)
    }

    func snapshot() -> (currentPlayerIndex: Int, roundNumber: Int, eventLog: [GameEventLogEntry], lastTurnMessage: String) {
        (currentPlayerIndex, roundNumber, eventLog, lastTurnMessage)
    }

    func skipTurn(activePlayer: PlayerCharacter, totalPlayers: Int) {
        appendLog(
            playerNumber: currentPlayerNumber,
            playerName: activePlayer.className,
            message: "Pominął turę."
        )
        lastTurnMessage = "Gracz \(currentPlayerNumber) (\(activePlayer.className)) pominął turę."
        advance(totalPlayers: totalPlayers)
    }

    func applyGameEvent(_ event: QRGameEventCode, activePlayer: PlayerCharacter, totalPlayers: Int) {
        appendLog(
            playerNumber: currentPlayerNumber,
            playerName: activePlayer.className,
            message: "\(event.title): \(event.effectDescription)"
        )
        lastTurnMessage = "Gracz \(currentPlayerNumber) (\(activePlayer.className)) — \(event.title)."
        advance(totalPlayers: totalPlayers)
    }

    func appendStartFieldStayLog(activePlayer: PlayerCharacter) {
        appendLog(
            playerNumber: currentPlayerNumber,
            playerName: activePlayer.className,
            message: "Jestem na start — +20% zdrowia."
        )
        lastTurnMessage = "Gracz \(currentPlayerNumber) (\(activePlayer.className)) zatrzymał się na polu start."
    }

    func completeStartFieldStay(activePlayer: PlayerCharacter, totalPlayers: Int) {
        lastTurnMessage = "Tura przechodzi do następnego gracza po polu start."
        _ = activePlayer
        advance(totalPlayers: totalPlayers)
    }

    func advanceToNextPlayer(totalPlayers: Int) {
        advance(totalPlayers: totalPlayers)
    }

    func clampCurrentPlayerIndexAfterRemoval(
        removedIndex: Int,
        wasCurrentPlayer: Bool,
        activePlayerCount: Int
    ) {
        guard activePlayerCount > 0 else {
            currentPlayerIndex = 0
            return
        }
        if removedIndex < currentPlayerIndex {
            currentPlayerIndex -= 1
        } else if wasCurrentPlayer, currentPlayerIndex >= activePlayerCount {
            currentPlayerIndex = 0
        }
        currentPlayerIndex = min(max(currentPlayerIndex, 0), activePlayerCount - 1)
    }

    func logCustomEvent(playerName: String, message: String, turnMessage: String? = nil) {
        appendLog(
            playerNumber: currentPlayerNumber,
            playerName: playerName,
            message: message
        )
        if let turnMessage {
            lastTurnMessage = turnMessage
        }
    }

    func beginStartFieldPass(activePlayer: PlayerCharacter) {
        lastTurnMessage = "Gracz \(currentPlayerNumber) (\(activePlayer.className)) przechodzi przez start — wybierz decyzję."
    }

    func completeStartFieldPass(activePlayer: PlayerCharacter, choice: String, totalPlayers: Int) {
        appendLog(
            playerNumber: currentPlayerNumber,
            playerName: activePlayer.className,
            message: "Przeszedł przez start: \(choice). +\(StartFieldRewards.passCoins) monet."
        )
        lastTurnMessage = "Gracz \(currentPlayerNumber) (\(activePlayer.className)) przeszedł przez start i otrzymał \(StartFieldRewards.passCoins) monet."
        advance(totalPlayers: totalPlayers)
    }

    private func advance(totalPlayers: Int) {
        guard totalPlayers > 0 else { return }
        currentPlayerIndex += 1
        if currentPlayerIndex >= totalPlayers {
            currentPlayerIndex = 0
            roundNumber += 1
        }
        turnAdvanceCount += 1
    }

    private func appendLog(playerNumber: Int, playerName: String, message: String) {
        eventLog.insert(
            GameEventLogEntry(
                round: roundNumber,
                playerNumber: playerNumber,
                playerName: playerName,
                message: message
            ),
            at: 0
        )
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
