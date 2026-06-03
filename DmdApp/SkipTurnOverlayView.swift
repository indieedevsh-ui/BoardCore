//
//  SkipTurnOverlayView.swift
//  DmdApp
//

import SwiftUI

struct SkipTurnFullScreenOverlay: View {
    @Environment(AppSettings.self) private var settings

    let playerGlow: PlayerGlowColor
    let playerName: String
    let onComplete: () -> Void

    @State private var backdropOpacity: Double = 0
    @State private var xScale: CGFloat = 0.2
    @State private var xRotation: Double = -28
    @State private var xOpacity: Double = 0
    @State private var glowOpacity: Double = 0
    @State private var messageOpacity: Double = 0
    @State private var messageOffset: CGFloat = 24
    @State private var dismissTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            AppGradientBackground(glow: playerGlow)
                .opacity(backdropOpacity)

            Color.black
                .opacity(0.35 * backdropOpacity)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer(minLength: 0)

                ZStack {
                    Circle()
                        .fill(Color.red.opacity(glowOpacity * 0.45))
                        .frame(width: 180, height: 180)
                        .blur(radius: 18)

                    Circle()
                        .strokeBorder(Color.red.opacity(glowOpacity * 0.55), lineWidth: 3)
                        .frame(width: 140, height: 140)

                    Image(systemName: "xmark")
                        .font(.system(size: 92, weight: .black))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.red, .red.opacity(0.75)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(xScale)
                        .rotationEffect(.degrees(xRotation))
                        .opacity(xOpacity)
                }

                Text("Gracz-\(playerName) pominął turę")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .opacity(messageOpacity)
                    .offset(y: messageOffset)

                Spacer(minLength: 0)
            }
            .padding(24)
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
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }

            HapticManager.playSkipTurn(intensity: settings.hapticIntensity)
            SoundManager.playSkipTurn(volume: settings.volume)

            withAnimation(.spring(response: 0.52, dampingFraction: 0.58)) {
                xScale = 1.08
                xRotation = 0
                xOpacity = 1
                glowOpacity = 1
            }

            withAnimation(.spring(response: 0.45, dampingFraction: 0.82).delay(0.12)) {
                xScale = 1
            }

            withAnimation(.spring(response: 0.62, dampingFraction: 0.84).delay(0.28)) {
                messageOpacity = 1
                messageOffset = 0
            }

            withAnimation(.easeInOut(duration: 0.8).delay(0.55)) {
                glowOpacity = 0.35
            }
        }

        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(2400))
            guard !Task.isCancelled else { return }

            withAnimation(.easeInOut(duration: 0.4)) {
                backdropOpacity = 0
                xOpacity = 0
                messageOpacity = 0
            }

            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            onComplete()
        }
    }
}
