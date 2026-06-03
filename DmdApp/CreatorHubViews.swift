//
//  CreatorHubViews.swift
//  DmdApp
//

import SwiftUI

enum CreatorEntryKind: String, CaseIterable, Identifiable {
    case item
    case ability
    case power

    var id: String { rawValue }

    var title: String {
        switch self {
        case .item: "Przedmiot"
        case .ability: "Zdolność"
        case .power: "Moc"
        }
    }

    var icon: String {
        switch self {
        case .item: "bag.fill"
        case .ability: "sparkles"
        case .power: "bolt.circle.fill"
        }
    }

    var themeColor: Color {
        switch self {
        case .item: Color(red: 1.0, green: 0.72, blue: 0.28)
        case .ability: Color(red: 0.62, green: 0.38, blue: 0.98)
        case .power: Color(red: 0.88, green: 0.42, blue: 0.95)
        }
    }
}

struct CreatorTypeHubView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(CreatorStore.self) private var creatorStore
    @Environment(TrikiNavigationCoordinator.self) private var trikiCoordinator
    let kind: CreatorEntryKind

    @State private var showBatchConfirmation = false
    @State private var lastBatchCount = 0
    @State private var showAddedList = false
    @State private var showCreateForm = false
    private let hubTrikiFocusID = UUID()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                hubButton(
                    title: "Zobacz dodane",
                    icon: "list.bullet.rectangle"
                ) {
                    showAddedList = true
                }

                hubButton(
                    title: "Stwórz",
                    icon: "plus.circle.fill"
                ) {
                    showCreateForm = true
                }

                Button {
                    settings.playTapSound()
                    lastBatchCount = CreatorRandomBatchGenerator.generate(kind: kind, into: creatorStore).addedCount
                    showBatchConfirmation = true
                } label: {
                    Label("Stwórz 10 losowych", systemImage: "dice.fill")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .liquidGlassButtonBackground(prominent: false, cornerRadius: 14, accent: kind.themeColor)
                }
                .buttonStyle(.plain)

                Text("Dotknij wpisu na liście „Zobacz dodane”, aby zobaczyć inspirację do własnej wersji.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)
            }
            .padding()
        }
        .appScrollSurface()
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .appThemedScreen()
        .alert("Wygenerowano", isPresented: $showBatchConfirmation) {
            Button("OK", role: .cancel) {
                settings.playTapSound()
            }
        } message: {
            Text("Dodano \(lastBatchCount) szablonów. Otwórz „Zobacz dodane” i dotknij wpis, aby zobaczyć podpowiedź (np. „Zbuduj orka”).")
        }
        .navigationDestination(isPresented: $showAddedList) {
            CreatorAddedListView(kind: kind)
        }
        .navigationDestination(isPresented: $showCreateForm) {
            creatorForm
        }
        .trikiFocusContext(
            id: hubTrikiFocusID,
            buttons: hubTrikiButtons,
            onActivate: { activateHubTriki(at: $0) }
        )
    }

    private var hubTrikiButtons: [TrikiFocusButton] {
        [
            TrikiFocusButton(id: "added", title: "Zobacz dodane"),
            TrikiFocusButton(id: "create", title: "Stwórz"),
            TrikiFocusButton(id: "batch", title: "Stwórz 10 losowych")
        ]
    }

    private func activateHubTriki(at index: Int) {
        let buttons = hubTrikiButtons
        guard buttons.indices.contains(index) else { return }
        settings.playTapSound()
        switch buttons[index].id {
        case "added":
            showAddedList = true
        case "create":
            showCreateForm = true
        case "batch":
            lastBatchCount = CreatorRandomBatchGenerator.generate(kind: kind, into: creatorStore).addedCount
            showBatchConfirmation = true
        default:
            break
        }
        trikiCoordinator.statusMessage = "Wciśnięto: \(buttons[index].title)"
    }

    @ViewBuilder
    private var creatorForm: some View {
        switch kind {
        case .item:
            ItemCreatorView()
        case .ability:
            AbilityCreatorView()
        case .power:
            PowerPathCreatorView()
        }
    }

    private func hubButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button {
            settings.playTapSound()
            action()
        } label: {
            Label(title, systemImage: icon)
                .font(.title3.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .liquidGlassButtonBackground(prominent: true, cornerRadius: 14, accent: kind.themeColor)
        }
        .buttonStyle(.plain)
    }
}

struct CreatorAddedListView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(CreatorStore.self) private var creatorStore
    let kind: CreatorEntryKind

    @State private var showDeleteAllConfirmation = false
    @State private var promptVisibleIDs: Set<UUID> = []

    var body: some View {
        Group {
            if isEmpty {
                ContentUnavailableView(
                    "Brak wpisów",
                    systemImage: "tray",
                    description: Text("Nic jeszcze nie dodano w tej kategorii.")
                )
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        Text("Dotknij wpis, aby zobaczyć inspirację. Dotknij ponownie, aby wrócić do szczegółów.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        switch kind {
                        case .item:
                            ForEach(Array(creatorStore.catalog.items.enumerated()), id: \.element.id) { index, entry in
                                tappableTile(id: entry.id, prompt: entry.displayBuildPrompt) {
                                    itemRow(entry)
                                }
                                .contextMenu { deleteMenu { creatorStore.removeItems(at: IndexSet(integer: index)) } }
                            }
                        case .ability:
                            ForEach(Array(creatorStore.catalog.abilities.enumerated()), id: \.element.id) { index, entry in
                                tappableTile(id: entry.id, prompt: entry.displayBuildPrompt) {
                                    abilityRow(entry)
                                }
                                .contextMenu { deleteMenu { creatorStore.removeAbilities(at: IndexSet(integer: index)) } }
                            }
                        case .power:
                            ForEach(creatorStore.catalog.powerPaths) { path in
                                NavigationLink {
                                    PowerPathDetailView(pathID: path.id)
                                } label: {
                                    powerPathRow(path)
                                }
                                .buttonStyle(.plain)
                                .simultaneousGesture(TapGesture().onEnded {
                                    settings.playTapSound()
                                })
                                .contextMenu {
                                    if !path.isBuiltIn {
                                        deleteMenu { creatorStore.removePowerPath(id: path.id) }
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .padding(.bottom, 8)
                    .animation(.spring(response: 0.42, dampingFraction: 0.86), value: promptVisibleIDs)
                }
                .appScrollSurface()
            }
        }
        .navigationTitle("Dodane: \(kind.title)")
        .navigationBarTitleDisplayMode(.inline)
        .appThemedScreen()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !isEmpty {
                deleteAllFooter
            }
        }
        .alert("Usunąć wszystkie wpisy?", isPresented: $showDeleteAllConfirmation) {
            Button("Usuń wszystkie", role: .destructive) {
                settings.playTapSound()
                _ = creatorStore.removeAll(for: kind)
            }
            Button("Anuluj", role: .cancel) {
                settings.playTapSound()
            }
        } message: {
            Text("Zostanie usuniętych \(entryCount) \(entryCountLabel) z kategorii „\(kind.title)”. Tej operacji nie można cofnąć.")
        }
    }

    private var deleteAllFooter: some View {
        Button {
            settings.playTapSound()
            showDeleteAllConfirmation = true
        } label: {
            Label("Usuń wszystkie (\(entryCount))", systemImage: "trash.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.appSecondary)
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

    private func catalogTile<Content: View>(@ViewBuilder content: @escaping () -> Content) -> some View {
        CreatorCatalogTile(accentColor: kind.themeColor, content: content)
    }

    private func tappableTile<Content: View>(
        id: UUID,
        prompt: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        Button {
            togglePromptVisibility(for: id)
        } label: {
            catalogTile {
                if promptVisibleIDs.contains(id) {
                    buildPromptPanel(prompt)
                } else {
                    content()
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func buildPromptPanel(_ prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Inspiracja", systemImage: "lightbulb.fill")
                .font(.caption.bold())
                .foregroundStyle(kind.themeColor)

            Text(prompt)
                .font(.title3.bold())
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Dotknij ponownie, aby wrócić do szczegółów.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func togglePromptVisibility(for id: UUID) {
        settings.playTapSound()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            if promptVisibleIDs.contains(id) {
                promptVisibleIDs.remove(id)
            } else {
                promptVisibleIDs.insert(id)
            }
        }
    }

    @ViewBuilder
    private func deleteMenu(action: @escaping () -> Void) -> some View {
        Button("Usuń", role: .destructive) {
            settings.playTapSound()
            action()
        }
    }

    private var isEmpty: Bool {
        entryCount == 0
    }

    private var entryCount: Int {
        switch kind {
        case .item: creatorStore.catalog.items.count
        case .ability: creatorStore.catalog.abilities.count
        case .power: creatorStore.catalog.powerPaths.count
        }
    }

    private func powerPathRow(_ path: CreatedPowerPath) -> some View {
        HStack(spacing: 14) {
            Image(systemName: path.iconSymbol)
                .font(.title2)
                .foregroundStyle(path.glowColor.swiftUIColor)
                .frame(width: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text(path.name)
                    .font(.headline)
                Text("\(path.upgrades.count) ulepszeń · \(path.isBuiltIn ? "domyślna" : "własna")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(LiquidGlassBackground(accentStroke: path.glowColor.swiftUIColor, cornerRadius: 14, fillOpacity: 0.1))
    }

    private var entryCountLabel: String {
        switch entryCount {
        case 1: "wpis"
        case 2...4: "wpisy"
        default: "wpisów"
        }
    }

    private func characterRow(_ character: CreatedCharacter) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                if let image = creatorStore.loadImage(fileName: character.imageFileName) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(character.name)
                        .font(.headline)
                    Text("ID \(character.numericId) · \(character.raceName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Text("Zalety: \(character.advantages.joined(separator: ", "))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Wady: \(character.flaws.joined(separator: ", "))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func itemRow(_ item: CreatedItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(item.name)
                    .font(.headline)
                Label(item.resolvedItemKind.displayName, systemImage: item.resolvedItemKind.icon)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            Text("ID \(item.numericId) · koszt \(item.cost)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func abilityRow(_ ability: CreatedAbility) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(ability.name)
                .font(.headline)
            Text("ID \(ability.numericId) · \(ability.elementCategory)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(ability.effectDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
    }

    private func raceRow(_ race: CreatedRace) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(race.name)
                .font(.headline)
            Text("Zalety: \(race.advantages.joined(separator: ", "))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Wady: \(race.flaws.joined(separator: ", "))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func elementRow(_ element: CreatedElement) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(element.name)
                .font(.headline)
            Text(element.advantages)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
    }
}
