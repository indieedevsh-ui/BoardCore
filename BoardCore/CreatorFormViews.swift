//
//  CreatorFormViews.swift
//  BoardCore
//

import SwiftUI

// MARK: - Wspólne komponenty

struct CreatorPillTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.headline)

            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(accentColor.opacity(0.32), lineWidth: 1)
                }
        }
    }
}

struct CreatorPillTextEditor: View {
    let label: String
    @Binding var text: String
    var minHeight: CGFloat = 100
    var accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.headline)

            TextEditor(text: $text)
                .frame(minHeight: minHeight)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .scrollContentBackground(.hidden)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(accentColor.opacity(0.32), lineWidth: 1)
                }
        }
    }
}

struct CreatorNumericIDField: View {
    @Environment(AppSettings.self) private var settings
    @Binding var numericId: String
    let label: String
    let onRandomize: () -> Void
    var isTaken: (String) -> Bool
    var accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.headline)
            HStack(spacing: 10) {
                TextField("ID", text: $numericId)
                    .keyboardType(.numberPad)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                    )
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(accentColor.opacity(0.32), lineWidth: 1)
                    }
                Button {
                    settings.playTapSound()
                    onRandomize()
                } label: {
                    Label("Losuj", systemImage: "dice.fill")
                }
                .buttonStyle(.appSecondary)
            }
            if !numericId.isEmpty, isTaken(numericId) {
                Text("To ID jest już zajęte — wylosuj inne.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }
}

struct CreatorPillPickerField<Content: View>: View {
    let label: String
    var accentColor: Color
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.headline)

            content()
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(accentColor.opacity(0.32), lineWidth: 1)
                }
        }
    }
}

struct CreatorStatsEditor: View {
    @Environment(AppSettings.self) private var settings
    @Binding var stats: CreatorStats
    var showRandomize: Bool = true
    var accentColor: Color
    /// Gdy ustawiony, edytor pokazuje tylko statystykę właściwą dla typu przedmiotu.
    var itemKind: CreatorItemKind?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Statystyki")
                    .font(.headline)
                Spacer()
                if showRandomize {
                    Button("Losuj") {
                        settings.playTapSound()
                        stats = .random(itemKind: itemKind)
                    }
                    .buttonStyle(.appSecondary)
                }
            }

            switch itemKind {
            case .weapon:
                statSlider(
                    "Siła",
                    value: $stats.strength,
                    range: Double(CreatorStats.weaponStrengthRange.lowerBound)...Double(CreatorStats.weaponStrengthRange.upperBound),
                    showsPlus: true
                )
            case .armor:
                statSlider(
                    "Zdrowie",
                    value: $stats.health,
                    range: Double(CreatorStats.armorHealthRange.lowerBound)...Double(CreatorStats.armorHealthRange.upperBound),
                    showsPlus: true
                )
            case .brush:
                statSlider(
                    "Szansa na lepszy drop (%)",
                    value: $stats.mana,
                    range: Double(CreatorStats.brushArtifactLuckRange.lowerBound)...Double(CreatorStats.brushArtifactLuckRange.upperBound),
                    showsPercent: true
                )
            case nil:
                statSlider("Obrażenia / Siła", value: $stats.strength)
                statSlider("Zdrowie", value: $stats.health)
                statSlider("Mana", value: $stats.mana)
                statSlider("Finanse", value: $stats.finances)
            default:
                EmptyView()
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(accentColor.opacity(0.28), lineWidth: 1)
        }
    }

    private func statSlider(
        _ title: String,
        value: Binding<Int>,
        range: ClosedRange<Double> = 0...100,
        showsPlus: Bool = false,
        showsPercent: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                if showsPlus {
                    Text("+\(value.wrappedValue)")
                        .monospacedDigit()
                } else if showsPercent {
                    Text("\(value.wrappedValue)%")
                        .monospacedDigit()
                } else {
                    Text("\(value.wrappedValue)")
                        .monospacedDigit()
                }
            }
            .font(.subheadline)
            Slider(
                value: Binding(
                    get: { Double(value.wrappedValue) },
                    set: { value.wrappedValue = Int($0.rounded()) }
                ),
                in: range,
                step: 1
            )
        }
    }
}

// MARK: - Postać

struct CharacterCreatorView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(CreatorStore.self) private var creatorStore
    @Environment(\.dismiss) private var dismiss

    private let theme = Color(red: 0.35, green: 0.65, blue: 1.0)

    @State private var numericId = ""
    @State private var name = ""
    @State private var raceName = CreatorCatalog.defaultRaceNames[0]
    @State private var selectedAdvantages: Set<String> = []
    @State private var selectedFlaws: Set<String> = []
    @State private var stats = CreatorStats()
    @State private var showValidationAlert = false
    @State private var savedConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                CreatorNumericIDField(
                    numericId: $numericId,
                    label: "ID postaci",
                    onRandomize: rollUniqueID,
                    isTaken: creatorStore.isNumericIDTaken,
                    accentColor: theme
                )

                CreatorPillTextField(
                    label: "Nazwa postaci",
                    placeholder: "Np. Aelion Straznik",
                    text: $name,
                    accentColor: theme
                )

                CreatorPillPickerField(label: "Rasa", accentColor: theme) {
                    Picker("Rasa", selection: $raceName) {
                        ForEach(creatorStore.availableRaceNames, id: \.self) { race in
                            Text(race).tag(race)
                        }
                    }
                    .pickerStyle(.menu)
                }

                CreatorTraitPickerSection(
                    title: "Zalety",
                    options: CharacterOptions.advantages,
                    selection: $selectedAdvantages,
                    oppositeSelection: $selectedFlaws,
                    maxCount: 2,
                    accentColor: theme
                )

                CreatorTraitPickerSection(
                    title: "Wady",
                    options: CharacterOptions.flaws,
                    selection: $selectedFlaws,
                    oppositeSelection: $selectedAdvantages,
                    maxCount: 2,
                    accentColor: theme
                )

                CreatorStatsEditor(stats: $stats, accentColor: theme)

                Button("Zapisz postać") {
                    save()
                }
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
        .navigationTitle("Postać")
        .navigationBarTitleDisplayMode(.inline)
        .appThemedScreen()
        .onAppear {
            if numericId.isEmpty {
                rollUniqueID()
            }
        }
        .alert("Uzupełnij dane", isPresented: $showValidationAlert) {
            Button("OK", role: .cancel) { settings.playTapSound() }
        } message: {
            Text("Podaj unikalne ID, nazwę oraz co najmniej jedną zaletę i jedną wadę.")
        }
        .alert("Zapisano", isPresented: $savedConfirmation) {
            Button("OK") {
                settings.playTapSound()
                dismiss()
            }
        } message: {
            Text("Postać „\(name)” (ID \(numericId)) została dodana do katalogu.")
        }
    }

    private func rollUniqueID() {
        numericId = creatorStore.randomCharacterID()
    }

    private func save() {
        let trimmedID = numericId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !trimmedID.isEmpty,
            !trimmedName.isEmpty,
            !selectedAdvantages.isEmpty,
            !selectedFlaws.isEmpty,
            !creatorStore.isNumericIDTaken(trimmedID)
        else {
            settings.playTapSound()
            showValidationAlert = true
            return
        }

        settings.playTapSound()

        let character = CreatedCharacter(
            numericId: trimmedID,
            name: trimmedName,
            raceName: raceName,
            advantages: selectedAdvantages.sorted(),
            flaws: selectedFlaws.sorted(),
            stats: stats,
            imageFileName: nil,
            buildPrompt: CreatorBuildPrompts.character(race: raceName)
        )
        creatorStore.addCharacter(character)
        savedConfirmation = true
    }
}

// MARK: - Przedmiot

struct ItemCreatorView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(CreatorStore.self) private var creatorStore
    @Environment(\.dismiss) private var dismiss

    private let theme = CreatorEntryKind.item.themeColor

    @State private var numericId = ""
    @State private var name = ""
    @State private var cost = 50
    @State private var itemKind: CreatorItemKind = .weapon
    @State private var stats = CreatorStats()
    @State private var showValidationAlert = false
    @State private var savedConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                CreatorNumericIDField(
                    numericId: $numericId,
                    label: "ID przedmiotu",
                    onRandomize: { numericId = creatorStore.randomItemID() },
                    isTaken: creatorStore.isNumericIDTaken,
                    accentColor: theme
                )

                CreatorPillTextField(
                    label: itemKind == .brush ? "Nazwa pędzla" : "Nazwa przedmiotu",
                    placeholder: itemKind == .brush ? "Np. Pędzel Kryształowej Mgły" : "Np. Miecz Strażnika Mgły",
                    text: $name,
                    accentColor: theme
                )

                CreatorPillPickerField(label: "Kategoria ekwipunku", accentColor: theme) {
                    Picker("Kategoria", selection: $itemKind) {
                        ForEach(CreatorItemKind.formSelectableCases) { kind in
                            Label(kind.displayName, systemImage: kind.icon).tag(kind)
                        }
                    }
                    .pickerStyle(.menu)
                }

                if let hint = itemKind.artifactHint {
                    Text(hint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }

                CreatorPillStepperField(
                    label: "Koszt",
                    value: $cost,
                    range: 0...9999,
                    accentColor: theme
                )

                CreatorStatsEditor(stats: $stats, accentColor: theme, itemKind: itemKind)
                    .onChange(of: itemKind) { _, kind in
                        switch kind {
                        case .weapon:
                            if !CreatorStats.weaponStrengthRange.contains(stats.strength) {
                                stats.strength = 40
                            }
                        case .armor:
                            if !CreatorStats.armorHealthRange.contains(stats.health) {
                                stats.health = 40
                            }
                        case .brush:
                            if !CreatorStats.brushArtifactLuckRange.contains(stats.mana) {
                                stats.mana = 10
                            }
                        default:
                            break
                        }
                    }

                Button("Zapisz przedmiot") { save() }
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
        .navigationTitle("Przedmiot")
        .navigationBarTitleDisplayMode(.inline)
        .appThemedScreen()
        .onAppear {
            if numericId.isEmpty {
                numericId = creatorStore.randomItemID()
            }
        }
        .alert("Uzupełnij dane", isPresented: $showValidationAlert) {
            Button("OK", role: .cancel) { settings.playTapSound() }
        } message: {
            Text("Podaj unikalne ID i nazwę przedmiotu.")
        }
        .alert("Zapisano", isPresented: $savedConfirmation) {
            Button("OK") { settings.playTapSound(); dismiss() }
        } message: {
            Text("Przedmiot „\(name)” (ID \(numericId)) został zapisany.")
        }
    }

    private func save() {
        let trimmedID = numericId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedID.isEmpty, !trimmedName.isEmpty, !creatorStore.isNumericIDTaken(trimmedID) else {
            settings.playTapSound()
            showValidationAlert = true
            return
        }
        settings.playTapSound()
        creatorStore.addItem(
            CreatedItem(
                numericId: trimmedID,
                name: trimmedName,
                cost: cost,
                stats: CreatorStats.normalizedForItemKind(itemKind, stats: stats),
                itemKind: itemKind,
                imageFileName: nil,
                buildPrompt: CreatorBuildPrompts.item(isBrush: itemKind == .brush)
            )
        )
        savedConfirmation = true
    }
}

// MARK: - Zdolność

struct AbilityCreatorView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(CreatorStore.self) private var creatorStore
    @Environment(\.dismiss) private var dismiss

    private let theme = Color(red: 0.62, green: 0.38, blue: 0.98)

    @State private var numericId = ""
    @State private var name = ""
    @State private var effectDescription = ""
    @State private var elementCategory = CreatorCatalog.defaultElementNames[0]
    @State private var showValidationAlert = false
    @State private var savedConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                CreatorNumericIDField(
                    numericId: $numericId,
                    label: "ID zdolności",
                    onRandomize: { numericId = creatorStore.randomAbilityID() },
                    isTaken: creatorStore.isNumericIDTaken,
                    accentColor: theme
                )

                CreatorPillTextField(
                    label: "Nazwa zdolności",
                    placeholder: "Np. Rozdarcie Płomienia",
                    text: $name,
                    accentColor: theme
                )

                CreatorPillTextEditor(
                    label: "Co robi zdolność",
                    text: $effectDescription,
                    minHeight: 120,
                    accentColor: theme
                )

                CreatorPillPickerField(label: "Kategoria żywiołu", accentColor: theme) {
                    Picker("Żywioł", selection: $elementCategory) {
                        ForEach(creatorStore.availableElementNames, id: \.self) { element in
                            Text(element).tag(element)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Button("Zapisz zdolność") { save() }
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
        .navigationTitle("Zdolność")
        .navigationBarTitleDisplayMode(.inline)
        .appThemedScreen()
        .onAppear {
            if numericId.isEmpty {
                numericId = creatorStore.randomAbilityID()
            }
        }
        .alert("Uzupełnij dane", isPresented: $showValidationAlert) {
            Button("OK", role: .cancel) { settings.playTapSound() }
        } message: {
            Text("Podaj unikalne ID, nazwę i opis działania zdolności.")
        }
        .alert("Zapisano", isPresented: $savedConfirmation) {
            Button("OK") { settings.playTapSound(); dismiss() }
        } message: {
            Text("Zdolność „\(name)” została zapisana.")
        }
    }

    private func save() {
        let trimmedID = numericId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEffect = effectDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !trimmedID.isEmpty,
            !trimmedName.isEmpty,
            !trimmedEffect.isEmpty,
            !creatorStore.isNumericIDTaken(trimmedID)
        else {
            settings.playTapSound()
            showValidationAlert = true
            return
        }
        settings.playTapSound()
        creatorStore.addAbility(
            CreatedAbility(
                numericId: trimmedID,
                name: trimmedName,
                effectDescription: trimmedEffect,
                elementCategory: elementCategory,
                buildPrompt: CreatorBuildPrompts.ability(element: elementCategory)
            )
        )
        savedConfirmation = true
    }
}

// MARK: - Rasa

struct RaceCreatorView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(CreatorStore.self) private var creatorStore
    @Environment(\.dismiss) private var dismiss

    private let theme = Color(red: 0.34, green: 0.84, blue: 0.58)

    @State private var name = ""
    @State private var selectedAdvantages: Set<String> = []
    @State private var selectedFlaws: Set<String> = []
    @State private var stats = CreatorStats()
    @State private var showValidationAlert = false
    @State private var savedConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                CreatorPillTextField(
                    label: "Nazwa rasy",
                    placeholder: "Np. Luminarowie",
                    text: $name,
                    accentColor: theme
                )

                CreatorTraitPickerSection(
                    title: "Zalety rasy",
                    options: CharacterOptions.advantages,
                    selection: $selectedAdvantages,
                    oppositeSelection: $selectedFlaws,
                    maxCount: 3,
                    accentColor: theme
                )

                CreatorTraitPickerSection(
                    title: "Wady rasy",
                    options: CharacterOptions.flaws,
                    selection: $selectedFlaws,
                    oppositeSelection: $selectedAdvantages,
                    maxCount: 3,
                    accentColor: theme
                )

                CreatorStatsEditor(stats: $stats, accentColor: theme)

                Button("Zapisz rasę") { save() }
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
        .navigationTitle("Rasy")
        .navigationBarTitleDisplayMode(.inline)
        .appThemedScreen()
        .alert("Uzupełnij dane", isPresented: $showValidationAlert) {
            Button("OK", role: .cancel) { settings.playTapSound() }
        } message: {
            Text("Podaj nazwę rasy oraz co najmniej jedną zaletę i jedną wadę.")
        }
        .alert("Zapisano", isPresented: $savedConfirmation) {
            Button("OK") { settings.playTapSound(); dismiss() }
        } message: {
            Text("Rasa „\(name)” została zapisana i jest dostępna przy tworzeniu postaci.")
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !selectedAdvantages.isEmpty, !selectedFlaws.isEmpty else {
            settings.playTapSound()
            showValidationAlert = true
            return
        }
        settings.playTapSound()
        creatorStore.addRace(
            CreatedRace(
                name: trimmedName,
                advantages: selectedAdvantages.sorted(),
                flaws: selectedFlaws.sorted(),
                stats: stats,
                buildPrompt: CreatorBuildPrompts.race()
            )
        )
        savedConfirmation = true
    }
}

// MARK: - Żywioł

struct ElementCreatorView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(CreatorStore.self) private var creatorStore
    @Environment(\.dismiss) private var dismiss

    private let theme = Color(red: 1.0, green: 0.42, blue: 0.36)

    @State private var name = ""
    @State private var advantages = ""
    @State private var disadvantages = ""
    @State private var showValidationAlert = false
    @State private var savedConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                CreatorPillTextField(
                    label: "Nazwa żywiołu",
                    placeholder: "Np. Pustka",
                    text: $name,
                    accentColor: theme
                )

                CreatorPillTextEditor(
                    label: "Zalety żywiołu",
                    text: $advantages,
                    minHeight: 90,
                    accentColor: theme
                )

                CreatorPillTextEditor(
                    label: "Wady żywiołu",
                    text: $disadvantages,
                    minHeight: 90,
                    accentColor: theme
                )

                Button("Zapisz żywioł") { save() }
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
        .navigationTitle("Żywioły")
        .navigationBarTitleDisplayMode(.inline)
        .appThemedScreen()
        .alert("Uzupełnij dane", isPresented: $showValidationAlert) {
            Button("OK", role: .cancel) { settings.playTapSound() }
        } message: {
            Text("Podaj nazwę oraz zalety i wady żywiołu.")
        }
        .alert("Zapisano", isPresented: $savedConfirmation) {
            Button("OK") { settings.playTapSound(); dismiss() }
        } message: {
            Text("Żywioł „\(name)” jest dostępny przy tworzeniu zdolności.")
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAdv = advantages.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDis = disadvantages.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedAdv.isEmpty, !trimmedDis.isEmpty else {
            settings.playTapSound()
            showValidationAlert = true
            return
        }
        settings.playTapSound()
        creatorStore.addElement(
            CreatedElement(
                name: trimmedName,
                advantages: trimmedAdv,
                disadvantages: trimmedDis,
                buildPrompt: CreatorBuildPrompts.element()
            )
        )
        savedConfirmation = true
    }
}
