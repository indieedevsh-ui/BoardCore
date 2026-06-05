//
//  PlayerRuntimeStats.swift
//  DmdApp
//

import Foundation
import SwiftUI

struct PlayerRuntimeStats: Codable, Hashable {
    var finances: Int
    var health: Int
    var strength: Int
    var abilities: Int

    static let startingStrength = 20

    static let defaultStarting = PlayerRuntimeStats(
        finances: 100,
        health: 100,
        strength: startingStrength,
        abilities: 0
    )

    static func initial(for player: PlayerCharacter) -> PlayerRuntimeStats {
        _ = player
        return PlayerRuntimeStats(
            finances: CharacterTraitStats.fixedFinances,
            health: CharacterTraitStats.fixedHealth,
            strength: startingStrength,
            abilities: 0
        )
    }

    /// Liczba posiadanych zdolności sesji (0 na start, +1 / −1 przy zdobyciu / utracie).
    static func abilityCountStat(_ count: Int) -> Int {
        max(0, count)
    }

    static func defaultStarting(for player: PlayerCharacter) -> PlayerRuntimeStats {
        initial(for: player)
    }

    static var startingHealth: Int { PlayerElimination.startingHealth }

    mutating func applyStartFieldStaying() {
        let bonus = Int(Double(health) * 0.2)
        health = min(100, health + max(bonus, 1))
    }

    mutating func applyStartFieldPassReward() {
        finances += StartFieldRewards.passCoins
    }

    mutating func applyStartFieldStayFullHealthBonus() {
        finances += StartFieldRewards.stayAtFullHealthCoins
    }

    mutating func apply(effects: CampaignChoiceEffects) {
        strength = clamp(strength + effects.strength)
        finances = max(0, finances + effects.coins)
        health = clamp(health + effects.health)
        _ = effects.abilities
        _ = effects.boardMove
        _ = effects.blockRounds
        _ = effects.mana
    }

    private func clamp(_ value: Int) -> Int {
        min(100, max(0, value))
    }

    mutating func apply(event: QRGameEventCode) {
        switch event {
        case .startField:
            break
        case .artifact:
            break
        case .bossFight:
            health = max(0, health - 12)
            strength = min(100, strength + 5)
        case .shop:
            break
        case .specialCard:
            break
        case .arenaPvP:
            break
        }
    }
}

struct PlayerStatCircle: View {
    let label: String
    let value: Int
    let color: Color
    var ringMax: Int = 100

    private var ringProgress: CGFloat {
        guard ringMax > 0 else { return 0 }
        return CGFloat(min(max(value, 0), ringMax)) / CGFloat(ringMax)
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.25), lineWidth: 4)
                    .frame(width: 56, height: 56)
                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 56, height: 56)
                Text("\(value)")
                    .font(.caption.bold())
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(width: 64)
        }
    }
}

struct PlayerStatsRow: View {
    let stats: PlayerRuntimeStats

    var body: some View {
        HStack(spacing: 8) {
            PlayerStatCircle(label: "Finanse", value: stats.finances, color: .yellow, ringMax: max(100, stats.finances))
            PlayerStatCircle(label: "Zdrowie", value: stats.health, color: .green)
            PlayerStatCircle(label: "Siła", value: stats.strength, color: .red)
            PlayerStatCircle(label: "Zdolności", value: stats.abilities, color: .blue, ringMax: max(10, stats.abilities))
        }
        .frame(maxWidth: .infinity)
    }
}

private struct PlayerStatDefinition: Identifiable {
    let id: String
    let label: String
    let icon: String
    let value: Int
    let color: Color
}

struct PlayerStatsRevealSection: View {
    @Environment(AppSettings.self) private var settings

    let stats: PlayerRuntimeStats
    let playerID: UUID
    let playerGlow: PlayerGlowColor
    var playerName: String?
    var isTrikiSelected: Bool = false
    var trikiHoldChargeProgress: Double = 0
    @Binding var isScreenPresented: Bool

    var body: some View {
        Button {
            settings.playStatsRevealSound()
            isScreenPresented = true
        } label: {
            Label("Pokaż Statystyki", systemImage: "chart.bar.doc.horizontal.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.appProminent)
        .trikiSelectableHighlight(
            isSelected: isTrikiSelected,
            chargeProgress: isTrikiSelected ? trikiHoldChargeProgress : 0
        )
        .onChange(of: playerID) { _, _ in
            isScreenPresented = false
        }
    }
}

struct PlayerStatsFullScreenView: View {
    @Environment(AppSettings.self) private var settings

    let stats: PlayerRuntimeStats
    let experiencePoints: Int
    let playerGlow: PlayerGlowColor
    let playerName: String?
    let onExit: () -> Void
    var trikiExitHighlighted: Bool = false
    var trikiHoldChargeProgress: Double = 0

    @State private var revealedCount = 0
    @State private var revealTask: Task<Void, Never>?

    private var statDefinitions: [PlayerStatDefinition] {
        [
            PlayerStatDefinition(id: "finances", label: "Finanse", icon: "dollarsign.circle.fill", value: stats.finances, color: .yellow),
            PlayerStatDefinition(id: "health", label: "Zdrowie", icon: "heart.fill", value: stats.health, color: .green),
            PlayerStatDefinition(id: "strength", label: "Siła", icon: "bolt.fill", value: stats.strength, color: .red),
            PlayerStatDefinition(id: "xp", label: "Doświadczenie (XP)", icon: "star.circle.fill", value: experiencePoints, color: .purple),
        ]
    }

    var body: some View {
        ZStack {
            AppGradientBackground(glow: playerGlow)

            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    Text("Statystyki")
                        .font(.largeTitle.bold())

                    if let playerName, !playerName.isEmpty {
                        Text(playerName)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 28)

                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(Array(statDefinitions.enumerated()), id: \.element.id) { index, definition in
                            if index < revealedCount {
                                PlayerStatRevealRow(definition: definition)
                                    .transition(
                                        .asymmetric(
                                            insertion: .move(edge: .top).combined(with: .opacity),
                                            removal: .opacity
                                        )
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .animation(.spring(response: 0.52, dampingFraction: 0.82), value: revealedCount)
                }

                Button {
                    onExit()
                } label: {
                    Text("Wyjdź")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.appProminent)
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 24)
                .trikiSelectableHighlight(
                    isSelected: trikiExitHighlighted,
                    chargeProgress: trikiExitHighlighted ? trikiHoldChargeProgress : 0
                )
            }
        }
        .onAppear {
            beginReveal()
        }
        .onDisappear {
            revealTask?.cancel()
            revealedCount = 0
        }
    }

    private func beginReveal() {
        revealTask?.cancel()
        revealedCount = 0

        revealTask = Task { @MainActor in
            for index in statDefinitions.indices {
                guard !Task.isCancelled else { return }
                if index > 0 {
                    try? await Task.sleep(for: .milliseconds(320))
                }
                guard !Task.isCancelled else { return }

                HapticManager.playStatReveal(intensity: settings.hapticIntensity * 0.55)
                SoundManager.playStatsRevealStep(volume: settings.volume)
                withAnimation(.spring(response: 0.52, dampingFraction: 0.82)) {
                    revealedCount = index + 1
                }
            }
        }
    }
}

private struct PlayerStatRevealRow: View {
    let definition: PlayerStatDefinition

    @State private var displayedValue = 0
    @State private var rowScale: CGFloat = 0.92
    @State private var rowOpacity: Double = 0

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: definition.icon)
                .font(.title2)
                .foregroundStyle(definition.color)
                .frame(width: 32)

            Text(definition.label)
                .font(.title3.bold())

            Spacer()

            Text("\(displayedValue)")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(definition.color)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 22)
        .background(
            LiquidGlassBackground(accentStroke: definition.color, cornerRadius: 18)
        )
        .scaleEffect(rowScale)
        .opacity(rowOpacity)
        .onAppear {
            displayedValue = 0
            rowScale = 0.92
            rowOpacity = 0
            withAnimation(.spring(response: 0.62, dampingFraction: 0.82)) {
                rowScale = 1
                rowOpacity = 1
                displayedValue = definition.value
            }
        }
        .onChange(of: definition.value) { _, newValue in
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                displayedValue = newValue
            }
        }
    }
}
