//
//  ArtifactDrawOverlay.swift
//  DmdApp
//

import SwiftUI

struct ArtifactDrawOverlay: View {
    @Environment(AppSettings.self) private var settings

    let playerGlow: PlayerGlowColor
    let playerName: String
    let outcome: ArtifactOutcome
    var onRevealed: (() -> Void)? = nil
    let onComplete: () -> Void

    @State private var backdropOpacity: Double = 0
    @State private var brushRotation: Double = -32
    @State private var brushScale: CGFloat = 1
    @State private var sparkleOpacity: Double = 0.35
    @State private var isRevealed = false
    @State private var revealScale: CGFloat = 0.82
    @State private var revealOpacity: Double = 0
    @State private var brushTask: Task<Void, Never>?
    @State private var dismissTask: Task<Void, Never>?

    private let brushDuration: TimeInterval = 2.0

    var body: some View {
        ZStack {
            AppGradientBackground(glow: playerGlow)
                .opacity(backdropOpacity)

            Color.black.opacity(0.48 * backdropOpacity)
                .ignoresSafeArea()

            crystalSparkles
                .opacity(backdropOpacity * sparkleOpacity)

            VStack(spacing: 24) {
                Text(isRevealed ? "Artefakt ujawniony!" : "Odkrywanie artefaktu…")
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Text(playerName)
                    .font(.headline)
                    .foregroundStyle(.secondary)

                if isRevealed {
                    revealedOutcome
                } else {
                    wavingBrush
                }

                if isRevealed {
                    Button("Kontynuuj") {
                        settings.playTapSound()
                        onComplete()
                    }
                    .buttonStyle(.appProminent)
                    .padding(.horizontal, 24)
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .onAppear { runFlow() }
        .onDisappear {
            brushTask?.cancel()
            dismissTask?.cancel()
        }
    }

    private var crystalSparkles: some View {
        GeometryReader { geometry in
            ForEach(0..<14, id: \.self) { index in
                Image(systemName: "sparkle")
                    .font(.system(size: CGFloat(10 + index % 5 * 4)))
                    .foregroundStyle(settings.accentColor.opacity(0.25 + Double(index % 3) * 0.15))
                    .position(
                        x: geometry.size.width * CGFloat((index * 37) % 100) / 100,
                        y: geometry.size.height * CGFloat((index * 53 + 11) % 100) / 100
                    )
                    .opacity(sparkleOpacity)
            }
        }
        .ignoresSafeArea()
    }

    private var wavingBrush: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            settings.accentColor.opacity(0.35),
                            settings.accentColor.opacity(0.08),
                            Color.clear,
                        ],
                        center: .center,
                        startRadius: 8,
                        endRadius: 120
                    )
                )
                .frame(width: 220, height: 220)
                .blur(radius: 8)

            Image(systemName: "paintbrush.pointed.fill")
                .font(.system(size: 96, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, settings.accentColor, .cyan.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .rotationEffect(.degrees(brushRotation), anchor: UnitPoint(x: 0.18, y: 0.82))
                .scaleEffect(brushScale)
                .shadow(color: settings.accentColor.opacity(0.45), radius: 18, y: 6)
        }
        .frame(height: 240)
    }

    private var revealedOutcome: some View {
        VStack(spacing: 14) {
            Image(systemName: outcome.icon)
                .font(.system(size: 52, weight: .semibold))
                .foregroundStyle(outcome.isPositive ? Color.cyan : Color.red)

            Text(outcome.title)
                .font(.title3.bold())
                .multilineTextAlignment(.center)

            Text(outcome.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let brushBonusSummary = outcome.brushBonusSummary {
                Text(brushBonusSummary)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .frame(maxWidth: 320)
        .background(
            LiquidGlassBackground(
                accentStroke: outcome.isPositive ? .cyan : .red,
                cornerRadius: 20
            )
        )
        .scaleEffect(revealScale)
        .opacity(revealOpacity)
    }

    private func runFlow() {
        withAnimation(.easeInOut(duration: 0.45)) {
            backdropOpacity = 1
        }

        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
            sparkleOpacity = 0.85
        }

        brushTask = Task { @MainActor in
            let start = Date()
            var tickIndex = 0

            while !Task.isCancelled {
                let elapsed = Date().timeIntervalSince(start)
                if elapsed >= brushDuration { break }

                let phase = min(1, elapsed / brushDuration)

                withAnimation(.easeInOut(duration: 0.28)) {
                    brushRotation = brushRotation > 0 ? -32 : 32
                    brushScale = 0.96 + CGFloat(phase) * 0.08
                }

                settings.playArtifactBrushFeedback(tickIndex: tickIndex, phase: phase)
                tickIndex += 1

                try? await Task.sleep(for: .milliseconds(95))
            }

            guard !Task.isCancelled else { return }

            settings.playArtifactRevealSound(positive: outcome.isPositive)

            withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
                isRevealed = true
                revealScale = 1
                revealOpacity = 1
            }
            onRevealed?()
        }

        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(7000))
            guard !Task.isCancelled, isRevealed else { return }
            onComplete()
        }
    }
}
