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

struct SessionAbilityPoolSummaryView: View {
    let pool: GameplaySessionAbilityPoolState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Pula zdolności sesji", systemImage: "sparkles.rectangle.stack")
                .font(.headline)
            Text("Odblokowano \(pool.unlockedCount)/\(GameplaySessionAbilityPoolState.poolSize) · zablokowane: \(pool.lockedCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
