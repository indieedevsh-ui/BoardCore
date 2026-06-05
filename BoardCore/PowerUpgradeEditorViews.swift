//
//  PowerUpgradeEditorViews.swift
//  BoardCore
//

import SwiftUI

struct PowerUpgradeEditSession: Identifiable, Hashable {
    let id: UUID
    var draft: CreatedPowerUpgrade
    let isNew: Bool

    init(draft: CreatedPowerUpgrade, isNew: Bool) {
        id = draft.id
        self.draft = draft
        self.isNew = isNew
    }
}

struct PowerUpgradesListSection: View {
    @Environment(AppSettings.self) private var settings

    let upgrades: [CreatedPowerUpgrade]
    let accent: Color
    let canAdd: Bool
    let canEdit: Bool
    let onAdd: () -> Void
    let onEdit: (CreatedPowerUpgrade) -> Void
    let onDelete: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Ulepszenia")
                    .font(.headline)
                Spacer()
                if canAdd {
                    Button {
                        settings.playTapSound()
                        onAdd()
                    } label: {
                        Label("Dodaj", systemImage: "plus.circle.fill")
                    }
                }
            }

            if upgrades.isEmpty {
                Text("Dodaj ulepszenia z kosztem XP i efektem dla gracza.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(upgrades) { upgrade in
                Button {
                    guard canEdit else { return }
                    settings.playTapSound()
                    onEdit(upgrade)
                } label: {
                    PowerUpgradeListRow(upgrade: upgrade, accent: accent)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    if canAdd {
                        Button("Usuń", role: .destructive) {
                            settings.playTapSound()
                            onDelete(upgrade.id)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(LiquidGlassBackground(accentStroke: accent, cornerRadius: 16, fillOpacity: 0.1))
    }
}

struct PowerUpgradeListRow: View {
    let upgrade: CreatedPowerUpgrade
    let accent: Color

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(upgrade.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(upgrade.effectSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text("Koszt XP: \(upgrade.xpCost) · Poziom \(upgrade.tier)")
                    .font(.caption2)
                    .foregroundStyle(accent)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(accent.opacity(0.18), lineWidth: 1)
        }
    }
}

struct PowerUpgradeEditorScreen: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var draft: CreatedPowerUpgrade
    let accent: Color
    let canEdit: Bool
    let onSave: (CreatedPowerUpgrade) -> Void

    init(
        upgrade: CreatedPowerUpgrade,
        accent: Color,
        canEdit: Bool = true,
        onSave: @escaping (CreatedPowerUpgrade) -> Void
    ) {
        _draft = State(initialValue: upgrade)
        self.accent = accent
        self.canEdit = canEdit
        self.onSave = onSave
    }

    var body: some View {
        ScrollView {
            PowerUpgradeEditorForm(upgrade: $draft, accent: accent)
                .disabled(!canEdit)
                .padding()
                .padding(.bottom, 8)
        }
        .appScrollSurface()
        .navigationTitle("Nowe ulepszenie")
        .navigationBarTitleDisplayMode(.inline)
        .appThemedScreen()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if canEdit {
                editorFooter
            } else {
                readOnlyFooter
            }
        }
    }

    private var editorFooter: some View {
        HStack(spacing: 12) {
            Button("Anuluj") {
                settings.playTapSound()
                dismiss()
            }
            .buttonStyle(.appSecondary)

            Button("Zapisz") {
                settings.playTapSound()
                onSave(draft)
                dismiss()
            }
            .buttonStyle(.appProminent)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(alignment: .top) {
                    Divider().opacity(0.35)
                }
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private var readOnlyFooter: some View {
        Button("Wróć") {
            settings.playTapSound()
            dismiss()
        }
        .buttonStyle(.appSecondary)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(alignment: .top) {
                    Divider().opacity(0.35)
                }
                .ignoresSafeArea(edges: .bottom)
        }
    }
}

struct PowerUpgradeEditorForm: View {
    @Binding var upgrade: CreatedPowerUpgrade
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            CreatorPillTextField(
                label: "Nazwa ulepszenia",
                placeholder: "Np. Cień kradzieży",
                text: $upgrade.name,
                accentColor: accent
            )

            influenceGrid
            influenceEditor
            costSection
        }
    }

    private var influenceGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Wpływ ulepszenia")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(PowerUpgradeInfluence.allCases) { influence in
                    influenceChip(influence)
                }
            }
        }
    }

    private func influenceChip(_ influence: PowerUpgradeInfluence) -> some View {
        let isSelected = upgrade.influence == influence
        return Button {
            upgrade.influence = influence
        } label: {
            HStack(spacing: 8) {
                Image(systemName: influence.icon)
                    .font(.subheadline.weight(.semibold))
                Text(influence.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? accent.opacity(0.22) : Color.primary.opacity(0.06))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? accent : Color.clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var influenceEditor: some View {
        switch upgrade.influence {
        case .board:
            PowerUpgradeBoardEditor(board: $upgrade.boardEffect, accent: accent)
        case .bossFight:
            PowerUpgradeBossFightEditor(effect: $upgrade.bossFightEffect, accent: accent)
        case .players:
            PowerUpgradePlayersEditor(effect: $upgrade.playersEffect, accent: accent)
        case .gameplay:
            PowerUpgradeGameplayEditor(effect: $upgrade.gameplayEffect, accent: accent)
        }
    }

    private var costSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Divider().opacity(0.35)

            TextField("Opis (opcjonalnie)", text: $upgrade.summary, axis: .vertical)
                .lineLimit(2...4)
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(accent.opacity(0.32), lineWidth: 1)
                }

            CreatorPillStepperField(
                label: "Koszt XP",
                value: $upgrade.xpCost,
                range: 0...999,
                accentColor: accent
            )
            CreatorPillStepperField(
                label: "Poziom",
                value: $upgrade.tier,
                range: 1...10,
                accentColor: accent
            )
        }
    }
}

// MARK: - Plansza

private struct PowerUpgradeBoardEditor: View {
    @Environment(AppSettings.self) private var settings
    @Binding var board: PowerUpgradeBoardEffect
    let accent: Color

    var body: some View {
        PowerUpgradeSectionCard(title: "Plansza", icon: "map.fill", accent: accent) {
            Picker("Ruch", selection: $board.mode) {
                ForEach(PowerUpgradeBoardMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: board.mode) { _, _ in settings.playTapSound() }

            if board.mode != .anyField {
                CreatorPillStepperField(
                    label: board.mode == .moveForward ? "Pola do przodu" : "Pola do tyłu",
                    value: $board.spaces,
                    range: 1...30,
                    accentColor: accent
                )
            } else {
                Label("Gracz może wybrać dowolne pole na planszy.", systemImage: "hand.tap.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Walka z bossem

private struct PowerUpgradeBossFightEditor: View {
    @Binding var effect: PowerUpgradeBossFightEffect
    let accent: Color

    var body: some View {
        PowerUpgradeSectionCard(title: "Walka z bossem", icon: "figure.stand.line.dotted.figure.stand", accent: accent) {
            PowerUpgradeToggleBlock(
                title: "Podgląd ruchu bossa",
                subtitle: "Gracz z tą mocą zobaczy ruch bossa przed jego wykonaniem.",
                isOn: $effect.previewBossMoveEnabled,
                accent: accent
            ) {
                CreatorPillStepperField(
                    label: "Co ile tur można użyć",
                    value: $effect.previewEveryTurns,
                    range: 1...20,
                    accentColor: accent
                )
                CreatorPillStepperField(
                    label: "Ile razy na jedno starcie",
                    value: $effect.previewUsesPerEncounter,
                    range: 1...10,
                    accentColor: accent
                )
            }

            PowerUpgradeToggleBlock(
                title: "Nieśmiertelny",
                subtitle: "Po spadku zdrowia do zera gracz zostaje na planszy.",
                isOn: $effect.immortalEnabled,
                accent: accent
            ) {
                CreatorPillStepperField(
                    label: "Przywrócone zdrowie",
                    value: $effect.immortalHealthRestore,
                    range: 1...100,
                    accentColor: accent
                )
                CreatorPillStepperField(
                    label: "Co ile bitew można użyć",
                    value: $effect.immortalEveryBattles,
                    range: 1...20,
                    accentColor: accent
                )
            }
        }
    }
}

// MARK: - Gracze

private struct PowerUpgradePlayersEditor: View {
    @Binding var effect: PowerUpgradePlayersEffect
    let accent: Color

    var body: some View {
        PowerUpgradeSectionCard(title: "Gracze", icon: "person.3.fill", accent: accent) {
            PowerUpgradeToggleBlock(
                title: "Okradnij gracza",
                subtitle: "Posiadacz umiejętności zabiera część statystyk innym.",
                isOn: $effect.robPlayerEnabled,
                accent: accent
            ) {
                CreatorPillStepperField(
                    label: "Procent kradzieży",
                    value: $effect.robPercent,
                    range: 1...100,
                    accentColor: accent
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("Dotyczy statystyk")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Toggle("Fundusze", isOn: $effect.robTargetsFinances)
                    Toggle("Siła", isOn: $effect.robTargetsStrength)
                    Toggle("Zdrowie", isOn: $effect.robTargetsHealth)
                }
                .font(.subheadline)
            }

            PowerUpgradeToggleBlock(
                title: "Zablokuj ruch",
                subtitle: "Blokuje ruch wybranych graczy na kilka tur.",
                isOn: $effect.blockMoveEnabled,
                accent: accent
            ) {
                CreatorPillStepperField(
                    label: "Na ile tur",
                    value: $effect.blockMoveTurns,
                    range: 1...10,
                    accentColor: accent
                )
                Picker("Zakres", selection: $effect.blockMoveScope) {
                    ForEach(PowerUpgradeBlockMoveScope.allCases) { scope in
                        Text(scope.title).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
            }

            PowerUpgradeToggleBlock(
                title: "Usuń gracza",
                subtitle: "Usuwa wskazaną liczbę graczy z rozgrywki.",
                isOn: $effect.removePlayerEnabled,
                accent: accent
            ) {
                CreatorPillStepperField(
                    label: "Liczba usuwanych graczy",
                    value: $effect.removePlayerCount,
                    range: 1...4,
                    accentColor: accent
                )
            }
        }
    }
}

// MARK: - Rozgrywka

private struct PowerUpgradeGameplayEditor: View {
    @Binding var effect: PowerUpgradeGameplayEffect
    let accent: Color

    var body: some View {
        PowerUpgradeSectionCard(title: "Rozgrywka", icon: "chart.bar.fill", accent: accent) {
            Text("Bonusy do statystyk gracza po odblokowaniu ulepszenia.")
                .font(.caption)
                .foregroundStyle(.secondary)

            CreatorPillStepperField(
                label: "Zdrowie",
                value: $effect.healthBonus,
                range: -50...50,
                accentColor: accent
            )
            CreatorPillStepperField(
                label: "Siła",
                value: $effect.strengthBonus,
                range: -50...50,
                accentColor: accent
            )
            CreatorPillStepperField(
                label: "Fundusze",
                value: $effect.coinsBonus,
                range: -200...200,
                accentColor: accent
            )
            CreatorPillStepperField(
                label: "Doświadczenie (XP)",
                value: $effect.xpBonus,
                range: -200...200,
                accentColor: accent
            )
        }
    }
}

// MARK: - Shared UI

private struct PowerUpgradeSectionCard<Content: View>: View {
    let title: String
    let icon: String
    let accent: Color
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(accent)

            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(accent.opacity(0.2), lineWidth: 1)
        }
    }
}

private struct PowerUpgradeToggleBlock<Content: View>: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    let accent: Color
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $isOn) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(accent)

            if isOn {
                VStack(alignment: .leading, spacing: 10) {
                    content()
                }
                .padding(.leading, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 4)
        .animation(.easeInOut(duration: 0.2), value: isOn)
    }
}
