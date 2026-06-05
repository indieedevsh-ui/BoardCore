//
//  TrikiCalibrationOverlay.swift
//  BoardCore
//

import Combine
import SwiftUI
import VeltoKit

/// Wieloetapowa kalibracja neutralnej pozycji Triki.
struct TrikiCalibrationOverlay: View {
    @Environment(AppSettings.self) private var settings
    @Environment(TrikiNavigationCoordinator.self) private var coordinator

    var showsSkip = true
    var onFinished: (() -> Void)?

    @State private var step = 0
    @State private var sampleCount = 0

    private let steps = [
        "Krok 1/3: Trzymaj Triki nieruchomo w naturalnej pozycji.",
        "Krok 2/3: Lekko przechyl w lewo i wróć do środka (sprawdzenie osi X).",
        "Krok 3/3: Zatwierdź — zapiszemy pozycję neutralną."
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.72)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(settings.accentColor)

                Text("Kalibracja Triki")
                    .font(.title2.bold())

                Text(steps[min(step, steps.count - 1)])
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                signalCard

                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { index in
                        Capsule()
                            .fill(index <= step ? settings.accentColor : Color.white.opacity(0.2))
                            .frame(height: 4)
                    }
                }
                .padding(.horizontal, 12)

                VStack(spacing: 10) {
                    if step < 2 {
                        Button(step == 0 ? "Dalej" : "Zapisz neutralną") {
                            settings.playTapSound()
                            advanceStep()
                        }
                        .buttonStyle(.appProminent)
                        .disabled(!coordinator.isBLEReceiving)
                    } else {
                        Button("Zakończ kalibrację") {
                            settings.playTapSound()
                            finishCalibration()
                        }
                        .buttonStyle(.appProminent)
                        .disabled(!coordinator.isBLEReceiving)
                    }

                    if showsSkip {
                        Button("Później") {
                            settings.playTapSound()
                            coordinator.skipCalibration()
                            onFinished?()
                        }
                        .buttonStyle(.appSecondary)
                    }
                }
            }
            .padding(26)
            .frame(maxWidth: 380)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 18)
        }
        .onReceive(Timer.publish(every: 1.0 / 20.0, on: .main, in: .common).autoconnect()) { _ in
            if coordinator.isBLEReceiving, step == 0 {
                sampleCount += 1
            }
        }
    }

    private func advanceStep() {
        if step == 0 {
            coordinator.calibrateNeutralForSpeedometerDiagnostics()
            step = 1
            return
        }
        if step == 1 {
            coordinator.performCalibration()
            step = 2
        }
    }

    private func finishCalibration() {
        coordinator.performCalibration()
        settings.trikiControllerCalibrated = true
        onFinished?()
    }

    private var signalCard: some View {
        let ready = coordinator.isBLEReceiving
        let input = coordinator.lastGameInput

        return VStack(spacing: 8) {
            HStack {
                Circle()
                    .fill(ready ? Color.green : Color.orange)
                    .frame(width: 10, height: 10)
                Text(ready ? "Sygnał BLE OK" : "Czekam na dane…")
                    .font(.caption.bold())
                Spacer()
                Text(coordinator.debugPointerDirection)
                    .font(.caption.monospaced())
            }

            HStack(spacing: 12) {
                axisLabel("X", value: input.posX)
                axisLabel("Y", value: input.posY)
                axisLabel("tilt", value: input.tiltX)
            }
            .font(.caption2.monospaced())

            if step == 0, ready {
                Text("Próbki stabilności: \(sampleCount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }

    private func axisLabel(_ name: String, value: Double) -> some View {
        Text(String(format: "%@ %+.2f", name, value))
    }
}
