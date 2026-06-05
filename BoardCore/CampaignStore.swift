//
//  CampaignStore.swift
//  BoardCore
//

import Foundation
import Observation

@MainActor
@Observable
final class CampaignStore {
    private static let climateKey = "campaignClimate"
    private static let titleKey = "campaignTitle"

    private var skipReparse = false

    var climate: CampaignClimate {
        didSet {
            UserDefaults.standard.set(climate.rawValue, forKey: Self.climateKey)
        }
    }

    var rawText: String {
        didSet {
            guard !skipReparse else {
                skipReparse = false
                return
            }
            let reparsed = CampaignParser.parse(rawText)
            parsedCampaign = reparsed
            title = reparsed.title
            Task { await persistAll() }
        }
    }

    private(set) var parsedCampaign: ParsedCampaign
    private(set) var title: String
    private(set) var library: [SavedCampaignEntry] = []
    private(set) var activeCampaignID: UUID?

    var activeLibraryEntry: SavedCampaignEntry? {
        guard let activeCampaignID else { return nil }
        return library.first { $0.id == activeCampaignID }
    }

    var generatedPrompt: String {
        CampaignPromptBuilder.makePrompt(climate: climate)
    }

    var hasSavedCampaign: Bool {
        !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasPlayableCampaign: Bool {
        hasSavedCampaign && parsedCampaign.hasPlayableContent
    }

    init() {
        let defaults = UserDefaults.standard
        let climateRaw = defaults.string(forKey: Self.climateKey) ?? CampaignClimate.fantasy.rawValue
        climate = CampaignClimate(rawValue: climateRaw) ?? .fantasy

        let storedTitle = defaults.string(forKey: Self.titleKey) ?? "Kampania bez tytułu"
        let storedText = CampaignPersistence.loadRawText() ?? ""
        let parsed = CampaignPersistence.loadParsedCampaign() ?? CampaignParser.parse(storedText)

        skipReparse = true
        rawText = storedText
        parsedCampaign = parsed
        title = storedTitle.isEmpty ? parsed.title : storedTitle
        skipReparse = false
        loadLibraryFromDisk()
        migrateLegacyCampaignIfNeeded()
        syncActiveCampaignFromLibrary()
    }

    func saveCampaign(text: String, parsed: ParsedCampaign) async {
        let entry = SavedCampaignEntry(
            id: UUID(),
            title: parsed.title,
            climate: climate,
            savedAt: Date(),
            sceneCount: parsed.scenes.count,
            decisionCount: parsed.decisions.count
        )

        library.insert(entry, at: 0)
        activeCampaignID = entry.id
        CampaignLibraryPersistence.saveManifest(library)
        CampaignLibraryPersistence.saveCampaignData(
            id: entry.id,
            text: text,
            parsed: parsed,
            climate: climate
        )

        skipReparse = true
        rawText = text
        parsedCampaign = parsed
        title = parsed.title
        UserDefaults.standard.set(title, forKey: Self.titleKey)
        await persistAll()
    }

    func activateCampaign(id: UUID) {
        guard let data = CampaignLibraryPersistence.loadCampaignData(id: id) else { return }
        activeCampaignID = id
        climate = data.climate
        skipReparse = true
        rawText = data.text
        parsedCampaign = data.parsed
        title = data.parsed.title
        UserDefaults.standard.set(title, forKey: Self.titleKey)
        UserDefaults.standard.set(climate.rawValue, forKey: Self.climateKey)
        skipReparse = false
        Task { await persistAll() }
    }

    func removeCampaign(id: UUID) {
        library.removeAll { $0.id == id }
        CampaignLibraryPersistence.deleteCampaignData(id: id)
        CampaignLibraryPersistence.saveManifest(library)

        if activeCampaignID == id {
            if let next = library.first {
                activateCampaign(id: next.id)
            } else {
                activeCampaignID = nil
                title = "Kampania bez tytułu"
                parsedCampaign = ParsedCampaign(title: title, decisions: [])
                rawText = ""
                CampaignPersistence.clearAll()
            }
        }
    }

    private func loadLibraryFromDisk() {
        library = CampaignLibraryPersistence.loadManifest()
        if let first = library.first {
            activeCampaignID = first.id
        }
    }

    private func migrateLegacyCampaignIfNeeded() {
        guard library.isEmpty, hasSavedCampaign else { return }

        let entry = SavedCampaignEntry(
            id: UUID(),
            title: title,
            climate: climate,
            savedAt: Date(),
            sceneCount: parsedCampaign.scenes.count,
            decisionCount: parsedCampaign.decisions.count
        )
        library = [entry]
        activeCampaignID = entry.id
        CampaignLibraryPersistence.saveManifest(library)
        CampaignLibraryPersistence.saveCampaignData(
            id: entry.id,
            text: rawText,
            parsed: parsedCampaign,
            climate: climate
        )
    }

    private func syncActiveCampaignFromLibrary() {
        guard let activeCampaignID,
              let data = CampaignLibraryPersistence.loadCampaignData(id: activeCampaignID)
        else { return }

        skipReparse = true
        climate = data.climate
        rawText = data.text
        parsedCampaign = data.parsed
        title = data.parsed.title
        skipReparse = false
    }

    func updateRawText(_ text: String) {
        rawText = text
    }

    func applyParsedCampaign(_ parsed: ParsedCampaign) {
        parsedCampaign = parsed
        title = parsed.title
        UserDefaults.standard.set(title, forKey: Self.titleKey)
        Task { await persistAll() }
    }

    func reset() {
        climate = .fantasy
        title = "Kampania bez tytułu"
        parsedCampaign = ParsedCampaign(title: title, decisions: [])
        rawText = ""
        library = []
        activeCampaignID = nil

        UserDefaults.standard.removeObject(forKey: Self.climateKey)
        UserDefaults.standard.removeObject(forKey: Self.titleKey)
        CampaignPersistence.clearAll()
        CampaignLibraryPersistence.clearAll()
    }

    private func persistAll() async {
        let textSnapshot = rawText
        let parsedSnapshot = parsedCampaign

        await Task.detached(priority: .utility) {
            CampaignPersistence.persistRawText(textSnapshot)
            CampaignPersistence.persistParsedCampaign(parsedSnapshot)
        }.value
    }
}

// MARK: - Persistence (poza MainActor — tylko I/O)

enum CampaignPersistence {
    private static let rawTextUsesFileKey = "campaignRawTextUsesFile"
    private static let parsedUsesFileKey = "campaignParsedUsesFile"
    private static let maxInlineBytes = 256_000

    static var campaignDirectoryURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("Campaign", isDirectory: true)
    }

    private static var rawTextFileURL: URL {
        campaignDirectoryURL.appendingPathComponent("rawText.txt")
    }

    private static var parsedCampaignFileURL: URL {
        campaignDirectoryURL.appendingPathComponent("parsedCampaign.json")
    }

    static func clearAll() {
        UserDefaults.standard.removeObject(forKey: rawTextUsesFileKey)
        UserDefaults.standard.removeObject(forKey: parsedUsesFileKey)
        UserDefaults.standard.removeObject(forKey: "campaignRawText")
        UserDefaults.standard.removeObject(forKey: "campaignParsedJSON")
        try? FileManager.default.removeItem(at: campaignDirectoryURL)
    }

    private static func ensureCampaignDirectory() throws {
        try FileManager.default.createDirectory(at: campaignDirectoryURL, withIntermediateDirectories: true)
    }

    static func ensureCampaignDirectoryPublic() throws {
        try ensureCampaignDirectory()
    }

    static func persistRawText(_ text: String) {
        let byteCount = text.utf8.count
        if byteCount <= maxInlineBytes {
            UserDefaults.standard.set(text, forKey: "campaignRawText")
            UserDefaults.standard.set(false, forKey: rawTextUsesFileKey)
            try? FileManager.default.removeItem(at: rawTextFileURL)
            return
        }

        do {
            try ensureCampaignDirectory()
            try text.write(to: rawTextFileURL, atomically: true, encoding: .utf8)
            UserDefaults.standard.set(true, forKey: rawTextUsesFileKey)
            UserDefaults.standard.removeObject(forKey: "campaignRawText")
        } catch {
            UserDefaults.standard.set(String(text.prefix(20_000)), forKey: "campaignRawText")
            UserDefaults.standard.set(false, forKey: rawTextUsesFileKey)
        }
    }

    static func loadRawText() -> String? {
        if UserDefaults.standard.bool(forKey: rawTextUsesFileKey) {
            return try? String(contentsOf: rawTextFileURL, encoding: .utf8)
        }
        return UserDefaults.standard.string(forKey: "campaignRawText")
    }

    static func persistParsedCampaign(_ parsed: ParsedCampaign) {
        guard let data = try? JSONEncoder().encode(parsed) else { return }

        if data.count <= maxInlineBytes {
            UserDefaults.standard.set(data, forKey: "campaignParsedJSON")
            UserDefaults.standard.set(false, forKey: parsedUsesFileKey)
            try? FileManager.default.removeItem(at: parsedCampaignFileURL)
            return
        }

        do {
            try ensureCampaignDirectory()
            try data.write(to: parsedCampaignFileURL, options: .atomic)
            UserDefaults.standard.set(true, forKey: parsedUsesFileKey)
            UserDefaults.standard.removeObject(forKey: "campaignParsedJSON")
        } catch {
            UserDefaults.standard.set(data, forKey: "campaignParsedJSON")
            UserDefaults.standard.set(false, forKey: parsedUsesFileKey)
        }
    }

    static func loadParsedCampaign() -> ParsedCampaign? {
        let data: Data?
        if UserDefaults.standard.bool(forKey: parsedUsesFileKey) {
            data = try? Data(contentsOf: parsedCampaignFileURL)
        } else {
            data = UserDefaults.standard.data(forKey: "campaignParsedJSON")
        }
        guard let data else { return nil }
        return try? JSONDecoder().decode(ParsedCampaign.self, from: data)
    }
}
