//
//  CreatorBuildPrompts.swift
//  DmdApp
//

import Foundation

enum CreatorBuildPrompts {
    static func character(race: String) -> String {
        let options = characterArchetypes(for: race)
        return options.randomElement() ?? "Wymyśl własną postać i opisz jej historię."
    }

    static func item(isBrush: Bool) -> String {
        if isBrush {
            return brushPrompts.randomElement() ?? "Stwórz magiczny pędzel do odkrywania artefaktów."
        }
        return weaponPrompts.randomElement() ?? "Wymyśl broń, która pasuje do twojej postaci."
    }

    static func powerPath(name: String) -> String {
        "Zaprojektuj własną ścieżkę mocy „\(name)” z unikalnymi ulepszeniami i efektami."
    }

    static func ability(element: String) -> String {
        let templates = [
            "Wymyśl zdolność żywiołu \(element) — opisz efekt turowy bez odległości.",
            "Stwórz zaklęcie \(element.lowercased()) — np. wzmocnienie statystyk lub obrażenia co turę.",
            "Zaprojektuj moc \(element.lowercased()) — użyj wyobraźni, nie gotowych szablonów.",
            "Zbuduj zdolność \(element.lowercased()) dla swojego bohatera — opisz ją własnymi słowami.",
        ]
        return templates.randomElement() ?? "Wymyśl własną zdolność magiczną."
    }

    static func race() -> String {
        racePrompts.randomElement() ?? "Wymyśl rasę z unikalnymi zaletami i wadami."
    }

    static func element() -> String {
        elementPrompts.randomElement() ?? "Stwórz żywioł z własnymi zasadami gry."
    }

    private static func characterArchetypes(for race: String) -> [String] {
        let normalized = race.lowercased()
        switch normalized {
        case "elf", "elfy":
            return [
                "Zbuduj elfiego łucznika",
                "Wymyśl leśnego strażnika",
                "Stwórz elfią zwiadowczynię",
                "Zaprojektuj maga run leśnych",
            ]
        case "ork", "orkowie":
            return [
                "Zbuduj orka",
                "Zbuduj orkiego berserka",
                "Wymyśl wojownika klanu kamienia",
                "Stwórz szamana wojny",
                "Zaprojektuj orkiego strażnika jaskini",
            ]
        case "krasnolud", "krasnoludy":
            return [
                "Zbuduj krasnoludzkiego kowala",
                "Wymyśl górniczego wojownika",
                "Stwórz mistrza run kowalskich",
                "Zaprojektuj obrońcę podziemi",
            ]
        case "niziołek", "niziołki", "hobbit":
            return [
                "Zbuduj niziołkiego złodzieja",
                "Wymyśl podróżnika-kucharza",
                "Stwórz szczęśliwego szczurołapa",
                "Zaprojektuj barda opowiadacza",
            ]
        case "człowiek", "ludzie":
            return [
                "Zbuduj ninja",
                "Zbuduj roboczłowieka",
                "Wymyśl rycerza bez korony",
                "Stwórz alchemika z miejskiej dzielnicy",
                "Zaprojektuj łowcę nagród",
            ]
        default:
            return [
                "Zbuduj ninja (\(race))",
                "Zbuduj roboczłowieka (\(race))",
                "Zbuduj \(race.lowercased())",
                "Wymyśl bohatera rasy \(race)",
                "Stwórz wojownika — \(race) z własną legendą",
                "Zaprojektuj maga rasy \(race)",
            ]
        }
    }

    private static let weaponPrompts = [
        "Zbuduj miecz",
        "Wymyśl miecz, który rośnie wraz z odwagą gracza",
        "Stwórz tarczę z odłamka spadającej gwiazdy",
        "Zbuduj kuszę, strzelającą runami zamiast bełtów",
        "Wymyśl sztylet, który szepta tylko w nocy",
        "Stwórz kostur żywiołów — opisz jego moc własnymi słowami",
        "Zaprojektuj łuk z gałęzi świętego drzewa",
        "Wymyśl broń, która pasuje do twojej postaci",
        "Stwórz helm z pamięcią dawnych bitew",
        "Zbuduj pancerz z metalu i snów",
        "Wymyśl pierścień z ukrytą klątwą",
    ]

    private static let brushPrompts = [
        "Stwórz pędzel mgły — im droższy, tym lepsze artefakty",
        "Wymyśl pędzel run, który odsłania skarby",
        "Zbuduj pędzel kryształowej iskry",
        "Zaprojektuj pędzel starożytnego odkrywcy",
        "Stwórz pędzel, który maluje los gracza",
    ]

    private static let racePrompts = [
        "Wymyśl rasę mechaniczną — np. roboczłowieków",
        "Stwórz rasę cieni z własnymi zasadami",
        "Zbuduj rasę ptasich wojowników",
        "Wymyśl rasę żyjącą w korzeniu gigantycznych drzew",
        "Zaprojektuj rasę, która nie śpi, lecz śni na jawie",
    ]

    private static let elementPrompts = [
        "Stwórz żywioł burzy — opisz zalety i wady",
        "Wymyśl żywioł czasu z efektami turowymi",
        "Zbuduj żywioł rdzy, który osłabia broń",
        "Zaprojektuj żywioł echa — powtarza ostatnią akcję",
        "Stwórz żywioł harmonii wzmacniający drużynę",
    ]
}

struct CreatorBatchResult {
    let addedCount: Int
}

extension CreatedCharacter {
    var displayBuildPrompt: String {
        buildPrompt ?? CreatorBuildPrompts.character(race: raceName)
    }
}

extension CreatedItem {
    var displayBuildPrompt: String {
        buildPrompt ?? CreatorBuildPrompts.item(isBrush: isBrush)
    }
}

extension CreatedAbility {
    var displayBuildPrompt: String {
        buildPrompt ?? CreatorBuildPrompts.ability(element: elementCategory)
    }
}

extension CreatedRace {
    var displayBuildPrompt: String {
        buildPrompt ?? CreatorBuildPrompts.race()
    }
}

extension CreatedElement {
    var displayBuildPrompt: String {
        buildPrompt ?? CreatorBuildPrompts.element()
    }
}
