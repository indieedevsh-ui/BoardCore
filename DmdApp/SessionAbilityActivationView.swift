//
//  SessionAbilityActivationView.swift
//  DmdApp
//

import SwiftUI

struct PendingSessionAbilityUse: Identifiable {
    let id = UUID()
    let ability: GameplaySessionAbility
    let casterID: UUID
}

struct SessionAbilityActivationView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(TrikiNavigationCoordinator.self) private var trikiCoordinator

    private let abilityTrikiFocusID = UUID()

    let ability: GameplaySessionAbility
    let caster: PlayerCharacter
    let players: [PlayerCharacter]
    let onConfirm: (UUID, Int) -> Void
    let onCancel: () -> Void

    @State private var selectedTargetID: UUID?
    @State private var boardSpaces = 1

    private var selectableTargets: [PlayerCharacter] {
        players
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(ability.name)
                        .font(.title2.bold())
                    Text(ability.effectDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cel")
                            .font(.headline)
                        Picker("Cel", selection: $selectedTargetID) {
                            Text("Wybierz gracza…").tag(UUID?.none)
                            ForEach(selectableTargets) { player in
                                Text(player.displayTitle).tag(Optional(player.id))
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    if ability.kind == .boardMove {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Przesunięcie na planszy")
                                .font(.headline)
                            Stepper(
                                value: $boardSpaces,
                                in: -ability.boardMaxSpaces...ability.boardMaxSpaces
                            ) {
                                Text("\(boardSpaces >= 0 ? "+" : "")\(boardSpaces) pól")
                            }
                            Text("Ujemne cofa, dodatnie przesuwa do przodu.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        settings.playTapSound()
                        guard let targetID = selectedTargetID else { return }
                        let spaces = ability.kind == .boardMove ? boardSpaces : 0
                        onConfirm(targetID, spaces)
                    } label: {
                        Text("Użyj zdolności")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.appProminent)
                    .disabled(selectedTargetID == nil || (ability.kind == .boardMove && boardSpaces == 0))
                }
                .padding()
            }
            .appScrollSurface()
            .navigationTitle("Aktywacja")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") {
                        settings.playTapSound()
                        onCancel()
                    }
                }
            }
        }
        .onAppear {
            selectedTargetID = caster.id
            boardSpaces = max(1, ability.boardMaxSpaces / 2)
        }
        .trikiFocusContext(
            id: abilityTrikiFocusID,
            buttons: abilityTrikiButtons,
            onActivate: { activateAbilityTriki(at: $0) }
        )
    }

    private var abilityTrikiButtons: [TrikiFocusButton] {
        var buttons = selectableTargets.map { player in
            TrikiFocusButton(id: "target-\(player.id.uuidString)", title: player.displayTitle)
        }
        buttons.append(TrikiFocusButton(id: "confirm", title: "Użyj zdolności"))
        buttons.append(TrikiFocusButton(id: "cancel", title: "Anuluj"))
        return buttons
    }

    private func activateAbilityTriki(at index: Int) {
        let buttons = abilityTrikiButtons
        guard buttons.indices.contains(index) else { return }
        settings.playTapSound()
        let row = buttons[index]
        switch row.id {
        case "confirm":
            guard let targetID = selectedTargetID else { return }
            let spaces = ability.kind == .boardMove ? boardSpaces : 0
            onConfirm(targetID, spaces)
        case "cancel":
            onCancel()
        case let id where id.hasPrefix("target-"):
            let uuidString = String(id.dropFirst("target-".count))
            if let uuid = UUID(uuidString: uuidString) {
                selectedTargetID = uuid
            }
        default:
            break
        }
        trikiCoordinator.statusMessage = "Wybrano: \(row.title)"
    }
}

struct SessionAbilitiesRevealSection: View {
    @Environment(AppSettings.self) private var settings

    var isTrikiSelected: Bool = false
    var trikiHoldChargeProgress: Double = 0
    @Binding var isScreenPresented: Bool

    var body: some View {
        Button {
            settings.playTapSound()
            isScreenPresented = true
        } label: {
            Label("Zdolności", systemImage: "sparkles")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.appProminent)
        .trikiSelectableHighlight(
            isSelected: isTrikiSelected,
            chargeProgress: isTrikiSelected ? trikiHoldChargeProgress : 0
        )
    }
}

struct SessionAbilitiesHubView: View {
    @Environment(AppSettings.self) private var settings

    let pool: GameplaySessionAbilityPoolState
    let activePlayer: PlayerCharacter?
    let playerGlow: PlayerGlowColor
    let playerName: String?
    let canUseAbility: (GameplaySessionAbility) -> Bool
    let onUseAbility: (GameplaySessionAbility) -> Void
    let onExit: () -> Void
    var trikiExitHighlighted: Bool = false
    var trikiHoldChargeProgress: Double = 0

    @State private var selectedAbility: GameplaySessionAbility?

    private var playerID: UUID? {
        activePlayer?.id
    }

    private var collectedCount: Int {
        guard let playerID else { return 0 }
        return pool.collectedCount(for: playerID)
    }

    private var orderedAbilities: [GameplaySessionAbility] {
        Array(pool.abilities.prefix(GameplaySessionAbilityPoolState.poolSize))
    }

    var body: some View {
        ZStack {
            AppGradientBackground(glow: playerGlow)

            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    Text("Zdolności")
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
                .padding(.bottom, 12)

                Text("Zebrano \(collectedCount)/\(GameplaySessionAbilityPoolState.poolSize)")
                    .font(.headline.bold())
                    .foregroundStyle(settings.accentColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5),
                    spacing: 14
                ) {
                    ForEach(orderedAbilities) { ability in
                        abilityCircle(ability)
                    }
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 0)

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
                .padding(.bottom, 24)
                .trikiSelectableHighlight(
                    isSelected: trikiExitHighlighted,
                    chargeProgress: trikiExitHighlighted ? trikiHoldChargeProgress : 0
                )
            }

            if let selectedAbility {
                abilityDetailOverlay(selectedAbility)
            }
        }
    }

    @ViewBuilder
    private func abilityCircle(_ ability: GameplaySessionAbility) -> some View {
        let isCollected = playerID.map { pool.hasCollected(ability.id, for: $0) } ?? false

        Button {
            settings.playTapSound()
            if isCollected {
                selectedAbility = ability
            } else {
                HapticManager.playStatReveal(intensity: settings.hapticIntensity * 0.35)
            }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(circleFill(collected: isCollected))
                        .frame(width: 56, height: 56)
                        .overlay {
                            Circle()
                                .strokeBorder(
                                    isCollected ? settings.accentColor.opacity(0.9) : .white.opacity(0.12),
                                    lineWidth: isCollected ? 2.5 : 1.5
                                )
                        }

                    if isCollected {
                        Image(systemName: abilityIcon(for: ability))
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                }

                if isCollected {
                    Text(ability.name)
                        .font(.system(size: 9, weight: .semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(height: 24)
                } else {
                    Color.clear
                        .frame(height: 24)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func circleFill(collected: Bool) -> some ShapeStyle {
        if collected {
            return AnyShapeStyle(
                RadialGradient(
                    colors: [settings.accentColor.opacity(0.75), settings.accentColor.opacity(0.35)],
                    center: .center,
                    startRadius: 2,
                    endRadius: 30
                )
            )
        }
        return AnyShapeStyle(Color.gray.opacity(0.28))
    }

    private func abilityIcon(for ability: GameplaySessionAbility) -> String {
        switch ability.kind {
        case .turnDamage: "bolt.fill"
        case .temporaryStatBoost: "heart.fill"
        case .boardMove: "sparkles"
        }
    }

    private func abilityDetailOverlay(_ ability: GameplaySessionAbility) -> some View {
        let isCollected = playerID.map { pool.hasCollected(ability.id, for: $0) } ?? false
        let canUse = isCollected && canUseAbility(ability)

        return ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture {
                    settings.playTapSound()
                    selectedAbility = nil
                }

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [settings.accentColor.opacity(0.65), settings.accentColor.opacity(0.25)],
                                center: .center,
                                startRadius: 4,
                                endRadius: 44
                            )
                        )
                        .frame(width: 88, height: 88)
                    Image(systemName: abilityIcon(for: ability))
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)
                }

                Text(ability.name)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                Text(ability.scopeLabel)
                    .font(.caption.bold())
                    .foregroundStyle(settings.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(settings.accentColor.opacity(0.16), in: Capsule())

                Text("Super umiejętność")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                Text(ability.effectDescription)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                if canUse {
                    Button {
                        settings.playTapSound()
                        selectedAbility = nil
                        onUseAbility(ability)
                    } label: {
                        Text("Użyj zdolności")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.appProminent)
                } else if isCollected {
                    Text("Dostępne tylko w: \(ability.scope.label)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button("Zamknij") {
                    settings.playTapSound()
                    selectedAbility = nil
                }
                .buttonStyle(.appSecondary)
            }
            .padding(24)
            .frame(maxWidth: 340)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(.white.opacity(0.14), lineWidth: 1)
            )
            .padding(.horizontal, 24)
        }
    }
}
