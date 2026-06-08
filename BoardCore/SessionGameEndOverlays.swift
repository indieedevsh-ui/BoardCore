//
//  SessionGameEndOverlays.swift
//  BoardCore
//

import SwiftUI

enum SessionEndPhase: String, Codable, Equatable {
    case none
    case winnerReveal
    case rankings
}

struct SessionFinalTurnIntroOverlay: View {
    @Environment(AppSettings.self) private var settings

    let playerGlow: PlayerGlowColor
    let onComplete: () -> Void

    @State private var backdropOpacity: Double = 0
    @State private var iconScale: CGFloat = 0.35
    @State private var iconOpacity: Double = 0
    @State private var titleOpacity: Double = 0
    @State private var titleOffset: CGFloat = 18
    @State private var subtitleOpacity: Double = 0
    @State private var subtitleOffset: CGFloat = 14
    @State private var dismissTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            AppGradientBackground(glow: playerGlow)
                .opacity(backdropOpacity)

            Color.black
                .opacity(0.45 * backdropOpacity)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "flag.checkered.2.crossed.fill")
                    .font(.system(size: 84, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(playerGlow.accentColor)
                    .scaleEffect(iconScale)
                    .opacity(iconOpacity)

                Text("Ostatnia tura do zakończenia rozgrywki")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .opacity(titleOpacity)
                    .offset(y: titleOffset)

                Text("Każdy gracz kończy jeszcze jedną turę — potem podsumowanie.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .opacity(subtitleOpacity)
                    .offset(y: subtitleOffset)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .onAppear { runAnimation() }
        .onDisappear { dismissTask?.cancel() }
    }

    private func runAnimation() {
        withAnimation(.easeInOut(duration: 0.55)) {
            backdropOpacity = 1
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(160))
            guard !Task.isCancelled else { return }

            HapticManager.playStatReveal(intensity: settings.hapticIntensity)
            SoundManager.playTap(volume: settings.volume)

            withAnimation(.spring(response: 0.56, dampingFraction: 0.68)) {
                iconScale = 1.06
                iconOpacity = 1
            }

            withAnimation(.spring(response: 0.42, dampingFraction: 0.84).delay(0.1)) {
                iconScale = 1
            }

            withAnimation(.spring(response: 0.58, dampingFraction: 0.84).delay(0.2)) {
                titleOpacity = 1
                titleOffset = 0
            }

            withAnimation(.spring(response: 0.58, dampingFraction: 0.84).delay(0.34)) {
                subtitleOpacity = 1
                subtitleOffset = 0
            }
        }

        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(2600))
            guard !Task.isCancelled else { return }

            withAnimation(.easeInOut(duration: 0.38)) {
                backdropOpacity = 0
                iconOpacity = 0
                titleOpacity = 0
                subtitleOpacity = 0
            }

            try? await Task.sleep(for: .milliseconds(380))
            guard !Task.isCancelled else { return }
            onComplete()
        }
    }
}

struct SessionWinnerRevealOverlay: View {
    @Environment(AppSettings.self) private var settings

    let playerGlow: PlayerGlowColor
    let winnerName: String
    let detail: String
    let onComplete: () -> Void

    @State private var backdropOpacity: Double = 0
    @State private var trophyScale: CGFloat = 0.4
    @State private var trophyOpacity: Double = 0
    @State private var titleOpacity: Double = 0
    @State private var nameOpacity: Double = 0
    @State private var nameOffset: CGFloat = 20
    @State private var detailOpacity: Double = 0
    @State private var dismissTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            AppGradientBackground(glow: playerGlow)
                .opacity(backdropOpacity)

            Color.black
                .opacity(0.48 * backdropOpacity)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 92, weight: .semibold))
                    .foregroundStyle(.yellow)
                    .scaleEffect(trophyScale)
                    .opacity(trophyOpacity)
                    .shadow(color: .yellow.opacity(0.35), radius: 18, y: 8)

                Text("Zwycięzca rozgrywki")
                    .font(.title2.bold())
                    .foregroundStyle(.secondary)
                    .opacity(titleOpacity)

                Text(winnerName)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .opacity(nameOpacity)
                    .offset(y: nameOffset)

                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .opacity(detailOpacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .onAppear { runAnimation() }
        .onDisappear { dismissTask?.cancel() }
    }

    private func runAnimation() {
        settings.playStatsRevealSound()

        withAnimation(.easeInOut(duration: 0.55)) {
            backdropOpacity = 1
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }

            HapticManager.playStatReveal(intensity: settings.hapticIntensity)

            withAnimation(.spring(response: 0.58, dampingFraction: 0.68)) {
                trophyScale = 1.08
                trophyOpacity = 1
            }

            withAnimation(.spring(response: 0.42, dampingFraction: 0.84).delay(0.12)) {
                trophyScale = 1
            }

            withAnimation(.spring(response: 0.58, dampingFraction: 0.84).delay(0.24)) {
                titleOpacity = 1
            }

            withAnimation(.spring(response: 0.58, dampingFraction: 0.84).delay(0.36)) {
                nameOpacity = 1
                nameOffset = 0
            }

            withAnimation(.spring(response: 0.58, dampingFraction: 0.84).delay(0.48)) {
                detailOpacity = 1
            }
        }

        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(3400))
            guard !Task.isCancelled else { return }

            withAnimation(.easeInOut(duration: 0.38)) {
                backdropOpacity = 0
                trophyOpacity = 0
                titleOpacity = 0
                nameOpacity = 0
                detailOpacity = 0
            }

            try? await Task.sleep(for: .milliseconds(380))
            guard !Task.isCancelled else { return }
            onComplete()
        }
    }
}

enum SessionWinnerResolver {
    static func pickWinner(
        from contenders: [PlayerCharacter],
        stats: [UUID: PlayerRuntimeStats],
        itemValuesByPlayer: [UUID: Int],
        bossFightCounts: [UUID: Int],
        firstToGoalOrder: [UUID]
    ) -> PlayerCharacter? {
        guard !contenders.isEmpty else { return nil }

        let orderIndex: [UUID: Int] = Dictionary(
            uniqueKeysWithValues: firstToGoalOrder.enumerated().map { ($0.element, $0.offset) }
        )

        let sorted = contenders.sorted { lhs, rhs in
            let leftFinance = totalFinances(
                playerID: lhs.id,
                stats: stats,
                itemValue: itemValuesByPlayer[lhs.id] ?? 0
            )
            let rightFinance = totalFinances(
                playerID: rhs.id,
                stats: stats,
                itemValue: itemValuesByPlayer[rhs.id] ?? 0
            )
            if leftFinance != rightFinance { return leftFinance > rightFinance }

            let leftBoss = bossFightCounts[lhs.id] ?? 0
            let rightBoss = bossFightCounts[rhs.id] ?? 0
            if leftBoss != rightBoss { return leftBoss > rightBoss }

            let leftStrength = stats[lhs.id]?.strength ?? 0
            let rightStrength = stats[rhs.id]?.strength ?? 0
            if leftStrength != rightStrength { return leftStrength > rightStrength }

            let leftOrder = orderIndex[lhs.id] ?? Int.max
            let rightOrder = orderIndex[rhs.id] ?? Int.max
            if leftOrder != rightOrder { return leftOrder < rightOrder }

            return lhs.displayTitle < rhs.displayTitle
        }

        return sorted.first
    }

    private static func totalFinances(
        playerID: UUID,
        stats: [UUID: PlayerRuntimeStats],
        itemValue: Int
    ) -> Int {
        (stats[playerID]?.finances ?? 0) + itemValue
    }
}
