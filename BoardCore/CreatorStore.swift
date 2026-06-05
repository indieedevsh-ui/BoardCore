//
//  CreatorStore.swift
//  BoardCore
//

import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class CreatorStore {
    private let catalogFileName = "creatorCatalog.json"
    private let imagesDirectoryName = "CreatorImages"

    private(set) var catalog = CreatorCatalog()

    private var catalogURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("Creator/\(catalogFileName)")
    }

    private var imagesDirectoryURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("Creator/\(imagesDirectoryName)", isDirectory: true)
    }

    init() {
        load()
        seedDefaultElementsIfNeeded()
        seedDefaultPowerPathsIfNeeded()
        GameRulesRuntime.update(catalog.gameRules)
    }

    var gameRules: GameRulesConfiguration {
        get { catalog.gameRules }
        set {
            catalog.gameRules = newValue
            GameRulesRuntime.update(newValue)
            persist()
        }
    }

    func updateGameRules(_ rules: GameRulesConfiguration) {
        gameRules = rules
    }

    var reservedNumericIDs: Set<String> {
        var ids = Set<String>()
        ids.formUnion(QRCharacterCode.allCases.map(\.rawValue))
        ids.formUnion(PlayerSlotCode.allCases.map(\.qrID))
        ids.formUnion(catalog.characters.map(\.numericId))
        ids.formUnion(catalog.items.map(\.numericId))
        ids.formUnion(catalog.abilities.map(\.numericId))
        return ids
    }

    var availableRaceNames: [String] {
        let custom = catalog.races.map(\.name)
        let merged = CreatorCatalog.defaultRaceNames + custom
        return Array(Set(merged)).sorted()
    }

    var availableElementNames: [String] {
        let custom = catalog.elements.map(\.name)
        let merged = CreatorCatalog.defaultElementNames + custom
        return Array(Set(merged)).sorted()
    }

    func randomCharacterID(excluding additional: Set<String> = []) -> String {
        CreatorIDGenerator.randomUnique(
            pool: .character,
            reserved: reservedNumericIDs.union(additional)
        )
    }

    func randomItemID(excluding additional: Set<String> = []) -> String {
        CreatorIDGenerator.randomUnique(
            pool: .item,
            reserved: reservedNumericIDs.union(additional)
        )
    }

    func randomAbilityID(excluding additional: Set<String> = []) -> String {
        CreatorIDGenerator.randomUnique(
            pool: .ability,
            reserved: reservedNumericIDs.union(additional)
        )
    }

    func isNumericIDTaken(_ id: String) -> Bool {
        reservedNumericIDs.contains(id.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    @discardableResult
    func saveImage(_ image: UIImage) throws -> String {
        try FileManager.default.createDirectory(at: imagesDirectoryURL, withIntermediateDirectories: true)
        let fileName = UUID().uuidString + ".jpg"
        let url = imagesDirectoryURL.appendingPathComponent(fileName)
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            throw CreatorStoreError.imageEncodingFailed
        }
        try data.write(to: url, options: .atomic)
        return fileName
    }

    func loadImage(fileName: String?) -> UIImage? {
        guard let fileName, !fileName.isEmpty else { return nil }
        let url = imagesDirectoryURL.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    func addCharacter(_ character: CreatedCharacter) {
        catalog.characters.append(character)
        persist()
    }

    func addItem(_ item: CreatedItem) {
        catalog.items.append(item)
        persist()
    }

    func addAbility(_ ability: CreatedAbility) {
        catalog.abilities.append(ability)
        persist()
    }

    func addPowerPath(_ path: CreatedPowerPath) {
        catalog.powerPaths.append(path)
        persist()
    }

    func updatePowerPath(_ path: CreatedPowerPath) {
        guard let index = catalog.powerPaths.firstIndex(where: { $0.id == path.id }) else { return }
        catalog.powerPaths[index] = path
        persist()
    }

    func powerPath(id: UUID) -> CreatedPowerPath? {
        catalog.powerPaths.first { $0.id == id }
    }

    func addRace(_ race: CreatedRace) {
        catalog.races.append(race)
        persist()
    }

    func addElement(_ element: CreatedElement) {
        catalog.elements.append(element)
        persist()
    }

    @discardableResult
    func addRandomBatch(for kind: CreatorEntryKind, count: Int = CreatorRandomBatchGenerator.defaultBatchCount) -> CreatorBatchResult {
        CreatorRandomBatchGenerator.generate(kind: kind, count: count, into: self)
    }

    func character(matching query: String) -> CreatedCharacter? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let lowered = trimmed.lowercased()
        if let byID = catalog.characters.first(where: { $0.numericId == trimmed }) {
            return byID
        }
        return catalog.characters.first { $0.name.lowercased() == lowered }
    }

    func character(withNumericId id: String) -> CreatedCharacter? {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        return catalog.characters.first { $0.numericId == trimmed }
    }

    func removeCharacters(at offsets: IndexSet) {
        let ids = offsets.map { catalog.characters[$0].id }
        catalog.characters.removeAll { ids.contains($0.id) }
        persist()
    }

    func removeItems(at offsets: IndexSet) {
        let ids = offsets.map { catalog.items[$0].id }
        catalog.items.removeAll { ids.contains($0.id) }
        persist()
    }

    func removeAbilities(at offsets: IndexSet) {
        let ids = offsets.map { catalog.abilities[$0].id }
        catalog.abilities.removeAll { ids.contains($0.id) }
        persist()
    }

    func removePowerPaths(at offsets: IndexSet) {
        let ids = offsets.map { catalog.powerPaths[$0].id }
        catalog.powerPaths.removeAll { path in
            ids.contains(path.id) && !path.isBuiltIn
        }
        persist()
    }

    func removePowerPath(id: UUID) {
        catalog.powerPaths.removeAll { $0.id == id && !$0.isBuiltIn }
        persist()
    }

    func removeRaces(at offsets: IndexSet) {
        let ids = offsets.map { catalog.races[$0].id }
        catalog.races.removeAll { ids.contains($0.id) }
        persist()
    }

    func removeElements(at offsets: IndexSet) {
        let ids = offsets.map { catalog.elements[$0].id }
        catalog.elements.removeAll { ids.contains($0.id) }
        persist()
    }

    @discardableResult
    func removeAll(for kind: CreatorEntryKind) -> Int {
        let count: Int
        switch kind {
        case .item:
            count = catalog.items.count
            catalog.items.removeAll()
        case .ability:
            count = catalog.abilities.count
            catalog.abilities.removeAll()
        case .power:
            let removable = catalog.powerPaths.filter { !$0.isBuiltIn }
            count = removable.count
            catalog.powerPaths.removeAll { !$0.isBuiltIn }
        }
        if count > 0 {
            persist()
        }
        return count
    }

    func restoreToDefaults() {
        catalog = CreatorCatalog.restoredDefaults()
        persist()
    }

    private func seedDefaultPowerPathsIfNeeded() {
        guard catalog.powerPaths.isEmpty else { return }
        catalog.powerPaths = CreatorPowerPathSeed.defaultPaths()
        persist()
    }

    private func seedDefaultElementsIfNeeded() {
        guard catalog.elements.isEmpty else { return }
        catalog.elements = CreatorCatalog.defaultElements()
        persist()
    }

    private func load() {
        guard let data = try? Data(contentsOf: catalogURL),
              let decoded = try? JSONDecoder().decode(CreatorCatalog.self, from: data) else {
            return
        }
        catalog = decoded
        GameRulesRuntime.update(catalog.gameRules)
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(
                at: catalogURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(catalog)
            try data.write(to: catalogURL, options: .atomic)
            GameRulesRuntime.update(catalog.gameRules)
        } catch {
            // Ignoruj błąd zapisu — kreator nadal działa w sesji.
        }
    }
}

enum CreatorStoreError: LocalizedError {
    case imageEncodingFailed

    var errorDescription: String? {
        switch self {
        case .imageEncodingFailed: "Nie udało się zapisać zdjęcia."
        }
    }
}
