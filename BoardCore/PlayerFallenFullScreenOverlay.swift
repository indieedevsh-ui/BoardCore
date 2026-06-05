//
//  PlayerFallenFullScreenOverlay.swift
//  BoardCore
//

import SwiftUI
import UIKit

struct PlayerFallenSummary: Identifiable, Equatable {
    let id: UUID
    let playerNumber: Int
    let displayTitle: String
    let lobbySlotNumber: Int?
    let characterQRCode: String?
    let bossFightCount: Int
    let abilityCount: Int
    let finances: Int
}

struct PlayerFallenFullScreenOverlay: View {
    @Environment(AppSettings.self) private var settings
    @Environment(PlayerSlotStore.self) private var playerSlotStore
    @Environment(CreatorStore.self) private var creatorStore

    let summary: PlayerFallenSummary
    var isTrikiSelected: Bool = false
    let onContinue: () -> Void

    @State private var backdropOpacity: Double = 0
    @State private var contentOpacity: Double = 0
    @State private var contentOffset: CGFloat = 24

    private var playerGlow: PlayerGlowColor {
        if let slot = summary.lobbySlotNumber,
           let record = playerSlotStore.characterRecord(for: slot) {
            return record.needsSlotDefaultGlow
                ? PlayerGlowColor.defaultForSlot(slot)
                : record.glowColor
        }
        return PlayerGlowColor.defaultForSlot(summary.lobbySlotNumber ?? 1)
    }

    private var profileImage: UIImage? {
        if let slot = summary.lobbySlotNumber,
           let image = playerSlotStore.appearanceImage(for: slot) {
            return image
        }
        if let qrCode = summary.characterQRCode,
           let character = creatorStore.character(withNumericId: qrCode)
            ?? creatorStore.character(matching: qrCode) {
            return creatorStore.loadImage(fileName: character.imageFileName)
        }
        return nil
    }

    var body: some View {
        ZStack {
            AppGradientBackground(glow: playerGlow)
                .opacity(backdropOpacity)

            Color.black
                .opacity(0.38 * backdropOpacity)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                VStack(spacing: 22) {
                    Text("Gracz \(summary.playerNumber) poległ")
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)

                    profileAvatar
                        .frame(width: 120, height: 120)

                    Text(summary.displayTitle)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.92))
                        .multilineTextAlignment(.center)

                    VStack(spacing: 14) {
                        fallenStatRow(
                            icon: "shield.lefthalf.filled",
                            title: "Walki z bossami",
                            value: "\(summary.bossFightCount)"
                        )
                        fallenStatRow(
                            icon: "sparkles",
                            title: "Zebrane zdolności",
                            value: "\(summary.abilityCount)"
                        )
                        fallenStatRow(
                            icon: "dollarsign.circle.fill",
                            title: "Fundusze",
                            value: "\(summary.finances) monet"
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 28)
                .opacity(contentOpacity)
                .offset(y: contentOffset)

                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .safeAreaInset(edge: .bottom, spacing: 16) {
            Button {
                settings.playTapSound()
                onContinue()
            } label: {
                Text("Przejdź dalej")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.appProminent)
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isTrikiSelected ? settings.accentColor.opacity(0.95) : .clear,
                        lineWidth: isTrikiSelected ? 2.6 : 0
                    )
                    .shadow(
                        color: isTrikiSelected ? settings.accentColor.opacity(0.7) : .clear,
                        radius: 10
                    )
                    .animation(.easeInOut(duration: 0.16), value: isTrikiSelected)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 8)
            .opacity(contentOpacity)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.45)) {
                backdropOpacity = 1
            }
            withAnimation(.spring(response: 0.58, dampingFraction: 0.84).delay(0.12)) {
                contentOpacity = 1
                contentOffset = 0
            }
            HapticManager.playStatReveal(intensity: settings.hapticIntensity * 0.75)
            SoundManager.playStatsRevealStep(volume: settings.volume)
        }
    }

    @ViewBuilder
    private var profileAvatar: some View {
        if let profileImage {
            Image(uiImage: profileImage)
                .resizable()
                .scaledToFill()
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 2))
        } else if let slot = summary.lobbySlotNumber,
                  let record = playerSlotStore.characterRecord(for: slot),
                  let icon = record.profileIcon {
            PlayerProfileIconBadge(icon: icon, size: 120)
        } else {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.08))
                Image(systemName: "figure.stand")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(settings.accentColor.opacity(0.85))
            }
        }
    }

    private func fallenStatRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(settings.accentColor)
                .frame(width: 28)

            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(.white)
        }
    }
}
