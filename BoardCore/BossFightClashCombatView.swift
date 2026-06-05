//
//  BossFightClashCombatView.swift
//  BoardCore
//

import Combine
import SwiftUI

extension BossClashMove {
    var tintColor: Color {
        switch self {
        case .attack: Color(red: 1.0, green: 0.32, blue: 0.28)
        case .defense: Color(red: 0.35, green: 0.62, blue: 1.0)
        case .strongAttack: Color(red: 1.0, green: 0.58, blue: 0.12)
        case .specialAbility: Color(red: 0.78, green: 0.42, blue: 1.0)
        }
    }
}

struct BossFightClashCombatView: View {
    @Environment(AppSettings.self) private var settings

    let session: BossCombatSession
    var trikiHighlightedMove: BossClashMove? = nil
    var trikiHoldChargeProgress: Double = 0
    let onSelectMove: (BossClashMove) -> Void

    @State private var now = Date()
    @State private var revealHeadlineVisible = false
    @State private var revealMovesVisible = false

    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 14) {
            countdownHeader

            if case .revealing = session.phase, let clash = session.lastClash {
                clashReveal(clash)
            } else {
                moveButtons
                rulesHint
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .onReceive(timer) { date in
            now = date
        }
    }

    private var countdownHeader: some View {
        VStack(spacing: 6) {
            Text("Runda \(session.roundNumber)")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            if let remaining = remainingSeconds {
                Text("\(remaining)")
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(remaining <= 3 ? .red : settings.accentColor)
                    .contentTransition(.numericText())

                if let playerMove = session.playerMove {
                    Label {
                        Text(playerMove.title)
                    } icon: {
                        Image(systemName: playerMove.icon)
                            .foregroundStyle(playerMove.tintColor)
                    }
                    .font(.subheadline.bold())
                    Text("Czekaj na koniec odliczania…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Wybierz ruch!")
                        .font(.headline)
                }
            } else if case .revealing = session.phase {
                Text("Wynik starcia")
                    .font(.headline)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var remainingSeconds: Int? {
        guard let endsAt = session.reactionEndsAt else { return nil }
        return max(0, Int(ceil(endsAt.timeIntervalSince(now))))
    }

    private var moveButtons: some View {
        HStack(spacing: 10) {
            ForEach(BossClashMove.playerSelectable) { move in
                moveButton(move)
            }
        }
    }

    private func moveButton(_ move: BossClashMove) -> some View {
        let locked = session.playerMove
        let isSelected = locked == move
        let disabled = locked != nil
        let tint = move.tintColor

        return Button {
            guard locked == nil else { return }
            settings.playTapSound()
            onSelectMove(move)
        } label: {
            VStack(spacing: 8) {
                Image(systemName: move.icon)
                    .font(.title2.bold())
                    .foregroundStyle(tint)
                Text(move.title)
                    .font(.caption.bold())
                    .multilineTextAlignment(.center)
                Text(move.beatsHint)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 6)
            .background(
                isSelected ? tint.opacity(0.28) : Color.white.opacity(0.08),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isSelected ? tint : Color.white.opacity(0.15),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled && !isSelected ? 0.45 : 1)
        .trikiSelectableHighlight(
            isSelected: trikiHighlightedMove == move && locked == nil,
            chargeProgress: trikiHighlightedMove == move && locked == nil ? trikiHoldChargeProgress : 0
        )
    }

    private var rulesHint: some View {
        VStack(spacing: 4) {
            Text("Obrona > Atak · Mocny atak > Obrona · Atak > Mocny atak")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if session.bossSpecialAbility != nil, !session.bossSpecialUsed {
                Text("Boss może raz użyć zdolności przebijającej każdy ruch.")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func clashReveal(_ clash: BossClashResult) -> some View {
        VStack(spacing: 18) {
            VStack(spacing: 8) {
                Text(clashHeadline(clash))
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(clashHeadlineColor(clash))

                Text(clashDamageLine(clash))
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
            }
            .scaleEffect(revealHeadlineVisible ? 1 : 0.85)
            .opacity(revealHeadlineVisible ? 1 : 0)

            VStack(spacing: 10) {
                Text(clashBeatLine(clash))
                    .font(.headline)
                    .multilineTextAlignment(.center)

                HStack(spacing: 12) {
                    clashMoveCard(
                        label: "Ty",
                        move: clash.playerMove,
                        highlight: clash.winner == .player
                    )

                    Image(systemName: clash.winner == .draw ? "equal.circle.fill" : "arrow.left.arrow.right")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    clashMoveCard(
                        label: "Boss",
                        move: clash.bossMove,
                        displayName: clash.bossMove == .specialAbility ? session.bossSpecialDisplayName : nil,
                        highlight: clash.winner == .boss
                    )
                }
            }
            .scaleEffect(revealMovesVisible ? 1 : 0.9)
            .opacity(revealMovesVisible ? 1 : 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .onAppear {
            revealHeadlineVisible = false
            revealMovesVisible = false
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                revealHeadlineVisible = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.35)) {
                revealMovesVisible = true
            }
        }
        .onChange(of: clash.summary) { _, _ in
            revealHeadlineVisible = false
            revealMovesVisible = false
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                revealHeadlineVisible = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.35)) {
                revealMovesVisible = true
            }
        }
    }

    private func clashHeadline(_ clash: BossClashResult) -> String {
        let bossLabel = clash.bossMove == .specialAbility ? session.bossSpecialDisplayName : "Boss"
        switch clash.winner {
        case .player:
            return "Ty przebijasz \(bossLabel)!"
        case .boss:
            return "\(bossLabel) przebija Cię!"
        case .draw:
            return "Remis — nikt nie przebija!"
        }
    }

    private func clashHeadlineColor(_ clash: BossClashResult) -> Color {
        switch clash.winner {
        case .player: .green
        case .boss: .red
        case .draw: .secondary
        }
    }

    private func clashDamageLine(_ clash: BossClashResult) -> String {
        switch clash.winner {
        case .player:
            return "Boss −\(clash.damageToBoss) HP"
        case .boss:
            return "Drużyna −\(clash.damageToPlayer) HP"
        case .draw:
            return "Bez obrażeń"
        }
    }

    private func clashBeatLine(_ clash: BossClashResult) -> String {
        let bossName = clash.bossMove == .specialAbility
            ? session.bossSpecialDisplayName
            : clash.bossMove.title
        switch clash.winner {
        case .player:
            return "\(clash.playerMove.title) przebija \(bossName)"
        case .boss:
            return "\(bossName) przebija \(clash.playerMove.title)"
        case .draw:
            return "\(clash.playerMove.title) vs \(bossName)"
        }
    }

    private func clashMoveCard(
        label: String,
        move: BossClashMove,
        displayName: String? = nil,
        highlight: Bool
    ) -> some View {
        let tint = move.tintColor

        return VStack(spacing: 8) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Image(systemName: move.icon)
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(tint)
                .shadow(color: tint.opacity(highlight ? 0.55 : 0.2), radius: highlight ? 10 : 4)
            Text(displayName ?? move.title)
                .font(.caption.bold())
                .foregroundStyle(highlight ? tint : .primary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(
            highlight ? tint.opacity(0.22) : Color.white.opacity(0.06),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(highlight ? tint.opacity(0.65) : Color.white.opacity(0.1), lineWidth: highlight ? 2 : 1)
        )
    }
}
