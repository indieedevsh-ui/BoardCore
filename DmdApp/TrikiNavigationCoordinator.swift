//
//  TrikiNavigationCoordinator.swift
//  DmdApp
//

import Foundation
import Observation
import SwiftUI
#if canImport(VeltoKit)
import VeltoKit
#endif

struct TrikiFocusButton: Identifiable, Hashable {
    let id: String
    let title: String
}

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

    var lastMotionGesture: TrikiInferredGestureKind?
    private(set) var motionGestureRevision = 0

    private var resolvedDirection: TrikiResolvedDirection = .center
    private var previousShakeForGesture = false
    private var lastSlideGestureAt: TimeInterval = 0

    private var registrationStack: [TrikiFocusRegistration] = []
    private var pollTask: Task<Void, Never>?
    private var overlayHideTask: Task<Void, Never>?
    private var reconnectAttemptAt: TimeInterval = 0
    private var trikiButtonHeldLastFrame = false
    private var trikiButtonPressBeganAt: TimeInterval?
    private var trikiLongPressActivated = false
    private var showPairingOverlay = false
    private var connectedBannerShown = false
    private var sessionCalibrated = false
    private var connectionHoldCount = 0
    private var pairingUIActive = false

#if canImport(VeltoKit)
    private var motionSDK: MotionSDK?
#endif

    private static let shortClickMaxDuration: TimeInterval = 0.42
    var longPressHoldDuration: TimeInterval = 1.5

    func setLongPressHoldDuration(_ duration: TimeInterval) {
        longPressHoldDuration = max(0.2, duration)
    }

    var activeButtons: [TrikiFocusButton] {
        registrationStack.last?.buttons ?? []
    }

#if canImport(VeltoKit)
    var isBLEConnected: Bool { motionSDK?.isConnected ?? false }
    var isBLEReceiving: Bool { motionSDK?.isReceiving ?? false }
    var livePointerX: Double { motionSDK?.liveInput.posX ?? 0 }
    var isTrikiConnectionActive: Bool { isEnabled && pollTask != nil }
#else
    var isBLEConnected: Bool { false }
    var isBLEReceiving: Bool { false }
    var livePointerX: Double { 0 }
    var isTrikiConnectionActive: Bool { false }
#endif

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

    func performCalibration() {
#if canImport(VeltoKit)
        guard let sdk = motionSDK else { return }
        TrikiMotionCalibration.applyUserCalibration(on: sdk)
#endif
        markSessionCalibrated()
    }

    func skipCalibration() {
        markSessionCalibrated()
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
#if canImport(VeltoKit)
        guard pollTask == nil else { return }
        connectionMessage = "Triki: szukam kontrolera…"
        showPairingOverlay = true
        connectedBannerShown = false

        let sdk = motionSDK ?? MotionSDK()
        TrikiMotionTuning.applyGentlePointerProfile(to: sdk)
        sdk.connect()
        motionSDK = sdk
        reconnectAttemptAt = Date().timeIntervalSinceReferenceDate
        resetButtonPressState()

        pollTask = Task { @MainActor in
            var previous = Date()
            while !Task.isCancelled {
                let now = Date()
                let delta = now.timeIntervalSince(previous)
                previous = now
                let nowRef = now.timeIntervalSinceReferenceDate
                refreshConnectionState(now: nowRef)
                pollMotionFrame(deltaTime: max(0.01, delta))
                if acceptsTrikiInput {
                    processPhysicalButton(now: nowRef)
                }
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
#endif
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
#if canImport(VeltoKit)
        motionSDK?.disconnect()
        motionSDK = nil
#endif
    }

#if canImport(VeltoKit)
    private func pollMotionFrame(deltaTime: TimeInterval) {
        guard let sdk = motionSDK else { return }
        let input = sdk.pollInput(deltaTime: deltaTime)
        debugDeltaX = sdk.debug.relX
        debugTiltX = input.tiltX
        debugTiltY = input.tiltY
        debugButtonHeld = BLEButtonDecoder.isPressed(sdk.lastButtonByte)
        debugShake = input.shake
        debugClick = input.primaryAction

        let previousDirection = resolvedDirection
        resolvedDirection = TrikiDirectionResolver.resolve(posX: input.posX, previous: resolvedDirection)
        debugPointerDirection = resolvedDirection.label

        if resolvedDirection == .left, previousDirection != .left {
            emitMotionGesture(.rotateLeft)
        } else if resolvedDirection == .right, previousDirection != .right {
            emitMotionGesture(.rotateRight)
        }
        if debugShake, !previousShakeForGesture {
            emitMotionGesture(.shake)
        }
        let now = Date().timeIntervalSinceReferenceDate
        if abs(sdk.debug.relX) >= TrikiMotionTuning.diagnosticDeltaThreshold,
           now - lastSlideGestureAt > 0.5 {
            emitMotionGesture(.slide)
            lastSlideGestureAt = now
        }
        previousShakeForGesture = debugShake
    }

    private func emitMotionGesture(_ kind: TrikiInferredGestureKind) {
        lastMotionGesture = kind
        motionGestureRevision += 1
    }
#endif

#if canImport(VeltoKit)
    private func refreshConnectionState(now: TimeInterval) {
        let connected = motionSDK?.isConnected ?? false
        let receiving = motionSDK?.isReceiving ?? false

        if !connected, now - reconnectAttemptAt > 2.8 {
            motionSDK?.connect()
            reconnectAttemptAt = now
        }

        if connected, receiving {
            connectionMessage = "Triki: połączono"
            if !sessionCalibrated {
                if pairingUIActive {
                    // Parowanie w arkuszu ustawień — kalibracja w tym arkuszu.
                } else {
                    showsCalibrationPrompt = true
                    showPairingOverlay = true
                    connectedBannerShown = false
                    overlayHideTask?.cancel()
                    overlayHideTask = nil
                }
            } else if !connectedBannerShown {
                connectedBannerShown = true
                overlayHideTask?.cancel()
                overlayHideTask = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(900))
                    showPairingOverlay = false
                }
            }
        } else if connected {
            connectionMessage = "Triki: czekam na dane…"
            if !sessionCalibrated {
                showsCalibrationPrompt = false
            } else if !connectedBannerShown {
                connectedBannerShown = true
                overlayHideTask?.cancel()
                overlayHideTask = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(900))
                    showPairingOverlay = false
                }
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

    private func processPhysicalButton(now: TimeInterval) {
        guard let sdk = motionSDK else { return }
        let buttonHeld = BLEButtonDecoder.isPressed(sdk.lastButtonByte)

        if buttonHeld, !trikiButtonHeldLastFrame {
            trikiButtonPressBeganAt = now
            trikiLongPressActivated = false
            holdChargeProgress = 0
        } else if buttonHeld, let beganAt = trikiButtonPressBeganAt {
            let elapsed = now - beganAt
            holdChargeProgress = min(1, elapsed / longPressHoldDuration)
            if elapsed >= longPressHoldDuration, !trikiLongPressActivated {
                trikiLongPressActivated = true
                activateCurrentSelection()
            }
        } else if !buttonHeld, trikiButtonHeldLastFrame {
            if let beganAt = trikiButtonPressBeganAt, !trikiLongPressActivated {
                let elapsed = now - beganAt
                if elapsed < Self.shortClickMaxDuration {
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
#endif

    func cycleSelectionForward() {
        let buttons = activeButtons
        guard !buttons.isEmpty else {
            statusMessage = "Brak opcji do wyboru."
            return
        }
        selectionIndex = (selectionIndex + 1) % buttons.count
        statusMessage = "Wybrano: \(buttons[selectionIndex].title)"
    }

    func cycleSelectionBackward() {
        let buttons = activeButtons
        guard !buttons.isEmpty else {
            statusMessage = "Brak opcji do wyboru."
            return
        }
        selectionIndex = (selectionIndex - 1 + buttons.count) % buttons.count
        statusMessage = "Wybrano: \(buttons[selectionIndex].title)"
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
