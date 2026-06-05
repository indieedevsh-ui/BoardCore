//
//  PowerPathSkillUnlockOverlay.swift
//  BoardCore
//

import SwiftUI

struct PowerPathSkillUnlockOverlay: View {
    @Environment(AppSettings.self) private var settings

    let skill: PowerPathSkillID
    let side: PowerPathSide
    let detailMessage: String
    let onDismiss: () -> Void

    @State private var backdropOpacity: Double = 0
    @State private var ringScale: CGFloat = 0.3
    @State private var ringOpacity: Double = 0
    @State private var cardScale: CGFloat = 0.72
    @State private var cardOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var shimmerPhase: CGFloat = 0

    var body: some View {
        ZStack {
            Color.black.opacity(backdropOpacity * 0.72)
                .ignoresSafeArea()

            PowerPathAuraBackground(side: side)
                .opacity(backdropOpacity * 0.85)
                .allowsHitTesting(false)

            ZStack {
                Circle()
                    .strokeBorder(side.auraAccent.opacity(0.5), lineWidth: 2)
                    .frame(width: 280, height: 280)
                    .scaleEffect(ringScale)
                    .opacity(ringOpacity)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                side.auraAccent.opacity(0.35),
                                side.auraAccent.opacity(0.08),
                                Color.clear,
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 160
                        )
                    )
                    .frame(width: 320, height: 320)
                    .scaleEffect(ringScale * 1.05)
                    .opacity(ringOpacity * 0.9)

                VStack(spacing: 18) {
                    Image(systemName: skillIcon)
                        .font(.system(size: 56, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [side.auraAccent, side.auraAccent.opacity(0.65)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: side.auraAccent.opacity(0.65), radius: 24)

                    Text("Odblokowano!")
                        .font(.title.bold())

                    Text(skill.title)
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .multilineTextAlignment(.center)

                    Text(skill.summary)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)

                    Label(
                        "+\(PowerPathEngine.skillUnlockStrengthBonus) siły · +\(PowerPathEngine.skillUnlockHealthBonus) zdrowia",
                        systemImage: "arrow.up.circle.fill"
                    )
                    .font(.subheadline.bold())
                    .foregroundStyle(.green)

                    if let qr = skill.qrPayload {
                        Text("Kod QR: \(qr)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.orange)
                    }

                    if !detailMessage.isEmpty, detailMessage != "Odblokowano „\(skill.title)”." {
                        Text(detailMessage)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(28)
                .frame(maxWidth: 340)
                .background(
                    LiquidGlassBackground(accentStroke: side.auraAccent, cornerRadius: 24)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    side.auraAccent.opacity(0.7),
                                    side.auraAccent.opacity(0.15),
                                    side.auraAccent.opacity(0.5),
                                ],
                                startPoint: UnitPoint(x: shimmerPhase, y: 0),
                                endPoint: UnitPoint(x: shimmerPhase + 0.5, y: 1)
                            ),
                            lineWidth: 1.5
                        )
                }
                .scaleEffect(cardScale)
                .opacity(cardOpacity)
            }

            VStack {
                Spacer()
                Button {
                    settings.playTapSound()
                    dismissAnimated()
                } label: {
                    Text("Kontynuuj")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.appProminent)
                .tint(side.auraAccent)
                .padding(.horizontal, 40)
                .padding(.bottom, 36)
                .opacity(textOpacity)
            }
        }
        .onAppear { runReveal() }
    }


    private var skillIcon: String {
        switch skill.side {
        case .dark:
            switch skill {
            case .darkAura: "moon.haze.fill"
            case .curse: "eye.trianglebadge.exclamationmark.fill"
            case .shadow: "figure.stand.line.dotted.figure.stand"
            default: "moon.stars.fill"
            }
        case .light:
            switch skill {
            case .benevolent: "hands.sparkles.fill"
            case .protection: "shield.lefthalf.filled"
            case .healing: "heart.circle.fill"
            default: "sun.max.fill"
            }
        }
    }

    private func runReveal() {
        HapticManager.playStatReveal(intensity: settings.hapticIntensity * 0.9)
        settings.playStatsRevealSound()

        withAnimation(.easeOut(duration: 0.45)) {
            backdropOpacity = 1
        }

        withAnimation(.spring(response: 0.85, dampingFraction: 0.62)) {
            ringScale = 1.15
            ringOpacity = 1
        }

        withAnimation(.spring(response: 0.62, dampingFraction: 0.78).delay(0.12)) {
            cardScale = 1
            cardOpacity = 1
            textOpacity = 1
        }

        withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
            shimmerPhase = 1
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(5.5))
            dismissAnimated()
        }
    }

    private func dismissAnimated() {
        withAnimation(.easeInOut(duration: 0.35)) {
            backdropOpacity = 0
            cardOpacity = 0
            textOpacity = 0
            ringOpacity = 0
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(360))
            onDismiss()
        }
    }
}
