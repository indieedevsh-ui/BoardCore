//
//  BossFightAttackAbilityPickerOverlay.swift
//  BoardCore
//

import SwiftUI

struct BossFightAttackAbilityPickerOverlay: View {
    @Environment(AppSettings.self) private var settings

    let abilities: [GameplaySessionAbility]
    let onSelectAbility: (GameplaySessionAbility) -> Void

    @State private var appeared = false
    @State private var bobPhase: Double = 0

    var body: some View {
        floatingAbilityField
            .scaleEffect(appeared ? 1 : 0.9)
            .opacity(appeared ? 1 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.58, dampingFraction: 0.82)) {
                    appeared = true
                }
                withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                    bobPhase = 1
                }
            }
    }

    private var floatingAbilityField: some View {
        ZStack {
            ForEach(Array(abilities.enumerated()), id: \.element.id) { index, ability in
                abilityOrb(ability, index: index, total: abilities.count)
            }
        }
        .frame(height: 168)
        .frame(maxWidth: 360)
    }

    private func abilityOrb(_ ability: GameplaySessionAbility, index: Int, total: Int) -> some View {
        let position = orbPosition(index: index, total: total)
        let bob = sin(bobPhase * .pi * 2 + Double(index) * 0.85) * 5

        return Button {
            settings.playTapSound()
            onSelectAbility(ability)
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    settings.accentColor.opacity(0.55),
                                    settings.accentColor.opacity(0.18),
                                ],
                                center: .center,
                                startRadius: 4,
                                endRadius: 38
                            )
                        )
                        .frame(width: 76, height: 76)
                        .shadow(color: settings.accentColor.opacity(0.35), radius: 10, y: 4)

                    Circle()
                        .strokeBorder(.white.opacity(0.35), lineWidth: 2)
                        .frame(width: 76, height: 76)

                    Image(systemName: abilityIcon(for: ability))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                }

                Text(ability.name)
                    .font(.caption2.bold())
                    .lineLimit(1)
                    .frame(maxWidth: 88)
                    .shadow(color: .black.opacity(0.45), radius: 4, y: 2)
            }
        }
        .buttonStyle(.plain)
        .offset(x: position.x, y: position.y + bob)
    }

    private func orbPosition(index: Int, total: Int) -> CGPoint {
        guard total > 1 else { return .zero }
        let angle = (Double(index) / Double(total)) * 2 * .pi - .pi / 2
        let radiusX = min(118, 38 + CGFloat(total) * 22)
        let radiusY: CGFloat = 34
        return CGPoint(
            x: cos(angle) * radiusX,
            y: sin(angle) * radiusY
        )
    }

    private func abilityIcon(for ability: GameplaySessionAbility) -> String {
        switch ability.kind {
        case .turnDamage: "bolt.fill"
        case .temporaryStatBoost: "heart.fill"
        case .boardMove: "sparkles"
        }
    }
}
