//
//  GameRulesViews.swift
//  BoardCore
//

import SwiftUI

struct GameRulesHomeView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(CreatorStore.self) private var creatorStore

    @State private var draft: GameRulesConfiguration = GameRulesRuntime.current
    @State private var savedConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text("Dostosuj nagrody i szanse pól planszy. Zmiany działają od razu w każdej rozgrywce.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(GameRulesFieldKind.allCases) { kind in
                    NavigationLink {
                        GameRulesFieldEditorView(kind: kind, rules: $draft)
                    } label: {
                        gameRulesRow(kind)
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(TapGesture().onEnded { settings.playTapSound() })
                }

                Button("Zapisz reguły") {
                    settings.playTapSound()
                    creatorStore.updateGameRules(draft)
                    savedConfirmation = true
                }
                .buttonStyle(.appProminent)
                .padding(.top, 8)
            }
            .padding()
        }
        .appScrollSurface()
        .navigationTitle("Reguły gry")
        .navigationBarTitleDisplayMode(.inline)
        .appThemedScreen()
        .onAppear { draft = creatorStore.gameRules }
        .onChange(of: draft) { _, newValue in
            creatorStore.updateGameRules(newValue)
        }
        .alert("Zapisano", isPresented: $savedConfirmation) {
            Button("OK", role: .cancel) { settings.playTapSound() }
        }
    }

    private func gameRulesRow(_ kind: GameRulesFieldKind) -> some View {
        let color = Color(red: kind.themeColor.red, green: kind.themeColor.green, blue: kind.themeColor.blue)
        return HStack(spacing: 14) {
            Image(systemName: kind.icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 36)
            Text(kind.title)
                .font(.headline)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(LiquidGlassBackground(accentStroke: color, cornerRadius: 14, fillOpacity: 0.1))
    }
}

struct GameRulesFieldEditorView: View {
    @Environment(CreatorStore.self) private var creatorStore

    let kind: GameRulesFieldKind
    @Binding var rules: GameRulesConfiguration

    private var accent: Color {
        Color(red: kind.themeColor.red, green: kind.themeColor.green, blue: kind.themeColor.blue)
    }

    private func syncLiveRules() {
        creatorStore.updateGameRules(rules)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                switch kind {
                case .startField: startFieldSection
                case .shop: shopSection
                case .bossFight: bossSection
                case .artifact: artifactSection
                case .specialCard: specialCardSection
                }
            }
            .padding()
        }
        .appScrollSurface()
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .appThemedScreen()
        .onChange(of: rules) { _, newValue in
            creatorStore.updateGameRules(newValue)
        }
        .onDisappear { syncLiveRules() }
    }

    private var startFieldSection: some View {
        Group {
            CreatorPillNumericField(label: "Monety za przejście", value: $rules.startField.passCoins, range: 0...9999, accentColor: accent, onCommit: syncLiveRules)
            CreatorPillNumericField(label: "Monety przy pełnym zdrowiu (zostając)", value: $rules.startField.stayAtFullHealthCoins, range: 0...9999, accentColor: accent, onCommit: syncLiveRules)
            CreatorPillNumericField(label: "XP przy pełnym zdrowiu", value: $rules.startField.stayAtFullHealthXP, range: 0...999, accentColor: accent, onCommit: syncLiveRules)
            CreatorPillNumericField(label: "Maks. zdrowie (pełne HP)", value: $rules.startField.maxHealth, range: 1...999, accentColor: accent, onCommit: syncLiveRules)
            CreatorPillNumericField(label: "Leczenie % aktualnego HP (zostając)", value: $rules.startField.stayHealPercentOfCurrent, range: 1...100, accentColor: accent, onCommit: syncLiveRules)
            CreatorPillNumericField(label: "XP za wizytę na polu start", value: $rules.startField.xpPerVisit, range: 0...999, accentColor: accent, onCommit: syncLiveRules)
            CreatorPillNumericField(label: "Co ile wizyt otwiera ścieżkę mocy", value: $rules.startField.powerPathEveryVisits, range: 1...20, accentColor: accent, onCommit: syncLiveRules)
        }
    }

    private var shopSection: some View {
        CreatorPillNumericField(label: "Maks. ofert w sklepie", value: $rules.shop.maxOffers, range: 1...20, accentColor: accent, onCommit: syncLiveRules)
    }

    private var bossSection: some View {
        Group {
            CreatorPillNumericField(label: "Zmiana zdrowia po skanowaniu", value: $rules.bossFight.scanHealthDelta, range: -100...100, accentColor: accent, onCommit: syncLiveRules)
            CreatorPillNumericField(label: "Zmiana siły po skanowaniu", value: $rules.bossFight.scanStrengthDelta, range: -100...100, accentColor: accent, onCommit: syncLiveRules)
            CreatorPillNumericField(label: "% nagrody dla głównego walczącego", value: $rules.bossFight.victoryFinanceMainPercent, range: 0...100, accentColor: accent, onCommit: syncLiveRules)
            CreatorPillNumericField(label: "% nagrody dla wspierających", value: $rules.bossFight.victoryFinanceSupportPercent, range: 0...100, accentColor: accent, onCommit: syncLiveRules)
            CreatorPillNumericField(label: "XP za zwycięstwo (łatwy)", value: $rules.bossFight.xpEasy, range: 0...999, accentColor: accent, onCommit: syncLiveRules)
            CreatorPillNumericField(label: "XP za zwycięstwo (średni)", value: $rules.bossFight.xpMedium, range: 0...999, accentColor: accent, onCommit: syncLiveRules)
            CreatorPillNumericField(label: "XP za zwycięstwo (trudny)", value: $rules.bossFight.xpHard, range: 0...999, accentColor: accent, onCommit: syncLiveRules)
        }
    }

    private var artifactSection: some View {
        Group {
            FieldCategoryOddsEditor(title: "Szanse losowania", odds: $rules.artifact.categoryOdds, accentColor: accent, onCommit: syncLiveRules)
            CreatorPillNumericField(label: "Monety — min", value: $rules.artifact.financesMin, range: 0...9999, accentColor: accent, onCommit: syncLiveRules)
            CreatorPillNumericField(label: "Monety — max", value: $rules.artifact.financesMax, range: 0...9999, accentColor: accent, onCommit: syncLiveRules)
            CreatorPillNumericField(label: "Statystyka — min", value: $rules.artifact.statBoostMin, range: 0...100, accentColor: accent, onCommit: syncLiveRules)
            CreatorPillNumericField(label: "Statystyka — max", value: $rules.artifact.statBoostMax, range: 0...100, accentColor: accent, onCommit: syncLiveRules)
            CreatorPillNumericField(label: "Pech HP — min", value: $rules.artifact.misfortuneHealthMin, range: 0...100, accentColor: accent, onCommit: syncLiveRules)
            CreatorPillNumericField(label: "Pech HP — max", value: $rules.artifact.misfortuneHealthMax, range: 0...100, accentColor: accent, onCommit: syncLiveRules)
            CreatorPillNumericField(label: "Pech siła — min", value: $rules.artifact.misfortuneStrengthMin, range: 0...100, accentColor: accent, onCommit: syncLiveRules)
            CreatorPillNumericField(label: "Pech siła — max", value: $rules.artifact.misfortuneStrengthMax, range: 0...100, accentColor: accent, onCommit: syncLiveRules)
            CreatorPillNumericField(label: "Pech monety — min", value: $rules.artifact.misfortuneFundMin, range: 0...9999, accentColor: accent, onCommit: syncLiveRules)
            CreatorPillNumericField(label: "Pech monety — max", value: $rules.artifact.misfortuneFundMax, range: 0...9999, accentColor: accent, onCommit: syncLiveRules)
            CreatorPillNumericField(label: "XP za losowanie", value: $rules.artifact.drawXP, range: 0...999, accentColor: accent, onCommit: syncLiveRules)
        }
    }

    private var specialCardSection: some View {
        Group {
            FieldCategoryOddsEditor(title: "Szanse kategorii karty", odds: $rules.specialCard.categoryOdds, accentColor: accent, onCommit: syncLiveRules)
            CreatorPillNumericField(label: "XP za kartę pozytywną", value: $rules.specialCard.positiveXP, range: 0...999, accentColor: accent, onCommit: syncLiveRules)
            CreatorPillNumericField(label: "XP za kartę negatywną", value: $rules.specialCard.negativeXP, range: 0...999, accentColor: accent, onCommit: syncLiveRules)

            NavigationLink {
                SpecialCardRulesListView(cards: $rules.specialCard.customCards, accent: accent)
            } label: {
                Label("Zarządzaj kartami (\(rules.specialCard.customCards.count))", systemImage: "rectangle.stack.badge.plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.appSecondary)
        }
    }
}

// MARK: - Karty specjalne

struct SpecialCardDraft {
    var id: String
    var title: String
    var summary: String
    var icon: String
    var isPositive: Bool
    var template: SpecialCardEffectTemplate
    var financesAmount: Int
    var healthAmount: Int
    var strengthAmount: Int
    var tripleAmount: Int
    var percentTenths: Int
    var queueRounds: Int

    init(from card: SpecialCardDefinition) {
        id = card.id
        title = card.title
        summary = card.summary
        icon = card.icon
        isPositive = card.isPositive
        template = SpecialCardEffectTemplate.from(card.effect)
        financesAmount = 25
        healthAmount = 15
        strengthAmount = 12
        tripleAmount = 8
        percentTenths = 25
        queueRounds = 2
        switch card.effect {
        case .financesDelta(let v): financesAmount = v
        case .healthDelta(let v): healthAmount = v
        case .strengthDelta(let v): strengthAmount = v
        case .tripleStatBoost(let v): tripleAmount = v
        case .healthPercentBonus(let v): percentTenths = Int(v * 100)
        case .combinedDrain(let h, let s, let f):
            healthAmount = h; strengthAmount = s; financesAmount = f
        case .plunder(let f): financesAmount = f
        case .queueBlock(let r): queueRounds = r
        default: break
        }
    }

    func buildCard() -> SpecialCardDefinition {
        var card = SpecialCardDefinition(
            id: id,
            title: title,
            summary: summary,
            icon: icon,
            isPositive: isPositive,
            effect: .financesDelta(0)
        )
        card.effect = template.buildEffect(
            finances: financesAmount,
            health: healthAmount,
            strength: strengthAmount,
            triple: tripleAmount,
            percentTenths: percentTenths,
            queueRounds: queueRounds
        )
        if summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            card.summary = template.defaultSummary(
                finances: financesAmount,
                health: healthAmount,
                strength: strengthAmount,
                triple: tripleAmount,
                percentTenths: percentTenths,
                queueRounds: queueRounds
            )
        }
        return card
    }
}

struct SpecialCardRulesListView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(CreatorStore.self) private var creatorStore
    @Binding var cards: [SpecialCardDefinition]
    let accent: Color

    @State private var editorSession: SpecialCardEditSession?

    var body: some View {
        List {
            if cards.isEmpty {
                Text("Brak kart — używany jest domyślny talia.")
                    .foregroundStyle(.secondary)
            }
            ForEach(cards) { card in
                Button {
                    settings.playTapSound()
                    editorSession = SpecialCardEditSession(card: card, isNew: false)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(card.title).font(.headline)
                        Text(card.summary).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { indexSet in
                settings.playTapSound()
                cards.remove(atOffsets: indexSet)
            }
        }
        .navigationTitle("Karty specjalne")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    settings.playTapSound()
                    editorSession = SpecialCardEditSession(
                        card: SpecialCardDefinition.makeTemplate(),
                        isNew: true
                    )
                } label: {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                Button("Domyślne") {
                    settings.playTapSound()
                    cards = SpecialCardDefinition.defaultDeck()
                }
            }
        }
        .navigationDestination(item: $editorSession) { session in
            SpecialCardRuleEditorView(
                card: session.card,
                isNew: session.isNew,
                accent: accent,
                onSave: { saved in
                    if session.isNew {
                        cards.append(saved)
                    } else if let index = cards.firstIndex(where: { $0.id == saved.id }) {
                        cards[index] = saved
                    }
                    syncCardsToLiveRules()
                }
            )
        }
        .onChange(of: cards) { _, _ in
            syncCardsToLiveRules()
        }
    }

    private func syncCardsToLiveRules() {
        var rules = creatorStore.gameRules
        rules.specialCard.customCards = cards
        creatorStore.updateGameRules(rules)
    }
}

struct SpecialCardEditSession: Identifiable, Hashable {
    let id: String
    var card: SpecialCardDefinition
    let isNew: Bool

    init(card: SpecialCardDefinition, isNew: Bool) {
        id = card.id
        self.card = card
        self.isNew = isNew
    }
}

struct SpecialCardRuleEditorView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var draft: SpecialCardDraft
    let isNew: Bool
    let accent: Color
    let onSave: (SpecialCardDefinition) -> Void

    init(card: SpecialCardDefinition, isNew: Bool, accent: Color, onSave: @escaping (SpecialCardDefinition) -> Void) {
        _draft = State(initialValue: SpecialCardDraft(from: card))
        self.isNew = isNew
        self.accent = accent
        self.onSave = onSave
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                CreatorPillTextField(label: "Tytuł", placeholder: "Nazwa karty", text: $draft.title, accentColor: accent)
                CreatorPillTextEditor(label: "Opis", text: $draft.summary, accentColor: accent)
                Picker("Typ karty", selection: $draft.isPositive) {
                    Text("Pozytywna").tag(true)
                    Text("Negatywna").tag(false)
                }
                .pickerStyle(.segmented)

                Picker("Efekt", selection: $draft.template) {
                    ForEach(SpecialCardEffectTemplate.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.menu)

                templateFields

                CreatorPillTextField(label: "Ikona SF Symbol", placeholder: "sparkles", text: $draft.icon, accentColor: accent)
            }
            .padding()
        }
        .navigationTitle(isNew ? "Nowa karta" : "Edycja karty")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                Button("Anuluj") { settings.playTapSound(); dismiss() }
                    .buttonStyle(.appSecondary)
                Button("Zapisz") {
                    settings.playTapSound()
                    onSave(draft.buildCard())
                    dismiss()
                }
                .buttonStyle(.appProminent)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
    }

    @ViewBuilder
    private var templateFields: some View {
        switch draft.template {
        case .financesDelta:
            CreatorPillNumericField(label: "Zmiana finansów", value: $draft.financesAmount, range: -9999...9999, accentColor: accent)
        case .healthDelta:
            CreatorPillNumericField(label: "Zmiana zdrowia", value: $draft.healthAmount, range: -100...100, accentColor: accent)
        case .strengthDelta:
            CreatorPillNumericField(label: "Zmiana siły", value: $draft.strengthAmount, range: -100...100, accentColor: accent)
        case .tripleStatBoost:
            CreatorPillNumericField(label: "Bonus do trzech statystyk", value: $draft.tripleAmount, range: 1...100, accentColor: accent)
        case .healthPercentBonus:
            CreatorPillNumericField(label: "Procent zdrowia (×10 = %)", value: $draft.percentTenths, range: 1...100, accentColor: accent)
        case .combinedDrain:
            CreatorPillNumericField(label: "− Zdrowie", value: $draft.healthAmount, range: 0...100, accentColor: accent)
            CreatorPillNumericField(label: "− Siła", value: $draft.strengthAmount, range: 0...100, accentColor: accent)
            CreatorPillNumericField(label: "− Finanse", value: $draft.financesAmount, range: 0...9999, accentColor: accent)
        case .plunder:
            CreatorPillNumericField(label: "Utrata monet", value: $draft.financesAmount, range: 0...9999, accentColor: accent)
        case .queueBlock:
            CreatorPillNumericField(label: "Blokada kolejki (tury)", value: $draft.queueRounds, range: 1...10, accentColor: accent)
        default:
            Text(draft.template.description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

enum SpecialCardEffectTemplate: String, CaseIterable, Identifiable {
    case financesDelta, healthDelta, strengthDelta, tripleStatBoost
    case grantRandomAbility, grantRandomItem, grantDoubleAbility
    case healthPercentBonus, treasuryAndItem, combinedDrain, plunder
    case removeRandomAbility, removeRandomItem, queueBlock

    var id: String { rawValue }

    var title: String {
        switch self {
        case .financesDelta: "Fundusze ±"
        case .healthDelta: "Zdrowie ±"
        case .strengthDelta: "Siła ±"
        case .tripleStatBoost: "Trzy statystyki +"
        case .grantRandomAbility: "Losowa zdolność"
        case .grantRandomItem: "Losowy przedmiot"
        case .grantDoubleAbility: "Dwie zdolności"
        case .healthPercentBonus: "% zdrowia +"
        case .treasuryAndItem: "Skarb + przedmiot"
        case .combinedDrain: "Osłabienie (HP/siła/finanse)"
        case .plunder: "Plądrowanie"
        case .removeRandomAbility: "Utrata zdolności"
        case .removeRandomItem: "Utrata przedmiotu"
        case .queueBlock: "Blokada kolejki"
        }
    }

    var description: String {
        switch self {
        case .grantRandomAbility: "Przyznaje losową zdolność z DevCentrum."
        case .grantRandomItem: "Przyznaje losowy przedmiot z DevCentrum."
        case .grantDoubleAbility: "Przyznaje do dwóch zdolności."
        case .treasuryAndItem: "+200 monet i losowy przedmiot."
        case .removeRandomAbility: "Usuwa losową zdolność gracza."
        case .removeRandomItem: "Usuwa losowy przedmiot gracza."
        default: ""
        }
    }

    static func from(_ effect: SpecialCardEffectKind) -> SpecialCardEffectTemplate {
        switch effect {
        case .financesDelta: .financesDelta
        case .healthDelta: .healthDelta
        case .strengthDelta: .strengthDelta
        case .tripleStatBoost: .tripleStatBoost
        case .grantRandomAbility: .grantRandomAbility
        case .grantRandomItem: .grantRandomItem
        case .grantDoubleAbility: .grantDoubleAbility
        case .healthPercentBonus: .healthPercentBonus
        case .treasuryAndItem: .treasuryAndItem
        case .combinedDrain: .combinedDrain
        case .plunder: .plunder
        case .removeRandomAbility: .removeRandomAbility
        case .removeRandomItem: .removeRandomItem
        case .queueBlock: .queueBlock
        }
    }

    func buildEffect(
        finances: Int,
        health: Int,
        strength: Int,
        triple: Int,
        percentTenths: Int,
        queueRounds: Int
    ) -> SpecialCardEffectKind {
        switch self {
        case .financesDelta: .financesDelta(finances)
        case .healthDelta: .healthDelta(health)
        case .strengthDelta: .strengthDelta(strength)
        case .tripleStatBoost: .tripleStatBoost(triple)
        case .grantRandomAbility: .grantRandomAbility
        case .grantRandomItem: .grantRandomItem
        case .grantDoubleAbility: .grantDoubleAbility
        case .healthPercentBonus: .healthPercentBonus(Double(percentTenths) / 100.0)
        case .treasuryAndItem: .treasuryAndItem
        case .combinedDrain: .combinedDrain(health: health, strength: strength, finances: finances)
        case .plunder: .plunder(finances: finances)
        case .removeRandomAbility: .removeRandomAbility
        case .removeRandomItem: .removeRandomItem
        case .queueBlock: .queueBlock(rounds: queueRounds)
        }
    }

    func defaultSummary(
        finances: Int,
        health: Int,
        strength: Int,
        triple: Int,
        percentTenths: Int,
        queueRounds: Int
    ) -> String {
        switch self {
        case .financesDelta: "\(finances >= 0 ? "+" : "")\(finances) finansów."
        case .healthDelta: "\(health >= 0 ? "+" : "")\(health) zdrowia."
        case .strengthDelta: "\(strength >= 0 ? "+" : "")\(strength) siły."
        case .tripleStatBoost: "+\(triple) finanse, zdrowie i siła."
        case .grantRandomAbility: "Losowa zdolność."
        case .grantRandomItem: "Losowy przedmiot."
        case .grantDoubleAbility: "Dwie losowe zdolności."
        case .healthPercentBonus: "+\(percentTenths)% zdrowia."
        case .treasuryAndItem: "+200 monet i przedmiot."
        case .combinedDrain: "−\(health) HP, −\(strength) siły, −\(finances) monet."
        case .plunder: "−\(finances) monet i utrata przedmiotu."
        case .removeRandomAbility: "Utrata zdolności."
        case .removeRandomItem: "Utrata przedmiotu."
        case .queueBlock: "Blokada kolejki \(queueRounds) tury."
        }
    }
}

extension SpecialCardDefinition {
    static func makeTemplate() -> SpecialCardDefinition {
        SpecialCardDefinition(
            id: "custom_\(UUID().uuidString.prefix(8))",
            title: "Nowa karta",
            summary: "+10 finansów.",
            icon: "sparkles",
            isPositive: true,
            effect: .financesDelta(10)
        )
    }
}
