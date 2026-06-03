//
//  ShopOverlayViews.swift
//  DmdApp
//

import SwiftUI
import UIKit

enum ShopOverlayPhase: Equatable {
    case hidden
    case menu
    case buy
    case sell
}

struct ShopFullScreenOverlay: View {
    @Environment(AppSettings.self) private var settings

    let playerGlow: PlayerGlowColor
    let phase: ShopOverlayPhase
    let playerName: String
    let playerFinances: Int
    let stockItems: [CreatedItem]
    let ownedItems: [CreatedItem]
    let itemSellValue: (CreatedItem) -> Int
    let isItemOwned: (CreatedItem) -> Bool
    let loadImage: (String?) -> UIImage?
    let onSelectBuy: () -> Void
    let onSelectSell: () -> Void
    let onPurchase: (CreatedItem) -> Void
    let onSell: (CreatedItem) -> Void
    let onBack: () -> Void
    let onExit: () -> Void
    var trikiHighlightIndex: Int? = nil

    var body: some View {
        ZStack {
            AppGradientBackground(glow: playerGlow)

            Color.black.opacity(0.38)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(spacing: 16) {
                        switch phase {
                        case .menu:
                            menuContent
                        case .buy:
                            buyContent
                        case .sell:
                            sellContent
                        case .hidden:
                            EmptyView()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            footer
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Label("Sklepik handlowy", systemImage: "cart.fill")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text(playerName)
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Monety: \(playerFinances)")
                .font(.subheadline.bold())
                .foregroundStyle(.yellow)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
        }
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    private var menuContent: some View {
        VStack(spacing: 14) {
            Text("Co chcesz zrobić?")
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                settings.playTapSound()
                onSelectBuy()
            } label: {
                Label("Kup", systemImage: "bag.fill.badge.plus")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
            }
            .buttonStyle(.appProminent)
            .overlay(shopTrikiHighlight(isSelected: trikiHighlightIndex == 0))

            Button {
                settings.playTapSound()
                onSelectSell()
            } label: {
                Label("Sprzedaj", systemImage: "tag.fill")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
            }
            .buttonStyle(.appSecondary)
            .overlay(shopTrikiHighlight(isSelected: trikiHighlightIndex == 1))
        }
    }

    @ViewBuilder
    private var buyContent: some View {
        if stockItems.isEmpty {
            ContentUnavailableView(
                "Brak towaru",
                systemImage: "shippingbox",
                description: Text("Dodaj przedmioty w kreatorze, aby pojawiły się w sklepie.")
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        } else {
            ForEach(Array(stockItems.enumerated()), id: \.element.id) { index, item in
                ShopBuyItemCard(
                    item: item,
                    canAfford: playerFinances >= item.cost,
                    alreadyOwned: isItemOwned(item),
                    loadImage: loadImage,
                    isTrikiSelected: trikiHighlightIndex == index,
                    onPurchase: {
                        onPurchase(item)
                    }
                )
            }
        }
    }

    @ViewBuilder
    private var sellContent: some View {
        if ownedItems.isEmpty {
            ContentUnavailableView(
                "Brak przedmiotów",
                systemImage: "bag",
                description: Text("Gracz nie ma nic do sprzedania.")
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        } else {
            ForEach(Array(ownedItems.enumerated()), id: \.element.id) { index, item in
                ShopSellItemCard(
                    item: item,
                    sellValue: itemSellValue(item),
                    loadImage: loadImage,
                    isTrikiSelected: trikiHighlightIndex == index,
                    onSell: {
                        onSell(item)
                    }
                )
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            if phase == .buy || phase == .sell {
                Button {
                    settings.playTapSound()
                    onBack()
                } label: {
                    Text("Wróć")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.appSecondary)
                .overlay(shopTrikiHighlight(isSelected: trikiFooterBackSelected))
            }

            Button {
                settings.playTapSound()
                onExit()
            } label: {
                Text("Wyjdź")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.appProminent)
            .overlay(shopTrikiHighlight(isSelected: trikiFooterExitSelected))
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(alignment: .top) {
                    Divider().opacity(0.35)
                }
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private var trikiFooterBackSelected: Bool {
        guard let trikiHighlightIndex else { return false }
        switch phase {
        case .buy:
            return trikiHighlightIndex == stockItems.count
        case .sell:
            return trikiHighlightIndex == ownedItems.count
        default:
            return false
        }
    }

    private var trikiFooterExitSelected: Bool {
        guard let trikiHighlightIndex else { return false }
        switch phase {
        case .hidden, .menu:
            return trikiHighlightIndex == 2
        case .buy:
            return trikiHighlightIndex == stockItems.count + 1
        case .sell:
            return trikiHighlightIndex == ownedItems.count + 1
        }
    }

    @ViewBuilder
    private func shopTrikiHighlight(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(
                isSelected ? settings.accentColor.opacity(0.95) : .clear,
                lineWidth: isSelected ? 2.6 : 0
            )
            .shadow(
                color: isSelected ? settings.accentColor.opacity(0.7) : .clear,
                radius: 10
            )
            .animation(.easeInOut(duration: 0.16), value: isSelected)
    }
}

private struct ShopBuyItemCard: View {
    @Environment(AppSettings.self) private var settings

    let item: CreatedItem
    let canAfford: Bool
    let alreadyOwned: Bool
    let loadImage: (String?) -> UIImage?
    var isTrikiSelected: Bool = false
    let onPurchase: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 12) {
                ShopItemImageView(image: loadImage(item.imageFileName), name: item.name)

                Text(item.name)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)

                ShopPriceTile(amount: item.cost)

                if let bonus = item.stats.shopEquipBonus(for: item.resolvedItemKind) {
                    ShopEquipBonusBadge(
                        icon: bonus.icon,
                        label: bonus.label,
                        bonus: bonus.bonus
                    )
                }
            }
            .frame(maxWidth: .infinity)

            Button {
                onPurchase()
            } label: {
                Text(alreadyOwned ? "Posiadany" : "Kup")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.appProminent)
            .disabled(!canAfford || alreadyOwned)
            .overlay(shopCardTrikiHighlight(isSelected: isTrikiSelected))
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            LiquidGlassBackground(accentStroke: .orange, cornerRadius: 16)
        )
    }

    @ViewBuilder
    private func shopCardTrikiHighlight(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(
                isSelected ? settings.accentColor.opacity(0.95) : .clear,
                lineWidth: isSelected ? 2.6 : 0
            )
            .shadow(
                color: isSelected ? settings.accentColor.opacity(0.7) : .clear,
                radius: 10
            )
            .animation(.easeInOut(duration: 0.16), value: isSelected)
    }
}

private struct ShopSellItemCard: View {
    @Environment(AppSettings.self) private var settings

    let item: CreatedItem
    let sellValue: Int
    let loadImage: (String?) -> UIImage?
    var isTrikiSelected: Bool = false
    let onSell: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 12) {
                ShopItemImageView(image: loadImage(item.imageFileName), name: item.name)

                Text(item.name)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)

                ShopPriceTile(amount: sellValue)

                if let bonus = item.stats.shopEquipBonus(for: item.resolvedItemKind) {
                    ShopEquipBonusBadge(
                        icon: bonus.icon,
                        label: bonus.label,
                        bonus: bonus.bonus
                    )
                }
            }
            .frame(maxWidth: .infinity)

            Button {
                onSell()
            } label: {
                Text("Sprzedaj")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.appSecondary)
            .overlay(shopCardTrikiHighlight(isSelected: isTrikiSelected))
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            LiquidGlassBackground(accentStroke: .yellow, cornerRadius: 16)
        )
    }

    @ViewBuilder
    private func shopCardTrikiHighlight(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(
                isSelected ? settings.accentColor.opacity(0.95) : .clear,
                lineWidth: isSelected ? 2.6 : 0
            )
            .shadow(
                color: isSelected ? settings.accentColor.opacity(0.7) : .clear,
                radius: 10
            )
            .animation(.easeInOut(duration: 0.16), value: isSelected)
    }
}

private struct ShopEquipBonusBadge: View {
    let icon: String
    let label: String
    let bonus: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(accentColor)
            Text("+\(bonus) \(label)")
                .font(.subheadline.bold())
                .monospacedDigit()
                .foregroundStyle(accentColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(accentColor.opacity(0.35), lineWidth: 1)
        }
        .accessibilityLabel("Zwiększa \(label.lowercased()) o \(bonus)")
    }

    private var accentColor: Color {
        switch label {
        case "Siła": .red
        case "Zdrowie": .green
        default: .secondary
        }
    }
}

private struct ShopItemImageView: View {
    let image: UIImage?
    let name: String

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color.white.opacity(0.06)
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 120, height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
        )
        .accessibilityLabel(name)
    }
}

private struct ShopPriceTile: View {
    let amount: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "dollarsign.circle.fill")
                .foregroundStyle(.yellow)
            Text("\(amount)")
                .font(.title3.bold())
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
