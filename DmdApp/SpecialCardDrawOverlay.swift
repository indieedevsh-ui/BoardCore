//
//  SpecialCardDrawOverlay.swift
//  DmdApp
//

import SwiftUI

struct SpecialCardDrawOverlay: View {
    @Environment(AppSettings.self) private var settings

    let playerGlow: PlayerGlowColor
    let playerName: String
    let drawnCard: SpecialCardDefinition
    var onRevealed: (() -> Void)? = nil
    let onComplete: () -> Void

    @State private var backdropOpacity: Double = 0
    @State private var shuffleOffset: CGFloat = 0
    @State private var displayedShuffleIndex = 0
    @State private var isRevealed = false
    @State private var revealScale: CGFloat = 0.85
    @State private var revealOpacity: Double = 0
    @State private var shuffleTask: Task<Void, Never>?
    @State private var dismissTask: Task<Void, Never>?

    private let shufflePool = SpecialCardDefinition.allCards.shuffled()
    private let shuffleDuration: TimeInterval = 2.0

    var body: some View {
        ZStack {
            AppGradientBackground(glow: playerGlow)
                .opacity(backdropOpacity)

            Color.black.opacity(0.45 * backdropOpacity)
                .ignoresSafeArea()

            gridBackground
                .opacity(backdropOpacity * 0.35)

            VStack(spacing: 24) {
                Text(isRevealed ? "Wylosowano kartę!" : "Losowanie kart…")
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Text(playerName)
                    .font(.headline)
                    .foregroundStyle(.secondary)

                if isRevealed {
                    revealedCard
                } else {
                    shufflingCard
                }

                if isRevealed {
                    Button("Kontynuuj") {
                        settings.playTapSound()
                        onComplete()
                    }
                    .buttonStyle(.appProminent)
                    .padding(.horizontal, 24)
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .onAppear { runFlow() }
        .onDisappear {
            shuffleTask?.cancel()
            dismissTask?.cancel()
        }
    }

    private var gridBackground: some View {
        GeometryReader { geometry in
            let columns = 8
            let rows = 12
            Path { path in
                let colStep = geometry.size.width / CGFloat(columns)
                let rowStep = geometry.size.height / CGFloat(rows)
                for index in 0...columns {
                    let x = CGFloat(index) * colStep
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                }
                for index in 0...rows {
                    let y = CGFloat(index) * rowStep
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                }
            }
            .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
        .ignoresSafeArea()
    }

    private var shufflingCard: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(0..<9, id: \.self) { index in
                let card = shufflePool[(displayedShuffleIndex + index) % shufflePool.count]
                miniTile(card)
                    .scaleEffect(index == 4 ? 1.05 : 0.92)
                    .opacity(index == 4 ? 1 : 0.55)
            }
        }
        .padding(.horizontal, 8)
        .offset(x: shuffleOffset)
    }

    private func miniTile(_ card: SpecialCardDefinition) -> some View {
        VStack(spacing: 6) {
            Image(systemName: card.icon)
                .font(.title2)
                .foregroundStyle(card.isPositive ? Color.green : Color.red)
            Text(card.title)
                .font(.caption2.bold())
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 88)
        .background(
            LiquidGlassBackground(
                accentStroke: card.isPositive ? .green : .red,
                cornerRadius: 12
            )
        )
    }

    private var revealedCard: some View {
        cardTile(drawnCard, highlighted: true)
            .scaleEffect(revealScale)
            .opacity(revealOpacity)
    }

    private func cardTile(_ card: SpecialCardDefinition, highlighted: Bool) -> some View {
        VStack(spacing: 14) {
            Image(systemName: card.icon)
                .font(.system(size: 52, weight: .semibold))
                .foregroundStyle(card.isPositive ? Color.green : Color.red)

            Text(card.title)
                .font(.title3.bold())
                .multilineTextAlignment(.center)

            if highlighted {
                Text(card.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .frame(maxWidth: 320)
        .background(
            LiquidGlassBackground(
                accentStroke: card.isPositive ? .green : .red,
                cornerRadius: 20
            )
        )
    }

    private func runFlow() {
        withAnimation(.easeInOut(duration: 0.45)) {
            backdropOpacity = 1
        }

        shuffleTask = Task { @MainActor in
            let start = Date()
            var tickIndex = 0

            while !Task.isCancelled {
                let elapsed = Date().timeIntervalSince(start)
                if elapsed >= shuffleDuration { break }

                let phase = min(1, elapsed / shuffleDuration)

                withAnimation(.easeInOut(duration: 0.12)) {
                    shuffleOffset = shuffleOffset > 0 ? -14 : 14
                    displayedShuffleIndex += 1
                }

                settings.playDrawShuffleFeedback(tickIndex: tickIndex, phase: phase)
                tickIndex += 1

                try? await Task.sleep(for: .milliseconds(120))
            }

            guard !Task.isCancelled else { return }

            settings.playDrawRevealSound()

            withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
                isRevealed = true
                revealScale = 1
                revealOpacity = 1
            }
            onRevealed?()
        }

        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(6500))
            guard !Task.isCancelled, isRevealed else { return }
            onComplete()
        }
    }
}
