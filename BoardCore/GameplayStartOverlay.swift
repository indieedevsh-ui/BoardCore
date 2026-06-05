//
//  GameplayStartOverlay.swift
//  BoardCore
//

import SwiftUI

struct GameplayStartOverlay: View {
    @Environment(AppSettings.self) private var settings

    let playerGlow: PlayerGlowColor
    let onComplete: () -> Void

    private var overlayAccent: Color {
        playerGlow.accentColor
    }

    @State private var titleScale: CGFloat = 0.88
    @State private var titleOpacity: Double = 0
    @State private var backdropOpacity: Double = 1

    var body: some View {
        ZStack {
            AppGradientBackground(glow: playerGlow)
                .opacity(backdropOpacity)

            Text("Rozgrywka się zaczyna")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .shadow(color: overlayAccent.opacity(0.45), radius: 20, y: 4)
                .scaleEffect(titleScale)
                .opacity(titleOpacity)
                .padding(.horizontal, 32)
        }
        .ignoresSafeArea()
        .onAppear { runIntro() }
    }

    private func runIntro() {
        settings.playStatsRevealSound()
        HapticManager.playStatReveal(intensity: settings.hapticIntensity * 0.5)

        withAnimation(.spring(response: 0.7, dampingFraction: 0.78)) {
            titleScale = 1
            titleOpacity = 1
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(2200))
            withAnimation(.easeInOut(duration: 0.55)) {
                titleOpacity = 0
                backdropOpacity = 0
            }
            try? await Task.sleep(for: .milliseconds(580))
            onComplete()
        }
    }
}
