//
//  GameEventIntroOverlay.swift
//  DmdApp
//

import SwiftUI

struct GameEventIntroOverlay: View {
    @Environment(AppSettings.self) private var settings

    let playerGlow: PlayerGlowColor
    let event: QRGameEventCode
    let onComplete: () -> Void

    private var overlayAccent: Color {
        playerGlow.accentColor
    }

    @State private var backdropOpacity: Double = 0
    @State private var iconScale: CGFloat = 0.35
    @State private var iconOpacity: Double = 0
    @State private var titleOpacity: Double = 0
    @State private var titleOffset: CGFloat = 18
    @State private var dismissTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            AppGradientBackground(glow: playerGlow)
                .opacity(backdropOpacity)

            Color.black
                .opacity(0.42 * backdropOpacity)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: event.icon)
                    .font(.system(size: 88, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(overlayAccent)
                    .scaleEffect(iconScale)
                    .opacity(iconOpacity)

                Text(event.title)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .opacity(titleOpacity)
                    .offset(y: titleOffset)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .onAppear {
            runAnimation()
        }
        .onDisappear {
            dismissTask?.cancel()
        }
    }

    private func runAnimation() {
        withAnimation(.easeInOut(duration: 0.55)) {
            backdropOpacity = 1
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(160))
            guard !Task.isCancelled else { return }

            HapticManager.playStatReveal(intensity: settings.hapticIntensity)
            SoundManager.playTap(volume: settings.volume)

            withAnimation(.spring(response: 0.56, dampingFraction: 0.68)) {
                iconScale = 1.06
                iconOpacity = 1
            }

            withAnimation(.spring(response: 0.42, dampingFraction: 0.84).delay(0.1)) {
                iconScale = 1
            }

            withAnimation(.spring(response: 0.58, dampingFraction: 0.84).delay(0.22)) {
                titleOpacity = 1
                titleOffset = 0
            }
        }

        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1900))
            guard !Task.isCancelled else { return }

            withAnimation(.easeInOut(duration: 0.38)) {
                backdropOpacity = 0
                iconOpacity = 0
                titleOpacity = 0
            }

            try? await Task.sleep(for: .milliseconds(380))
            guard !Task.isCancelled else { return }
            onComplete()
        }
    }
}
