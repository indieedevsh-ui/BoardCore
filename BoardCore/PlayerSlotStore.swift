//
//  PlayerSlotStore.swift
//  BoardCore
//

import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class PlayerSlotStore {
    static let slotCount = 4

    private static let storageKey = "playerSlotCharacters"
    private static let imagesDirectoryName = "PlayerSlotCharacters"

    private(set) var slotCharacters: [Int: SlotCharacterRecord] = [:]

    init() {
        load()
    }

    func hasCharacter(for slot: Int) -> Bool {
        slotCharacters[slot] != nil
    }

    func characterRecord(for slot: Int) -> SlotCharacterRecord? {
        slotCharacters[slot]
    }

    func appearanceImage(for slot: Int) -> UIImage? {
        guard let record = slotCharacters[slot], record.usesPhoto else { return nil }
        guard let fileName = record.imageFileName else { return nil }
        return loadImage(fileName: fileName)
    }

    func profileIconID(for slot: Int) -> String? {
        slotCharacters[slot]?.profileIconID
    }

    func takenProfileIconIDs(excludingSlot: Int? = nil) -> Set<String> {
        var taken = Set<String>()
        for (slot, record) in slotCharacters {
            if let exclude = excludingSlot, slot == exclude { continue }
            if record.appearanceKind == .icon, let iconID = record.profileIconID {
                taken.insert(iconID)
            }
        }
        return taken
    }

    func isProfileIconAvailable(_ iconID: String, excludingSlot: Int? = nil) -> Bool {
        !takenProfileIconIDs(excludingSlot: excludingSlot).contains(iconID)
    }

    func saveCharacter(
        name: String,
        glowColor: PlayerGlowColor,
        appearanceKind: SlotCharacterAppearanceKind,
        profileIconID: String?,
        photo: UIImage?,
        for slot: Int
    ) {
        guard (1...Self.slotCount).contains(slot) else { return }

        var record = SlotCharacterRecord(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            advantage: "",
            flaw: "",
            appearanceKind: appearanceKind,
            profileIconID: appearanceKind == .icon ? profileIconID : nil,
            qrCode: SlotCharacterQR.code(for: slot),
            glowColor: glowColor
        )

        if let existingFile = slotCharacters[slot]?.imageFileName {
            deleteImage(fileName: existingFile)
        }

        if appearanceKind == .photo, let photo, let fileName = try? writeImage(photo) {
            record.imageFileName = fileName
        }

        slotCharacters[slot] = record
        persist()
    }

    func clearCharacter(for slot: Int) {
        if let fileName = slotCharacters[slot]?.imageFileName {
            deleteImage(fileName: fileName)
        }
        slotCharacters.removeValue(forKey: slot)
        persist()
    }

    func playerCharacter(for slot: PlayerSlotCode) -> PlayerCharacter? {
        guard let record = slotCharacters[slot.rawValue] else { return nil }
        return PlayerCharacter.fromSlotCharacter(record, slot: slot.rawValue)
    }

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: Self.storageKey),
            let decoded = try? JSONDecoder().decode([Int: SlotCharacterRecord].self, from: data)
        else { return }
        slotCharacters = decoded
        for slot in 1...Self.slotCount {
            guard var record = slotCharacters[slot], record.needsSlotDefaultGlow else { continue }
            record.applyDefaultGlow(forSlot: slot)
            slotCharacters[slot] = record
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(slotCharacters) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private var imagesDirectoryURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("PlayerSlots/\(Self.imagesDirectoryName)", isDirectory: true)
    }

    private func writeImage(_ image: UIImage) throws -> String {
        try FileManager.default.createDirectory(at: imagesDirectoryURL, withIntermediateDirectories: true)
        let fileName = UUID().uuidString + ".jpg"
        let url = imagesDirectoryURL.appendingPathComponent(fileName)
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            throw CreatorStoreError.imageEncodingFailed
        }
        try data.write(to: url, options: .atomic)
        return fileName
    }

    private func loadImage(fileName: String) -> UIImage? {
        let url = imagesDirectoryURL.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    private func deleteImage(fileName: String) {
        let url = imagesDirectoryURL.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: url)
    }
}
