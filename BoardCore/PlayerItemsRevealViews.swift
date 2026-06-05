//
//  PlayerItemsRevealViews.swift
//  BoardCore
//

import SwiftUI
import UIKit

struct PlayerItemsRevealSection: View {
    @Environment(AppSettings.self) private var settings

    let items: [CreatedItem]
    let playerID: UUID
    let playerGlow: PlayerGlowColor
    var playerName: String?
    var playerSlot: PlayerSlotCode?
    let loadImage: (String?) -> UIImage?
    let itemMarketValue: (CreatedItem) -> Int
    let equippedItemIDs: Set<UUID>
    let onToggleEquip: (CreatedItem) -> EquipmentStatBoostPresentation?
    var isTrikiSelected: Bool = false
    var trikiHoldChargeProgress: Double = 0
    @Binding var isScreenPresented: Bool

    var body: some View {
        Button {
            settings.playStatsRevealSound()
            isScreenPresented = true
        } label: {
            Label("Pokaż przedmioty", systemImage: "bag.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.appSecondary)
        .trikiSelectableHighlight(
            isSelected: isTrikiSelected,
            chargeProgress: isTrikiSelected ? trikiHoldChargeProgress : 0
        )
        .onChange(of: playerID) { _, _ in
            isScreenPresented = false
        }
    }
}

struct PlayerItemsFullScreenView: View {
    @Environment(AppSettings.self) private var settings

    let playerGlow: PlayerGlowColor
    let items: [CreatedItem]
    let playerName: String?
    let playerSlot: PlayerSlotCode?
    let loadImage: (String?) -> UIImage?
    let itemMarketValue: (CreatedItem) -> Int
    let equippedItemIDs: Set<UUID>
    let onToggleEquip: (CreatedItem) -> EquipmentStatBoostPresentation?
    let onExit: () -> Void
    var trikiHighlightItemID: UUID? = nil
    var trikiExitHighlighted: Bool = false
    var trikiHoldChargeProgress: Double = 0

    @State private var revealedCount = 0
    @State private var revealTask: Task<Void, Never>?
    @State private var equipNotice: String?
    @State private var statBoostPresentation: EquipmentStatBoostPresentation?

    private var equippableItems: [CreatedItem] {
        items.filter(\.itemKind.isEquippable)
    }

    private var otherItems: [CreatedItem] {
        items.filter { !$0.itemKind.isEquippable }
    }

    var body: some View {
        ZStack {
            AppGradientBackground(glow: playerGlow)

            if let statBoostPresentation {
                EquipmentStatBoostOverlay(presentation: statBoostPresentation) {
                    self.statBoostPresentation = nil
                }
                .zIndex(10)
            }

            VStack(spacing: 0) {
                header

                if items.isEmpty {
                    ContentUnavailableView(
                        "Brak przedmiotów",
                        systemImage: "bag",
                        description: Text("Gracz nie posiada jeszcze żadnych przedmiotów.")
                    )
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 18) {
                            equippedSummarySection

                            if !equippableItems.isEmpty {
                                inventorySection(
                                    title: "Ekwipunek — stuknij, aby założyć / zdjąć",
                                    items: equippableItems
                                )
                            }

                            if !otherItems.isEmpty {
                                inventorySection(
                                    title: "Inne przedmioty",
                                    items: otherItems
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                        .animation(.spring(response: 0.52, dampingFraction: 0.82), value: revealedCount)
                    }
                }

                Button {
                    onExit()
                } label: {
                    Text("Wyjdź")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.appProminent)
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 24)
                .trikiSelectableHighlight(
                    isSelected: trikiExitHighlighted,
                    chargeProgress: trikiExitHighlighted ? trikiHoldChargeProgress : 0
                )
            }
        }
        .onAppear {
            beginReveal()
        }
        .onDisappear {
            revealTask?.cancel()
            revealedCount = 0
        }
        .alert("Ekwipunek", isPresented: Binding(
            get: { equipNotice != nil },
            set: { if !$0 { equipNotice = nil } }
        )) {
            Button("OK", role: .cancel) {
                settings.playTapSound()
                equipNotice = nil
            }
        } message: {
            if let equipNotice {
                Text(equipNotice)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("Przedmioty")
                .font(.largeTitle.bold())

            if let playerName, !playerName.isEmpty {
                Text(playerName)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Text("Można założyć jedną broń i jeden pancerz (hełm lub tarcza liczą się jako pancerz).")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private var equippedSummarySection: some View {
        let equipped = items.filter { equippedItemIDs.contains($0.id) }
        if !equipped.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Założone")
                    .font(.headline)

                ForEach(equipped) { item in
                    HStack(spacing: 8) {
                        Image(systemName: item.resolvedItemKind.icon)
                        Text(item.name)
                            .font(.subheadline.bold())
                        Spacer()
                        Text(item.resolvedItemKind.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(16)
            .background(
                LiquidGlassBackground(accentStroke: .green.opacity(0.8), cornerRadius: 16)
            )
        }
    }

    @ViewBuilder
    private func inventorySection(title: String, items sectionItems: [CreatedItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            ForEach(Array(sectionItems.enumerated()), id: \.element.id) { index, item in
                let globalIndex = items.firstIndex(where: { $0.id == item.id }) ?? index
                if globalIndex < revealedCount {
                    PlayerItemRevealRow(
                        item: item,
                        marketValue: itemMarketValue(item),
                        image: loadImage(item.imageFileName),
                        isEquipped: equippedItemIDs.contains(item.id),
                        isEquippable: item.resolvedItemKind.isEquippable,
                        onToggleEquip: {
                            handleToggleEquip(item)
                        }
                    )
                    .trikiSelectableHighlight(
                        isSelected: trikiHighlightItemID == item.id,
                        chargeProgress: trikiHighlightItemID == item.id ? trikiHoldChargeProgress : 0
                    )
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .opacity
                        )
                    )
                }
            }
        }
    }

    private func handleToggleEquip(_ item: CreatedItem) {
        guard item.resolvedItemKind.isEquippable else {
            settings.playTapSound()
            equipNotice = "Pędzel nie zakłada się do slotów ekwipunku."
            return
        }
        settings.playTapSound()
        if let presentation = onToggleEquip(item) {
            statBoostPresentation = presentation
        }
    }

    private func beginReveal() {
        revealTask?.cancel()
        revealedCount = 0
        guard !items.isEmpty else { return }

        revealTask = Task { @MainActor in
            for index in items.indices {
                guard !Task.isCancelled else { return }
                if index > 0 {
                    try? await Task.sleep(for: .milliseconds(340))
                }
                guard !Task.isCancelled else { return }

                HapticManager.playStatReveal(intensity: settings.hapticIntensity * 0.5)
                SoundManager.playStatsRevealStep(volume: settings.volume)
                withAnimation(.spring(response: 0.54, dampingFraction: 0.8)) {
                    revealedCount = index + 1
                }
            }
        }
    }
}

private struct PlayerItemRevealRow: View {
    @Environment(AppSettings.self) private var settings

    let item: CreatedItem
    let marketValue: Int
    let image: UIImage?
    let isEquipped: Bool
    let isEquippable: Bool
    let onToggleEquip: () -> Void

    @State private var rowScale: CGFloat = 0.9
    @State private var rowOpacity: Double = 0
    @State private var rowOffset: CGFloat = -28

    private var accentStroke: Color {
        if isEquipped { return .green }
        switch item.resolvedItemKind {
        case .brush: return .cyan
        case .armor: return .gray
        case .weapon: return .orange
        case .helmet, .shield: return .gray
        }
    }

    var body: some View {
        Button {
            onToggleEquip()
        } label: {
            rowContent
        }
        .buttonStyle(.plain)
        .disabled(!isEquippable)
        .scaleEffect(rowScale)
        .opacity(rowOpacity)
        .offset(y: rowOffset)
        .onAppear {
            rowScale = 0.9
            rowOpacity = 0
            rowOffset = -28
            withAnimation(.spring(response: 0.62, dampingFraction: 0.82)) {
                rowScale = 1
                rowOpacity = 1
                rowOffset = 0
            }
        }
    }

    private var rowContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                itemThumbnail

                VStack(alignment: .leading, spacing: 6) {
                    Text(item.name)
                        .font(.title3.bold())
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(.primary)

                    Label(item.resolvedItemKind.displayName, systemImage: item.resolvedItemKind.icon)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                if isEquipped {
                    Label("Założony", systemImage: "checkmark.circle.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                } else if isEquippable {
                    Text("Załóż")
                        .font(.caption.bold())
                        .foregroundStyle(settings.accentColor)
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundStyle(.yellow)
                Text("\(marketValue) monet")
                    .font(.subheadline.bold())
                    .monospacedDigit()
                Text("· katalog \(item.cost)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            VStack(spacing: 8) {
                ForEach(item.stats.itemShopStatRows(for: item.resolvedItemKind), id: \.label) { row in
                    HStack(spacing: 10) {
                        Image(systemName: row.icon)
                            .frame(width: 22)
                            .foregroundStyle(.secondary)
                        Text(row.label)
                            .font(.subheadline)
                        Spacer()
                        Text(row.showsPercent ? "\(row.value)%" : "+\(row.value)")
                            .font(.subheadline.bold())
                            .monospacedDigit()
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(
            LiquidGlassBackground(
                accentStroke: accentStroke,
                cornerRadius: 18
            )
        )
    }

    @ViewBuilder
    private var itemThumbnail: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color.white.opacity(0.06)
                    Image(systemName: item.resolvedItemKind.icon)
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
        )
    }
}
