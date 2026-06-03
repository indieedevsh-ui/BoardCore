//
//  BossFightCombatIconPulseView.swift
//  DmdApp
//

import SwiftUI

struct BossFightCombatIconPulse: Identifiable, Equatable {
    enum Kind: Equatable {
        case attackPrimed
        case attackStrike
        case defense
        case bossAttack
        case bossDodge
        case bossHeal
    }

    let id = UUID()
    let kind: Kind
}

struct BossFightCombatIconPulseView: View {
    @Environment(AppSettings.self) private var settings

    let pulse: BossFightCombatIconPulse
    let onComplete: () -> Void

    @State private var backdropOpacity: Double = 0
    @State private var iconScale: CGFloat = 0.25
    @State private var iconRotation: Double = 0
    @State private var iconOpacity: Double = 0
    @State private var glowOpacity: Double = 0
    @State private var ringScale: CGFloat = 0.6
    @State private var ringOpacity: Double = 0
    @State private var dismissTask: Task<Void, Never>?

    private var iconName: String {
        switch pulse.kind {
        case .attackPrimed, .attackStrike: "bolt.fill"
        case .defense: "shield.lefthalf.filled"
        case .bossAttack: "flame.fill"
        case .bossDodge: "figure.run"
        case .bossHeal: "heart.circle.fill"
        }
    }

    private var accentColor: Color {
        switch pulse.kind {
        case .attackPrimed, .attackStrike: .yellow
        case .defense: .cyan
        case .bossAttack: .red
        case .bossDodge: .mint
        case .bossHeal: .green
        }
    }

    private var caption: String {
        switch pulse.kind {
        case .attackPrimed: "Atak!"
        case .attackStrike: "Cios!"
        case .defense: "Obrona!"
        case .bossAttack: "Boss atakuje!"
        case .bossDodge: "Boss unika!"
        case .bossHeal: "Boss się leczy!"
        }
    }

    var body: some View {
        ZStack {
            Color.black
                .opacity(0.42 * backdropOpacity)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(glowOpacity * 0.5))
                        .frame(
                            width: pulse.kind == .attackStrike || pulse.kind == .bossAttack ? 220 : 190,
                            height: pulse.kind == .attackStrike || pulse.kind == .bossAttack ? 220 : 190
                        )
                        .blur(radius: 20)

                    Circle()
                        .strokeBorder(accentColor.opacity(ringOpacity * 0.7), lineWidth: 3)
                        .frame(width: 150, height: 150)
                        .scaleEffect(ringScale)

                    Image(systemName: iconName)
                        .font(.system(size: iconFontSize, weight: .black))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [accentColor, accentColor.opacity(0.65), .white.opacity(0.95)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(iconScale)
                        .rotationEffect(.degrees(iconRotation))
                        .opacity(iconOpacity)
                        .shadow(color: accentColor.opacity(0.55), radius: 14)
                }

                Text(caption)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .opacity(iconOpacity)
            }
        }
        .allowsHitTesting(false)
        .onAppear { runAnimation() }
        .onDisappear { dismissTask?.cancel() }
    }

    private var iconFontSize: CGFloat {
        switch pulse.kind {
        case .attackStrike, .bossAttack: 96
        case .bossDodge, .bossHeal: 88
        default: 82
        }
    }

    private func runAnimation() {
        withAnimation(.easeOut(duration: 0.22)) {
            backdropOpacity = 1
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(60))
            guard !Task.isCancelled else { return }

            HapticManager.playStatReveal(intensity: settings.hapticIntensity * (pulse.kind == .attackStrike ? 1 : 0.75))
            settings.playTapSound()

            let startRotation: Double = pulse.kind == .defense ? -18 : -24
            iconRotation = startRotation

            withAnimation(.spring(response: 0.48, dampingFraction: 0.58)) {
                iconScale = pulse.kind == .attackStrike ? 1.15 : 1.05
                iconOpacity = 1
                glowOpacity = 1
                ringScale = 1.08
                ringOpacity = 1
                iconRotation = 0
            }

            withAnimation(.spring(response: 0.38, dampingFraction: 0.82).delay(0.08)) {
                iconScale = 1
                ringScale = 1
            }

            if pulse.kind == .attackStrike || pulse.kind == .bossAttack {
                withAnimation(.easeInOut(duration: 0.12).delay(0.15)) {
                    iconScale = 1.22
                }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7).delay(0.22)) {
                    iconScale = 1
                }
            }

            if pulse.kind == .bossDodge {
                withAnimation(.easeInOut(duration: 0.18).delay(0.1)) {
                    iconRotation = 14
                }
                withAnimation(.spring(response: 0.42, dampingFraction: 0.72).delay(0.24)) {
                    iconRotation = -10
                }
                withAnimation(.spring(response: 0.38, dampingFraction: 0.8).delay(0.36)) {
                    iconRotation = 0
                }
            }
        }

        let duration: UInt64 = switch pulse.kind {
        case .attackStrike, .bossAttack: 850
        case .bossDodge: 780
        case .bossHeal: 800
        default: 720
        }
        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(duration))
            guard !Task.isCancelled else { return }

            withAnimation(.easeIn(duration: 0.28)) {
                backdropOpacity = 0
                iconOpacity = 0
                glowOpacity = 0
                ringOpacity = 0
            }

            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled else { return }
            onComplete()
        }
    }
}

struct BossFightAbilityPillsRow: View {
    @Environment(AppSettings.self) private var settings

    let abilities: [GameplaySessionAbility]
    let selectedAbilityID: UUID?

    var body: some View {
        VStack(spacing: 8) {
            Text("Twoje zdolności — zeskanuj QR zdolności")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(abilities) { ability in
                        abilityPill(ability)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func abilityPill(_ ability: GameplaySessionAbility) -> some View {
        let isSelected = selectedAbilityID == ability.id
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.caption2)
                Text(ability.name)
                    .font(.caption.bold())
                    .lineLimit(1)
            }
            Text(ability.kindLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(ability.numericId)
                .font(.caption2.monospaced())
                .foregroundStyle(settings.accentColor.opacity(0.9))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            isSelected
                ? settings.accentColor.opacity(0.28)
                : Color.white.opacity(0.08),
            in: Capsule()
        )
        .overlay(
            Capsule()
                .strokeBorder(
                    isSelected ? settings.accentColor : Color.white.opacity(0.15),
                    lineWidth: isSelected ? 2 : 1
                )
        )
    }
}
