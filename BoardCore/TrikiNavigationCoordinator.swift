//
//  TrikiNavigationCoordinator.swift
//  BoardCore
//
//  Sterowanie Triki przez VeltoKit (`MotionSDK` + `GameInput`).
//

import Foundation
import Observation
import SwiftUI
import VeltoKit

struct TrikiFocusRegistration {
    let id: UUID
    let buttons: [TrikiFocusButton]
    let onActivate: (Int) -> Void

    var fingerprint: String {
        buttons.map(\.id).joined(separator: "|")
    }
}

@Observable
@MainActor
final class TrikiNavigationCoordinator {
    let motion = MotionSDK()

    var isEnabled = false
    var isBlocked = false
    var selectionIndex = 0
    var holdChargeProgress: Double = 0
    var statusMessage = ""
    var connectionMessage = ""
    var showsCalibrationPrompt = false

    var debugDeltaX = 0.0
    var debugTiltX = 0.0
    var debugTiltY = 0.0
    var debugPointerDirection = "środek"
    var debugButtonHeld = false
    var debugShake = false
    var debugClick = false
    var debugSwingPhase = "—"
    var debugSwingMotion: Double = 0
    var debugSwingGyro: Double = 0
    var debugSwingPosY: Double = 0
    var debugRelY: Double = 0
    var debugSensorSpeed: Double = 0
    var debugSensorMotion: Double = 0
    var debugConnectedRSSI: Int?

    var lastMotionGesture: TrikiInferredGestureKind?
    var lastMotionGestureDetail = ""
    private(set) var motionGestureRevision = 0
    private(set) var lastGameInput = GameInput()

    var activityLog: TrikiControllerLogStore?

    var isBLEConnected: Bool { motion.isConnected }
    var isBLEReceiving: Bool { motion.isReceiving }
    var livePointerX: Double = 0
    var isTrikiConnectionActive: Bool { isEnabled && pollTask != nil }
    var hasCachedBLEDevice: Bool { motion.hasCachedBLEDevice }
    var trikiBLEModeLabel: String {
        switch motion.trikiBLEMode {
        case .fast: "szybki"
        case .normal: "normalny"
        case .lowPower: "oszczędny"
        case .unknown: "nieznany"
        }
    }

    private var registrationStack: [TrikiFocusRegistration] = []
    private var pollTask: Task<Void, Never>?
    private var overlayHideTask: Task<Void, Never>?
    private var trikiButtonHeldLastFrame = false
    private var trikiButtonPressBeganAt: TimeInterval?
    private var trikiLongPressActivated = false
    private var showPairingOverlay = false
    private var connectedBannerShown = false
    private var sessionCalibrated = false
    private var connectionHoldCount = 0
    private var pairingUIActive = false

    private var previousPointerDirection: PointerDirection = .center
    private var previousShake = false
    private var previousFlick = false
    private var previousShot = false
    private var lastMotionGestureAt: TimeInterval = 0

    private static let shortClickMaxDuration: TimeInterval = 0.42
    private static let motionGestureCooldown: TimeInterval = 0.38
    var longPressHoldDuration: TimeInterval = 0.8

    func setLongPressHoldDuration(_ duration: TimeInterval) {
        longPressHoldDuration = max(0.2, duration)
    }

    var activeButtons: [TrikiFocusButton] {
        registrationStack.last?.buttons ?? []
    }

    private var acceptsTrikiInput: Bool {
        isEnabled && !isBlocked
    }

    var highlightIndex: Int? {
        guard acceptsTrikiInput, !activeButtons.isEmpty else { return nil }
        return min(max(0, selectionIndex), activeButtons.count - 1)
    }

    var showPairingBanner: Bool {
        showPairingOverlay && isEnabled && acceptsTrikiInput && !showsCalibrationPrompt
    }

    func applyPersistedCalibration(_ calibrated: Bool) {
        if calibrated {
            sessionCalibrated = true
        }
    }

    func beginConnectionHold() {
        connectionHoldCount += 1
        pairingUIActive = true
        refreshPolling()
    }

    func endConnectionHold() {
        connectionHoldCount = max(0, connectionHoldCount - 1)
        pairingUIActive = connectionHoldCount > 0
        refreshPolling()
    }

    func startScanningForPairing() {
        motion.configure(for: .menu)
        motion.connect()
    }

    func connectToCachedDevice() {
        motion.configure(for: .menu)
        motion.connectLastDevice()
    }

    func performCalibration() {
        motion.configure(for: .menu)
        motion.calibrateNeutralPose()
        lastGameInput = motion.snapshotInput()
        previousPointerDirection = .center
        livePointerX = lastGameInput.posX
        debugSwingPhase = "—"
        activityLog?.record(.system, title: "Kalibracja wykonana (VeltoKit)")
        markSessionCalibrated()
    }

    func skipCalibration() {
        motion.discardStaleButtonInput()
        activityLog?.record(.system, title: "Pominięto kalibrację")
        markSessionCalibrated()
    }

    func calibrateNeutralForSpeedometerDiagnostics() {
        motion.calibrateNeutralPose()
    }

    private func markSessionCalibrated() {
        sessionCalibrated = true
        showsCalibrationPrompt = false
        showPairingOverlay = false
        connectedBannerShown = true
        overlayHideTask?.cancel()
        overlayHideTask = nil
        statusMessage = "Triki: skalibrowano pozycję neutralną."
    }

    private func refreshPolling() {
        if isEnabled {
            startPollingIfNeeded()
        } else {
            stopPolling()
        }
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if !enabled {
            sessionCalibrated = false
            showsCalibrationPrompt = false
            logActivity(.system, title: "Triki wyłączone w aplikacji")
        } else {
            logActivity(.system, title: "Triki włączone w aplikacji")
        }
        refreshPolling()
    }

    func setBlocked(_ blocked: Bool) {
        isBlocked = blocked
        refreshPolling()
    }

    func register(_ registration: TrikiFocusRegistration) {
        registrationStack.removeAll { $0.id == registration.id }
        registrationStack.append(registration)
        reconcileSelection(resetToFirst: true)
    }

    func unregister(id: UUID) {
        registrationStack.removeAll { $0.id == id }
        reconcileSelection(resetToFirst: true)
    }

    func reconcileSelection(resetToFirst: Bool = false) {
        let count = activeButtons.count
        if count == 0 {
            selectionIndex = 0
            return
        }
        if resetToFirst || selectionIndex >= count {
            selectionIndex = 0
        }
    }

    func clearRegistrations() {
        registrationStack.removeAll()
        selectionIndex = 0
    }

    private func startPollingIfNeeded() {
        guard pollTask == nil else { return }
        connectionMessage = "Triki: szukam kontrolera…"
        showPairingOverlay = true
        connectedBannerShown = false

        motion.configure(for: .menu)
        motion.connect()
        previousPointerDirection = .center
        previousShake = false
        previousFlick = false
        previousShot = false
        resetButtonPressState()

        pollTask = Task { @MainActor in
            var previous = Date()
            while !Task.isCancelled {
                let now = Date()
                let delta = now.timeIntervalSince(previous)
                previous = now
                refreshConnectionState()
                pollMotionFrame(deltaTime: max(0.01, delta))
                if acceptsTrikiInput {
                    processPhysicalButton(now: now.timeIntervalSinceReferenceDate)
                }
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }

    private func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
        overlayHideTask?.cancel()
        overlayHideTask = nil
        connectionMessage = ""
        showPairingOverlay = false
        connectedBannerShown = false
        showsCalibrationPrompt = false
        resetButtonPressState()
        motion.disconnect()
    }

    private func pollMotionFrame(deltaTime: TimeInterval) {
        let input = motion.pollInput(deltaTime: deltaTime)
        lastGameInput = input

        debugDeltaX = input.deltaX
        debugTiltX = input.tiltX
        debugTiltY = input.tiltY
        debugButtonHeld = BLEButtonDecoder.isPressed(motion.lastButtonByte)
        debugShake = input.shake
        debugClick = input.bleButtonClick

        livePointerX = input.posX
        debugPointerDirection = input.pointerDirection.polishLabel
        debugRelY = input.deltaY
        debugSensorSpeed = input.trikiVelocity
        debugSensorMotion = input.intensity
        debugSwingPosY = input.posY
        debugSwingMotion = input.intensity
        debugSwingGyro = input.sensors.gyroZ

        detectSDKGestures(input: input)
        previousPointerDirection = input.pointerDirection
    }

    /// Impulsy z VeltoKit (`GameInput`) — bez własnego parsera BLE.
    private func detectSDKGestures(input: GameInput) {
        if input.shake, !previousShake {
            emitMotionGesture(.shake, detail: "trikiVelocity \(String(format: "%.2f", input.trikiVelocity))")
        }
        previousShake = input.shake

        if input.flick, !previousFlick {
            debugSwingPhase = "swing"
            emitMotionGesture(
                .swordSwing,
                detail: String(format: "flick · mot %.2f · v %.2f", input.intensity, input.trikiVelocity)
            )
        }
        previousFlick = input.flick

        if input.shotTriggered, !previousShot {
            debugSwingPhase = "rzut"
            emitMotionGesture(
                .bowRelease,
                detail: String(format: "power %.0f%% · posY %+.2f", input.throwPower * 100, input.posY)
            )
        }
        previousShot = input.shotTriggered

        if sessionCalibrated {
            switch input.pointerDirection {
            case .left where previousPointerDirection != .left:
                emitMotionGesture(.rotateLeft, detail: String(format: "posX %+.2f", input.posX))
            case .right where previousPointerDirection != .right:
                emitMotionGesture(.rotateRight, detail: String(format: "posX %+.2f", input.posX))
            case .up where previousPointerDirection != .up:
                emitMotionGesture(.moveForward, detail: String(format: "posY %+.2f", input.posY))
            case .down where previousPointerDirection != .down:
                emitMotionGesture(.moveBackward, detail: String(format: "posY %+.2f", input.posY))
            default:
                break
            }
        }
    }

    private func emitMotionGesture(_ kind: TrikiInferredGestureKind, detail: String = "") {
        if kind != .physicalButton {
            let now = Date().timeIntervalSinceReferenceDate
            guard now - lastMotionGestureAt >= Self.motionGestureCooldown else { return }
            lastMotionGestureAt = now
        }
        lastMotionGesture = kind
        lastMotionGestureDetail = detail.isEmpty ? kind.rawValue : detail
        motionGestureRevision += 1
        activityLog?.recordGesture(kind, detail: lastMotionGestureDetail)
    }

    private func logActivity(
        _ category: TrikiLogCategory,
        title: String,
        detail: String = ""
    ) {
        activityLog?.record(category, title: title, detail: detail)
    }

    private func refreshConnectionState() {
        let connected = motion.isConnected
        let receiving = motion.isReceiving

        if connected, receiving {
            connectionMessage = "Triki: połączono · \(trikiBLEModeLabel)"
            if let hint = motion.trikiIdleStatusMessage, !hint.isEmpty {
                connectionMessage += " · \(hint)"
            }
            if !sessionCalibrated {
                if !pairingUIActive {
                    showsCalibrationPrompt = true
                    showPairingOverlay = true
                    connectedBannerShown = false
                    overlayHideTask?.cancel()
                    overlayHideTask = nil
                }
            } else if !connectedBannerShown {
                connectedBannerShown = true
                scheduleHidePairingOverlay()
            }
        } else if connected {
            connectionMessage = "Triki: czekam na dane…"
            if !sessionCalibrated {
                showsCalibrationPrompt = false
            } else if !connectedBannerShown {
                connectedBannerShown = true
                scheduleHidePairingOverlay()
            }
        } else {
            connectionMessage = "Triki: szukam kontrolera BLE…"
            showsCalibrationPrompt = false
            connectedBannerShown = false
            if !sessionCalibrated {
                showPairingOverlay = true
            }
        }
    }

    private func scheduleHidePairingOverlay() {
        overlayHideTask?.cancel()
        overlayHideTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            showPairingOverlay = false
        }
    }

    private func processPhysicalButton(now: TimeInterval) {
        let buttonHeld = BLEButtonDecoder.isPressed(motion.lastButtonByte)

        if buttonHeld, !trikiButtonHeldLastFrame {
            trikiButtonPressBeganAt = now
            trikiLongPressActivated = false
            holdChargeProgress = 0
        } else if buttonHeld, let beganAt = trikiButtonPressBeganAt {
            let elapsed = now - beganAt
            holdChargeProgress = min(1, elapsed / longPressHoldDuration)
            if elapsed >= longPressHoldDuration, !trikiLongPressActivated {
                trikiLongPressActivated = true
                let label = activeButtons.indices.contains(selectionIndex)
                    ? activeButtons[selectionIndex].title
                    : "—"
                logActivity(.button, title: "Długie przytrzymanie", detail: "aktywacja: \(label)")
                emitMotionGesture(.physicalButton, detail: "długie · \(label)")
                activateCurrentSelection()
            }
        } else if !buttonHeld, trikiButtonHeldLastFrame {
            if let beganAt = trikiButtonPressBeganAt, !trikiLongPressActivated {
                let elapsed = now - beganAt
                if elapsed < Self.shortClickMaxDuration {
                    logActivity(
                        .button,
                        title: "Krótki klik",
                        detail: String(format: "czas %.0f ms", elapsed * 1000)
                    )
                    emitMotionGesture(.physicalButton, detail: "krótki klik")
                    cycleSelection()
                }
            }
            trikiButtonPressBeganAt = nil
            holdChargeProgress = 0
            trikiLongPressActivated = false
        } else if !buttonHeld {
            holdChargeProgress = 0
        }

        trikiButtonHeldLastFrame = buttonHeld
    }

    func cycleSelectionForward() {
        let buttons = activeButtons
        guard !buttons.isEmpty else {
            statusMessage = "Brak opcji do wyboru."
            return
        }
        selectionIndex = (selectionIndex + 1) % buttons.count
        statusMessage = "Wybrano: \(buttons[selectionIndex].title)"
        logActivity(
            .navigation,
            title: "Następna opcja",
            detail: buttons[selectionIndex].title
        )
    }

    func cycleSelectionBackward() {
        let buttons = activeButtons
        guard !buttons.isEmpty else {
            statusMessage = "Brak opcji do wyboru."
            return
        }
        selectionIndex = (selectionIndex - 1 + buttons.count) % buttons.count
        statusMessage = "Wybrano: \(buttons[selectionIndex].title)"
        logActivity(
            .navigation,
            title: "Poprzednia opcja",
            detail: buttons[selectionIndex].title
        )
    }

    func activateHighlightedSelection() {
        activateCurrentSelection()
    }

    private func cycleSelection() {
        cycleSelectionForward()
    }

    private func activateCurrentSelection() {
        let buttons = activeButtons
        guard !buttons.isEmpty else { return }
        let index = min(max(0, selectionIndex), buttons.count - 1)
        registrationStack.last?.onActivate(index)
        statusMessage = "Wciśnięto: \(buttons[index].title)"
        logActivity(.navigation, title: "Aktywacja opcji", detail: buttons[index].title)
    }

    private func resetButtonPressState() {
        trikiButtonHeldLastFrame = false
        trikiButtonPressBeganAt = nil
        trikiLongPressActivated = false
        holdChargeProgress = 0
    }
}

// MARK: - Rejestracja kontekstu w widokach

private struct TrikiFocusRegistrar: View {
    @Environment(TrikiNavigationCoordinator.self) private var coordinator

    let id: UUID
    let buttons: [TrikiFocusButton]
    let onActivate: (Int) -> Void

    private var fingerprint: String {
        buttons.map(\.id).joined(separator: "|")
    }

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear { publish() }
            .onDisappear { coordinator.unregister(id: id) }
            .onChange(of: fingerprint) { _, _ in publish() }
    }

    private func publish() {
        guard !buttons.isEmpty else {
            coordinator.unregister(id: id)
            return
        }
        coordinator.register(
            TrikiFocusRegistration(id: id, buttons: buttons, onActivate: onActivate)
        )
    }
}

extension View {
    func trikiFocusContext(
        id: UUID = UUID(),
        buttons: [TrikiFocusButton],
        onActivate: @escaping (Int) -> Void
    ) -> some View {
        background {
            TrikiFocusRegistrar(id: id, buttons: buttons, onActivate: onActivate)
        }
    }
}

// MARK: - Host na poziomie aplikacji

struct TrikiNavigationHostModifier: ViewModifier {
    @Environment(AppSettings.self) private var settings
    @Environment(TrikiNavigationCoordinator.self) private var coordinator

    let isBlocked: Bool

    private var showsCalibrationCover: Binding<Bool> {
        Binding(
            get: { coordinator.showsCalibrationPrompt },
            set: { isPresented in
                if !isPresented, coordinator.showsCalibrationPrompt {
                    coordinator.skipCalibration()
                }
            }
        )
    }

    func body(content: Content) -> some View {
        content
            .onAppear {
                coordinator.setEnabled(settings.trikiControllerEnabled)
                coordinator.applyPersistedCalibration(settings.trikiControllerCalibrated)
                coordinator.setBlocked(isBlocked)
            }
            .onChange(of: settings.trikiControllerEnabled) { _, enabled in
                coordinator.setEnabled(enabled)
                if enabled {
                    coordinator.applyPersistedCalibration(settings.trikiControllerCalibrated)
                }
            }
            .onChange(of: settings.trikiControllerCalibrated) { _, calibrated in
                coordinator.applyPersistedCalibration(calibrated)
            }
            .onChange(of: isBlocked) { _, blocked in
                coordinator.setBlocked(blocked)
            }
            .fullScreenCover(isPresented: showsCalibrationCover) {
                TrikiCalibrationOverlay(showsSkip: true)
            }
    }
}

extension View {
    func trikiNavigationHost(isBlocked: Bool) -> some View {
        modifier(TrikiNavigationHostModifier(isBlocked: isBlocked))
    }
}
