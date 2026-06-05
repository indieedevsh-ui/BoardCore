//
//  PlayerAddedOverlay.swift
//  BoardCore
//

import SwiftUI

struct PlayerAddedOverlay: View {
    @Environment(AppSettings.self) private var settings

    let playerName: String
    let onComplete: () -> Void

    @State private var glowSpread: CGFloat = 0.08
    @State private var glowOpacity: Double = 0
    @State private var plusScale: CGFloat = 0.35
    @State private var plusOpacity: Double = 0
    @State private var labelOpacity: Double = 0
    @State private var dismissTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { geometry in
            let maxDimension = max(geometry.size.width, geometry.size.height)
            let spreadRadius = maxDimension * glowSpread

            ZStack {
                Color.black
                    .ignoresSafeArea()

                RadialGradient(
                    colors: [
                        settings.backgroundColor.opacity(0.98),
                        settings.backgroundColor.opacity(0.72),
                        settings.backgroundColor.opacity(0.34),
                        Color.clear,
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: spreadRadius
                )
                .opacity(glowOpacity)
                .ignoresSafeArea()

                LinearGradient(
                    stops: [
                        .init(color: settings.backgroundColor.opacity(0.35 * glowOpacity), location: 0),
                        .init(color: settings.backgroundColor.opacity(0.18 * glowOpacity), location: 0.35),
                        .init(color: Color.black.opacity(0.45), location: 0.75),
                        .init(color: Color.black, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .opacity(glowOpacity)
                .ignoresSafeArea()

                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 76, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(settings.accentColor)
                    .shadow(color: settings.accentColor.opacity(0.45), radius: 20, y: 4)
                    .scaleEffect(plusScale)
                    .opacity(plusOpacity)
            }
        }
        .ignoresSafeArea()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Text("Dodano: \(playerName)")
                .font(.title2.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.top, 14)
                .padding(.bottom, 8)
                .opacity(labelOpacity)
                .background {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .overlay(alignment: .top) {
                            Divider().opacity(0.35)
                        }
                        .ignoresSafeArea(edges: .bottom)
                }
        }
        .onAppear {
            runAnimation()
        }
        .onDisappear {
            dismissTask?.cancel()
        }
    }

    private func runAnimation() {
        HapticManager.playStatReveal(intensity: settings.hapticIntensity)
        SoundManager.playTap(volume: settings.volume)

        withAnimation(.easeInOut(duration: 0.65)) {
            glowOpacity = 1
        }

        withAnimation(.timingCurve(0.2, 0.05, 0.15, 1.0, duration: 1.1)) {
            glowSpread = 1.15
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(420))
            guard !Task.isCancelled else { return }

            withAnimation(.spring(response: 0.52, dampingFraction: 0.68)) {
                plusScale = 1.08
                plusOpacity = 1
            }

            withAnimation(.spring(response: 0.42, dampingFraction: 0.82).delay(0.1)) {
                plusScale = 1
            }
        }

        withAnimation(.easeOut(duration: 0.45).delay(0.85)) {
            labelOpacity = 1
        }

        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1900))
            guard !Task.isCancelled else { return }

            withAnimation(.easeInOut(duration: 0.45)) {
                glowOpacity = 0
                glowSpread = 0.08
                plusOpacity = 0
                plusScale = 0.85
                labelOpacity = 0
            }

            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            onComplete()
        }
    }
}
