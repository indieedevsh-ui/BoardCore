//
//  TrikiControllerDiagnosticsStore.swift
//  DmdApp
//

import Foundation
import Observation
#if canImport(VeltoKit)
import VeltoKit
#endif

struct TrikiDebugEvent: Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let title: String
    let detail: String

    init(title: String, detail: String, timestamp: Date = Date()) {
        self.id = UUID()
        self.timestamp = timestamp
        self.title = title
        self.detail = detail
    }
}

enum TrikiInferredGestureKind: String, CaseIterable {
    case slide = "Pochylenie / przesunięcie"
    case rotateLeft = "Obrót w lewo"
    case rotateRight = "Obrót w prawo"
    case shake = "Potrząśnięcie"
    case click = "Klik"
    case physicalButton = "Przycisk fizyczny"
}

@Observable
@MainActor
final class TrikiControllerDiagnosticsStore {
    var isMonitoring = false

    var connectionStatus = "Monitor wyłączony"
    var lastDetectedAction = "—"
    var lastInferredGesture: TrikiInferredGestureKind?
    var liveSensorSummary = ""
    var events: [TrikiDebugEvent] = []

    private var smoothedPosX = 0.0
    private var smoothedDeltaX = 0.0
    private var previousPosX = 0.0
    private var previousButtonHeld = false
    private var previousShake = false
    private var previousDirectionLabel = "środek"
    private var lastSlideGestureAt: TimeInterval = 0

    func setMonitoring(_ enabled: Bool) {
        isMonitoring = enabled
        if !enabled {
            connectionStatus = "Monitor wyłączony"
            resetTransientState()
        }
    }

    func clearEvents() {
        events.removeAll()
    }

#if canImport(VeltoKit)
    func ingest(from coordinator: TrikiNavigationCoordinator) {
        guard isMonitoring else { return }

        if coordinator.isBLEReceiving {
            connectionStatus = "Połączono · odbiór danych"
        } else if coordinator.isBLEConnected {
            connectionStatus = "Połączono · brak pakietów"
        } else if coordinator.isTrikiConnectionActive {
            connectionStatus = "Szukam kontrolera BLE…"
        } else {
            connectionStatus = "Triki wyłączone w ustawieniach"
        }

        let posX = coordinator.livePointerX
        let deltaX = coordinator.debugDeltaX
        let tiltX = coordinator.debugTiltX
        let tiltY = coordinator.debugTiltY
        let direction = coordinator.debugPointerDirection
        let buttonHeld = coordinator.debugButtonHeld
        let shake = coordinator.debugShake

        smoothedPosX += (posX - smoothedPosX) * TrikiMotionTuning.diagnosticDisplayBlend
        smoothedDeltaX += (deltaX - smoothedDeltaX) * TrikiMotionTuning.diagnosticDisplayBlend

        let directionLabel = direction

        liveSensorSummary = String(
            format: "pos %+.2f · Δ %+.2f · tilt %+.2f/%+.2f · %@ · btn %@",
            smoothedPosX,
            smoothedDeltaX,
            tiltX,
            tiltY,
            directionLabel,
            buttonHeld ? "TAK" : "nie"
        )

        detectEvents(
            posX: smoothedPosX,
            deltaX: smoothedDeltaX,
            rawDeltaX: deltaX,
            direction: directionLabel,
            buttonHeld: buttonHeld,
            shake: shake
        )

        previousPosX = smoothedPosX
        previousButtonHeld = buttonHeld
        previousShake = shake
        previousDirectionLabel = directionLabel
    }
#endif

    private func resetTransientState() {
        smoothedPosX = 0
        smoothedDeltaX = 0
        previousPosX = 0
        previousButtonHeld = false
        previousShake = false
        previousDirectionLabel = "środek"
        lastSlideGestureAt = 0
        lastDetectedAction = "—"
        lastInferredGesture = nil
        liveSensorSummary = ""
    }

    private func detectEvents(
        posX: Double,
        deltaX: Double,
        rawDeltaX: Double,
        direction: String,
        buttonHeld: Bool,
        shake: Bool
    ) {
        let now = Date().timeIntervalSinceReferenceDate

        if buttonHeld, !previousButtonHeld {
            record(.physicalButton, detail: "BLEButtonDecoder: wciśnięty")
        }

        if shake, !previousShake {
            record(.shake, detail: "Impuls shake z parsera BLE")
        }

        if abs(rawDeltaX) >= TrikiMotionTuning.diagnosticDeltaThreshold,
           now - lastSlideGestureAt > 0.55 {
            record(.slide, detail: String(format: "Δx=%+.2f", rawDeltaX))
            lastSlideGestureAt = now
        }

        if direction == "lewo", previousDirectionLabel != "lewo" {
            record(.rotateLeft, detail: String(format: "posX=%+.2f", posX))
        } else if direction == "prawo", previousDirectionLabel != "prawo" {
            record(.rotateRight, detail: String(format: "posX=%+.2f", posX))
        }

        if direction != "środek", direction != previousDirectionLabel {
            lastDetectedAction = "Kierunek: \(direction)"
        }
    }

    private func record(_ kind: TrikiInferredGestureKind, detail: String) {
        lastInferredGesture = kind
        lastDetectedAction = kind.rawValue
        appendEvent(title: kind.rawValue, detail: detail)
    }

    private func appendEvent(title: String, detail: String) {
        events.insert(TrikiDebugEvent(title: title, detail: detail), at: 0)
        if events.count > 80 {
            events.removeLast(events.count - 80)
        }
    }
}
