//
//  TrikiCalibrationOverlay.swift
//  DmdApp
//

import SwiftUI
#if canImport(VeltoKit)
import VeltoKit
#endif

/// Ekran kalibracji — trzymaj Triki w ręce i zatwierdź pozycję neutralną.
struct TrikiCalibrationOverlay: View {
    @Environment(AppSettings.self) private var settings
    @Environment(TrikiNavigationCoordinator.self) private var coordinator

    var showsSkip = true
    var onFinished: (() -> Void)?

    var body: some View {
        ZStack {
            Color.black.opacity(0.72)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(settings.accentColor)

                VStack(spacing: 10) {
                    Text("Trzymaj Triki w ręce")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)

                    Text("Ustaw kontroler naturalnie, lekko wyprostuj nadgarstek, a potem naciśnij „Kalibruj”.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 8)

                signalCard

                VStack(spacing: 12) {
                    Button("Kalibruj") {
                        settings.playTapSound()
                        coordinator.performCalibration()
                        settings.trikiControllerCalibrated = true
                        onFinished?()
                    }
                    .buttonStyle(.appProminent)
                    .disabled(!coordinator.isBLEReceiving)

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
            .padding(28)
            .frame(maxWidth: 360)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 20)
        }
    }

    private var signalCard: some View {
        let ready = coordinator.isBLEReceiving
        let posX = coordinator.livePointerX

        return VStack(spacing: 10) {
            HStack {
                Circle()
                    .fill(ready ? Color.green : Color.orange)
                    .frame(width: 10, height: 10)
                Text(ready ? "Sygnał BLE OK" : "Czekam na dane z Triki…")
                    .font(.caption.bold())
                    .foregroundStyle(ready ? Color.green : Color.orange)
                Spacer()
                Text(String(format: "pos %+.2f", posX))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                let center = geo.size.width / 2
                let bar = geo.size.width * min(1, abs(posX))
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.white.opacity(0.12))
                    if posX < 0 {
                        Rectangle()
                            .fill(settings.accentColor)
                            .frame(width: bar)
                            .offset(x: center - bar)
                    } else if posX > 0 {
                        Rectangle()
                            .fill(settings.accentColor)
                            .frame(width: bar)
                            .offset(x: center)
                    }
                    Rectangle()
                        .fill(Color.white.opacity(0.55))
                        .frame(width: 2)
                        .offset(x: center - 1)
                }
            }
            .frame(height: 22)
        }
        .padding(12)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }
}
