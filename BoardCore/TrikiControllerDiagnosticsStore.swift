//
//  TrikiControllerDiagnosticsStore.swift
//  BoardCore
//

import Foundation
import Observation
import VeltoKit

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

enum TrikiDiagnosticsMonitorMode: String, CaseIterable, Identifiable {
    case rotate
    case translation
    case speedometer
    case actions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rotate: "Oś X"
        case .translation: "Ruch 3D"
        case .speedometer: "Prędkość"
        case .actions: "Gest / rzut"
        }
    }

    var idleHint: String {
        switch self {
        case .rotate: "Monitor: obrót lewo / prawo (VeltoKit posX)"
        case .translation: "Monitor: przód, tył (VeltoKit posY)"
        case .speedometer: "Monitor: trikiVelocity z SDK"
        case .actions: "Monitor: flick, shot, shake"
        }
    }
}

@Observable
@MainActor
final class TrikiControllerDiagnosticsStore {
    static let diagnosticDisplayBlend: Double = 0.22

    var isMonitoring = false
    var connectionStatus = "Monitor wyłączony"
    var lastDetectedAction = "—"
    var lastInferredGesture: TrikiInferredGestureKind?
    var liveSensorSummary = ""
    var events: [TrikiDebugEvent] = []
    var monitorMode: TrikiDiagnosticsMonitorMode = .rotate

    private var smoothedPosX = 0.0
    private var previousDirectionLabel = "środek"
    private var lastRecordedMotionGestureRevision = 0
    private var speedPeak: Double = 0
    private var speedPeakAt: TimeInterval = 0

    weak var activityLog: TrikiControllerLogStore?

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

    func setMonitorMode(_ mode: TrikiDiagnosticsMonitorMode) {
        guard monitorMode != mode else { return }
        monitorMode = mode
        events.removeAll()
        resetDetectionTracking()
        lastDetectedAction = mode.idleHint
        lastInferredGesture = nil
    }

    func ingest(from coordinator: TrikiNavigationCoordinator) {
        guard isMonitoring else { return }

        if coordinator.isBLEReceiving {
            connectionStatus = "Połączono · \(coordinator.trikiBLEModeLabel) · odbiór"
        } else if coordinator.isBLEConnected {
            connectionStatus = "Połączono · brak pakietów"
        } else if coordinator.isTrikiConnectionActive {
            connectionStatus = "Szukam kontrolera BLE…"
        } else {
            connectionStatus = "Triki wyłączone w ustawieniach"
        }

        let input = coordinator.lastGameInput
        let posX = input.posX
        let posY = input.posY
        let tiltX = input.tiltX
        let tiltY = input.tiltY
        let direction = input.pointerDirection.polishLabel
        let velocity = input.trikiVelocity

        smoothedPosX += (posX - smoothedPosX) * Self.diagnosticDisplayBlend

        liveSensorSummary = liveSummary(
            mode: monitorMode,
            posX: smoothedPosX,
            posY: posY,
            velocity: velocity,
            tiltX: tiltX,
            tiltY: tiltY,
            direction: direction,
            flick: input.flick,
            shot: input.shotTriggered
        )

        switch monitorMode {
        case .rotate:
            detectRotateEvents(posX: smoothedPosX, direction: direction)
        case .translation:
            detectTranslationEvents(direction: direction, posY: posY, tiltX: tiltX)
        case .actions:
            detectActionEvents(input: input)
        case .speedometer:
            applySpeedometer(velocity: velocity, moving: input.isMoving)
        }

        detectSwingEvents(from: coordinator)
        previousDirectionLabel = direction
    }

    private func resetTransientState() {
        smoothedPosX = 0
        resetDetectionTracking()
        lastDetectedAction = "—"
        lastInferredGesture = nil
        liveSensorSummary = ""
    }

    private func resetDetectionTracking() {
        previousDirectionLabel = "środek"
        lastRecordedMotionGestureRevision = 0
        speedPeak = 0
        speedPeakAt = 0
    }

    private func liveSummary(
        mode: TrikiDiagnosticsMonitorMode,
        posX: Double,
        posY: Double,
        velocity: Double,
        tiltX: Double,
        tiltY: Double,
        direction: String,
        flick: Bool,
        shot: Bool
    ) -> String {
        switch mode {
        case .rotate:
            return String(
                format: "[%@] posX %+.2f · %@ · tilt %+.2f/%+.2f",
                mode.title, posX, direction, tiltX, tiltY
            )
        case .translation:
            return String(
                format: "[%@] posY %+.2f · %@ · tiltX %+.2f",
                mode.title, posY, direction, tiltX
            )
        case .actions:
            return String(
                format: "[%@] flick %@ · shot %@ · v %.2f · posY %+.2f",
                mode.title, flick ? "tak" : "nie", shot ? "tak" : "nie", velocity, posY
            )
        case .speedometer:
            return String(
                format: "[%@] %.2f · ruch %@ · BLE %@",
                mode.title,
                velocity,
                velocity > 0.35 ? "tak" : "nie",
                direction
            )
        }
    }

    private func detectRotateEvents(posX: Double, direction: String) {
        if direction == "lewo", previousDirectionLabel != "lewo" {
            record(.rotateLeft, detail: String(format: "posX=%+.2f", posX))
        } else if direction == "prawo", previousDirectionLabel != "prawo" {
            record(.rotateRight, detail: String(format: "posX=%+.2f", posX))
        }
    }

    private func detectTranslationEvents(direction: String, posY: Double, tiltX: Double) {
        if direction == "przód", previousDirectionLabel != "przód" {
            record(.moveForward, detail: String(format: "posY=%+.2f", posY))
        } else if direction == "tył", previousDirectionLabel != "tył" {
            record(.moveBackward, detail: String(format: "posY=%+.2f", posY))
        } else if tiltX > 0.14, !previousDirectionLabel.contains("prawo") {
            record(.strafeRight, detail: String(format: "tiltX=%+.2f", tiltX))
        } else if tiltX < -0.14, !previousDirectionLabel.contains("lewo") {
            record(.strafeLeft, detail: String(format: "tiltX=%+.2f", tiltX))
        }
    }

    private func detectActionEvents(input: GameInput) {
        if input.shotTriggered {
            record(
                .bowRelease,
                detail: String(format: "power %.0f%%", input.throwPower * 100)
            )
        } else if input.flick {
            record(.swordSwing, detail: String(format: "v %.2f", input.trikiVelocity))
        } else if input.shake {
            record(.shake, detail: "shake")
        }
    }

    private func detectSwingEvents(from coordinator: TrikiNavigationCoordinator) {
        let revision = coordinator.motionGestureRevision
        guard revision != lastRecordedMotionGestureRevision else { return }
        lastRecordedMotionGestureRevision = revision
        guard let kind = coordinator.lastMotionGesture else { return }
        switch kind {
        case .bowRelease, .swordSwing, .shake:
            record(kind, detail: coordinator.lastMotionGestureDetail)
        default:
            break
        }
    }

    private func applySpeedometer(velocity: Double, moving: Bool) {
        lastDetectedAction = String(format: "Prędkość SDK: %.2f", velocity)
        guard moving, velocity > 0.5 else {
            speedPeak = 0
            return
        }
        let now = Date().timeIntervalSinceReferenceDate
        if velocity >= speedPeak {
            speedPeak = velocity
            speedPeakAt = now
        } else if speedPeak > 0, now - speedPeakAt > 0.35 {
            let detail = String(format: "szczyt %.2f", speedPeak)
            record(.speedBurst, detail: detail)
            activityLog?.recordGesture(.speedBurst, detail: detail)
            speedPeak = 0
        }
    }

    private func record(_ kind: TrikiInferredGestureKind, detail: String) {
        guard shouldRecord(kind) else { return }
        lastInferredGesture = kind
        lastDetectedAction = kind == .speedBurst
            ? String(format: "Prędkość: %@", detail)
            : kind.rawValue
        appendEvent(title: kind.rawValue, detail: detail)
    }

    private func shouldRecord(_ kind: TrikiInferredGestureKind) -> Bool {
        switch monitorMode {
        case .rotate:
            kind == .rotateLeft || kind == .rotateRight
        case .translation:
            kind == .moveForward || kind == .moveBackward || kind == .strafeLeft || kind == .strafeRight
        case .actions:
            kind == .bowRelease || kind == .swordSwing || kind == .shake
        case .speedometer:
            kind == .speedBurst
        }
    }

    private func appendEvent(title: String, detail: String) {
        events.insert(TrikiDebugEvent(title: title, detail: detail), at: 0)
        if events.count > 80 {
            events.removeLast(events.count - 80)
        }
    }
}
