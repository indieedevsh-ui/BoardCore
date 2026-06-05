//
//  CampaignModels.swift
//  BoardCore
//

import Foundation

enum CampaignClimate: String, CaseIterable, Identifiable, Codable {
    case darkFantasy
    case future
    case fantasy
    case lego
    case cute
    case multiverse

    var id: String { rawValue }

    var title: String {
        switch self {
        case .darkFantasy: "Dark Fantasy"
        case .future: "Future"
        case .fantasy: "Fantasy"
        case .lego: "Lego"
        case .cute: "Cute"
        case .multiverse: "Multiverse"
        }
    }

    var description: String {
        switch self {
        case .darkFantasy:
            "Mroczny świat pełen grozy, trudnych wyborów moralnych, krwawej magii i zepsucia."
        case .future:
            "Science fiction: technologia, przyszłość, androidy, kolonie kosmiczne i konsekwencje postępu."
        case .fantasy:
            "Klasyczne heroic fantasy: questy, potwory, magia, sojusze i epicka przygoda."
        case .lego:
            "Świat jak z klocków LEGO: kolorowe budowle, humor, kreatywne łączenie elementów, drużyna jak figurki — lekkie przeszkody i pomysłowe rozwiązania zamiast brutalnej przemocy."
        case .cute:
            "Słodki, przyjazny klimat: pastelowe tony, urocze postacie i zwierzęta, ciepły humor, niskie stawki — przygoda bez drastycznej krwi i mroku."
        case .multiverse:
            "Multiwersum: równoległe światy, spotkania z innymi wersjami bohaterów, paradoksy czasu i konwergencja rzeczywistości — mieszanka sci-fi, fantasy i zaskakujących twistów."
        }
    }
}

struct CampaignScene: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var narrative: String
    /// Identyfikator gałęzi, np. „1”, „2A”, „3B”, „4C” (finał).
    var sceneTag: String

    init(id: UUID = UUID(), title: String, narrative: String, sceneTag: String = "") {
        self.id = id
        self.title = title
        self.narrative = narrative
        self.sceneTag = sceneTag
    }

    enum CodingKeys: String, CodingKey {
        case id, title, narrative, sceneTag
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        narrative = try container.decode(String.self, forKey: .narrative)
        sceneTag = try container.decodeIfPresent(String.self, forKey: .sceneTag) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(narrative, forKey: .narrative)
        try container.encode(sceneTag, forKey: .sceneTag)
    }
}

struct CampaignChoiceEffects: Codable, Hashable {
    var strength: Int = 0
    var coins: Int = 0
    var abilities: Int = 0
    var boardMove: Int = 0
    var blockRounds: Int = 0
    var health: Int = 0
    var mana: Int = 0

    var isEmpty: Bool {
        strength == 0 && coins == 0 && abilities == 0 && boardMove == 0
            && blockRounds == 0 && health == 0 && mana == 0
    }

    var summaryTokens: [String] {
        var tokens: [String] = []
        if strength != 0 { tokens.append("sila\(strength > 0 ? "+" : "")\(strength)") }
        if coins != 0 { tokens.append("monety\(coins > 0 ? "+" : "")\(coins)") }
        if abilities != 0 { tokens.append("zdolnosci\(abilities > 0 ? "+" : "")\(abilities)") }
        if boardMove != 0 { tokens.append("plansza\(boardMove > 0 ? "+" : "")\(boardMove)") }
        if blockRounds != 0 { tokens.append("blokada\(blockRounds)r") }
        if health != 0 { tokens.append("zdrowie\(health > 0 ? "+" : "")\(health)") }
        if mana != 0 { tokens.append("mana\(mana > 0 ? "+" : "")\(mana)") }
        return tokens
    }

    var negativeDescriptions: [String] {
        statLines.filter { $0.delta < 0 }.map(\.label)
    }

    var positiveDescriptions: [String] {
        statLines.filter { $0.delta > 0 }.map(\.label)
    }

    private var statLines: [(delta: Int, label: String)] {
        var lines: [(Int, String)] = []
        if strength != 0 { lines.append((strength, formatStat("Siła", strength))) }
        if coins != 0 { lines.append((coins, formatStat("Monety", coins))) }
        if abilities != 0 { lines.append((abilities, formatStat("Zdolności", abilities))) }
        if boardMove != 0 { lines.append((boardMove, formatStat("Plansza", boardMove))) }
        if blockRounds != 0 { lines.append((blockRounds, "Blokada: \(blockRounds) r.")) }
        if health != 0 { lines.append((health, formatStat("Zdrowie", health))) }
        if mana != 0 { lines.append((mana, formatStat("Mana", mana))) }
        return lines
    }

    private func formatStat(_ name: String, _ value: Int) -> String {
        value > 0 ? "\(name): +\(value)" : "\(name): \(value)"
    }

    func mechanicalNegativeDetails(impliedItemLoss: Bool = false) -> [String] {
        var lines: [String] = []
        if coins < 0 { lines.append("Zmniejszenie funduszy o \(abs(coins)) monet") }
        if boardMove < 0 { lines.append("Cofnięcie na planszy o \(abs(boardMove)) pól") }
        if strength < 0 { lines.append("Osłabienie siły o \(abs(strength)) punktów") }
        if health < 0 { lines.append("Utrata zdrowia: \(abs(health)) punktów") }
        if abilities < 0 { lines.append("Osłabienie zdolności o \(abs(abilities)) punktów") }
        if blockRounds > 0 { lines.append("Blokada akcji na \(blockRounds) tur") }
        if mana < 0 { lines.append("Utrata many: \(abs(mana)) punktów") }
        if impliedItemLoss { lines.append("Utrata losowego przedmiotu z ekwipunku") }
        return lines
    }

    func mechanicalPositiveDetails(impliedItemGain: Bool = false) -> [String] {
        var lines: [String] = []
        if coins > 0 { lines.append("Wzrost funduszy o \(coins) monet") }
        if boardMove > 0 { lines.append("Ruch do przodu na planszy o \(boardMove) pól") }
        if strength > 0 { lines.append("Wzmocnienie siły o \(strength) punktów") }
        if health > 0 { lines.append("Odzyskanie zdrowia: +\(health) punktów") }
        if abilities > 0 { lines.append("Wzrost zdolności o \(abilities) punktów") }
        if mana > 0 { lines.append("Przyrost many: +\(mana) punktów") }
        if impliedItemGain { lines.append("Szansa na nowy przedmiot w ekwipunku") }
        return lines
    }

    /// Łączy jawne [SKUTKI] z wnioskowanymi z tekstu [WADA]/[ZALETA] — każda wada ma mieć realną stratę.
    static func resolved(
        explicit: CampaignChoiceEffects,
        disadvantage: String,
        advantage: String
    ) -> CampaignChoiceEffects {
        var result = explicit
        let trimmedDisadvantage = disadvantage.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmedDisadvantage.isEmpty {
            result.mergeDisadvantageInferred(inferredFromDisadvantage(trimmedDisadvantage))
            if result.mechanicalNegativeDetails().isEmpty {
                result.mergeDisadvantageInferred(defaultDisadvantagePenalty(for: trimmedDisadvantage))
            }
        }

        let trimmedAdvantage = advantage.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedAdvantage.isEmpty {
            result.mergeAdvantageInferred(inferredFromAdvantage(trimmedAdvantage))
        }

        return result
    }

    private mutating func mergeDisadvantageInferred(_ inferred: CampaignChoiceEffects) {
        if coins == 0, inferred.coins != 0 { coins = inferred.coins }
        if health == 0, inferred.health != 0 { health = inferred.health }
        if strength == 0, inferred.strength != 0 { strength = inferred.strength }
        if abilities == 0, inferred.abilities != 0 { abilities = inferred.abilities }
        if mana == 0, inferred.mana != 0 { mana = inferred.mana }
        if boardMove == 0, inferred.boardMove != 0 { boardMove = inferred.boardMove }
        if blockRounds == 0, inferred.blockRounds > 0 { blockRounds = inferred.blockRounds }
    }

    private mutating func mergeAdvantageInferred(_ inferred: CampaignChoiceEffects) {
        if coins == 0, inferred.coins > 0 { coins = inferred.coins }
        if health == 0, inferred.health > 0 { health = inferred.health }
        if strength == 0, inferred.strength > 0 { strength = inferred.strength }
        if abilities == 0, inferred.abilities > 0 { abilities = inferred.abilities }
        if mana == 0, inferred.mana > 0 { mana = inferred.mana }
        if boardMove == 0, inferred.boardMove > 0 { boardMove = inferred.boardMove }
    }

    private static func inferredFromDisadvantage(_ text: String) -> CampaignChoiceEffects {
        let lower = normalizeEffectText(text)
        var effects = CampaignChoiceEffects()

        if containsAny(lower, ["monet", "fundusz", "zloto", "złoto", "bogactw", "skarb", "koszt"]) {
            effects.coins = -parsedMagnitude(in: lower, default: 10)
        }
        if containsAny(lower, ["zdrow", "rana", "krwaw", "bol", "ból", "chorob", "trucizn", "oslab", "osłab"]) {
            effects.health = -parsedMagnitude(in: lower, default: 8)
        }
        if containsAny(lower, ["sila", "siła", "moc", "zmecz", "zmęcz", "wyczerp"]) {
            effects.strength = -parsedMagnitude(in: lower, default: 6)
        }
        if containsAny(lower, ["zdolnos", "zdolnoś", "pamiec", "pamięć", "amnez", "wiedz", "koncentr"]) {
            effects.abilities = -parsedMagnitude(in: lower, default: 8)
        }
        if containsAny(lower, ["mana", "magia", "zaklec", "zaklę"]) {
            effects.mana = -parsedMagnitude(in: lower, default: 6)
        }
        if containsAny(lower, ["plansz", "cofn", "wstecz", "retreat", "ucieczk"]) {
            effects.boardMove = -parsedMagnitude(in: lower, default: 2)
        }
        if containsAny(lower, ["blokad", "spowoln", "parali", "kolejk", "unieruchom", "zablok"]) {
            effects.blockRounds = max(1, parsedMagnitude(in: lower, default: 1))
        }
        if containsAny(lower, ["zaufan", "osamot", "samot", "izolac", "stres", "niepokoj", "strach", "leku", "lęk"]) {
            if effects.health == 0 { effects.health = -5 }
            if effects.abilities == 0 { effects.abilities = -4 }
        }

        applyExplicitLabeledNumbers(from: lower, into: &effects, negativeOnly: true)
        return effects
    }

    private static func inferredFromAdvantage(_ text: String) -> CampaignChoiceEffects {
        let lower = normalizeEffectText(text)
        var effects = CampaignChoiceEffects()

        if containsAny(lower, ["monet", "fundusz", "zloto", "złoto", "bogactw", "skarb"]) {
            effects.coins = parsedMagnitude(in: lower, default: 10)
        }
        if containsAny(lower, ["zdrow", "leczen", "uzdrow", "regener"]) {
            effects.health = parsedMagnitude(in: lower, default: 8)
        }
        if containsAny(lower, ["sila", "siła", "moc", "wzmoc"]) {
            effects.strength = parsedMagnitude(in: lower, default: 6)
        }
        if containsAny(lower, ["zdolnos", "zdolnoś", "umiejet", "umiejęt", "mistrz"]) {
            effects.abilities = parsedMagnitude(in: lower, default: 8)
        }
        if containsAny(lower, ["mana", "magia"]) {
            effects.mana = parsedMagnitude(in: lower, default: 6)
        }
        if containsAny(lower, ["plansz", "przod", "naprzod", "naprzód"]) {
            effects.boardMove = parsedMagnitude(in: lower, default: 2)
        }

        applyExplicitLabeledNumbers(from: lower, into: &effects, negativeOnly: false)
        return effects
    }

    private static func defaultDisadvantagePenalty(for text: String) -> CampaignChoiceEffects {
        var effects = CampaignChoiceEffects()
        effects.coins = -5
        effects.health = -4
        _ = text
        return effects
    }

    private static func normalizeEffectText(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pl_PL"))
            .lowercased()
    }

    private static func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0) }
    }

    private static func parsedMagnitude(in text: String, default defaultValue: Int) -> Int {
        let pattern = /[+-]?\d{1,3}/
        if let match = text.firstMatch(of: pattern), let value = Int(match.output) {
            return min(30, max(1, abs(value)))
        }
        return defaultValue
    }

    private static func applyExplicitLabeledNumbers(
        from text: String,
        into effects: inout CampaignChoiceEffects,
        negativeOnly: Bool
    ) {
        let rules: [(needles: [String], keyPath: WritableKeyPath<CampaignChoiceEffects, Int>)] = [
            (["monet", "fundusz"], \.coins),
            (["zdrow"], \.health),
            (["sila", "siła"], \.strength),
            (["zdolnos", "zdolnoś"], \.abilities),
            (["mana"], \.mana),
            (["plansz"], \.boardMove),
        ]

        for rule in rules {
            guard let value = labeledValue(in: text, labels: rule.needles) else { continue }
            if negativeOnly, value > 0 {
                effects[keyPath: rule.keyPath] = -value
            } else if !negativeOnly, value > 0 {
                effects[keyPath: rule.keyPath] = value
            } else if value < 0 {
                effects[keyPath: rule.keyPath] = value
            }
        }
    }

    private static func labeledValue(in text: String, labels: [String]) -> Int? {
        for label in labels where text.contains(label) {
            let start = text.range(of: label)?.lowerBound ?? text.startIndex
            let window = text[start...].prefix(36)
            let pattern = /[+-]?\d{1,3}/
            guard let match = window.firstMatch(of: pattern), let value = Int(match.output) else { continue }
            return value
        }
        return nil
    }
}

struct ChoiceEffectEntry: Equatable, Identifiable {
    let id = UUID()
    let title: String
    let detail: String
}

struct ChoiceEffectsPresentation: Equatable {
    let choiceTitle: String
    let negativeEntries: [ChoiceEffectEntry]
    let positiveEntries: [ChoiceEffectEntry]

    static func impliesItemLoss(from text: String) -> Bool {
        let lower = text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pl_PL"))
            .lowercased()
        let keywords = ["przedmiot", "ekwipunek", "bagaz", "utrata", "kradzie", "tracisz", "odebr", "zgub"]
        return keywords.contains { lower.contains($0) }
    }

    static func impliesItemGain(from text: String) -> Bool {
        let lower = text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pl_PL"))
            .lowercased()
        let keywords = ["przedmiot", "ekwipunek", "skarb", "lup", "zdobywasz", "znajdujesz"]
        return keywords.contains { lower.contains($0) }
    }

    static func from(choice: CampaignChoice?, fallbackLabel: String) -> ChoiceEffectsPresentation {
        guard let choice else {
            return ChoiceEffectsPresentation(
                choiceTitle: fallbackLabel,
                negativeEntries: [],
                positiveEntries: [
                    ChoiceEffectEntry(title: "Przejście przez start", detail: "+\(StartFieldRewards.passCoins) monet")
                ]
            )
        }

        let resolvedEffects = CampaignChoiceEffects.resolved(
            explicit: choice.effects,
            disadvantage: choice.disadvantage,
            advantage: choice.advantage
        )

        let itemLoss = impliesItemLoss(from: choice.disadvantage)
        let itemGain = impliesItemGain(from: choice.advantage)

        let disadvantageTitle = choice.disadvantage.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayDisadvantageTitle = disadvantageTitle.isEmpty ? "Wada decyzji" : disadvantageTitle

        var negativeEntries = buildEntries(
            title: displayDisadvantageTitle,
            mechanicalDetails: resolvedEffects.mechanicalNegativeDetails(impliedItemLoss: itemLoss)
        )

        var positiveEntries = buildEntries(
            title: choice.advantage,
            mechanicalDetails: resolvedEffects.mechanicalPositiveDetails(impliedItemGain: itemGain)
        )
        positiveEntries.append(
            ChoiceEffectEntry(title: "Przejście przez start", detail: "+\(StartFieldRewards.passCoins) monet")
        )

        if negativeEntries.isEmpty {
            let fallbackEffects = CampaignChoiceEffects.resolved(
                explicit: choice.effects,
                disadvantage: displayDisadvantageTitle,
                advantage: ""
            )
            negativeEntries = buildEntries(
                title: displayDisadvantageTitle,
                mechanicalDetails: fallbackEffects.mechanicalNegativeDetails(impliedItemLoss: itemLoss)
            )
        }

        return ChoiceEffectsPresentation(
            choiceTitle: choice.text.isEmpty ? fallbackLabel : choice.text,
            negativeEntries: negativeEntries,
            positiveEntries: positiveEntries
        )
    }

    private static func buildEntries(
        title: String,
        mechanicalDetails: [String]
    ) -> [ChoiceEffectEntry] {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayTitle = trimmedTitle.isEmpty ? "Skutek" : trimmedTitle

        return mechanicalDetails.map { detail in
            ChoiceEffectEntry(title: displayTitle, detail: detail)
        }
    }
}

struct CampaignChoice: Codable, Hashable {
    var text: String
    var advantage: String
    var disadvantage: String
    var effects: CampaignChoiceEffects
    /// Tag następnej sceny, np. „2A”, „3B”, „4C” — z [NASTĘPNA_SCENA: …].
    var nextSceneTag: String

    init(
        text: String,
        advantage: String = "",
        disadvantage: String = "",
        effects: CampaignChoiceEffects = CampaignChoiceEffects(),
        nextSceneTag: String = ""
    ) {
        self.text = text
        self.advantage = advantage
        self.disadvantage = disadvantage
        self.effects = effects
        self.nextSceneTag = nextSceneTag
    }

    enum CodingKeys: String, CodingKey {
        case text, advantage, disadvantage, effects, nextSceneTag
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decode(String.self, forKey: .text)
        advantage = try container.decodeIfPresent(String.self, forKey: .advantage) ?? ""
        disadvantage = try container.decodeIfPresent(String.self, forKey: .disadvantage) ?? ""
        effects = try container.decodeIfPresent(CampaignChoiceEffects.self, forKey: .effects) ?? CampaignChoiceEffects()
        nextSceneTag = try container.decodeIfPresent(String.self, forKey: .nextSceneTag) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(text, forKey: .text)
        try container.encode(advantage, forKey: .advantage)
        try container.encode(disadvantage, forKey: .disadvantage)
        try container.encode(effects, forKey: .effects)
        try container.encode(nextSceneTag, forKey: .nextSceneTag)
    }

    /// Krótka etykieta na przyciskach wyboru (bez zalet i wad).
    var buttonLabel: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var displayText: String {
        var parts = [buttonLabel]
        if !advantage.isEmpty { parts.append("Zaleta: \(advantage)") }
        if !disadvantage.isEmpty { parts.append("Wada: \(disadvantage)") }
        return parts.joined(separator: " · ")
    }

    /// Skutki do naliczenia w grze (jawne + wnioskowane z opisów wady/zalety).
    var resolvedEffects: CampaignChoiceEffects {
        CampaignChoiceEffects.resolved(
            explicit: effects,
            disadvantage: disadvantage,
            advantage: advantage
        )
    }
}

struct CampaignDecision: Identifiable, Hashable, Codable {
    let id: UUID
    var sceneTitle: String
    var question: String
    var alternatives: [String]
    var choicesByPlayer: [[String]]
    var choiceDetailsByPlayer: [[CampaignChoice]]

    init(
        id: UUID = UUID(),
        sceneTitle: String,
        question: String,
        alternatives: [String],
        choicesByPlayer: [[String]] = [],
        choiceDetailsByPlayer: [[CampaignChoice]] = []
    ) {
        self.id = id
        self.sceneTitle = sceneTitle
        self.question = question
        self.alternatives = alternatives
        self.choicesByPlayer = choicesByPlayer
        self.choiceDetailsByPlayer = choiceDetailsByPlayer
    }

    var playerCount: Int {
        max(choicesByPlayer.count, choiceDetailsByPlayer.count)
    }

    var totalChoiceCount: Int {
        if !choiceDetailsByPlayer.isEmpty {
            return choiceDetailsByPlayer.reduce(0) { $0 + $1.count }
        }
        return choicesByPlayer.reduce(0) { $0 + $1.count } + alternatives.count
    }

    func choiceTexts(forPlayerIndex playerIndex: Int) -> [String] {
        if choiceDetailsByPlayer.indices.contains(playerIndex), !choiceDetailsByPlayer[playerIndex].isEmpty {
            return choiceDetailsByPlayer[playerIndex].map(\.buttonLabel)
        }
        if choicesByPlayer.indices.contains(playerIndex), !choicesByPlayer[playerIndex].isEmpty {
            return choicesByPlayer[playerIndex]
        }
        return alternatives
    }

    func choiceDetail(forPlayerIndex playerIndex: Int, choiceIndex: Int) -> CampaignChoice? {
        guard choiceDetailsByPlayer.indices.contains(playerIndex),
              choiceDetailsByPlayer[playerIndex].indices.contains(choiceIndex)
        else { return nil }
        return choiceDetailsByPlayer[playerIndex][choiceIndex]
    }
}

struct ParsedCampaign: Hashable, Codable {
    var title: String
    var storyOutline: String
    var scenes: [CampaignScene]
    var decisions: [CampaignDecision]

    init(title: String, storyOutline: String = "", scenes: [CampaignScene] = [], decisions: [CampaignDecision]) {
        self.title = title
        self.storyOutline = storyOutline
        self.scenes = scenes
        self.decisions = decisions
    }

    var hasPlayableContent: Bool {
        !decisions.isEmpty || scenes.contains { !$0.narrative.isEmpty }
    }

    func scene(forDecisionIndex index: Int) -> CampaignScene? {
        guard !scenes.isEmpty else { return nil }
        let decision = decisions[safe: index]
        if let decision, let match = scenes.first(where: { Self.titlesMatch($0.title, decision.sceneTitle) }) {
            return match
        }
        return scenes[safe: index]
    }

    func decisionIndex(forSceneIndex sceneIndex: Int) -> Int? {
        guard let scene = scenes[safe: sceneIndex] else { return nil }

        if let idx = decisions.firstIndex(where: { Self.titlesMatch($0.sceneTitle, scene.title) }) {
            return idx
        }

        let sceneNumber = sceneIndex + 1
        if let idx = decisions.firstIndex(where: { Self.sceneNumber(from: $0.sceneTitle) == sceneNumber }) {
            return idx
        }

        return decisions.indices.contains(sceneIndex) ? sceneIndex : nil
    }

    func decision(forSceneIndex sceneIndex: Int) -> CampaignDecision? {
        guard let index = decisionIndex(forSceneIndex: sceneIndex) else { return nil }
        return decisions[safe: index]
    }

    func syncSceneIndex(_ sceneIdx: inout Int, decisionIdx: inout Int) {
        if let mapped = decisionIndex(forSceneIndex: sceneIdx) {
            decisionIdx = mapped
            return
        }
        if let scene = scene(forDecisionIndex: decisionIdx) {
            sceneIdx = scenes.firstIndex(where: { Self.titlesMatch($0.title, scene.title) }) ?? sceneIdx
        }
    }

    func sceneIndex(matchingDecisionIndex decisionIdx: Int) -> Int? {
        guard let scene = scene(forDecisionIndex: decisionIdx) else { return nil }
        return scenes.firstIndex(where: { Self.titlesMatch($0.title, scene.title) })
    }

    static func titlesMatch(_ lhs: String, _ rhs: String) -> Bool {
        normalizeTitle(lhs) == normalizeTitle(rhs)
    }

    static func normalizeTitle(_ text: String) -> String {
        text.lowercased()
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pl_PL"))
            .replacingOccurrences(of: " ", with: "")
    }

    private static func sceneNumber(from title: String) -> Int? {
        let pattern = "(?i)scena\\s*(\\d+)"
        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(in: title, range: NSRange(title.startIndex..., in: title)),
            match.numberOfRanges > 1,
            let range = Range(match.range(at: 1), in: title)
        else { return nil }
        return Int(title[range])
    }

    func choices(forPlayerIndex playerIndex: Int, decisionIndex: Int) -> [String] {
        guard let decision = decisions[safe: decisionIndex] else { return [] }
        return decision.choiceTexts(forPlayerIndex: playerIndex)
    }

    /// Krótkie etykiety wyborów (bez zalet i wad) — np. pole start.
    func choiceLabels(forPlayerIndex playerIndex: Int, decisionIndex: Int) -> [String] {
        guard let decision = decisions[safe: decisionIndex] else { return [] }
        let raw: [String]
        if decision.choiceDetailsByPlayer.indices.contains(playerIndex),
           !decision.choiceDetailsByPlayer[playerIndex].isEmpty {
            raw = decision.choiceDetailsByPlayer[playerIndex].map(\.buttonLabel)
        } else if decision.choicesByPlayer.indices.contains(playerIndex),
                  !decision.choicesByPlayer[playerIndex].isEmpty {
            raw = decision.choicesByPlayer[playerIndex]
        } else {
            raw = decision.alternatives
        }
        return Self.uniqueChoiceLabels(raw, limit: CampaignPromptBuilder.choicesPerPlayer)
    }

    func resolvedDecisionIndex(forSceneIndex sceneIndex: Int, fallback fallbackIndex: Int) -> Int {
        decisionIndex(forSceneIndex: sceneIndex) ?? fallbackIndex
    }

    static func uniqueChoiceLabels(_ labels: [String], limit: Int = CampaignPromptBuilder.choicesPerPlayer) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for label in labels {
            let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = normalizeChoiceLabelKey(trimmed)
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(trimmed)
            if result.count >= limit { break }
        }
        return result
    }

    static func normalizeChoiceLabelKey(_ text: String) -> String {
        text.lowercased()
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pl_PL"))
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static let decisionRoundCount = 3
    static let branchLetters = ["A", "B", "C", "D"]

    var sharedStartSceneIndex: Int {
        if let tagged = scenes.firstIndex(where: { Self.normalizeSceneTag($0.sceneTag) == "1" }) {
            return tagged
        }
        return scenes.isEmpty ? 0 : 0
    }

    func sceneIndex(forTag tag: String) -> Int? {
        let normalized = Self.normalizeSceneTag(tag)
        guard !normalized.isEmpty else { return nil }
        if let idx = scenes.firstIndex(where: { Self.normalizeSceneTag($0.sceneTag) == normalized }) {
            return idx
        }
        let stripped = normalized
            .replacingOccurrences(of: "SCENA", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespaces)
        if let idx = scenes.firstIndex(where: { Self.normalizeSceneTag($0.sceneTag) == stripped }) {
            return idx
        }
        return scenes.firstIndex(where: { Self.titlesMatch($0.title, tag) })
    }

    static func defaultBranchSceneTag(decisionRound: Int, choiceIndex: Int) -> String {
        let letter = branchLetters[min(max(choiceIndex, 0), branchLetters.count - 1)]
        return "\(decisionRound + 2)\(letter)"
    }

    func resolveNextSceneIndex(
        choice: CampaignChoice,
        decisionRound: Int,
        choiceIndex: Int
    ) -> Int? {
        let tag = choice.nextSceneTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tag.isEmpty, let index = sceneIndex(forTag: tag) {
            return index
        }
        let fallback = Self.defaultBranchSceneTag(decisionRound: decisionRound, choiceIndex: choiceIndex)
        return sceneIndex(forTag: fallback) ?? sceneIndex(forTag: "SCENA \(fallback)")
    }

    static func normalizeSceneTag(_ raw: String) -> String {
        var value = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pl_PL"))

        value = value.replacingOccurrences(of: "SCENA", with: "")
        value = value.replacingOccurrences(of: "FINALE", with: "4")
        value = value.replacingOccurrences(of: " ", with: "")
        return value
    }

    func isAtFinalDecisionRound(_ decisionRound: Int) -> Bool {
        guard !decisions.isEmpty else { return false }
        return decisionRound >= min(Self.decisionRoundCount, decisions.count) - 1
    }
}

enum CampaignPromptBuilder {
    static let playerCount = 4
    static let choicesPerPlayer = 4
    static let decisionRoundCount = 3

    static func makePrompt(climate: CampaignClimate) -> String {
        """
        Jesteś autorem kampanii fabularnej do gry RPG na telefonie dla \(playerCount) graczy. \
        Stwórz kompletną kampanię po polsku w klimacie: \(climate.title).

        Opis klimatu:
        \(climate.description)

        ═══════════════════════════════════════
        NOWY MODEL FABULARNY — ROZGAŁĘZIENIA
        ═══════════════════════════════════════

        Wszyscy gracze zaczynają od TEJ SAMEJ sceny 1. \
        Każdy wybór w decyzji prowadzi danego gracza do INNEJ, osobnej sceny (osobna ścieżka fabularna). \
        Po 3 decyzjach każdy gracz może mieć INNE zakończenie.

        Struktura gałęzi (obowiązkowa):
        - 1 wspólna scena startowa: [SCENA 1]
        - 4 warianty po decyzji 1: [SCENA 2A], [SCENA 2B], [SCENA 2C], [SCENA 2D]
        - 4 warianty po decyzji 2: [SCENA 3A], [SCENA 3B], [SCENA 3C], [SCENA 3D]
        - 4 finały po decyzji 3: [FINALE A], [FINALE B], [FINALE C], [FINALE D]

        Razem: 13 scen (1 + 4 + 4 + 4). Każda scena po starcie to OSOBNA gałąź — \
        nie łącz ścieżek z powrotem. Narracja każdej kolejnej sceny MUSI płynnie nawiązywać \
        do poprzedniej sceny TEGO gracza (1–2 zdania mostu na początku akapitu).

        Dokładnie \(decisionRoundCount) decyzje (nie więcej, nie mniej):
        * [DECYZJA 1 | SCENA 1] *
        * [DECYZJA 2] *
        * [DECYZJA 3] *

        Przy KAŻDYM wyborze (obowiązkowo):
        [NASTĘPNA_SCENA: 2A]  — tag następnej sceny dla tego wyboru (2A–2D po decyzji 1, 3A–3D po decyzji 2, 4A–4D po decyzji 3; finały jako 4A–4D lub FINALE A)
        [ZALETA: …]
        [WADA: …]
        [SKUTKI: SIŁA:±N | MONETY:±N | …]

        Wybór 1 gracza → zawsze [NASTĘPNA_SCENA: 2A], wybór 2 → 2B, wybór 3 → 2C, wybór 4 → 2D \
        (analogicznie 3A–3D i 4A–4D / FINALE A–D w kolejnych decyzjach).

        ═══════════════════════════════════════
        SYSTEM OZNACZEŃ (OBOWIĄZKOWY)
        ═══════════════════════════════════════

        >>ZARYG_FABULARNY<< … >>KONIEC_ZARYG_FABULARNY<<
        >>SCENY<< … >>KONIEC_SCEN<<
        >>DECYZJE<< … >>KONIEC_DECYZJI<<

        W decyzjach:
        >>PYTANIE<< … >>KONIEC_PYTANIA<<
        >>WYBORY_GRACZA_K<< … >>KONIEC_WYBOROW_GRACZA_K<<  (K = 1–4)

        ═══════════════════════════════════════
        CZĘŚĆ 0 — ZARYG (krótszy, 6–8 zdań)
        ═══════════════════════════════════════

        >>ZARYG_FABULARNY<<
        Konflikt, bohaterowie, antagonista, stawka, eskalacja do 3 decyzji i możliwych finałów.
        >>KONIEC_ZARYG_FABULARNY<<

        ═══════════════════════════════════════
        CZĘŚĆ I — SCENY (zwięzłe, 2–3 akapity na scenę)
        ═══════════════════════════════════════

        >>SCENY<<

        # TYTUŁ KAMPANII

        ## [SCENA 1] Tytuł — wspólny początek
        [2–3 akapity: wszyscy gracze tu startują]

        ## [SCENA 2A] Tytuł gałęzi A po decyzji 1
        [Most z poprzedniej sceny gracza + 2–3 akapity]

        ## [SCENA 2B] …
        ## [SCENA 2C] …
        ## [SCENA 2D] …

        ## [SCENA 3A] …
        ## [SCENA 3B] …
        ## [SCENA 3C] …
        ## [SCENA 3D] …

        ## [FINALE A] Zakończenie ścieżki A
        ## [FINALE B] …
        ## [FINALE C] …
        ## [FINALE D] …

        >>KONIEC_SCEN<<

        ═══════════════════════════════════════
        CZĘŚĆ II — DOKŁADNIE 3 DECYZJE
        ═══════════════════════════════════════

        >>DECYZJE<<

        * [DECYZJA 1 | SCENA 1] *
        >>PYTANIE<<
        Pytanie wynikające ze wspólnej sceny 1.
        >>KONIEC_PYTANIA<<
        >>WYBORY_GRACZA_1<<
        1) [akcja gracza 1]
           [NASTĘPNA_SCENA: 2A]
           [ZALETA: …] [WADA: …] [SKUTKI: …]
        2) [wybór 2]
           [NASTĘPNA_SCENA: 2B]
           …
        3) … [NASTĘPNA_SCENA: 2C]
        4) … [NASTĘPNA_SCENA: 2D]
        >>KONIEC_WYBOROW_GRACZA_1<<
        >>WYBORY_GRACZA_2<< … >>KONIEC_WYBOROW_GRACZA_2<<
        >>WYBORY_GRACZA_3<< … >>KONIEC_WYBOROW_GRACZA_3<<
        >>WYBORY_GRACZA_4<< … >>KONIEC_WYBOROW_GRACZA_4<<

        * [DECYZJA 2] *
        >>PYTANIE<<
        Jedno krótkie pytanie (1–2 zdania) o sytuację na scenie 2X — BEZ zalet, wad i skutków w tekście pytania.
        >>KONIEC_PYTANIA<<
        (dla KAŻDEGO gracza osobno: dokładnie \(choicesPerPlayer) NOWE wybory, inne niż w decyzji 1)

        * [DECYZJA 3] *
        >>PYTANIE<<
        Jedno krótkie pytanie finałowe (1–2 zdania) — BEZ zalet, wad i skutków w tekście pytania.
        >>KONIEC_PYTANIA<<
        (dla KAŻDEGO gracza: dokładnie \(choicesPerPlayer) NOWE wybory finałowe)

        >>KONIEC_DECYZJI<<

        ═══════════════════════════════════════
        ZASADY WYBORÓW (BARDZO WAŻNE)
        ═══════════════════════════════════════

        - W bloku >>PYTANIE<< tylko pytanie fabularne. Nigdy nie wklejaj tam [ZALETA], [WADA] ani [SKUTKI].
        - W linii z numerem wyboru (np. „1) …”) tylko krótka nazwa akcji (max ~12 słów). \
        Zalety, wady i skutki ZAWSZE w osobnych liniach pod wyborem.
        - W każdej decyzji podaj WYŁĄCZNIE wybory tej rundy — NIE powtarzaj wyborów z decyzji 1 ani 2.
        - Decyzje 2 i 3: zupełnie nowe akcje dopasowane do sceny gracza (2A–2D, 3A–3D, finał).
        - Dokładnie \(choicesPerPlayer) ponumerowane wybory (1–4) na gracza w każdej decyzji.

        ═══════════════════════════════════════
        ZASADY OGÓLNE
        ═══════════════════════════════════════

        - Dokładnie \(decisionRoundCount) bloki decyzji (* [DECYZJA N …] *).
        - Dokładnie 13 scen (1 + 4 + 4 + 4).
        - Każdy wybór MUSI mieć [NASTĘPNA_SCENA: …] z poprawnym tagiem gałęzi.
        - \(playerCount) graczy × \(choicesPerPlayer) wyborów na decyzję — perspektywa postaci gracza.
        - Sceny krótsze niż w starym formacie; jakość i spójność > długość.
        - Różne finały (A–D) muszą dawać odmienne zakończenia fabularne.
        - Bez komentarzy meta — tylko gotowa kampania w powyższym formacie.
        """
    }
}

enum CampaignParser {
    static func parse(_ text: String) -> ParsedCampaign {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ParsedCampaign(title: "Kampania bez tytułu", decisions: [])
        }

        let normalized = normalizeCampaignText(trimmed)
        let title = extractTitle(from: normalized) ?? "Kampania bez tytułu"
        let storyOutline = extractBlock(named: "ZARYG_FABULARNY", endName: "KONIEC_ZARYG_FABULARNY", from: normalized)
        let scenes = extractScenes(from: normalized)
        let decisionBlocks = splitDecisionBlocks(from: normalized)

        let cappedBlocks = Array(decisionBlocks.prefix(CampaignPromptBuilder.decisionRoundCount))

        let decisions = cappedBlocks.enumerated().map { index, block in
            let sceneTitle = resolveSceneTitle(for: block, decisionIndex: index, scenes: scenes)
            let question = extractQuestion(from: block)
            let choiceDetailsByPlayer = extractPlayerChoiceDetails(from: block)
            let choicesByPlayer = choiceDetailsByPlayer.map { $0.map(\.buttonLabel) }
            let alternatives = extractAlternatives(from: block)

            return CampaignDecision(
                sceneTitle: sceneTitle,
                question: question,
                alternatives: alternatives,
                choicesByPlayer: choicesByPlayer,
                choiceDetailsByPlayer: choiceDetailsByPlayer
            )
        }

        return ParsedCampaign(title: title, storyOutline: storyOutline, scenes: scenes, decisions: decisions)
    }

    // MARK: - Normalizacja tekstu z ChatGPT

    private static func normalizeCampaignText(_ text: String) -> String {
        var result = text
        result = stripCommentSlashesBeforeMarkers(in: result)
        result = normalizeDecisionHeaders(in: result)
        result = trimTrailingJunkAfterEndMarkers(in: result)

        let staticMarkers = [
            "ZARYG_FABULARNY", "KONIEC_ZARYG_FABULARNY",
            "SCENY", "KONIEC_SCEN",
            "DECYZJE", "KONIEC_DECYZJI",
            "PYTANIE", "KONIEC_PYTANIA",
        ]

        for marker in staticMarkers {
            result = canonicalizeMarker(marker, in: result)
        }

        for playerNumber in 1...8 {
            result = canonicalizeMarker("WYBORY_GRACZA_\(playerNumber)", in: result)
            result = canonicalizeMarker("KONIEC_WYBOROW_GRACZA_\(playerNumber)", in: result)
        }

        result = result.replacingOccurrences(of: "<<//", with: "<<")
        return result
    }

    /// Warianty z wklejki: //ZARYG_FABULARNY<<, //DECYZJE<<
    private static func stripCommentSlashesBeforeMarkers(in text: String) -> String {
        var result = text
        let markers = [
            "ZARYG_FABULARNY", "KONIEC_ZARYG_FABULARNY",
            "SCENY", "KONIEC_SCEN",
            "DECYZJE", "KONIEC_DECYZJI",
            "PYTANIE", "KONIEC_PYTANIA",
        ]
        for marker in markers {
            result = result.replacingOccurrences(of: "//\(marker)", with: marker, options: .caseInsensitive)
            result = result.replacingOccurrences(of: "//>>\(marker)", with: ">>\(marker)", options: .caseInsensitive)
        }
        for playerNumber in 1...8 {
            result = result.replacingOccurrences(
                of: "//WYBORY_GRACZA_\(playerNumber)",
                with: "WYBORY_GRACZA_\(playerNumber)",
                options: .caseInsensitive
            )
            result = result.replacingOccurrences(
                of: "//KONIEC_WYBOROW_GRACZA_\(playerNumber)",
                with: "KONIEC_WYBOROW_GRACZA_\(playerNumber)",
                options: .caseInsensitive
            )
        }
        return result
    }

    /// DECYZJA 2 | SCENA 2<< → * [DECYZJA 2 | SCENA 2] *
    private static func normalizeDecisionHeaders(in text: String) -> String {
        let pattern = """
        (?im)^\\s*(?:\\*\\s*)?(?:\\[\\s*)?DECYZJA\\s*(\\d+)\\s*\\|\\s*SCENA\\s*(\\d+)\\s*(?:\\]|\\*|<<|<<?)?\\s*\\*?\\s*$
        """
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let nsRange = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(
            in: text,
            range: nsRange,
            withTemplate: "* [DECYZJA $1 | SCENA $2] *"
        )
    }

    /// KONIEC_DECYZJI<<//komentarz użytkownika
    private static func trimTrailingJunkAfterEndMarkers(in text: String) -> String {
        let pattern = "(?im)(>>)?KONIEC_DECYZJI<<\\s*//[^\\n]*"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let nsRange = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(
            in: text,
            range: nsRange,
            withTemplate: ">>KONIEC_DECYZJI<<"
        )
    }

    /// Akceptuje warianty: >>MARKER<<, MARKER<<, >>MARKER, MARKER
    private static func canonicalizeMarker(_ name: String, in text: String) -> String {
        let escaped = NSRegularExpression.escapedPattern(for: name)
        let pattern = "(>>)?(\(escaped))(<<)?"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return text }

        let nsRange = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(
            in: text,
            range: nsRange,
            withTemplate: ">>\(name)<<"
        )
    }

    private static func extractBlock(named startName: String, endName: String, from text: String) -> String {
        extractMarkedBlock(from: text, start: ">>\(startName)<<", end: ">>\(endName)<<")
    }

    private static func extractMarkedBlock(from text: String, start: String, end: String) -> String {
        guard
            let startRange = text.range(of: start, options: .caseInsensitive),
            let endRange = text.range(of: end, options: .caseInsensitive, range: startRange.upperBound..<text.endIndex),
            startRange.upperBound < endRange.lowerBound
        else { return "" }

        return String(text[startRange.upperBound..<endRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func resolveSceneTitle(for block: String, decisionIndex: Int, scenes: [CampaignScene]) -> String {
        if let sceneNumber = extractSceneNumberFromDecision(block), sceneNumber > 0 {
            if scenes.indices.contains(sceneNumber - 1) {
                return scenes[sceneNumber - 1].title
            }
            return "Scena \(sceneNumber)"
        }
        return scenes[safe: decisionIndex]?.title ?? "Scena \(decisionIndex + 1)"
    }

    private static func extractSceneNumberFromDecision(_ text: String) -> Int? {
        let patterns = [
            "(?i)(?:\\*\\s*)?\\[\\s*DECYZJA\\s*\\d+\\s*\\|\\s*SCENA\\s*(\\d+)\\s*\\]",
            "(?i)DECYZJA\\s*\\d+\\s*\\|\\s*SCENA\\s*(\\d+)",
        ]
        for pattern in patterns {
            guard
                let regex = try? NSRegularExpression(pattern: pattern),
                let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                match.numberOfRanges > 1,
                let range = Range(match.range(at: 1), in: text),
                let number = Int(text[range])
            else { continue }
            return number
        }
        return nil
    }

    private static var decisionHeaderLineRegex: NSRegularExpression? {
        try? NSRegularExpression(
            pattern: "(?im)^\\s*\\*\\s*\\[\\s*DECYZJA\\s*\\d+(?:\\s*\\|\\s*SCENA\\s*\\d+)?\\s*\\]\\s*\\*\\s*$"
        )
    }

    private static func extractPartOne(from text: String) -> String {
        let scenesBlock = extractBlock(named: "SCENY", endName: "KONIEC_SCEN", from: text)
        if !scenesBlock.isEmpty {
            return scenesBlock
        }

        let lower = text.lowercased()
        let partTwoMarkers = [
            ">>decyzje<<", ">>koniec_scen<<", "## część ii", "## czesc ii",
            "### decyzja", "* [decyzja", "*[decyzja",
        ]
        var endIndex = text.endIndex

        for marker in partTwoMarkers {
            if let range = lower.range(of: marker) {
                endIndex = min(endIndex, range.lowerBound)
            }
        }

        var partOne = endIndex > text.startIndex ? String(text[..<endIndex]) : text

        for marker in ["## część i", "## czesc i", ">>sceny<<"] {
            if let range = partOne.lowercased().range(of: marker) {
                partOne = String(partOne[range.upperBound...])
            }
        }

        return partOne.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractScenes(from text: String) -> [CampaignScene] {
        let partOne = extractPartOne(from: text)
        guard !partOne.isEmpty else { return [] }

        let headerPattern = """
        (?im)^(?:##\\s*)?\\[(SCENA\\s*(\\d+)\\s*([A-D])?|FINALE\\s*([A-D]))\\]\\s*(.*)$
        """
        guard let regex = try? NSRegularExpression(pattern: headerPattern) else { return [] }

        let nsText = partOne as NSString
        let matches = regex.matches(in: partOne, range: NSRange(location: 0, length: nsText.length))
        guard !matches.isEmpty else { return [] }

        var scenes: [CampaignScene] = []

        for (index, match) in matches.enumerated() {
            let bodyStart = match.range.location + match.range.length
            let bodyEnd = index + 1 < matches.count
                ? matches[index + 1].range.location
                : nsText.length

            let bodyLength = max(0, bodyEnd - bodyStart)
            guard bodyLength > 0 else { continue }

            var sceneTag = ""
            var title = "Scena"

            if match.numberOfRanges > 4,
               let finaleRange = Range(match.range(at: 4), in: partOne),
               !partOne[finaleRange].isEmpty {
                let letter = String(partOne[finaleRange]).uppercased()
                sceneTag = "4\(letter)"
                title = "Finał \(letter)"
            } else if match.numberOfRanges > 2,
                      let numRange = Range(match.range(at: 2), in: partOne),
                      let num = Int(partOne[numRange]) {
                var letter = ""
                if match.numberOfRanges > 3,
                   let letterRange = Range(match.range(at: 3), in: partOne),
                   !partOne[letterRange].isEmpty {
                    letter = String(partOne[letterRange]).uppercased()
                }
                sceneTag = "\(num)\(letter)"
                title = letter.isEmpty ? "Scena \(num)" : "Scena \(num)\(letter)"
            }

            if match.numberOfRanges > 5,
               let titleRange = Range(match.range(at: 5), in: partOne) {
                let parsedTitle = String(partOne[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !parsedTitle.isEmpty { title = parsedTitle }
            }

            let body = nsText
                .substring(with: NSRange(location: bodyStart, length: bodyLength))
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !body.isEmpty else { continue }
            scenes.append(CampaignScene(title: title, narrative: body, sceneTag: sceneTag))
        }

        return scenes
    }

    private static func extractTitle(from text: String) -> String? {
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("# ") {
                return trimmed.dropFirst(2).trimmingCharacters(in: .whitespaces)
            }
        }

        let scenesBlock = extractBlock(named: "SCENY", endName: "KONIEC_SCEN", from: text)
        if !scenesBlock.isEmpty {
            let sceneHeader = try? NSRegularExpression(pattern: "(?im)^(?:##\\s*)?\\[SCENA\\s*\\d+\\]", options: [])
            for line in scenesBlock.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty { continue }
                if trimmed.hasPrefix(">>") { continue }
                if let sceneHeader,
                   sceneHeader.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil {
                    break
                }
                if trimmed.count >= 3, !trimmed.hasPrefix("[") {
                    return trimmed
                }
            }
        }

        let storyOutline = extractBlock(named: "ZARYG_FABULARNY", endName: "KONIEC_ZARYG_FABULARNY", from: text)
        if !storyOutline.isEmpty {
            let firstSentence = storyOutline.components(separatedBy: CharacterSet(charactersIn: ".!?")).first?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if firstSentence.count >= 12, firstSentence.count <= 80 {
                return firstSentence
            }
        }

        return nil
    }

    private static func splitDecisionBlocks(from text: String) -> [String] {
        let decisionsSection = extractBlock(named: "DECYZJE", endName: "KONIEC_DECYZJI", from: text)
        let searchText = decisionsSection.isEmpty ? text : decisionsSection

        let lineBlocks = splitDecisionBlocksByLines(from: searchText)
        if !lineBlocks.isEmpty {
            return lineBlocks
        }

        return splitDecisionBlocksByRegex(from: searchText)
    }

    private static func splitDecisionBlocksByLines(from text: String) -> [String] {
        guard let headerRegex = decisionHeaderLineRegex else { return [] }

        var blocks: [String] = []
        var currentLines: [String] = []

        func flush() {
            let block = currentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !block.isEmpty {
                blocks.append(block)
            }
            currentLines = []
        }

        for line in text.components(separatedBy: .newlines) {
            let probe = line + "\n"
            if headerRegex.firstMatch(in: probe, range: NSRange(probe.startIndex..., in: probe)) != nil {
                flush()
                currentLines = [line]
            } else if !currentLines.isEmpty {
                currentLines.append(line)
            }
        }

        flush()
        return blocks
    }

    private static func splitDecisionBlocksByRegex(from text: String) -> [String] {
        let patterns = [
            "(?im)^\\s*\\*\\s*\\[\\s*DECYZJA\\s*\\d+",
            "(?im)^\\s*\\[\\s*DECYZJA\\s*\\d+\\s*\\|",
            "(?im)^\\s*DECYZJA\\s*\\d+\\s*\\|\\s*SCENA",
            "(?im)^\\s*###\\s*Decyzja",
        ]

        var allMatches: [(location: Int, length: Int)] = []
        let nsText = text as NSString

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            for match in regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)) {
                allMatches.append((match.range.location, match.range.length))
            }
        }

        allMatches.sort { $0.location < $1.location }

        var uniqueMatches: [(location: Int, length: Int)] = []
        for match in allMatches {
            if let last = uniqueMatches.last, last.location == match.location {
                continue
            }
            uniqueMatches.append(match)
        }

        guard !uniqueMatches.isEmpty else { return [] }

        var blocks: [String] = []
        for (index, match) in uniqueMatches.enumerated() {
            let blockStart = match.location
            let end = index + 1 < uniqueMatches.count ? uniqueMatches[index + 1].location : nsText.length
            let length = max(0, end - blockStart)
            guard length > 0 else { continue }
            let block = nsText.substring(with: NSRange(location: blockStart, length: length))
            blocks.append(block.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return blocks
    }

    private static func extractQuestion(from block: String) -> String {
        let marked = extractBlock(named: "PYTANIE", endName: "KONIEC_PYTANIA", from: block)
        if !marked.isEmpty { return marked }

        let lines = block.components(separatedBy: .newlines)
        var questionLines: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            if isChoiceMetadataLine(trimmed) { break }
            let lower = trimmed.lowercased()
            if lower.hasPrefix("alternatywy") { break }
            if lower.hasPrefix("gracz ") { break }
            if lower.contains("wybory_gracza") { break }
            if lower.hasPrefix("decyzje dla gracza") { break }
            if isAlternativeLine(trimmed) { break }
            if isNumberedChoiceLine(trimmed) { break }
            if trimmed.hasPrefix("*") { continue }
            if trimmed.hasPrefix(">>") { continue }
            questionLines.append(trimmed)
        }

        return questionLines.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractPlayerChoiceDetails(from block: String) -> [[CampaignChoice]] {
        if block.range(of: "WYBORY_GRACZA_", options: .caseInsensitive) != nil {
            return extractMarkedPlayerChoiceDetails(from: block)
        }
        return extractLegacyPlayerChoiceDetails(from: block)
    }

    private static func extractMarkedPlayerChoiceDetails(from block: String) -> [[CampaignChoice]] {
        var result: [[CampaignChoice]] = []

        for playerNumber in 1...8 {
            let playerBlock = extractBlock(
                named: "WYBORY_GRACZA_\(playerNumber)",
                endName: "KONIEC_WYBOROW_GRACZA_\(playerNumber)",
                from: block
            )
            guard !playerBlock.isEmpty else { continue }
            let choices = dedupedChoices(parseChoiceEntries(from: playerBlock))
            if !choices.isEmpty {
                result.append(choices)
            }
        }

        return result
    }

    private static func dedupedChoices(_ choices: [CampaignChoice]) -> [CampaignChoice] {
        var seen = Set<String>()
        var result: [CampaignChoice] = []
        for choice in choices {
            let key = ParsedCampaign.normalizeChoiceLabelKey(choice.buttonLabel)
            guard !key.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(choice)
            if result.count >= CampaignPromptBuilder.choicesPerPlayer { break }
        }
        return result
    }

    private static func extractLegacyPlayerChoiceDetails(from block: String) -> [[CampaignChoice]] {
        let lines = block.components(separatedBy: .newlines)
        var result: [[CampaignChoice]] = []
        var currentLines: [String] = []

        func flushPlayer() {
            guard !currentLines.isEmpty else { return }
            let choices = dedupedChoices(parseChoiceEntries(from: currentLines.joined(separator: "\n")))
            if !choices.isEmpty {
                result.append(choices)
            }
            currentLines = []
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            if parsePlayerHeader(trimmed) != nil {
                flushPlayer()
                continue
            }

            if trimmed.lowercased().hasPrefix("decyzje dla gracza") {
                flushPlayer()
                continue
            }

            currentLines.append(trimmed)
        }

        flushPlayer()
        return result
    }

    private static func parseChoiceEntries(from text: String) -> [CampaignChoice] {
        let lines = text.components(separatedBy: .newlines)
        var choices: [CampaignChoice] = []
        var currentText = ""
        var currentAdvantage = ""
        var currentDisadvantage = ""
        var currentEffects = CampaignChoiceEffects()

        var currentNextSceneTag = ""

        func flushChoice() {
            let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            choices.append(
                CampaignChoice(
                    text: stripInlineTags(from: trimmed),
                    advantage: currentAdvantage,
                    disadvantage: currentDisadvantage,
                    effects: currentEffects,
                    nextSceneTag: currentNextSceneTag
                )
            )
            currentText = ""
            currentAdvantage = ""
            currentDisadvantage = ""
            currentEffects = CampaignChoiceEffects()
            currentNextSceneTag = ""
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            let lower = trimmed.lowercased()
            if lower.hasPrefix("decyzje dla gracza") { continue }

            if let nextScene = extractNextSceneTag(from: trimmed) {
                currentNextSceneTag = nextScene
                continue
            }

            if isNumberedChoiceLine(trimmed) {
                flushChoice()
                let parsed = parseTaggedChoiceLine(trimmed)
                currentText = parsed.text
                currentAdvantage = parsed.advantage
                currentDisadvantage = parsed.disadvantage
                currentEffects = parsed.effects
                if !parsed.nextSceneTag.isEmpty {
                    currentNextSceneTag = parsed.nextSceneTag
                }
                continue
            }

            if let advantage = extractTag("ZALETA", from: trimmed) {
                currentAdvantage = advantage
                continue
            }
            if let disadvantage = extractTag("WADA", from: trimmed) {
                currentDisadvantage = disadvantage
                continue
            }
            if trimmed.uppercased().contains("[SKUTKI:") {
                currentEffects = parseEffects(from: trimmed)
                continue
            }

            if isChoiceMetadataLine(trimmed) { continue }

            if currentText.isEmpty {
                currentText = trimmed
            } else {
                currentText += " " + trimmed
            }
        }

        flushChoice()
        return dedupedChoices(choices)
    }

    private static func isChoiceMetadataLine(_ line: String) -> Bool {
        let upper = line.uppercased()
        if upper.contains("[ZALETA") || upper.contains("[WADA") || upper.contains("[SKUTKI") { return true }
        if upper.contains("[NASTĘPNA_SCENA") || upper.contains("[NASTEPNA_SCENA") { return true }
        if upper.contains(">>KONIEC_WYBOROW") || upper.contains(">>WYBORY_GRACZA") { return true }
        return false
    }

    private static func parseTaggedChoiceLine(_ line: String) -> (
        text: String,
        advantage: String,
        disadvantage: String,
        effects: CampaignChoiceEffects,
        nextSceneTag: String
    ) {
        var working = stripNumberedPrefix(from: line) ?? line
        let advantage = extractTag("ZALETA", from: working) ?? ""
        let disadvantage = extractTag("WADA", from: working) ?? ""
        let nextSceneTag = extractNextSceneTag(from: working) ?? ""
        let effects = parseEffects(from: working)
        working = stripInlineTags(from: working)
        return (working, advantage, disadvantage, effects, nextSceneTag)
    }

    private static func extractNextSceneTag(from line: String) -> String? {
        if let tagged = extractTag("NASTĘPNA_SCENA", from: line) ?? extractTag("NASTEPNA_SCENA", from: line) {
            return tagged
        }
        return nil
    }

    private static func extractTag(_ name: String, from line: String) -> String? {
        let pattern = "\\[\(name)\\s*:\\s*([^\\]]+)\\]"
        guard
            let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
            let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
            match.numberOfRanges > 1,
            let range = Range(match.range(at: 1), in: line)
        else { return nil }

        let value = String(line[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private static func stripInlineTags(from line: String) -> String {
        var result = line
        let patterns = [
            "\\[ZALETA\\s*:[^\\]]+\\]",
            "\\[WADA\\s*:[^\\]]+\\]",
            "\\[SKUTKI\\s*:[^\\]]+\\]",
            "\\[NASTĘPNA_SCENA\\s*:[^\\]]+\\]",
            "\\[NASTEPNA_SCENA\\s*:[^\\]]+\\]",
        ]
        for pattern in patterns {
            result = result.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parseEffects(from line: String) -> CampaignChoiceEffects {
        guard let skutki = extractTag("SKUTKI", from: line.uppercased().contains("[SKUTKI") ? line : "[SKUTKI: \(line)]") else {
            if line.uppercased().contains("[SKUTKI:") {
                let start = line.uppercased().range(of: "[SKUTKI:")
                if let start {
                    let fragment = String(line[start.lowerBound...])
                    return parseEffectsFragment(fragment)
                }
            }
            return CampaignChoiceEffects()
        }
        return parseEffectsFragment(skutki)
    }

    private static func parseEffectsFragment(_ fragment: String) -> CampaignChoiceEffects {
        var effects = CampaignChoiceEffects()
        let pairs = fragment
            .replacingOccurrences(of: "[SKUTKI:", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "]", with: "")
            .split(separator: "|")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        for pair in pairs {
            let normalized = pair
                .replacingOccurrences(of: "SIŁA", with: "SILA", options: .caseInsensitive)
                .replacingOccurrences(of: "ZDOLNOŚCI", with: "ZDOLNOSCI", options: .caseInsensitive)
                .uppercased()

            if normalized.hasPrefix("SILA:") || normalized.hasPrefix("SIŁA:") {
                effects.strength = parseSignedInt(from: normalized)
            } else if normalized.hasPrefix("MONETY:") {
                effects.coins = parseSignedInt(from: normalized)
            } else if normalized.hasPrefix("ZDOLNOSCI:") {
                effects.abilities = parseSignedInt(from: normalized)
            } else if normalized.hasPrefix("PLANSZA:") {
                effects.boardMove = parseSignedInt(from: normalized)
            } else if normalized.hasPrefix("BLOKADA:") {
                effects.blockRounds = parseSignedInt(from: normalized)
            } else if normalized.hasPrefix("ZDROWIE:") {
                effects.health = parseSignedInt(from: normalized)
            } else if normalized.hasPrefix("MANA:") {
                effects.mana = parseSignedInt(from: normalized)
            }
        }

        return effects
    }

    private static func parseSignedInt(from token: String) -> Int {
        let parts = token.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return 0 }
        let value = parts[1]
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "r", with: "", options: .caseInsensitive)
        return Int(value) ?? 0
    }

    private static func extractPlayerChoices(from block: String) -> [[String]] {
        extractPlayerChoiceDetails(from: block).map { $0.map(\.buttonLabel) }
    }

    private static func parsePlayerHeader(_ line: String) -> Int? {
        let patterns = [
            "^Gracz\\s*(\\d+)\\s*:?\\s*$",
            "^Decyzje\\s+dla\\s+gracza\\s*(\\d+)\\s*:?\\s*$",
        ]
        for pattern in patterns {
            guard
                let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                match.numberOfRanges > 1,
                let range = Range(match.range(at: 1), in: line)
            else { continue }
            return Int(line[range])
        }
        return nil
    }

    private static func extractAlternatives(from block: String) -> [String] {
        block
            .components(separatedBy: .newlines)
            .compactMap { line -> String? in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if isNumberedChoiceLine(trimmed) {
                    return stripNumberedPrefix(from: trimmed)
                }
                guard isAlternativeLine(trimmed) else { return nil }
                return stripAlternativePrefix(from: trimmed)
            }
    }

    private static func isNumberedChoiceLine(_ line: String) -> Bool {
        line.range(of: "^\\d+[.)\\]:-]\\s*.+", options: .regularExpression) != nil
    }

    private static func stripNumberedPrefix(from line: String) -> String? {
        guard let match = line.range(of: "^\\d+[.)\\]:-]\\s*", options: .regularExpression) else {
            return line
        }
        let value = String(line[match.upperBound...]).trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }

    private static func isAlternativeLine(_ line: String) -> Bool {
        guard let first = line.first, first.isLetter else { return false }
        let pattern = "^[A-Za-z][\\).:-]\\s*.+"
        return line.range(of: pattern, options: .regularExpression) != nil
    }

    private static func stripAlternativePrefix(from line: String) -> String {
        guard let match = line.range(of: "^[A-Za-z][\\).:-]\\s*", options: .regularExpression) else {
            return line
        }
        return String(line[match.upperBound...]).trimmingCharacters(in: .whitespaces)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
