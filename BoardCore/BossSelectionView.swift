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
                        Text("Poziom trudności wpływa na HP, obrażenia i zdolności bossa.")
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
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: boss.difficulty.icon)
                        .font(.title)
                        .foregroundStyle(settings.accentColor)
                        .frame(width: 44)

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

                HStack(spacing: 20) {
                    statPill(icon: "heart.fill", label: "HP bossa", value: "\(boss.maxHP)", color: .green)
                    statPill(icon: "bolt.fill", label: "Siła", value: "\(boss.combatStrength)", color: .red)
                    if boss.difficulty.maxSpecialAbilityUses > 0 {
                        statPill(
                            icon: "sparkles",
                            label: "Zdolność",
                            value: "1×",
                            color: .blue
                        )
                    }
                }
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

    private func statPill(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(label, systemImage: icon)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.bold())
                .foregroundStyle(color)
        }
    }
}
