//
//  EquipmentStatBoostOverlay.swift
//  DmdApp
//

import SwiftUI

struct EquipmentStatBoostPresentation: Equatable, Identifiable {
    let id = UUID()
    let itemName: String
    let itemKind: CreatorItemKind
    let health: Int
    let strength: Int
    let armor: Int

    var hasVisibleStats: Bool {
        health > 0 || strength > 0 || armor > 0
    }

    init(item: CreatedItem, delta: EquipmentLoadoutBonus) {
        itemName = item.name
        itemKind = item.resolvedItemKind
        switch item.resolvedItemKind {
        case .weapon:
            health = 0
            strength = max(0, delta.strength)
            armor = 0
        case .armor:
            health = max(0, delta.health)
            strength = 0
            armor = 0
        default:
            health = max(0, delta.health)
            strength = max(0, delta.strength)
            armor = max(0, delta.armor)
        }
    }
}

struct EquipmentStatBoostOverlay: View {
    @Environment(AppSettings.self) private var settings

    let presentation: EquipmentStatBoostPresentation
    let onDismiss: () -> Void

    @State private var backdropOpacity: Double = 0
    @State private var tileScale: CGFloat = 0.55
    @State private var tileOpacity: Double = 0
    @State private var displayedHealth: Int = 0
    @State private var displayedStrength: Int = 0
    @State private var displayedArmor: Int = 0

    var body: some View {
        ZStack {
            Color.black.opacity(backdropOpacity * 0.68)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 20) {
                Image(systemName: presentation.itemKind.icon)
                    .font(.system(size: 52, weight: .bold))
                    .foregroundStyle(accentColor)
                    .shadow(color: accentColor.opacity(0.55), radius: 20)

                Text("Założono")
                    .font(.title3.bold())

                Text(presentation.itemName)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                if presentation.hasVisibleStats {
                    VStack(spacing: 14) {
                        if presentation.health > 0 {
                            statRow(
                                label: "Zdrowie",
                                value: displayedHealth,
                                target: presentation.health,
                                icon: "heart.fill",
                                color: .green
                            )
                        }
                        if presentation.strength > 0 {
                            statRow(
                                label: "Siła",
                                value: displayedStrength,
                                target: presentation.strength,
                                icon: "bolt.fill",
                                color: .red
                            )
                        }
                        if presentation.armor > 0 {
                            statRow(
                                label: "Pancerz",
                                value: displayedArmor,
                                target: presentation.armor,
                                icon: "shield.fill",
                                color: .orange
                            )
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(32)
            .frame(maxWidth: 320)
            .background(
                LiquidGlassBackground(accentStroke: accentColor, cornerRadius: 24)
            )
            .scaleEffect(tileScale)
            .opacity(tileOpacity)
        }
        .onAppear {
            HapticManager.playStatReveal(intensity: settings.hapticIntensity * 0.85)
            settings.playStatsRevealSound()

            withAnimation(.easeOut(duration: 0.35)) {
                backdropOpacity = 1
            }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
                tileScale = 1
                tileOpacity = 1
            }

            animateStatCounters()

            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2.4))
                dismiss()
            }
        }
    }

    private var accentColor: Color {
        switch presentation.itemKind.equipmentSlotKind {
        case .weapon: return .orange
        case .armor: return .gray
        case .brush: return .cyan
        case .helmet, .shield: return .gray
        }
    }

    private func statRow(label: String, value: Int, target: Int, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 28)
            Text(label)
                .font(.headline)
            Spacer()
            Text("+\(value)")
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundStyle(color)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
    }

    private func animateStatCounters() {
        let steps = 18
        let interval: Duration = .milliseconds(45)

        Task { @MainActor in
            for step in 1...steps {
                guard !Task.isCancelled else { return }
                let progress = Double(step) / Double(steps)
                let eased = 1 - pow(1 - progress, 2.2)

                withAnimation(.easeOut(duration: 0.08)) {
                    if presentation.health > 0 {
                        displayedHealth = Int((Double(presentation.health) * eased).rounded())
                    }
                    if presentation.strength > 0 {
                        displayedStrength = Int((Double(presentation.strength) * eased).rounded())
                    }
                    if presentation.armor > 0 {
                        displayedArmor = Int((Double(presentation.armor) * eased).rounded())
                    }
                }
                try? await Task.sleep(for: interval)
            }
            displayedHealth = presentation.health
            displayedStrength = presentation.strength
            displayedArmor = presentation.armor
        }
    }

    private func dismiss() {
        withAnimation(.easeIn(duration: 0.22)) {
            backdropOpacity = 0
            tileOpacity = 0
            tileScale = 0.9
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
            onDismiss()
        }
    }
}
