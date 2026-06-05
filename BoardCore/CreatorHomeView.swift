//
//  CreatorHomeView.swift
//  BoardCore
//

import SwiftUI

private enum CreatorHomeRoute: Hashable {
    case gameRules
}

struct CreatorHomeView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(CreatorStore.self) private var creatorStore
    @Environment(TrikiNavigationCoordinator.self) private var trikiCoordinator

    @State private var showRestoreDefaultsConfirmation = false
    @State private var restoreCompleted = false
    @State private var navigationPath = NavigationPath()
    private let creatorTrikiFocusID = UUID()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("DevCentrum")
                        .font(.largeTitle.bold())

                    Text("Twórz zawartość gry i edytuj reguły pól planszy. Zmiany działają od razu w każdej rozgrywce.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ForEach(CreatorEntryKind.allCases) { kind in
                        creatorButton(kind: kind)
                    }

                    devToolsSection
                }
                .padding()
            }
            .appScrollSurface()
            .navigationTitle("DevCentrum")
            .containerBackground(.clear, for: .navigation)
            .toolbarBackground(.hidden, for: .navigationBar)
            .alert("Przywrócić domyślne?", isPresented: $showRestoreDefaultsConfirmation) {
                Button("Przywróć domyślne", role: .destructive) {
                    settings.playTapSound()
                    creatorStore.restoreToDefaults()
                    restoreCompleted = true
                }
                Button("Anuluj", role: .cancel) {
                    settings.playTapSound()
                }
            } message: {
                Text("Katalog DevCentrum i reguły gry wrócą do stanu początkowego. Zapis graczy, kampanii i rozgrywek pozostanie bez zmian.")
            }
            .alert("Przywrócono domyślne", isPresented: $restoreCompleted) {
                Button("OK", role: .cancel) {
                    settings.playTapSound()
                }
            } message: {
                Text("DevCentrum zostało zresetowane do ustawień domyślnych.")
            }
            .navigationDestination(for: CreatorEntryKind.self) { kind in
                CreatorTypeHubView(kind: kind)
            }
            .navigationDestination(for: CreatorHomeRoute.self) { route in
                switch route {
                case .gameRules:
                    GameRulesHomeView()
                }
            }
            .trikiFocusContext(
                id: creatorTrikiFocusID,
                buttons: creatorHomeTrikiButtons,
                onActivate: { activateCreatorHomeTriki(at: $0) }
            )
        }
    }

    private var creatorHomeTrikiButtons: [TrikiFocusButton] {
        var buttons = CreatorEntryKind.allCases.map { kind in
            TrikiFocusButton(id: "kind-\(kind.rawValue)", title: kind.title)
        }
        buttons.append(TrikiFocusButton(id: "rules", title: "Zmień reguły gry"))
        buttons.append(TrikiFocusButton(id: "restore", title: "Przywróć domyślne"))
        return buttons
    }

    private func activateCreatorHomeTriki(at index: Int) {
        let buttons = creatorHomeTrikiButtons
        guard buttons.indices.contains(index) else { return }
        settings.playTapSound()
        let row = buttons[index]
        if row.id.hasPrefix("kind-") {
            let raw = String(row.id.dropFirst("kind-".count))
            if let kind = CreatorEntryKind(rawValue: raw) {
                navigationPath.append(kind)
            }
        } else if row.id == "rules" {
            navigationPath.append(CreatorHomeRoute.gameRules)
        } else if row.id == "restore" {
            showRestoreDefaultsConfirmation = true
        }
        trikiCoordinator.statusMessage = "Wciśnięto: \(row.title)"
    }

    private var devToolsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider().opacity(0.35)

            Button {
                settings.playTapSound()
                navigationPath.append(CreatorHomeRoute.gameRules)
            } label: {
                Label("Zmień reguły gry", systemImage: "slider.horizontal.3")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.appProminent)

            Button {
                settings.playTapSound()
                showRestoreDefaultsConfirmation = true
            } label: {
                Label("Przywróć domyślne", systemImage: "arrow.counterclockwise")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.appSecondary)

            Text("Reguły gry obejmują pola start, sklep, bossa, artefakt i karty specjalne. Przywrócenie nie usuwa zapisów graczy, kampanii ani rozgrywek.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private func creatorButton(kind: CreatorEntryKind) -> some View {
        Button {
            settings.playTapSound()
            navigationPath.append(kind)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: kind.icon)
                    .font(.title2)
                    .frame(width: 36)
                Text(kind.title)
                    .font(.title3.bold())
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(.vertical, 18)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .liquidGlassButtonBackground(prominent: true, cornerRadius: 14, accent: kind.themeColor)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture().onEnded {
            settings.playTapSound()
        })
    }
}

#Preview {
    CreatorHomeView()
        .environment(AppSettings())
        .environment(CreatorStore())
        .environment(TrikiNavigationCoordinator())
}
