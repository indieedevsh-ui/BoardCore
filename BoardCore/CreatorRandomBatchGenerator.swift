//
//  CreatorRandomBatchGenerator.swift
//  BoardCore
//

import Foundation

enum CreatorRandomBatchGenerator {
    static let defaultBatchCount = 10

    private static let characterFirstNames = [
        "Aldric", "Bryn", "Cael", "Dara", "Eira", "Finn", "Gwen", "Haldor", "Iris", "Jarek",
        "Kael", "Lira", "Mira", "Nolan", "Orin", "Petra", "Quinn", "Rhea", "Soren", "Tara",
        "Ulric", "Vera", "Wren", "Xander", "Yara", "Zolt",
    ]

    private static let characterEpithets = [
        "Smoka", "Mgły", "Północy", "Run", "Burzy", "Cienia", "Iskry", "Kamienia", "Wiatru", "Miecza",
    ]

    private static let itemPrefixes = [
        "Stalowy", "Miedziany", "Elficki", "Krasnoludzki", "Zaczarowany", "Pospolity", "Rzadki", "Legendarny",
    ]

    private static let itemKinds = [
        "miecz", "tarcza", "helm", "pierścień", "amulet", "kielich", "sztylet", "łuk", "kostur", "pancerz",
        "buty", "rękawice", "pas", "klucz", "totem",
    ]

    private static let brushPrefixes = [
        "Kryształowy", "Złoty", "Srebrny", "Mglisty", "Runiczny", "Gwiezdny", "Eteryczny", "Starodawny",
    ]

    private static let brushKinds = [
        "pędzel", "pędzel odkrywczy", "pędzel mgły", "pędzel iskry", "pędzel run",
    ]

    private static let abilityNameParts = [
        "Uderzenie", "Fala", "Klątwa", "Dotyk", "Szept", "Ryk", "Pocisk", "Bariera", "Iskra", "Cios",
        "Ostrze", "Płomień", "Lód", "Burza", "Cień", "Blask", "Runa", "Echa", "Gniew", "Przebudzenie",
    ]

    private static let abilityNameSuffixes = [
        "Pustki", "Żywiołów", "Nocy", "Bohatera", "Chaosu", "Harmonii", "Pradawnych", "Mgły", "Pioruna", "Ziemi",
    ]

    private static let raceNameParts = [
        "Lumin", "Ash", "Storm", "Iron", "Moon", "Sun", "Frost", "Ember", "Stone", "Wind",
    ]

    private static let raceNameSuffixes = [
        "arowie", "ici", "anie", "owie", "kin", "ari", "eth", "orn", "vale", "reach",
    ]

    private static let elementAdvantages = [
        "Wysokie obrażenia i presja na wroga",
        "Leczenie i kontrola pola bitwy",
        "Wysoka wytrzymałość i stabilność",
        "Zwinność i uniki",
        "Uniwersalność bez słabości żywiołu",
        "Oślepia wrogów i wzmacnia sojuszników",
        "Kradnie many i osłabia zaklęcia",
        "Spowalnia i zamraża cele",
        "Regeneracja i wzmocnienie drużyny",
        "Szybkie combo i mobilność",
    ]

    private static let elementDisadvantages = [
        "Słaba obrona przy długiej walce",
        "Niska siła bezpośrednia",
        "Niska mobilność",
        "Kruchość przy trafieniu",
        "Brak bonusu żywiołowego",
        "Wysokie zużycie many",
        "Słabe działanie na odporności",
        "Słabe przeciwko ogniu",
        "Wolne ładowanie",
        "Wymaga bliskiej odległości",
    ]

    @MainActor
    @discardableResult
    static func generate(kind: CreatorEntryKind, count: Int = defaultBatchCount, into store: CreatorStore) -> CreatorBatchResult {
        switch kind {
        case .item:
            return generateItems(count: count, store: store)
        case .ability:
            return generateAbilities(count: count, store: store)
        case .power:
            return generatePowerPaths(count: count, store: store)
        }
    }

    @MainActor
    private static func generatePowerPaths(count: Int, store: CreatorStore) -> CreatorBatchResult {
        let palette: [PlayerGlowColor] = [
            PlayerGlowColor(red: 0.42, green: 0.22, blue: 0.72, opacity: 1),
            PlayerGlowColor(red: 0.98, green: 0.78, blue: 0.22, opacity: 1),
            PlayerGlowColor(red: 0.22, green: 0.62, blue: 0.88, opacity: 1),
            PlayerGlowColor(red: 0.88, green: 0.32, blue: 0.42, opacity: 1),
        ]
        let icons = ["moon.stars.fill", "sun.max.fill", "flame.fill", "bolt.fill"]

        for index in 0..<count {
            let name = uniqueName(
                base: "Ścieżka \(abilityNameParts.randomElement()!)",
                existing: store.catalog.powerPaths.map(\.name),
                suffix: index
            )
            let upgrade = CreatedPowerUpgrade(
                name: "\(abilityNameParts.randomElement()!) \(abilityNameSuffixes.randomElement()!)",
                summary: randomAbilityDescription(
                    name: name,
                    element: store.availableElementNames.randomElement() ?? "Standard"
                ),
                xpCost: Int.random(in: 40...180),
                tier: 1,
                influence: .gameplay,
                gameplayEffect: PowerUpgradeGameplayEffect(
                    healthBonus: Bool.random() ? 10 : 0,
                    strengthBonus: Bool.random() ? 10 : 0,
                    coinsBonus: Bool.random() ? 20 : 0,
                    xpBonus: Bool.random() ? 15 : 0
                )
            )
            store.addPowerPath(
                CreatedPowerPath(
                    name: name,
                    iconSymbol: icons[index % icons.count],
                    glowColor: palette[index % palette.count],
                    upgrades: [upgrade],
                    buildPrompt: CreatorBuildPrompts.powerPath(name: name)
                )
            )
        }
        return CreatorBatchResult(addedCount: count)
    }

    @MainActor
    private static func generateCharacters(count: Int, store: CreatorStore) -> CreatorBatchResult {
        var reserved = store.reservedNumericIDs

        for index in 0..<count {
            let numericId = CreatorIDGenerator.randomUnique(pool: .character, reserved: reserved)
            reserved.insert(numericId)

            let name = uniqueName(
                base: "\(characterFirstNames.randomElement()!) \(characterEpithets.randomElement()!)",
                existing: store.catalog.characters.map(\.name),
                suffix: index
            )
            let race = store.availableRaceNames.randomElement() ?? "Człowiek"
            let advantages = pickTraits(from: CharacterOptions.advantages, count: 2)
            let flaws = pickFlaws(excluding: advantages)
            let prompt = CreatorBuildPrompts.character(race: race)

            store.addCharacter(
                CreatedCharacter(
                    numericId: numericId,
                    name: name,
                    raceName: race,
                    advantages: advantages,
                    flaws: flaws,
                    stats: CreatorStats.random(),
                    imageFileName: nil,
                    buildPrompt: prompt
                )
            )
        }
        return CreatorBatchResult(addedCount: count)
    }

    @MainActor
    private static func generateItems(count: Int, store: CreatorStore) -> CreatorBatchResult {
        var reserved = store.reservedNumericIDs
        var drafts: [(numericId: String, name: String, cost: Int, itemKind: CreatorItemKind, prompt: String)] = []

        for index in 0..<count {
            let numericId = CreatorIDGenerator.randomUnique(pool: .item, reserved: reserved)
            reserved.insert(numericId)

            let isBrush = Bool.random() && index % 4 == 0
            let kindWord = isBrush ? brushKinds.randomElement()! : itemKinds.randomElement()!
            let itemKind: CreatorItemKind = {
                if isBrush { return .brush }
                return CreatorItemKind.inferredFromGeneratedKindWord(kindWord, isBrush: false)
            }()
            let name = uniqueName(
                base: isBrush
                    ? "\(brushPrefixes.randomElement()!) \(kindWord)"
                    : "\(itemPrefixes.randomElement()!) \(kindWord)",
                existing: store.catalog.items.map(\.name) + drafts.map(\.name),
                suffix: index
            )
            let prompt = CreatorBuildPrompts.item(isBrush: isBrush)
            let cost = isBrush ? Int.random(in: 40...450) : Int.random(in: 15...350)

            drafts.append((
                numericId: numericId,
                name: name.capitalized,
                cost: cost,
                itemKind: itemKind,
                prompt: prompt
            ))
        }

        let equipmentCosts = drafts
            .filter { $0.itemKind.isEquippable }
            .map(\.cost)
        let costRange = (equipmentCosts.min() ?? 15)...(equipmentCosts.max() ?? 350)

        for draft in drafts {
            let stats = CreatorStats.forGeneratedBatchItem(
                cost: draft.cost,
                itemKind: draft.itemKind,
                costRange: costRange
            )
            store.addItem(
                CreatedItem(
                    numericId: draft.numericId,
                    name: draft.name,
                    cost: draft.cost,
                    stats: stats,
                    itemKind: draft.itemKind,
                    imageFileName: nil,
                    buildPrompt: draft.prompt
                )
            )
        }
        return CreatorBatchResult(addedCount: count)
    }

    @MainActor
    private static func generateAbilities(count: Int, store: CreatorStore) -> CreatorBatchResult {
        var reserved = store.reservedNumericIDs
        let elements = store.availableElementNames

        for index in 0..<count {
            let numericId = CreatorIDGenerator.randomUnique(pool: .ability, reserved: reserved)
            reserved.insert(numericId)

            let element = elements.randomElement() ?? "Standard"
            let name = uniqueName(
                base: "\(abilityNameParts.randomElement()!) \(abilityNameSuffixes.randomElement()!)",
                existing: store.catalog.abilities.map(\.name),
                suffix: index
            )
            let prompt = CreatorBuildPrompts.ability(element: element)

            store.addAbility(
                CreatedAbility(
                    numericId: numericId,
                    name: name,
                    effectDescription: randomAbilityDescription(name: name, element: element),
                    elementCategory: element,
                    buildPrompt: prompt
                )
            )
        }
        return CreatorBatchResult(addedCount: count)
    }

    @MainActor
    private static func generateRaces(count: Int, store: CreatorStore) -> CreatorBatchResult {
        for index in 0..<count {
            let name = uniqueName(
                base: "\(raceNameParts.randomElement()!)\(raceNameSuffixes.randomElement()!)",
                existing: store.catalog.races.map(\.name),
                suffix: index
            )
            let advantages = pickTraits(from: CharacterOptions.advantages, count: 2)
            let flaws = pickFlaws(excluding: advantages)
            let prompt = CreatorBuildPrompts.race()

            store.addRace(
                CreatedRace(
                    name: name,
                    advantages: advantages,
                    flaws: flaws,
                    stats: CreatorStats.random(),
                    buildPrompt: prompt
                )
            )
        }
        return CreatorBatchResult(addedCount: count)
    }

    @MainActor
    private static func generateElements(count: Int, store: CreatorStore) -> CreatorBatchResult {
        var usedNames = Set(store.catalog.elements.map(\.name))

        for index in 0..<count {
            let baseName = CreatorCatalog.defaultElementNames.randomElement() ?? "Żywioł"
            let name = uniqueName(base: "\(baseName) \(index + 1)", existing: Array(usedNames), suffix: index)
            usedNames.insert(name)
            let prompt = CreatorBuildPrompts.element()

            store.addElement(
                CreatedElement(
                    name: name,
                    advantages: elementAdvantages.randomElement() ?? "Uniwersalne bonusy",
                    disadvantages: elementDisadvantages.randomElement() ?? "Brak specjalizacji",
                    buildPrompt: prompt
                )
            )
        }
        return CreatorBatchResult(addedCount: count)
    }

    static func randomAbilityDescription(name: String, element: String) -> String {
        let damage = Int.random(in: 8...40)
        let turns = Int.random(in: 1...4)
        let spaces = Int.random(in: 1...4)
        let statBonus = Int.random(in: 5...18)
        let weaponBonus = Int.random(in: 6...22)
        let dotDamage = Int.random(in: 4...15)
        let elementLabel = element.lowercased()

        let templates: [String] = [
            // Obrażenia turowe
            "\(name): zadaje \(damage) obrażeń typu \(elementLabel) w tej turze.",
            "\(name): nakłada krwawienie \(elementLabel) — \(dotDamage) obrażeń co turę przez \(turns) tury.",
            "\(name): co turę przez \(turns) tury zadaje \(dotDamage) obrażeń \(elementLabel) wybranemu graczowi.",
            "\(name): seria \(turns) tur — każda tura zadaje \(dotDamage) obrażeń \(elementLabel) (łącznie do \(dotDamage * turns)).",
            "\(name): w tej turze +\(damage) obrażeń \(elementLabel), a w następnej turze kolejne +\(dotDamage).",

            // Ruch na planszy
            "\(name): popchnij wybranego gracza o \(spaces) \(spaces == 1 ? "pole" : "pola") do tyłu na planszy.",
            "\(name): cofnij wroga o \(spaces) \(spaces == 1 ? "pole" : "pola") — gracz traci postęp na planszy.",
            "\(name): przyciągnij gracza o \(spaces) \(spaces == 1 ? "pole" : "pola") w swoim kierunku.",
            "\(name): wymiana miejsc — ty przesuwasz się o \(spaces) \(spaces == 1 ? "pole" : "pola") do przodu, cel cofa się o \(max(1, spaces - 1)) \(spaces <= 2 ? "pole" : "pola").",
            "\(name): przez \(turns) tury każdy trafiony gracz jest cofany o 1 pole na koniec tury.",

            // Statystyki
            "\(name): +\(statBonus) zdrowia i +\(statBonus) siły na \(turns) tury (żywioł: \(element)).",
            "\(name): +\(statBonus) finansów natychmiast i +\(statBonus / 2) siły na \(turns) tury.",
            "\(name): w tej turze +\(statBonus) do wszystkich statystyk; w następnej turze efekt słabnie o połowę.",
            "\(name): leczy \(statBonus + 10) zdrowia i daje +\(statBonus) siły do końca bieżącej tury.",
            "\(name): przez \(turns) tury regenerujesz \(dotDamage) zdrowia na początku każdej swojej tury.",

            // Moc broni
            "\(name): broń zadaje +\(weaponBonus) obrażeń \(elementLabel) przez \(turns) tury.",
            "\(name): na \(turns) tury każdy atak bronią ma +\(weaponBonus) mocy i efekt \(elementLabel).",
            "\(name): w tej turze podwaja obrażenia z broni (min. +\(weaponBonus) \(elementLabel)).",
            "\(name): nałóż \(elementLabel) na broń — +\(weaponBonus) obrażeń co turę przez \(turns) tury przy trafieniu.",
            "\(name): na \(turns) tury broń ignoruje \(statBonus) pkt. obrony celu i zadaje +\(weaponBonus) obrażeń.",
        ]

        return templates.randomElement() ?? "\(name): wzmacnia gracza efektem \(elementLabel) na \(turns) tury."
    }

    private static func pickTraits(from pool: [String], count: Int) -> [String] {
        Array(pool.shuffled().prefix(count))
    }

    private static func pickFlaws(excluding advantages: [String]) -> [String] {
        let blocked = Set(advantages.compactMap { CharacterOptions.conflictingTrait(for: $0) })
        let available = CharacterOptions.flaws.filter { !blocked.contains($0) && !advantages.contains($0) }
        return Array(available.shuffled().prefix(2))
    }

    private static func uniqueName(base: String, existing: [String], suffix: Int) -> String {
        if !existing.contains(base) { return base }
        let candidate = "\(base) \(suffix + 1)"
        if !existing.contains(candidate) { return candidate }
        return "\(base) #\(suffix + 1)-\(Int.random(in: 100...999))"
    }
}
