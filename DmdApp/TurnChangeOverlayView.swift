//
//  TurnChangeOverlayView.swift
//  DmdApp
//

import SwiftUI
import UIKit

struct TurnChangePresentation: Identifiable, Equatable {
    let id = UUID()
    let playerNumber: Int
    let playerName: String
    let factionName: String
    let roundNumber: Int
    let isNewRound: Bool
    let lobbySlotNumber: Int?
    let characterQRCode: String?
    let glowColor: PlayerGlowColor
}

struct TurnChangeFullScreenOverlay: View {
    @Environment(AppSettings.self) private var settings
    @Environment(PlayerSlotStore.self) private var playerSlotStore
    @Environment(CreatorStore.self) private var creatorStore

    let presentation: TurnChangePresentation
    let onBeginGlowTransition: () -> Void
    let onComplete: () -> Void

    private var overlayAccent: Color {
        presentation.glowColor.accentColor
    }

    @State private var backdropOpacity: Double = 0
    @State private var ringScale: CGFloat = 0.35
    @State private var ringOpacity: Double = 0
    @State private var glowOpacity: Double = 0
    @State private var numberScale: CGFloat = 0.5
    @State private var numberOpacity: Double = 0
    @State private var profileScale: CGFloat = 0.55
    @State private var profileOpacity: Double = 0
    @State private var titleOpacity: Double = 0
    @State private var titleOffset: CGFloat = 28
    @State private var subtitleOpacity: Double = 0
    @State private var subtitleOffset: CGFloat = 20
    @State private var roundBadgeOpacity: Double = 0
    @State private var roundBadgeScale: CGFloat = 0.8
    @State private var dismissTask: Task<Void, Never>?

    private var profileImage: UIImage? {
        if let slot = presentation.lobbySlotNumber,
           let image = playerSlotStore.appearanceImage(for: slot) {
            return image
        }
        if let qrCode = presentation.characterQRCode,
           let character = creatorStore.character(withNumericId: qrCode)
            ?? creatorStore.character(matching: qrCode) {
            return creatorStore.loadImage(fileName: character.imageFileName)
        }
        return nil
    }

    var body: some View {
        ZStack {
            AppGradientBackground(glow: presentation.glowColor)
                .opacity(backdropOpacity)

            Color.black
                .opacity(0.32 * backdropOpacity)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer(minLength: 0)

                if presentation.isNewRound {
                    Text("Runda \(presentation.roundNumber)")
                        .font(.caption.bold())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(overlayAccent.opacity(0.22), in: Capsule())
                        .overlay(Capsule().strokeBorder(overlayAccent.opacity(0.45), lineWidth: 1))
                        .scaleEffect(roundBadgeScale)
                        .opacity(roundBadgeOpacity)
                }

                Text("\(presentation.playerNumber)")
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, overlayAccent.opacity(0.92)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .scaleEffect(numberScale)
                    .opacity(numberOpacity)

                ZStack {
                    Circle()
                        .fill(overlayAccent.opacity(glowOpacity * 0.38))
                        .frame(width: 210, height: 210)
                        .blur(radius: 22)

                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    overlayAccent,
                                    overlayAccent.opacity(0.55),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 4
                        )
                        .frame(width: 156, height: 156)
                        .scaleEffect(ringScale)
                        .opacity(ringOpacity)

                    profileAvatar
                        .frame(width: 136, height: 136)
                        .scaleEffect(profileScale)
                        .opacity(profileOpacity)
                }

                VStack(spacing: 10) {
                    Text("Tura gracza \(presentation.playerNumber)")
                        .font(.title.bold())
                        .multilineTextAlignment(.center)

                    Text(presentation.playerName)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.95))
                        .multilineTextAlignment(.center)

                    Text(presentation.factionName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 28)
                .opacity(titleOpacity)
                .offset(y: titleOffset)

                Text("Przygotuj się na swoją turę")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .opacity(subtitleOpacity)
                    .offset(y: subtitleOffset)

                Spacer(minLength: 0)
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .onAppear {
            runAnimation()
        }
        .onDisappear {
            dismissTask?.cancel()
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
        } else if let slot = presentation.lobbySlotNumber,
                  let record = playerSlotStore.characterRecord(for: slot),
                  let icon = record.profileIcon {
            PlayerProfileIconBadge(icon: icon, size: 136)
        } else {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.08))
                Image(systemName: "figure.stand")
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(overlayAccent.opacity(0.85))
            }
        }
    }

    private func runAnimation() {
        onBeginGlowTransition()
        withAnimation(.easeInOut(duration: 0.5)) {
            backdropOpacity = 1
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }

            if presentation.isNewRound {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
                    roundBadgeOpacity = 1
                    roundBadgeScale = 1
                }
            }

            HapticManager.playStatReveal(intensity: settings.hapticIntensity * 0.85)
            SoundManager.playStatsRevealStep(volume: settings.volume)

            withAnimation(.spring(response: 0.58, dampingFraction: 0.62)) {
                numberScale = 1.06
                numberOpacity = 1
            }

            withAnimation(.spring(response: 0.42, dampingFraction: 0.82).delay(0.06)) {
                numberScale = 1
            }

            withAnimation(.spring(response: 0.58, dampingFraction: 0.62).delay(0.08)) {
                ringScale = 1.06
                ringOpacity = 1
                glowOpacity = 1
                profileScale = 1.06
                profileOpacity = 1
            }

            withAnimation(.spring(response: 0.42, dampingFraction: 0.82).delay(0.16)) {
                ringScale = 1
                profileScale = 1
            }

            withAnimation(.spring(response: 0.62, dampingFraction: 0.84).delay(0.22)) {
                titleOpacity = 1
                titleOffset = 0
            }

            withAnimation(.spring(response: 0.58, dampingFraction: 0.86).delay(0.38)) {
                subtitleOpacity = 1
                subtitleOffset = 0
            }

            withAnimation(.easeInOut(duration: 0.9).delay(0.5)) {
                glowOpacity = 0.4
            }
        }

        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(2600))
            guard !Task.isCancelled else { return }

            withAnimation(.easeInOut(duration: 0.38)) {
                backdropOpacity = 0
                ringOpacity = 0
                numberOpacity = 0
                profileOpacity = 0
                titleOpacity = 0
                subtitleOpacity = 0
                roundBadgeOpacity = 0
            }

            try? await Task.sleep(for: .milliseconds(380))
            guard !Task.isCancelled else { return }
            onComplete()
        }
    }
}
