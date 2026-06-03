//
//  PlayerSlotCharacterSetupView.swift
//  DmdApp
//

import SwiftUI
import UIKit

struct PlayerSlotCharacterSetupView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(PlayerSlotStore.self) private var playerSlotStore

    let slot: PlayerSlotCode
    let onComplete: () -> Void

    @State private var name = ""
    @State private var glowColor = PlayerGlowColor.defaultForSlot(1)
    @State private var appearanceKind: SlotCharacterAppearanceKind = .icon
    @State private var selectedIconID: String?
    @State private var photo: UIImage?
    @State private var isEditing = false
    @State private var headerOpacity: Double = 0

    private var existingRecord: SlotCharacterRecord? {
        playerSlotStore.characterRecord(for: slot.rawValue)
    }

    private var takenIconIDs: Set<String> {
        playerSlotStore.takenProfileIconIDs(excludingSlot: isEditing ? slot.rawValue : nil)
    }

    private var isFormValid: Bool {
        let hasName = !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        switch appearanceKind {
        case .icon:
            guard let selectedIconID else { return false }
            return hasName && playerSlotStore.isProfileIconAvailable(selectedIconID, excludingSlot: slot.rawValue)
        case .photo:
            return hasName && photo != nil
        }
    }

    var body: some View {
        ZStack {
            AppGradientBackground(
                glowColor: glowColor.swiftUIColor,
                glowColorKey: glowColor.animationKey
            )

            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("Stwórz postać")
                            .font(.largeTitle.bold())
                        Text(slot.displayName)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        Text("Kod QR postaci: \(SlotCharacterQR.code(for: slot.rawValue))")
                            .font(.caption)
                            .foregroundStyle(settings.accentColor)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .opacity(headerOpacity)

                    if let existing = existingRecord, !isEditing {
                        existingCharacterCard(existing)
                    } else {
                        editorSection
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 32)
            }
            .appScrollSurface()
        }
        .onAppear {
            glowColor = PlayerGlowColor.defaultForSlot(slot.rawValue)
            loadExistingIfNeeded()
            pickDefaultIconIfNeeded()
            withAnimation(.easeInOut(duration: 0.35)) {
                headerOpacity = 1
            }
        }
    }

    @ViewBuilder
    private func existingCharacterCard(_ record: SlotCharacterRecord) -> some View {
        VStack(spacing: 16) {
            PlayerSlotAppearanceView(record: record, slot: slot.rawValue, playerSlotStore: playerSlotStore, size: 200, cornerRadius: 16)
                .frame(height: 200)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 10) {
                Text(record.name)
                    .font(.title2.bold())
                if let icon = record.profileIcon {
                    Label("Ikona: \(icon.title)", systemImage: icon.systemImage)
                        .font(.subheadline)
                        .foregroundStyle(icon.tintColor)
                }
                HStack(spacing: 10) {
                    Text("Kolor tury")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(record.glowColor.swiftUIColor)
                        .frame(width: 36, height: 24)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(.secondary.opacity(0.35), lineWidth: 1)
                        }
                }
                Text("❤️ \(CharacterTraitStats.fixedHealth) · 🪙 \(CharacterTraitStats.fixedFinances)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("💪 \(CharacterTraitStats.lobbyBaselineStrength) · ✨ \(CharacterTraitStats.lobbyBaselineAbilities)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(LiquidGlassBackground(accentStroke: settings.accentColor, cornerRadius: 16))

            Button {
                settings.playTapSound()
                isEditing = true
            } label: {
                Text("Zmień postać")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.appProminent)

            Button {
                settings.playTapSound()
                onComplete()
            } label: {
                Text("Gotowe")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.appSecondary)
        }
    }

    private var editorSection: some View {
        VStack(spacing: 18) {
            CreatorPillTextField(
                label: "Imię postaci",
                placeholder: "Np. Aldric",
                text: $name,
                accentColor: settings.accentColor
            )

            appearanceKindPicker

            if appearanceKind == .icon {
                profileIconPicker
            } else {
                CreatorCameraSection(
                    image: $photo,
                    title: "Zdjęcie postaci"
                )
            }

            glowColorSection

            Text("Statystyki startowe: ❤️ \(CharacterTraitStats.fixedHealth) · 🪙 \(CharacterTraitStats.fixedFinances) · 💪 \(CharacterTraitStats.lobbyBaselineStrength) · ✨ \(CharacterTraitStats.lobbyBaselineAbilities)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(LiquidGlassBackground(accentStroke: settings.accentColor, cornerRadius: 14, fillOpacity: 0.1))

            Button {
                settings.playTapSound()
                saveCharacter()
            } label: {
                Text(existingRecord == nil || isEditing ? "Zapisz postać" : "Gotowe")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.appProminent)
            .disabled(!isFormValid)

            if isEditing {
                Button("Anuluj") {
                    settings.playTapSound()
                    loadExistingIfNeeded()
                    isEditing = false
                }
                .buttonStyle(.appSecondary)
            }
        }
        .padding(18)
        .background(LiquidGlassBackground(accentStroke: settings.accentColor, cornerRadius: 18))
    }

    private var appearanceKindPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Wygląd postaci")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Picker("Wygląd", selection: $appearanceKind) {
                Text("Ikona").tag(SlotCharacterAppearanceKind.icon)
                Text("Zdjęcie").tag(SlotCharacterAppearanceKind.photo)
            }
            .pickerStyle(.segmented)
            .onChange(of: appearanceKind) { _, newValue in
                if newValue == .icon {
                    pickDefaultIconIfNeeded()
                }
            }
        }
    }

    private var profileIconPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Wybierz ikonę (każda tylko raz)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 12)], spacing: 12) {
                ForEach(PlayerProfileIcon.allCases) { icon in
                    let isTaken = takenIconIDs.contains(icon.id) && selectedIconID != icon.id
                    Button {
                        guard !isTaken else { return }
                        settings.playTapSound()
                        selectedIconID = icon.id
                    } label: {
                        ZStack {
                            PlayerProfileIconBadge(icon: icon, size: 64)
                                .opacity(isTaken ? 0.28 : 1)
                            if selectedIconID == icon.id {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(settings.accentColor, lineWidth: 3)
                                    .frame(width: 72, height: 72)
                            }
                            if isTaken {
                                Image(systemName: "lock.fill")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isTaken)
                }
            }
        }
    }

    private var glowColorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ColorPicker(
                "Kolor tury (tło podczas twojej tury)",
                selection: Binding(
                    get: { glowColor.swiftUIColor },
                    set: { glowColor.applySwiftUIColor($0) }
                ),
                supportsOpacity: true
            )
            .tint(settings.accentColor)

            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(glowColor.swiftUIColor)
                .frame(height: 44)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.secondary.opacity(0.3), lineWidth: 1)
                }
        }
    }

    private func pickDefaultIconIfNeeded() {
        guard appearanceKind == .icon else { return }
        if let selectedIconID,
           playerSlotStore.isProfileIconAvailable(selectedIconID, excludingSlot: slot.rawValue) {
            return
        }
        selectedIconID = PlayerProfileIcon.allCases.first {
            playerSlotStore.isProfileIconAvailable($0.id, excludingSlot: slot.rawValue)
        }?.id
    }

    private func loadExistingIfNeeded() {
        guard let record = existingRecord else { return }
        name = record.name
        glowColor = record.needsSlotDefaultGlow
            ? PlayerGlowColor.defaultForSlot(slot.rawValue)
            : record.glowColor
        appearanceKind = record.appearanceKind
        selectedIconID = record.profileIconID
        photo = playerSlotStore.appearanceImage(for: slot.rawValue)
        isEditing = false
    }

    private func saveCharacter() {
        switch appearanceKind {
        case .icon:
            guard selectedIconID != nil else { return }
            playerSlotStore.saveCharacter(
                name: name,
                glowColor: glowColor,
                appearanceKind: .icon,
                profileIconID: selectedIconID,
                photo: nil,
                for: slot.rawValue
            )
        case .photo:
            guard let photo else { return }
            playerSlotStore.saveCharacter(
                name: name,
                glowColor: glowColor,
                appearanceKind: .photo,
                profileIconID: nil,
                photo: photo,
                for: slot.rawValue
            )
        }
        if existingRecord != nil && isEditing {
            isEditing = false
            loadExistingIfNeeded()
        } else {
            onComplete()
        }
    }
}
