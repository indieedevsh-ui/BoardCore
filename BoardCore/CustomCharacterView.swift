//
//  CustomCharacterView.swift
//  BoardCore
//

import SwiftUI

struct CustomCharacterView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(CreatorStore.self) private var creatorStore
    @Environment(\.dismiss) private var dismiss

    let onSave: (PlayerCharacter) -> Void

    @State private var lookupQuery = ""
    @State private var loadedCharacter: CreatedCharacter?
    @State private var className = ""
    @State private var selectedAdvantages: Set<String> = []
    @State private var selectedFlaws: Set<String> = []
    @State private var selectedWeapon = CharacterOptions.weapons[0]
    @State private var showValidationAlert = false
    @State private var showNotFoundAlert = false

    private let maxTraitCount = 2

    private var isCreatorMode: Bool { loadedCharacter != nil }

    var body: some View {
        Form {
            Section {
                TextField("Nazwa lub ID postaci z kreatora", text: $lookupQuery)
                    .textInputAutocapitalization(.words)
                    .onChange(of: lookupQuery) { _, _ in
                        tryLoadFromCreator()
                    }

                Button("Wczytaj postać") {
                    settings.playTapSound()
                    tryLoadFromCreator(forceAlert: true)
                }
                .buttonStyle(.appProminent)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
            } header: {
                Text("Postać z kreatora")
            } footer: {
                Text("Wpisz nazwę lub ID (np. 3001). Postać wczyta rasę, zalety, wady i statystyki z kreatora.")
            }

            if let loadedCharacter {
                Section {
                    LabeledContent("Nazwa", value: loadedCharacter.name)
                    LabeledContent("ID", value: loadedCharacter.numericId)
                    LabeledContent("Rasa", value: loadedCharacter.raceName)
                    LabeledContent("Zalety", value: loadedCharacter.advantages.joined(separator: ", "))
                    LabeledContent("Wady", value: loadedCharacter.flaws.joined(separator: ", "))
                    LabeledContent("Finanse", value: "\(loadedCharacter.stats.finances)")
                    LabeledContent("Zdrowie", value: "\(loadedCharacter.stats.health)")
                    LabeledContent("Siła", value: "\(loadedCharacter.stats.strength)")
                } header: {
                    Text("Wczytana postać")
                }

                Section {
                    Picker("Broń główna", selection: $selectedWeapon) {
                        ForEach(CharacterOptions.weapons, id: \.self) { weapon in
                            Text(weapon).tag(weapon)
                        }
                    }
                } header: {
                    Text("Broń")
                }
            } else {
                Section {
                    TextField("Nazwa klasy (własna postać)", text: $className)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text("Własna postać")
                }

                Section {
                    traitSelection(
                        options: CharacterOptions.advantages,
                        selection: $selectedAdvantages
                    )
                } header: {
                    Text("Główne zalety")
                } footer: {
                    Text("Wybierz maksymalnie \(maxTraitCount) zalety.")
                }

                Section {
                    traitSelection(
                        options: CharacterOptions.flaws,
                        selection: $selectedFlaws
                    )
                } header: {
                    Text("Główne wady")
                } footer: {
                    Text("Wybierz maksymalnie \(maxTraitCount) wady.")
                }

                Section {
                    Picker("Broń główna", selection: $selectedWeapon) {
                        ForEach(CharacterOptions.weapons, id: \.self) { weapon in
                            Text(weapon).tag(weapon)
                        }
                    }
                } header: {
                    Text("Broń")
                }
            }
        }
        .appFormSurface()
        .background(Color.clear)
        .appThemedScreen()
        .navigationTitle("Dodaj postać")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Dodaj gracza") {
                    saveCharacter()
                }
            }
        }
        .alert("Uzupełnij postać", isPresented: $showValidationAlert) {
            Button("OK", role: .cancel) {
                settings.playTapSound()
            }
        } message: {
            Text(isCreatorMode
                ? "Wczytaj postać z kreatora (nazwa lub ID)."
                : "Podaj nazwę klasy oraz wybierz co najmniej po jednej zalecie i wadzie.")
        }
        .alert("Nie znaleziono", isPresented: $showNotFoundAlert) {
            Button("OK", role: .cancel) {
                settings.playTapSound()
            }
        } message: {
            Text("Brak postaci o nazwie lub ID „\(lookupQuery)” w kreatorze.")
        }
    }

    @ViewBuilder
    private func traitSelection(
        options: [String],
        selection: Binding<Set<String>>
    ) -> some View {
        ForEach(options, id: \.self) { option in
            Button {
                settings.playTapSound()
                toggle(option, in: selection, maxCount: maxTraitCount)
            } label: {
                HStack {
                    Text(option)
                        .foregroundStyle(.primary)
                    Spacer()
                    if selection.wrappedValue.contains(option) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.tint)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func toggle(_ option: String, in selection: Binding<Set<String>>, maxCount: Int) {
        if selection.wrappedValue.contains(option) {
            selection.wrappedValue.remove(option)
        } else if selection.wrappedValue.count < maxCount {
            selection.wrappedValue.insert(option)
        }
    }

    private func tryLoadFromCreator(forceAlert: Bool = false) {
        let trimmed = lookupQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            loadedCharacter = nil
            return
        }
        if let match = creatorStore.character(matching: trimmed) {
            loadedCharacter = match
            selectedWeapon = CharacterOptions.weapons[0]
            settings.playTapSound()
        } else {
            loadedCharacter = nil
            if forceAlert {
                showNotFoundAlert = true
            }
        }
    }

    private func saveCharacter() {
        if let loadedCharacter {
            settings.playTapSound()
            onSave(.fromCreated(loadedCharacter, mainWeapon: selectedWeapon))
            dismiss()
            return
        }

        let trimmedName = className.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !trimmedName.isEmpty,
            !selectedAdvantages.isEmpty,
            !selectedFlaws.isEmpty
        else {
            settings.playTapSound()
            showValidationAlert = true
            return
        }

        settings.playTapSound()
        let player = PlayerCharacter(
            className: trimmedName,
            advantages: selectedAdvantages.sorted(),
            flaws: selectedFlaws.sorted(),
            mainWeapon: selectedWeapon
        )
        onSave(player)
        dismiss()
    }
}
