//
//  CampaignLibrary.swift
//  BoardCore
//

import Foundation

struct SavedCampaignEntry: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var climate: CampaignClimate
    var savedAt: Date
    var sceneCount: Int
    var decisionCount: Int
}

enum CampaignLibraryPersistence {
    private static var manifestURL: URL {
        CampaignPersistence.campaignDirectoryURL.appendingPathComponent("library.json")
    }

    private static func campaignFolder(for id: UUID) -> URL {
        CampaignPersistence.campaignDirectoryURL
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent(id.uuidString, isDirectory: true)
    }

    static func loadManifest() -> [SavedCampaignEntry] {
        guard let data = try? Data(contentsOf: manifestURL),
              let entries = try? JSONDecoder().decode([SavedCampaignEntry].self, from: data)
        else { return [] }
        return entries.sorted { $0.savedAt > $1.savedAt }
    }

    static func saveManifest(_ entries: [SavedCampaignEntry]) {
        do {
            try CampaignPersistence.ensureCampaignDirectoryPublic()
            let data = try JSONEncoder().encode(entries)
            try data.write(to: manifestURL, options: .atomic)
        } catch {
            // Biblioteka pozostaje w pamięci — zapis pliku jest opcjonalny.
        }
    }

    static func saveCampaignData(
        id: UUID,
        text: String,
        parsed: ParsedCampaign,
        climate: CampaignClimate
    ) {
        do {
            try CampaignPersistence.ensureCampaignDirectoryPublic()
            let folder = campaignFolder(for: id)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try text.write(to: folder.appendingPathComponent("rawText.txt"), atomically: true, encoding: .utf8)
            if let data = try? JSONEncoder().encode(parsed) {
                try data.write(to: folder.appendingPathComponent("parsedCampaign.json"), options: .atomic)
            }
            try climate.rawValue.write(
                to: folder.appendingPathComponent("climate.txt"),
                atomically: true,
                encoding: .utf8
            )
        } catch {
            // Ignoruj błąd I/O — aktywna kampania nadal działa z pamięci.
        }
    }

    static func loadCampaignData(id: UUID) -> (text: String, parsed: ParsedCampaign, climate: CampaignClimate)? {
        let folder = campaignFolder(for: id)
        let rawURL = folder.appendingPathComponent("rawText.txt")
        let parsedURL = folder.appendingPathComponent("parsedCampaign.json")
        let climateURL = folder.appendingPathComponent("climate.txt")

        guard let text = try? String(contentsOf: rawURL, encoding: .utf8),
              let parsedData = try? Data(contentsOf: parsedURL),
              let parsed = try? JSONDecoder().decode(ParsedCampaign.self, from: parsedData)
        else { return nil }

        let climateRaw = (try? String(contentsOf: climateURL, encoding: .utf8)) ?? CampaignClimate.fantasy.rawValue
        let climate = CampaignClimate(rawValue: climateRaw) ?? .fantasy
        return (text, parsed, climate)
    }

    static func deleteCampaignData(id: UUID) {
        try? FileManager.default.removeItem(at: campaignFolder(for: id))
    }

    static func clearAll() {
        let libraryRoot = CampaignPersistence.campaignDirectoryURL.appendingPathComponent("Library", isDirectory: true)
        try? FileManager.default.removeItem(at: libraryRoot)
        try? FileManager.default.removeItem(at: manifestURL)
    }
}
