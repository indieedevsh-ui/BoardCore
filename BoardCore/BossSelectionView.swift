//
//  BossSelectionView.swift
//  BoardCore
//

import SwiftUI

struct BossSelectionView: View {
    @Environment(AppSettings.self) private var settings

    var highlightedDifficulty: BossDifficulty? = nil
    var trikiCancelHighlighted: Bool = false
    var trikiHoldChargeProgress: Double = 0
    let onSelect: (BossDefinition) -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            AppGradientBackground()

            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Wybierz bossa")
                            .font(.largeTitle.bold())
                        Text("Poziom trudności wpływa na statystyki bossa i nagrodę XP po zwycięstwie.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        settings.playTapSound()
                        onCancel()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(.plain)
                    .trikiSelectableHighlight(
                        isSelected: trikiCancelHighlighted,
                        chargeProgress: trikiCancelHighlighted ? trikiHoldChargeProgress : 0
                    )
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 28)

                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(BossDifficulty.allCases) { difficulty in
                            bossCard(BossDefinition(difficulty: difficulty))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .appThemedScreen()
    }

    private func bossCard(_ boss: BossDefinition) -> some View {
        Button {
            settings.playTapSound()
            onSelect(boss)
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(settings.accentColor.opacity(0.18))
                            .frame(width: 52, height: 52)
                        Image(systemName: boss.difficulty.icon)
                            .font(.title2)
                            .foregroundStyle(settings.accentColor)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(boss.difficulty.title)
                            .font(.title2.bold())
                        Text(boss.difficulty.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }

                BossStatsRow(
                    health: boss.maxHP,
                    strength: boss.combatStrength,
                    abilities: boss.difficulty.maxSpecialAbilityUses,
                    experience: boss.difficulty.victoryXPPool,
                    healthRingMax: max(200, boss.maxHP)
                )

                Text("Współpraca: 80% XP i monet dla gospodarza · 20% dla każdego uczestnika")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .liquidGlassButtonBackground(prominent: false, cornerRadius: 18)
        }
        .buttonStyle(.plain)
        .trikiSelectableHighlight(
            isSelected: highlightedDifficulty == boss.difficulty,
            chargeProgress: highlightedDifficulty == boss.difficulty ? trikiHoldChargeProgress : 0
        )
    }
}

private struct BossStatsRow: View {
    let health: Int
    let strength: Int
    let abilities: Int
    let experience: Int
    let healthRingMax: Int

    var body: some View {
        HStack(spacing: 0) {
            BossStatCircle(
                label: "Zdrowie",
                icon: "heart.fill",
                value: health,
                color: .green,
                ringMax: healthRingMax
            )
            BossStatCircle(
                label: "Siła",
                icon: "bolt.fill",
                value: strength,
                color: .red,
                ringMax: 40
            )
            BossStatCircle(
                label: "Zdolność",
                icon: "sparkles",
                value: abilities,
                color: .blue,
                ringMax: max(1, abilities)
            )
            BossStatCircle(
                label: "XP",
                icon: "star.circle.fill",
                value: experience,
                color: .purple,
                ringMax: max(80, experience)
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.04))
        )
    }
}

private struct BossStatCircle: View {
    let label: String
    let icon: String
    let value: Int
    let color: Color
    let ringMax: Int

    private var ringProgress: CGFloat {
        guard ringMax > 0 else { return 0 }
        return CGFloat(min(max(value, 0), ringMax)) / CGFloat(ringMax)
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.22), lineWidth: 4)
                    .frame(width: 58, height: 58)
                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 58, height: 58)
                VStack(spacing: 1) {
                    Image(systemName: icon)
                        .font(.caption2)
                        .foregroundStyle(color.opacity(0.9))
                    Text(displayValue)
                        .font(.caption.bold())
                        .minimumScaleFactor(0.55)
                        .lineLimit(1)
                }
            }
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(width: 72)
        }
        .frame(maxWidth: .infinity)
    }

    private var displayValue: String {
        if label == "Zdolność", value == 0 {
            return "—"
        }
        return "\(value)"
    }
}
