//
//  TrikiMotionCalibration.swift
//  DmdApp
//

import Foundation
#if canImport(VeltoKit)
import VeltoKit

/// Kalibracja pozycji neutralnej kontrolera Triki (VeltoKit).
enum TrikiMotionCalibration {
    /// Użytkownik trzyma kontroler w pozycji neutralnej i zatwierdza kalibrację.
    @MainActor
    static func applyUserCalibration(on motion: MotionSDK) {
        TrikiMotionTuning.applyGentlePointerProfile(to: motion)

        for _ in 0 ..< 15 {
            _ = motion.pollInput(deltaTime: 0.016)
        }

        motion.calibrateNeutralPose()
        _ = motion.pollInput(deltaTime: 0.016)
    }
}
#endif
