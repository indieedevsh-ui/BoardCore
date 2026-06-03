//
//  TrikiMotionTuning.swift
//  DmdApp
//

import Foundation
#if canImport(VeltoKit)
import VeltoKit

/// Parametry VeltoKit — mniejsza czułość i więcej wygładzania niż domyślny preset `.pointer`.
enum TrikiMotionTuning {
    /// Wygładzanie wyświetlanych wartości w zakładce diagnostycznej.
    static let diagnosticDisplayBlend: Double = 0.22

    /// Próg kierunku (używany z TrikiDirectionResolver).
    static let diagnosticDirectionThreshold: Double = TrikiDirectionResolver.enterThreshold

    /// Minimalna |Δ| do zarejestrowania ruchu w diagnostyce.
    static let diagnosticDeltaThreshold: Double = 0.38

    /// Minimalny skok |Δ| względem poprzedniej klatki.
    static let diagnosticDeltaStepMin: Double = 0.14

    @MainActor
    static func applyGentlePointerProfile(to motion: MotionSDK) {
        motion.setMode(.pointer)
        var config = MotionConfig.preset(for: .pointer)
        config.deadzone = 0.06
        config.inputSmoothing = 0.22
        config.pointerSensitivity = 0.016
        config.pointerRotDamping = 0.992
        config.pointerOutputSmoothing = 0.045
        config.gestureThreshold = 0.45
        config.gestureCooldown = 0.65
        config.gestureMinRelY = 0.14
        config.gestureMinThrustSpeed = 0.18
        config.gesturePullSpeed = 0.09
        config.gesturePullbackDelta = 0.16
        motion.config = config
    }
}
#endif
