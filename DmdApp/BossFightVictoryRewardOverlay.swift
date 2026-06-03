//
//  BossFightVictoryRewardOverlay.swift
//  DmdApp
//

import SwiftUI
import UIKit

struct BossFightVictoryRewardStep: Identifiable, Equatable {
    let id: UUID
    let playerID: UUID
    let playerName: String
    let roleLabel: String
    let lobbySlotNumber: Int?
    let characterQRCode: String?
    let financesBefore: Int
    let rewardAmount: Int
    let rewardPercentLabel: String
}

struct BossFightVictoryPresentation: Equatable {
    let steps: [BossFightVictoryRewardStep]
    let outcome: BossFightCombatOutcome

    var hasSupporters: Bool {
        steps.count > 1
    }
}

struct BossFightVictoryRewardOverlay: View {
    @Environment(AppSettings.self) private var settings
    @Environment(PlayerSlotStore.self) private var playerSlotStore
    @Environment(CreatorStore.self) private var creatorStore

    let presentation: BossFightVictoryPresentation
    let onComplete: () -> Void

    @State private var backdropOpacity: Double = 0
    @State private var contentOpacity: Double = 0
    @State private var contentOffset: CGFloat = 0
    @State private var contentScale: CGFloat = 1
    @State private var currentStepIndex = 0
    @State private var displayedFinances: Int = 0
    @State private var showBonus = false
    @State private var bonusOpacity: Double = 0
    @State private var showContinueButton = false
    @State private var sequenceTask: Task<Void, Never>?

    private var currentStep: BossFightVictoryRewardStep? {
        presentation.steps[safe: currentStepIndex]
    }

    private var currentStepGlow: PlayerGlowColor {
        guard let step = currentStep else {
            return PlayerGlowColor.defaultForSlot(1)
        }
        return glow(for: step)
    }

    private var overlayAccent: Color {
        currentStepGlow.accentColor
    }

    var body: some View {
        ZStack {
            AppGradientBackground(glow: currentStepGlow)
                .opacity(backdropOpacity)
                .id(currentStepIndex)
                .animation(.easeInOut(duration: 0.45), value: currentStepIndex)

            Color.black
                .opacity(0.38 * backdropOpacity)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                if let step = currentStep {
                    VStack(spacing: 22) {
                        Text("Boss został pokonany")
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)

                        profileAvatar(for: step)
                            .frame(width: 120, height: 120)

                        Text(step.playerName)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.92))

                        Text(step.roleLabel)
                            .font(.caption.bold())
                            .foregroundStyle(overlayAccent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(overlayAccent.opacity(0.18), in: Capsule())

                        if showContinueButton {
                            continueButton
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        financesBlock(for: step)
                    }
                    .padding(.horizontal, 28)
                    .opacity(contentOpacity)
                    .offset(y: contentOffset)
                    .scaleEffect(contentScale)
                    .id(step.id)
                }

                Spacer(minLength: 0)
            }
            .safeAreaPadding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 0.45)) {
                backdropOpacity = 1
                contentOpacity = 1
            }
            HapticManager.playStatReveal(intensity: settings.hapticIntensity * 0.85)
            SoundManager.playStatsRevealStep(volume: settings.volume)
            runStepSequence()
        }
        .onDisappear {
            sequenceTask?.cancel()
        }
    }

    @ViewBuilder
    private func profileAvatar(for step: BossFightVictoryRewardStep) -> some View {
        if let image = profileImage(for: step) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 2))
        } else if let slot = step.lobbySlotNumber,
                  let record = playerSlotStore.characterRecord(for: slot),
                  let icon = record.profileIcon {
            PlayerProfileIconBadge(icon: icon, size: 120)
        } else {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.08))
                Image(systemName: "figure.stand")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(overlayAccent.opacity(0.85))
            }
        }
    }

    private func glow(for step: BossFightVictoryRewardStep) -> PlayerGlowColor {
        if let slot = step.lobbySlotNumber,
           let record = playerSlotStore.characterRecord(for: slot) {
            return record.needsSlotDefaultGlow
                ? PlayerGlowColor.defaultForSlot(slot)
                : record.glowColor
        }
        return PlayerGlowColor.defaultForSlot(step.lobbySlotNumber ?? 1)
    }

    private func profileImage(for step: BossFightVictoryRewardStep) -> UIImage? {
        if let slot = step.lobbySlotNumber,
           let image = playerSlotStore.appearanceImage(for: slot) {
            return image
        }
        if let qrCode = step.characterQRCode,
           let character = creatorStore.character(withNumericId: qrCode)
            ?? creatorStore.character(matching: qrCode) {
            return creatorStore.loadImage(fileName: character.imageFileName)
        }
        return nil
    }

    private var continueButton: some View {
        Button {
            settings.playTapSound()
            onComplete()
        } label: {
            Text("Kontynuuj")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(.appProminent)
    }

    private func financesBlock(for step: BossFightVictoryRewardStep) -> some View {
        VStack(spacing: 10) {
            Text("Fundusze")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(displayedFinances)")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(.white)

                Text("monet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if showBonus {
                VStack(spacing: 4) {
                    Text("+\(step.rewardAmount)")
                        .font(.title2.bold())
                        .foregroundStyle(.green)
                    Text("+\(step.rewardPercentLabel) z nagrody")
                        .font(.caption.bold())
                        .foregroundStyle(.green.opacity(0.9))
                }
                .opacity(bonusOpacity)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func runStepSequence() {
        sequenceTask?.cancel()
        sequenceTask = Task { @MainActor in
            for index in presentation.steps.indices {
                guard !Task.isCancelled else { return }
                currentStepIndex = index
                await animateCurrentStep()
                guard !Task.isCancelled else { return }

                if index < presentation.steps.count - 1 {
                    withAnimation(.easeInOut(duration: 0.65)) {
                        contentOpacity = 0
                        contentOffset = 18
                        contentScale = 0.93
                    }
                    try? await Task.sleep(for: .milliseconds(720))
                    guard !Task.isCancelled else { return }
                    resetStepAnimationState(for: presentation.steps[index + 1])
                    contentOffset = -22
                    contentScale = 0.94
                    withAnimation(.spring(response: 0.82, dampingFraction: 0.9)) {
                        contentOpacity = 1
                        contentOffset = 0
                        contentScale = 1
                    }
                    try? await Task.sleep(for: .milliseconds(520))
                }
            }

            guard !Task.isCancelled else { return }

            if presentation.hasSupporters {
                withAnimation(.spring(response: 0.48, dampingFraction: 0.84)) {
                    showContinueButton = true
                }
            } else {
                try? await Task.sleep(for: .milliseconds(700))
                guard !Task.isCancelled else { return }
                onComplete()
            }
        }
    }

    private func resetStepAnimationState(for step: BossFightVictoryRewardStep) {
        displayedFinances = step.financesBefore
        showBonus = false
        bonusOpacity = 0
    }

    private func animateCurrentStep() async {
        guard let step = presentation.steps[safe: currentStepIndex] else { return }

        displayedFinances = step.financesBefore
        showBonus = false
        bonusOpacity = 0

        try? await Task.sleep(for: .milliseconds(1050))
        guard !Task.isCancelled else { return }

        showBonus = true
        withAnimation(.spring(response: 0.52, dampingFraction: 0.78)) {
            bonusOpacity = 1
        }
        HapticManager.playStatReveal(intensity: settings.hapticIntensity * 0.65)
        settings.playTapSound()

        try? await Task.sleep(for: .milliseconds(1650))
        guard !Task.isCancelled else { return }

        withAnimation(.easeOut(duration: 0.42)) {
            bonusOpacity = 0
        }
        try? await Task.sleep(for: .milliseconds(420))
        guard !Task.isCancelled else { return }

        showBonus = false
        withAnimation(.spring(response: 0.68, dampingFraction: 0.86)) {
            displayedFinances = step.financesBefore + step.rewardAmount
        }
        HapticManager.playStatReveal(intensity: settings.hapticIntensity * 0.75)

        try? await Task.sleep(for: .milliseconds(1100))
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
