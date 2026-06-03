//
//  MasterAlgorithmEngine.swift
//  DmdApp
//
//  Algorytm Mistrza — deterministyczny silnik pamięci fabuły i dopasowania wyborów.
//

import Foundation
import Observation

struct MasterChoiceRecommendation: Hashable {
    let choiceIndex: Int
    let choiceText: String
    let score: Int
    let confidencePercent: Int
    let matchedTraits: [String]
}

struct MasterAlgorithmIndex: Codable {
    let campaignTitle: String
    let campaignFingerprint: String
    let builtAt: Date
    var storyOutline: String
    var scenes: [IndexedScene]
    var decisions: [IndexedDecision]
    var vocabularySize: Int
    var indexByteEstimate: Int

    struct IndexedScene: Codable {
        let index: Int
        let title: String
        let narrative: String
        let keywords: [String]
        let bigrams: [String]
    }

    struct IndexedDecision: Codable {
        let index: Int
        let sceneTitle: String
        let question: String
        let keywords: [String]
        var playerChoices: [IndexedPlayerChoices]
    }

    struct IndexedPlayerChoices: Codable {
        let playerSlot: Int
        var choices: [IndexedChoice]
    }

    struct IndexedChoice: Codable {
        let index: Int
        let text: String
        let advantage: String
        let disadvantage: String
        let effects: CampaignChoiceEffects
        let keywords: [String]
        let bigrams: [String]
        let effectTokens: [String]
        let fingerprint: String
    }
}

@MainActor
@Observable
final class MasterAlgorithmEngine {
    private(set) var index: MasterAlgorithmIndex?
    private(set) var lastBuildSummary = ""
    private(set) var isReady = false
    private(set) var isBuilding = false

    var indexSizeLabel: String {
        guard let index else { return "Indeks niezbudowany" }
        return ByteCountFormatter.string(fromByteCount: Int64(index.indexByteEstimate), countStyle: .file)
    }

    func loadOrBuildIndex(for campaign: ParsedCampaign) {
        let fingerprint = campaign.fingerprint

        if let cached = MasterIndexPersistence.load(fingerprint: fingerprint), cached.campaignTitle == campaign.title {
            index = cached
            isReady = true
            lastBuildSummary = "Wczytano indeks (\(cached.vocabularySize) słów kluczowych, \(ByteCountFormatter.string(fromByteCount: Int64(cached.indexByteEstimate), countStyle: .file)))."
            return
        }

        Task {
            await buildIndex(for: campaign)
        }
    }

    func buildIndex(for campaign: ParsedCampaign) async {
        guard !isBuilding else { return }

        let fingerprint = campaign.fingerprint
        if let cached = MasterIndexPersistence.load(fingerprint: fingerprint), cached.campaignTitle == campaign.title {
            index = cached
            isReady = true
            lastBuildSummary = "Wczytano indeks (\(cached.vocabularySize) słów kluczowych)."
            return
        }

        isBuilding = true
        defer { isBuilding = false }

        let built = await Task.detached(priority: .utility) {
            MasterIndexBuilder.build(from: campaign, fingerprint: fingerprint)
        }.value

        guard let built else {
            lastBuildSummary = "Nie udało się zbudować indeksu kampanii."
            isReady = false
            return
        }

        index = built.index
        isReady = true
        lastBuildSummary = built.summary

        if let data = built.encodedData {
            await Task.detached(priority: .utility) {
                MasterIndexPersistence.save(data, fingerprint: fingerprint)
            }.value
        }
    }

    /// Synchroniczna wersja tylko dla małych kampanii testowych — preferuj `buildIndex(for:) async`.
    func buildIndexSynchronously(for campaign: ParsedCampaign) {
        guard let built = MasterIndexBuilder.build(from: campaign, fingerprint: campaign.fingerprint) else {
            lastBuildSummary = "Nie udało się zbudować indeksu kampanii."
            isReady = false
            return
        }
        index = built.index
        isReady = true
        lastBuildSummary = built.summary
        if let data = built.encodedData {
            MasterIndexPersistence.save(data, fingerprint: campaign.fingerprint)
        }
    }

    func recommendChoice(
        for player: PlayerCharacter,
        playerSlot: Int,
        decisionIndex: Int,
        sceneIndex: Int,
        playthrough: PlaythroughMemory
    ) -> MasterChoiceRecommendation? {
        guard let index, let decision = index.decisions.first(where: { $0.index == decisionIndex }) else {
            return nil
        }

        let scene = index.scenes.first(where: { $0.index == sceneIndex })
            ?? index.scenes.first(where: { $0.title == decision.sceneTitle })

        let playerBag = MasterIndexBuilder.playerTokenBag(player)
        let historyBag = historyTokenBag(playthrough: playthrough, index: index, upToDecision: decisionIndex)

        let choicesBlock = decision.playerChoices.first(where: { $0.playerSlot == playerSlot })
            ?? decision.playerChoices.first

        guard let choices = choicesBlock?.choices, !choices.isEmpty else { return nil }

        let scored = choices.map { choice -> (MasterAlgorithmIndex.IndexedChoice, Int, [String]) in
            let traits = matchedTraits(choice: choice, playerBag: playerBag, scene: scene, decision: decision, historyBag: historyBag)
            let score = scoreChoice(choice: choice, playerBag: playerBag, scene: scene, decision: decision, historyBag: historyBag, traits: traits)
            return (choice, score, traits)
        }

        guard let best = scored.max(by: { lhs, rhs in
            if lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
            return lhs.0.index > rhs.0.index
        }) else { return nil }

        let maxScore = max(scored.map(\.1).max() ?? 1, 1)
        let confidence = min(99, max(35, (best.1 * 100) / maxScore))

        return MasterChoiceRecommendation(
            choiceIndex: best.0.index,
            choiceText: best.0.text,
            score: best.1,
            confidencePercent: confidence,
            matchedTraits: best.2
        )
    }

    func interpretScene(
        campaign: ParsedCampaign,
        sceneIndex: Int,
        decisionIndex: Int?,
        players: [PlayerCharacter],
        selectedChoices: [UUID: String],
        recommendations: [UUID: MasterChoiceRecommendation],
        playthrough: PlaythroughMemory
    ) -> String {
        guard let index else {
            return "Algorytm Mistrza nie ma jeszcze indeksu kampanii. Zapisz kampanię w ustawieniach."
        }

        let decisionIdx = decisionIndex ?? sceneIndex
        let scene = index.scenes.first(where: { $0.index == sceneIndex })
            ?? index.scenes.first(where: { $0.index == decisionIdx })
        let decision = index.decisions.first(where: { $0.index == decisionIdx })

        var paragraphs: [String] = [
            "【\(campaign.title)】 — interpretacja Algorytmu Mistrza",
        ]

        if !index.storyOutline.isEmpty {
            paragraphs.append("Zarys fabularny:\n\(index.storyOutline)")
        }

        if let scene {
            paragraphs.append("Scena „\(scene.title)”:\n\(scene.narrative)")
        }

        if let decision {
            paragraphs.append("Sytuacja decyzyjna: \(decision.question)")
        }

        for (slot, player) in players.enumerated() {
            if let text = selectedChoices[player.id] {
                if let choiceIdx = choiceIndex(in: text, playerSlot: slot, decisionIdx: decisionIdx, campaign: campaign),
                   let detail = campaign.decisions[safe: decisionIdx]?
                    .choiceDetail(forPlayerIndex: slot, choiceIndex: choiceIdx) {
                    paragraphs.append(formatSelectedChoice(player: player, detail: detail, selectedText: text))
                } else {
                    paragraphs.append("• \(player.className) wybrał: \(text)")
                }
                continue
            }

            if let rec = recommendations[player.id] {
                let traits = rec.matchedTraits.prefix(3).joined(separator: ", ")
                let traitSuffix = traits.isEmpty ? "" : " (dopasowanie: \(traits))"
                paragraphs.append(
                    "• \(player.className) — rekomendacja [\(rec.confidencePercent)%]: \(rec.choiceText)\(traitSuffix)"
                )
            } else if let rec = recommendChoice(
                for: player,
                playerSlot: slot,
                decisionIndex: decisionIdx,
                sceneIndex: sceneIndex,
                playthrough: playthrough
            ) {
                paragraphs.append(
                    "• \(player.className) — sugerowany wybór [\(rec.confidencePercent)%]: \(rec.choiceText)"
                )
            }
        }

        let priorCount = playthrough.selections.keys.compactMap(Int.init).filter { $0 < decisionIdx }.count
        if priorCount > 0 {
            paragraphs.append("Mistrz pamięta \(priorCount) wcześniejszych decyzji w tej kampanii i uwzględnia je w dopasowaniu.")
        }

        paragraphs.append("Co robicie dalej? Czas na kolejną decyzję.")

        return paragraphs.joined(separator: "\n\n")
    }

    private func choiceIndex(in selectedText: String, playerSlot: Int, decisionIdx: Int, campaign: ParsedCampaign) -> Int? {
        guard let decision = campaign.decisions[safe: decisionIdx] else { return nil }
        let choices = decision.choiceTexts(forPlayerIndex: playerSlot)
        return choices.firstIndex(where: { $0 == selectedText || selectedText.hasPrefix($0.prefix(40)) })
    }

    private func formatSelectedChoice(player: PlayerCharacter, detail: CampaignChoice, selectedText: String) -> String {
        var lines = ["• \(player.className) wybrał: \(detail.text.isEmpty ? selectedText : detail.text)"]
        if !detail.advantage.isEmpty { lines.append("  Zaleta: \(detail.advantage)") }
        if !detail.disadvantage.isEmpty { lines.append("  Wada: \(detail.disadvantage)") }
        if !detail.effects.isEmpty {
            lines.append("  Skutki: \(effectSummary(detail.effects))")
        }
        return lines.joined(separator: "\n")
    }

    private func effectSummary(_ effects: CampaignChoiceEffects) -> String {
        var parts: [String] = []
        if effects.strength != 0 { parts.append("siła \(signed(effects.strength))") }
        if effects.coins != 0 { parts.append("monety \(signed(effects.coins))") }
        if effects.abilities != 0 { parts.append("zdolności \(signed(effects.abilities))") }
        if effects.boardMove != 0 { parts.append("plansza \(signed(effects.boardMove))") }
        if effects.blockRounds != 0 { parts.append("blokada \(effects.blockRounds) r.") }
        if effects.health != 0 { parts.append("zdrowie \(signed(effects.health))") }
        if effects.mana != 0 { parts.append("mana \(signed(effects.mana))") }
        return parts.isEmpty ? "brak" : parts.joined(separator: ", ")
    }

    private func signed(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }

    func unload() {
        index = nil
        isReady = false
        lastBuildSummary = "Indeks Mistrza zwolniony z pamięci operacyjnej (pozostaje na dysku)."
    }

    // MARK: - Scoring

    private func scoreChoice(
        choice: MasterAlgorithmIndex.IndexedChoice,
        playerBag: Set<String>,
        scene: MasterAlgorithmIndex.IndexedScene?,
        decision: MasterAlgorithmIndex.IndexedDecision,
        historyBag: Set<String>,
        traits: [String]
    ) -> Int {
        var score = traits.count * 12
        score += overlap(choice.keywords, playerBag) * 28
        score += overlap(choice.bigrams, playerBag) * 14
        score += overlap(choice.effectTokens, playerBag) * 22
        if let scene {
            score += overlap(choice.keywords, Set(scene.keywords)) * 18
            score += overlap(choice.bigrams, Set(scene.bigrams)) * 10
        }
        score += overlap(choice.keywords, Set(decision.keywords)) * 16
        score += overlap(choice.keywords, historyBag) * 8
        score += scoreEffects(choice.effects, playerBag: playerBag)
        score += scoreAdvantageDisadvantage(choice: choice, playerBag: playerBag)
        score += Int(stableHash(choice.fingerprint) % 7)
        return score
    }

    private func scoreEffects(_ effects: CampaignChoiceEffects, playerBag: Set<String>) -> Int {
        var score = 0
        if effects.health > 0 && (playerBag.contains("mag") || playerBag.contains("elf")) { score += 14 }
        if effects.strength > 0 && (playerBag.contains("rycerz") || playerBag.contains("ork")) { score += 12 }
        if effects.mana > 0 && playerBag.contains("mag") { score += 16 }
        if effects.abilities > 0 && playerBag.contains("elf") { score += 10 }
        if effects.coins > 0 { score += 8 }
        if effects.boardMove > 0 { score += 6 }
        if effects.blockRounds > 0 { score -= 10 }
        if effects.health < 0 || effects.strength < 0 { score -= 6 }
        return score
    }

    private func scoreAdvantageDisadvantage(
        choice: MasterAlgorithmIndex.IndexedChoice,
        playerBag: Set<String>
    ) -> Int {
        var score = 0
        let advantageTokens = MasterIndexBuilder.keywords(from: choice.advantage)
        let disadvantageTokens = MasterIndexBuilder.keywords(from: choice.disadvantage)
        score += overlap(Array(advantageTokens), playerBag) * 10
        score -= overlap(Array(disadvantageTokens), playerBag) * 8
        return score
    }

    private func matchedTraits(
        choice: MasterAlgorithmIndex.IndexedChoice,
        playerBag: Set<String>,
        scene: MasterAlgorithmIndex.IndexedScene?,
        decision: MasterAlgorithmIndex.IndexedDecision,
        historyBag: Set<String>
    ) -> [String] {
        var traits: [String] = []
        let choiceSet = Set(choice.keywords)

        for token in playerBag where choiceSet.contains(token) {
            traits.append(token)
        }
        if let scene {
            for token in scene.keywords.prefix(12) where choiceSet.contains(token) {
                traits.append("scena:\(token)")
            }
        }
        for token in decision.keywords.prefix(8) where choiceSet.contains(token) {
            traits.append("decyzja:\(token)")
        }
        for token in choice.effectTokens.prefix(4) {
            traits.append("skutek:\(token)")
        }
        if !choice.advantage.isEmpty {
            traits.append("zaleta")
        }
        if !choice.disadvantage.isEmpty {
            traits.append("wada")
        }
        for token in historyBag.prefix(6) where choiceSet.contains(token) {
            traits.append("historia:\(token)")
        }
        return Array(Set(traits)).sorted().prefix(6).map { String($0) }
    }

    private func historyTokenBag(
        playthrough: PlaythroughMemory,
        index: MasterAlgorithmIndex,
        upToDecision: Int
    ) -> Set<String> {
        var bag = Set<String>()
        for decisionIdx in playthrough.decisionIndices where decisionIdx < upToDecision {
            guard let perPlayer = playthrough.selections[String(decisionIdx)],
                  let decision = index.decisions.first(where: { $0.index == decisionIdx })
            else { continue }

            for (slotKey, choiceIdx) in perPlayer {
                guard let slot = Int(slotKey) else { continue }
                let choices = decision.playerChoices.first(where: { $0.playerSlot == slot })?.choices
                    ?? decision.playerChoices.first?.choices
                guard let choice = choices?.first(where: { $0.index == choiceIdx }) else { continue }
                bag.formUnion(choice.keywords)
            }
        }
        return bag
    }

    private func overlap(_ tokens: [String], _ bag: Set<String>) -> Int {
        tokens.reduce(0) { $0 + (bag.contains($1) ? 1 : 0) }
    }

    private func stableHash(_ text: String) -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        return hash
    }
}

private enum MasterIndexPersistence {
    private static let indexDirectoryName = "MistrzIndex"

    private static func indexFileURL(fingerprint: String) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent(indexDirectoryName, isDirectory: true)
        return dir.appendingPathComponent("\(fingerprint).mistrz.json")
    }

    static func load(fingerprint: String) -> MasterAlgorithmIndex? {
        let url = indexFileURL(fingerprint: fingerprint)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(MasterAlgorithmIndex.self, from: data)
    }

    static func save(_ data: Data, fingerprint: String) {
        let url = indexFileURL(fingerprint: fingerprint)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}

// MARK: - Bezpieczny builder (poza wątkiem głównym)

private enum MasterIndexBuilder {
    static let maxInputCharacters = 4_000
    static let maxStoredNarrative = 1_500
    static let maxWords = 400
    static let maxBigrams = 256
    static let maxKeywords = 200
    static let maxChoiceText = 600

    static let polishStopWords: Set<String> = [
        "i", "w", "z", "na", "do", "że", "ze", "to", "się", "nie", "jest", "jak", "co", "ale",
        "lub", "oraz", "dla", "po", "od", "przy", "tej", "ten", "ta", "te", "tym", "już", "być",
        "by", "go", "jej", "ich", "nas", "was", "gdy", "czy", "tak", "bardzo", "tylko", "też",
    ]

    struct BuildResult {
        let index: MasterAlgorithmIndex
        let summary: String
        let encodedData: Data?
    }

    static func build(from campaign: ParsedCampaign, fingerprint: String) -> BuildResult? {
        var scenes: [MasterAlgorithmIndex.IndexedScene] = []
        scenes.reserveCapacity(campaign.scenes.count)

        for (offset, scene) in campaign.scenes.enumerated() {
            let tokens = tokenize(scene.narrative + " " + scene.title)
            scenes.append(
                MasterAlgorithmIndex.IndexedScene(
                    index: offset,
                    title: clip(scene.title, max: 120),
                    narrative: clip(scene.narrative, max: maxStoredNarrative),
                    keywords: Array(tokens.keywords.prefix(maxKeywords)),
                    bigrams: Array(tokens.bigrams.prefix(maxBigrams))
                )
            )
        }

        var decisions: [MasterAlgorithmIndex.IndexedDecision] = []
        decisions.reserveCapacity(campaign.decisions.count)

        for (offset, decision) in campaign.decisions.enumerated() {
            let questionTokens = tokenize(decision.question + " " + decision.sceneTitle)
            var playerChoices: [MasterAlgorithmIndex.IndexedPlayerChoices] = []

            if decision.choiceDetailsByPlayer.isEmpty && decision.choicesByPlayer.isEmpty {
                let indexed = decision.alternatives.prefix(40).enumerated().map { choiceIndex, text in
                    indexedChoice(choiceIndex: choiceIndex, choice: CampaignChoice(text: text))
                }
                if !indexed.isEmpty {
                    playerChoices.append(MasterAlgorithmIndex.IndexedPlayerChoices(playerSlot: 0, choices: indexed))
                }
            } else if !decision.choiceDetailsByPlayer.isEmpty {
                for (slot, details) in decision.choiceDetailsByPlayer.enumerated() {
                    let indexed = details.prefix(20).enumerated().map { choiceIndex, detail in
                        indexedChoice(choiceIndex: choiceIndex, choice: detail)
                    }
                    guard !indexed.isEmpty else { continue }
                    playerChoices.append(
                        MasterAlgorithmIndex.IndexedPlayerChoices(playerSlot: slot, choices: indexed)
                    )
                }
            } else {
                for (slot, choices) in decision.choicesByPlayer.enumerated() {
                    let indexed = choices.prefix(20).enumerated().map { choiceIndex, text in
                        indexedChoice(choiceIndex: choiceIndex, choice: CampaignChoice(text: text))
                    }
                    guard !indexed.isEmpty else { continue }
                    playerChoices.append(
                        MasterAlgorithmIndex.IndexedPlayerChoices(playerSlot: slot, choices: indexed)
                    )
                }
            }

            decisions.append(
                MasterAlgorithmIndex.IndexedDecision(
                    index: offset,
                    sceneTitle: clip(decision.sceneTitle, max: 120),
                    question: clip(decision.question, max: 800),
                    keywords: Array(questionTokens.keywords.prefix(maxKeywords)),
                    playerChoices: playerChoices
                )
            )
        }

        let vocabulary = Set(
            scenes.flatMap(\.keywords)
                + decisions.flatMap(\.keywords)
                + tokenize(campaign.storyOutline).keywords
        )
        var built = MasterAlgorithmIndex(
            campaignTitle: clip(campaign.title, max: 200),
            campaignFingerprint: fingerprint,
            builtAt: Date(),
            storyOutline: clip(campaign.storyOutline, max: maxStoredNarrative),
            scenes: scenes,
            decisions: decisions,
            vocabularySize: vocabulary.count,
            indexByteEstimate: 0
        )

        let encodedData = try? JSONEncoder().encode(built)
        if let encodedData {
            built.indexByteEstimate = encodedData.count
        }

        let summary = "Zbudowano indeks Mistrza: \(built.scenes.count) scen, \(built.decisions.count) decyzji, \(vocabulary.count) słów kluczowych."
        return BuildResult(index: built, summary: summary, encodedData: encodedData)
    }

    static func keywords(from text: String) -> Set<String> {
        Set(tokenize(text).keywords)
    }

    static func playerTokenBag(_ player: PlayerCharacter) -> Set<String> {
        keywords(from: player.className + " " + player.mainWeapon + " "
            + player.advantages.joined(separator: " ") + " "
            + player.flaws.joined(separator: " "))
    }

    private struct TokenBag {
        let keywords: Set<String>
        let bigrams: [String]
    }

    private static func tokenize(_ text: String) -> TokenBag {
        let clipped = clip(text, max: maxInputCharacters)
        let normalized = clipped
            .lowercased()
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pl_PL"))

        var words: [String] = []
        words.reserveCapacity(min(maxWords, 64))
        normalized.enumerateSubstrings(in: normalized.startIndex..., options: .byWords) { substring, _, _, stop in
            guard words.count < maxWords else {
                stop = true
                return
            }
            guard let word = substring?.lowercased(), word.count >= 3 else { return }
            guard !polishStopWords.contains(word) else { return }
            words.append(word)
        }

        var keywords = Set<String>()
        keywords.reserveCapacity(min(words.count, maxKeywords))
        for word in words {
            keywords.insert(word)
            if keywords.count >= maxKeywords { break }
        }

        var bigrams: [String] = []
        bigrams.reserveCapacity(min(maxBigrams, words.count))
        var seenBigrams = Set<String>()

        for word in words {
            guard bigrams.count < maxBigrams else { break }
            let chars = Array(word)
            guard chars.count >= 2 else { continue }
            let charLimit = max(0, chars.count - 1)
            for idx in 0..<min(charLimit, 24) {
                guard bigrams.count < maxBigrams else { break }
                let bigram = String(chars[idx...idx + 1])
                if seenBigrams.insert(bigram).inserted {
                    bigrams.append(bigram)
                }
            }
        }

        if words.count >= 2 {
            for idx in 0..<(words.count - 1) {
                guard bigrams.count < maxBigrams else { break }
                let pair = "\(words[idx]) \(words[idx + 1])"
                if seenBigrams.insert(pair).inserted {
                    bigrams.append(pair)
                }
            }
        }

        return TokenBag(keywords: keywords, bigrams: bigrams)
    }

    private static func indexedChoice(choiceIndex: Int, choice: CampaignChoice) -> MasterAlgorithmIndex.IndexedChoice {
        let composite = [
            choice.text,
            choice.advantage,
            choice.disadvantage,
            choice.effects.summaryTokens.joined(separator: " "),
        ].joined(separator: " ")
        let clipped = clip(composite, max: maxChoiceText)
        let tokens = tokenize(clipped)
        return MasterAlgorithmIndex.IndexedChoice(
            index: choiceIndex,
            text: clip(choice.text, max: maxChoiceText),
            advantage: clip(choice.advantage, max: 200),
            disadvantage: clip(choice.disadvantage, max: 200),
            effects: choice.effects,
            keywords: Array(tokens.keywords.prefix(maxKeywords)),
            bigrams: Array(tokens.bigrams.prefix(64)),
            effectTokens: choice.effects.summaryTokens,
            fingerprint: String(format: "%016llx", stableHash(clipped))
        )
    }

    private static func stableHash(_ text: String) -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        return hash
    }

    private static func clip(_ text: String, max maxLength: Int) -> String {
        guard maxLength > 0, text.count > maxLength else { return text }
        guard let index = text.index(text.startIndex, offsetBy: maxLength, limitedBy: text.endIndex) else {
            return text
        }
        return String(text[..<index]) + "…"
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Skutki zdolności z opisu (walka z bossem)

extension MasterAlgorithmEngine {
    static func parseAbilityEffects(from description: String) -> CampaignChoiceEffects {
        let text = description.lowercased()
        var effects = CampaignChoiceEffects()

        effects.health += signedMagnitude(in: text, positive: [
            "leczenie", "wyleczenie", "regeneracja", "odnowa", "uzdrowienie", "zdrowie",
        ], negative: [
            "obrażenia", "obrazenia", "rany", "krwawienie", "cios", "atak wroga",
        ])
        effects.strength += signedMagnitude(in: text, positive: [
            "siła", "sila", "moc", "atak", "uderzenie", "wzmocnienie",
        ], negative: [
            "osłabienie", "oslabienie", "zmęczenie", "zmeczenie",
        ])
        effects.coins += signedMagnitude(in: text, positive: [
            "monety", "złoto", "zloto", "skarb", "łup", "lup",
        ], negative: ["koszt", "utrata monet"])
        effects.mana += signedMagnitude(in: text, positive: [
            "mana", "magia", "zaklęcie", "zaklecie", "energia",
        ], negative: ["wyczerpanie many"])
        effects.abilities += signedMagnitude(in: text, positive: [
            "zdolności", "zdolnosci", "mistrzostwo", "kunszt",
        ], negative: [])
        effects.boardMove += signedMagnitude(in: text, positive: [
            "plansza", "ruch", "przesunięcie", "przesuniecie",
        ], negative: [])
        effects.blockRounds += magnitude(in: text, keywords: [
            "blokada", "osłona", "oslona", "tarcza", "ochrona",
        ])

        applyExplicitNumbers(in: text, into: &effects)
        return effects
    }

    static func describeAbilityEffects(_ effects: CampaignChoiceEffects, abilityName: String) -> String {
        var parts: [String] = []
        if effects.health != 0 { parts.append("Zdrowie \(signed(effects.health))") }
        if effects.strength != 0 { parts.append("Siła \(signed(effects.strength))") }
        if effects.coins != 0 { parts.append("Monety \(signed(effects.coins))") }
        if effects.abilities != 0 { parts.append("Zdolności \(signed(effects.abilities))") }
        if effects.mana != 0 { parts.append("Mana \(signed(effects.mana))") }
        if effects.boardMove != 0 { parts.append("Plansza \(signed(effects.boardMove))") }
        if effects.blockRounds != 0 { parts.append("Blokada \(effects.blockRounds) r.") }
        if parts.isEmpty {
            return "„\(abilityName)” — brak wykrytych skutków liczbowych (neutralnie)."
        }
        return "„\(abilityName)” — \(parts.joined(separator: ", "))."
    }

    private static func signed(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }

    private static func signedMagnitude(
        in text: String,
        positive: [String],
        negative: [String]
    ) -> Int {
        var value = 0
        for word in positive where text.contains(word) {
            value += magnitude(in: text, keywords: [word], defaultValue: 8)
        }
        for word in negative where text.contains(word) {
            value -= magnitude(in: text, keywords: [word], defaultValue: 8)
        }
        return value
    }

    private static func magnitude(
        in text: String,
        keywords: [String],
        defaultValue: Int = 6
    ) -> Int {
        for keyword in keywords where text.contains(keyword) {
            if let number = firstNumber(near: keyword, in: text) {
                return min(30, max(1, number))
            }
            return defaultValue
        }
        return 0
    }

    private static func firstNumber(near keyword: String, in text: String) -> Int? {
        guard let range = text.range(of: keyword) else { return nil }
        let window = text[range.lowerBound...].prefix(40)
        let pattern = /[+-]?\d{1,3}/
        guard let match = window.firstMatch(of: pattern) else { return nil }
        return Int(match.output)
    }

    private static func applyExplicitNumbers(in text: String, into effects: inout CampaignChoiceEffects) {
        let rules: [(String, WritableKeyPath<CampaignChoiceEffects, Int>)] = [
            ("zdrowie", \.health),
            ("zdrowia", \.health),
            ("sila", \.strength),
            ("siła", \.strength),
            ("monety", \.coins),
            ("mana", \.mana),
            ("zdolnosci", \.abilities),
            ("zdolności", \.abilities),
        ]
        for (label, keyPath) in rules {
            guard let value = parseLabeledValue(label: label, in: text) else { continue }
            effects[keyPath: keyPath] = value
        }
    }

    private static func parseLabeledValue(label: String, in text: String) -> Int? {
        let pattern = #/(?:zdrowie|zdrowia|sila|siła|monety|mana|zdolnosci|zdolności)\s*[:+]?\s*([+-]?\d{1,3})/#
        for match in text.matches(of: pattern) {
            if let value = Int(match.1) { return value }
        }
        return nil
    }
}

private extension ParsedCampaign {
    var fingerprint: String {
        let choiceFingerprint = decisions.flatMap(\.choiceDetailsByPlayer)
            .flatMap { $0.map { "\($0.text)|\($0.advantage)|\($0.disadvantage)" } }
            .joined()
        let basis = title + "|" + storyOutline + "|" + scenes.map(\.title).joined()
            + "|" + decisions.map(\.sceneTitle).joined() + "|" + choiceFingerprint
        var hash: UInt64 = 0
        for byte in basis.utf8 {
            hash = hash &* 31 &+ UInt64(byte)
        }
        return String(format: "%016llx", hash)
    }
}
