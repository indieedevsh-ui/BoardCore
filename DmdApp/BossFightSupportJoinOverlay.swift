//
//  BossFightSupportJoinOverlay.swift
//  DmdApp
//

import SwiftUI

struct BossFightSupportJoinOverlay: View {
    @Environment(AppSettings.self) private var settings

    let presentation: BossFightSupportJoinPresentation
    let onComplete: () -> Void

    @State private var backdropOpacity: Double = 0
    @State private var iconScale: CGFloat = 0.4
    @State private var iconOpacity: Double = 0
    @State private var titleOpacity: Double = 0
    @State private var statsOpacity: Double = 0
    @State private var statsOffset: CGFloat = 18
    @State private var dismissTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Color.black.opacity(0.38 * backdropOpacity)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(settings.accentColor)
                    .scaleEffect(iconScale)
                    .opacity(iconOpacity)

                Text("Wsparcie dołącza")
                    .font(.headline)
                    .opacity(titleOpacity)

                Text(presentation.playerName)
                    .font(.title3.bold())
                    .opacity(titleOpacity)

                HStack(spacing: 14) {
                    if presentation.addedHealth > 0 {
                        deltaPill("❤️ +\(presentation.addedHealth)", color: .green)
                    }
                    if presentation.addedStrength > 0 {
                        deltaPill("⚔️ +\(presentation.addedStrength)", color: .red)
                    }
                    if presentation.addedArmor > 0 {
                        deltaPill("🛡 +\(presentation.addedArmor)", color: .orange)
                    }
                }
                .opacity(statsOpacity)
                .offset(y: statsOffset)
            }
            .padding(24)
        }
        .allowsHitTesting(false)
        .onAppear { runAnimation() }
        .onDisappear { dismissTask?.cancel() }
    }

    private func deltaPill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.2), in: Capsule())
    }

    private func runAnimation() {
        withAnimation(.easeOut(duration: 0.25)) { backdropOpacity = 1 }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            HapticManager.playStatReveal(intensity: settings.hapticIntensity * 0.8)
            SoundManager.playStatsRevealStep(volume: settings.volume)

            withAnimation(.spring(response: 0.52, dampingFraction: 0.62)) {
                iconScale = 1.08
                iconOpacity = 1
            }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82).delay(0.08)) {
                iconScale = 1
            }
            withAnimation(.spring(response: 0.58, dampingFraction: 0.84).delay(0.12)) {
                titleOpacity = 1
            }
            withAnimation(.spring(response: 0.58, dampingFraction: 0.84).delay(0.24)) {
                statsOpacity = 1
                statsOffset = 0
            }
        }

        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1500))
            withAnimation(.easeIn(duration: 0.28)) {
                backdropOpacity = 0
                iconOpacity = 0
                titleOpacity = 0
                statsOpacity = 0
            }
            try? await Task.sleep(for: .milliseconds(280))
            onComplete()
        }
    }
}
