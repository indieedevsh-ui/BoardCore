//
//  CreatorPowerViews.swift
//  BoardCore
//

import SwiftUI

struct PowerPathCreatorView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(CreatorStore.self) private var creatorStore
    @Environment(\.dismiss) private var dismiss

    private let theme = Color(red: 0.88, green: 0.42, blue: 0.95)

    @State private var name = ""
    @State private var iconSymbol = "sparkles"
    @State private var glowColor = PlayerGlowColor(red: 0.55, green: 0.35, blue: 0.92, opacity: 1)
    @State private var upgrades: [CreatedPowerUpgrade] = []
    @State private var upgradeEditSession: PowerUpgradeEditSession?
    @State private var showValidationAlert = false
    @State private var savedConfirmation = false

    private let iconChoices = [
        "sparkles", "moon.stars.fill", "sun.max.fill", "flame.fill",
        "bolt.fill", "leaf.fill", "shield.fill", "star.fill",
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                CreatorPillTextField(
                    label: "Nazwa ścieżki mocy",
                    placeholder: "Np. Strażnicy Mgły",
                    text: $name,
                    accentColor: theme
                )

                CreatorPillPickerField(label: "Ikona", accentColor: theme) {
                    Picker("Ikona", selection: $iconSymbol) {
                        ForEach(iconChoices, id: \.self) { symbol in
                            Label(symbol, systemImage: symbol).tag(symbol)
                        }
                    }
                    .pickerStyle(.menu)
                }

                VStack(alignment: .leading, spacing: 12) {
                    ColorPicker(
                        "Kolor mocy",
                        selection: Binding(
                            get: { glowColor.swiftUIColor },
                            set: { glowColor.applySwiftUIColor($0) }
                        ),
                        supportsOpacity: true
                    )
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(glowColor.swiftUIColor)
                        .frame(height: 44)
                }

                PowerUpgradesListSection(
                    upgrades: upgrades,
                    accent: theme,
                    canAdd: true,
                    canEdit: true,
                    onAdd: presentNewUpgradeEditor,
                    onEdit: { upgrade in
                        upgradeEditSession = PowerUpgradeEditSession(draft: upgrade, isNew: false)
                    },
                    onDelete: { id in
                        upgrades.removeAll { $0.id == id }
                    }
                )

                Button("Zapisz ścieżkę mocy") { save() }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .liquidGlassButtonBackground(prominent: true, accent: theme)
                    .buttonStyle(.plain)
            }
            .padding()
        }
        .appScrollSurface()
        .navigationTitle("Moc")
        .navigationBarTitleDisplayMode(.inline)
        .appThemedScreen()
        .navigationDestination(item: $upgradeEditSession) { session in
            PowerUpgradeEditorScreen(
                upgrade: session.draft,
                accent: theme,
                onSave: { saved in
                    if session.isNew {
                        upgrades.append(saved)
                    } else if let index = upgrades.firstIndex(where: { $0.id == saved.id }) {
                        upgrades[index] = saved
                    }
                }
            )
        }
        .alert("Uzupełnij dane", isPresented: $showValidationAlert) {
            Button("OK", role: .cancel) { settings.playTapSound() }
        } message: {
            Text("Podaj nazwę i co najmniej jedno ulepszenie.")
        }
        .alert("Zapisano", isPresented: $savedConfirmation) {
            Button("OK") { settings.playTapSound(); dismiss() }
        } message: {
            Text("Ścieżka „\(name)” została zapisana.")
        }
    }

    private func presentNewUpgradeEditor() {
        upgradeEditSession = PowerUpgradeEditSession(
            draft: CreatedPowerUpgrade(
                name: "Nowe ulepszenie",
                summary: "",
                xpCost: 50,
                tier: upgrades.count + 1,
                influence: .gameplay
            ),
            isNew: true
        )
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !upgrades.isEmpty else {
            showValidationAlert = true
            return
        }
        settings.playTapSound()
        creatorStore.addPowerPath(
            CreatedPowerPath(
                name: trimmedName,
                iconSymbol: iconSymbol,
                glowColor: glowColor,
                isBuiltIn: false,
                upgrades: upgrades,
                buildPrompt: CreatorBuildPrompts.powerPath(name: trimmedName)
            )
        )
        savedConfirmation = true
    }
}

struct PowerPathDetailView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(CreatorStore.self) private var creatorStore

    let pathID: UUID

    @State private var draft: CreatedPowerPath?
    @State private var upgradeEditSession: PowerUpgradeEditSession?
    @State private var savedConfirmation = false

    var body: some View {
        Group {
            if draft != nil {
                PowerPathDetailEditor(
                    path: pathBinding,
                    upgradeEditSession: $upgradeEditSession,
                    onDeleteUpgrade: { upgradeID in
                        guard draft?.isBuiltIn == false else { return }
                        settings.playTapSound()
                        draft?.upgrades.removeAll { $0.id == upgradeID }
                    },
                    onSave: {
                        guard let draft, !draft.isBuiltIn else { return }
                        settings.playTapSound()
                        creatorStore.updatePowerPath(draft)
                        savedConfirmation = true
                    }
                )
            } else {
                ContentUnavailableView("Brak ścieżki", systemImage: "sparkles")
            }
        }
        .navigationTitle("Ścieżka mocy")
        .navigationBarTitleDisplayMode(.inline)
        .appThemedScreen()
        .navigationDestination(item: $upgradeEditSession) { session in
            PowerUpgradeEditorScreen(
                upgrade: session.draft,
                accent: draft?.glowColor.swiftUIColor ?? .purple,
                canEdit: draft?.isBuiltIn == false,
                onSave: { saved in
                    guard draft?.isBuiltIn == false else { return }
                    if session.isNew {
                        draft?.upgrades.append(saved)
                    } else if let index = draft?.upgrades.firstIndex(where: { $0.id == saved.id }) {
                        draft?.upgrades[index] = saved
                    }
                }
            )
        }
        .onAppear {
            draft = creatorStore.powerPath(id: pathID)
        }
        .alert("Zapisano", isPresented: $savedConfirmation) {
            Button("OK", role: .cancel) { settings.playTapSound() }
        }
    }

    private var pathBinding: Binding<CreatedPowerPath> {
        Binding(
            get: { draft! },
            set: { draft = $0 }
        )
    }
}

private struct PowerPathDetailEditor: View {
    @Binding var path: CreatedPowerPath
    @Binding var upgradeEditSession: PowerUpgradeEditSession?
    let onDeleteUpgrade: (UUID) -> Void
    let onSave: () -> Void

    private var theme: Color { path.glowColor.swiftUIColor }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    Image(systemName: path.iconSymbol)
                        .font(.largeTitle)
                        .foregroundStyle(theme)
                    VStack(alignment: .leading) {
                        Text(path.name)
                            .font(.title2.bold())
                        if path.isBuiltIn {
                            Text("Domyślna ścieżka")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                ColorPicker(
                    "Kolor mocy",
                    selection: Binding(
                        get: { path.glowColor.swiftUIColor },
                        set: { path.glowColor.applySwiftUIColor($0) }
                    ),
                    supportsOpacity: true
                )
                .disabled(path.isBuiltIn)

                PowerUpgradesListSection(
                    upgrades: path.upgrades,
                    accent: theme,
                    canAdd: !path.isBuiltIn,
                    canEdit: true,
                    onAdd: {
                        upgradeEditSession = PowerUpgradeEditSession(
                            draft: CreatedPowerUpgrade(
                                name: "Nowe ulepszenie",
                                summary: "",
                                xpCost: 50,
                                tier: path.upgrades.count + 1,
                                influence: .gameplay
                            ),
                            isNew: true
                        )
                    },
                    onEdit: { upgrade in
                        upgradeEditSession = PowerUpgradeEditSession(draft: upgrade, isNew: false)
                    },
                    onDelete: onDeleteUpgrade
                )

                if !path.isBuiltIn {
                    Button("Zapisz zmiany", action: onSave)
                        .buttonStyle(.appProminent)
                }
            }
            .padding()
        }
        .appScrollSurface()
    }
}
