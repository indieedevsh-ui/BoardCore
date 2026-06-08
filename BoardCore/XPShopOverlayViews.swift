//
//  XPShopOverlayViews.swift
//  BoardCore
//

import SwiftUI

enum XPShopUnluckyKind: String, CaseIterable, Equatable {
    case halveFinances
    case queueBlock
    case weakenStrength
    case loseRandomAbility
    case halveStrength
    case halveHealth
    case removeRandomItem

    var shuffleTitle: String {
        switch self {
        case .halveFinances: "−50% monet"
        case .queueBlock: "Blokada kolejki"
        case .weakenStrength: "Osłabienie siły"
        case .loseRandomAbility: "Utrata zdolności"
        case .halveStrength: "−50% siły"
        case .halveHealth: "−50% zdrowia"
        case .removeRandomItem: "Utrata przedmiotu"
        }
    }

    var icon: String {
        switch self {
        case .halveFinances: "dollarsign.circle.fill"
        case .queueBlock: "hourglass.circle.fill"
        case .weakenStrength: "bolt.trianglebadge.exclamationmark.fill"
        case .loseRandomAbility: "sparkles.slash"
        case .halveStrength: "figure.arms.open"
        case .halveHealth: "heart.slash.fill"
        case .removeRandomItem: "bag.badge.minus"
        }
    }
}

struct XPShopFiftyFiftyRoll: Equatable {
    enum Kind: Equatable {
        case ability(GameplaySessionAbility)
        case emptyAbilityPool
        case unlucky(XPShopUnluckyKind)
    }

    let kind: Kind
}

struct XPShopRandomAbilityRoll: Equatable {
    enum Kind: Equatable {
        case ability(GameplaySessionAbility)
        case emptyPool
    }

    let kind: Kind
}

enum XPShopOverlayPhase: Equatable {
    case hidden
    case menu
    case drawingFiftyFifty(XPShopFiftyFiftyRoll)
    case drawingRandomAbility(XPShopRandomAbilityRoll)
    case revealedFiftyFifty(XPShopFiftyFiftyRoll)
    case revealedRandomAbility(XPShopRandomAbilityRoll)
}

struct XPShopFullScreenOverlay: View {
    @Environment(AppSettings.self) private var settings

    let playerGlow: PlayerGlowColor
    let phase: XPShopOverlayPhase
    let playerName: String
    let experiencePoints: Int
    let fiftyFiftyCost: Int
    let randomAbilityCost: Int
    let shuffleAbilities: [GameplaySessionAbility]
    let onFiftyFifty: () -> Void
    let onBuyRandomAbility: () -> Void
    let onDrawRevealed: () -> Void
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
                        case .drawingFiftyFifty(let roll):
                            XPShopDrawAnimationView(
                                mode: .fiftyFifty(roll.kind),
                                playerGlow: playerGlow,
                                playerName: playerName,
                                shuffleAbilities: shuffleAbilities,
                                onRevealed: onDrawRevealed
                            )
                        case .drawingRandomAbility(let roll):
                            XPShopDrawAnimationView(
                                mode: .randomAbility(roll.kind),
                                playerGlow: playerGlow,
                                playerName: playerName,
                                shuffleAbilities: shuffleAbilities,
                                onRevealed: onDrawRevealed
                            )
                        case .revealedFiftyFifty(let roll):
                            XPShopRevealedView(
                                mode: .fiftyFifty(roll.kind),
                                playerGlow: playerGlow,
                                playerName: playerName
                            )
                        case .revealedRandomAbility(let roll):
                            XPShopRevealedView(
                                mode: .randomAbility(roll.kind),
                                playerGlow: playerGlow,
                                playerName: playerName
                            )
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
            Label("Sklepik XP", systemImage: "star.circle.fill")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text(playerName)
                .font(.headline)
                .foregroundStyle(.secondary)

            if case .menu = phase {
                Text("Dostępne XP: \(experiencePoints)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(playerGlow.accentColor)
            }
        }
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    private var menuContent: some View {
        VStack(spacing: 14) {
            xpShopButton(
                title: "50 na 50",
                subtitle: "Szansa na losową zdolność albo pechowy los",
                cost: fiftyFiftyCost,
                icon: "dice.fill",
                action: onFiftyFifty,
                highlightIndex: 0
            )

            xpShopButton(
                title: "Kup Losową Zdolność",
                subtitle: "Gwarantowana zdolność z puli sesji",
                cost: randomAbilityCost,
                icon: "sparkles",
                action: onBuyRandomAbility,
                highlightIndex: 1
            )
        }
    }

    private func xpShopButton(
        title: String,
        subtitle: String,
        cost: Int,
        icon: String,
        action: @escaping () -> Void,
        highlightIndex: Int
    ) -> some View {
        let canAfford = experiencePoints >= cost
        let isHighlighted = trikiHighlightIndex == highlightIndex

        return Button {
            settings.playTapSound()
            action()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(playerGlow.accentColor)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                    Text("Koszt: \(cost) XP")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(canAfford ? playerGlow.accentColor : .red.opacity(0.85))
                }

                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LiquidGlassBackground(
                    accentStroke: isHighlighted ? playerGlow.accentColor : .white.opacity(0.2),
                    cornerRadius: 14
                )
            )
        }
        .buttonStyle(.plain)
        .disabled(!canAfford)
        .opacity(canAfford ? 1 : 0.55)
    }

    private var footer: some View {
        Group {
            if showsExitFooter {
                Button {
                    settings.playTapSound()
                    onExit()
                } label: {
                    Text("Wyjdź")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.appSecondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
            }
        }
    }

    private var showsExitFooter: Bool {
        switch phase {
        case .menu, .revealedFiftyFifty, .revealedRandomAbility:
            return true
        default:
            return false
        }
    }
}

// MARK: - Revealed outcome

private struct XPShopRevealedView: View {
    let mode: XPShopDrawMode
    let playerGlow: PlayerGlowColor
    let playerName: String

    var body: some View {
        VStack(spacing: 24) {
            Text(headerTitle)
                .font(.title2.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(playerName)
                .font(.headline)
                .foregroundStyle(.secondary)

            XPShopOutcomeTileView(tile: revealedTile, highlighted: true)
                .frame(maxWidth: 280)
        }
        .padding(.vertical, 8)
    }

    private var headerTitle: String {
        switch mode {
        case .fiftyFifty(let kind):
            switch kind {
            case .ability, .emptyAbilityPool: return "Zdobyta Zdolność"
            case .unlucky: return "Pechowy los!"
            }
        case .randomAbility(let kind):
            switch kind {
            case .ability: return "Zdobyta Zdolność"
            case .emptyPool: return "Brak zdolności"
            }
        }
    }

    private var revealedTile: XPShopShuffleTile {
        XPShopShuffleTile.make(for: mode)
    }
}

// MARK: - Draw animation

private enum XPShopDrawMode: Equatable {
    case fiftyFifty(XPShopFiftyFiftyRoll.Kind)
    case randomAbility(XPShopRandomAbilityRoll.Kind)
}

private struct XPShopDrawAnimationView: View {
    @Environment(AppSettings.self) private var settings

    let mode: XPShopDrawMode
    let playerGlow: PlayerGlowColor
    let playerName: String
    let shuffleAbilities: [GameplaySessionAbility]
    let onRevealed: () -> Void

    @State private var backdropOpacity: Double = 0
    @State private var shuffleOffset: CGFloat = 0
    @State private var displayedIndex = 0
    @State private var showLuckySide = true
    @State private var isRevealed = false
    @State private var revealScale: CGFloat = 0.85
    @State private var revealOpacity: Double = 0
    @State private var shuffleTask: Task<Void, Never>?

    private let shuffleDuration: TimeInterval = 2.0

    private var isFiftyFifty: Bool {
        if case .fiftyFifty = mode { return true }
        return false
    }

    private var shufflePool: [XPShopShuffleTile] {
        var tiles: [XPShopShuffleTile] = shuffleAbilities.map { ability in
            XPShopShuffleTile(
                title: ability.name,
                subtitle: ability.kindLabel,
                icon: XPShopShuffleTile.abilityIcon(for: ability),
                accent: .green
            )
        }
        if isFiftyFifty {
            tiles += XPShopUnluckyKind.allCases.map { kind in
                XPShopShuffleTile(
                    title: kind.shuffleTitle,
                    subtitle: "Pechowy los",
                    icon: kind.icon,
                    accent: .red
                )
            }
        }
        if tiles.isEmpty {
            tiles = [
                XPShopShuffleTile(title: "Zdolność", subtitle: "Losowanie…", icon: "sparkles", accent: .green),
                XPShopShuffleTile(title: "Pech", subtitle: "Losowanie…", icon: "exclamationmark.triangle.fill", accent: .red),
            ]
        }
        return tiles
    }

    var body: some View {
        VStack(spacing: 24) {
            Text(headerTitle)
                .font(.title2.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(playerName)
                .font(.headline)
                .foregroundStyle(.secondary)

            if isRevealed {
                XPShopOutcomeTileView(tile: revealedShuffleTile, highlighted: true)
                    .scaleEffect(revealScale)
                    .opacity(revealOpacity)
                    .frame(maxWidth: 280)
            } else {
                shufflingGrid
            }
        }
        .padding(.vertical, 8)
        .onAppear { runFlow() }
        .onDisappear { shuffleTask?.cancel() }
    }

    private var headerTitle: String {
        if isRevealed {
            switch mode {
            case .fiftyFifty(let kind):
                switch kind {
                case .ability, .emptyAbilityPool: return "Zdobyta Zdolność"
                case .unlucky: return "Pechowy los!"
                }
            case .randomAbility(let kind):
                switch kind {
                case .ability: return "Zdobyta Zdolność"
                case .emptyPool: return "Brak zdolności"
                }
            }
        }
        switch mode {
        case .fiftyFifty: return "Losowanie 50 na 50…"
        case .randomAbility: return "Losowanie zdolności…"
        }
    }

    private var shufflingGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(0..<9, id: \.self) { index in
                let tile = currentShuffleTile(for: index)
                XPShopOutcomeTileView(tile: tile, highlighted: false)
                    .scaleEffect(index == 4 ? 1.05 : 0.92)
                    .opacity(index == 4 ? 1 : 0.55)
            }
        }
        .padding(.horizontal, 4)
        .offset(x: shuffleOffset)
    }

    private func currentShuffleTile(for index: Int) -> XPShopShuffleTile {
        let pool = shufflePool
        let offset = displayedIndex + index + (showLuckySide ? 0 : pool.count / 2)
        return pool[offset % pool.count]
    }

    private var revealedShuffleTile: XPShopShuffleTile {
        XPShopShuffleTile.make(for: mode)
    }

    private func runFlow() {
        withAnimation(.easeInOut(duration: 0.35)) {
            backdropOpacity = 1
        }

        shuffleTask = Task { @MainActor in
            let start = Date()
            var tickIndex = 0

            while !Task.isCancelled {
                let elapsed = Date().timeIntervalSince(start)
                if elapsed >= shuffleDuration { break }

                let phase = min(1, elapsed / shuffleDuration)

                withAnimation(.easeInOut(duration: 0.1)) {
                    shuffleOffset = shuffleOffset > 0 ? -12 : 12
                    displayedIndex += 1
                    if isFiftyFifty {
                        showLuckySide.toggle()
                    }
                }

                settings.playDrawShuffleFeedback(tickIndex: tickIndex, phase: phase)
                tickIndex += 1

                try? await Task.sleep(for: .milliseconds(isFiftyFifty ? 100 : 110))
            }

            guard !Task.isCancelled else { return }

            settings.playDrawRevealSound()

            withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
                isRevealed = true
                revealScale = 1
                revealOpacity = 1
            }

            try? await Task.sleep(for: .milliseconds(1200))
            guard !Task.isCancelled else { return }
            onRevealed()
        }
    }
}

private struct XPShopShuffleTile {
    enum Accent {
        case green, red, orange

        var color: Color {
            switch self {
            case .green: .green
            case .red: .red
            case .orange: .orange
            }
        }
    }

    let title: String
    let subtitle: String
    let icon: String
    let accent: Accent

    static func abilityIcon(for ability: GameplaySessionAbility) -> String {
        switch ability.kind {
        case .turnDamage: "bolt.fill"
        case .temporaryStatBoost: "heart.fill"
        case .boardMove: "sparkles"
        }
    }

    static func make(for mode: XPShopDrawMode) -> XPShopShuffleTile {
        switch mode {
        case .fiftyFifty(let kind):
            switch kind {
            case .ability(let ability):
                return XPShopShuffleTile(
                    title: ability.name,
                    subtitle: ability.effectDescription,
                    icon: abilityIcon(for: ability),
                    accent: .green
                )
            case .emptyAbilityPool:
                return XPShopShuffleTile(
                    title: "Pusta pula",
                    subtitle: "Brak wolnych zdolności",
                    icon: "sparkles",
                    accent: .orange
                )
            case .unlucky(let kind):
                return XPShopShuffleTile(
                    title: kind.shuffleTitle,
                    subtitle: "Pechowy los",
                    icon: kind.icon,
                    accent: .red
                )
            }
        case .randomAbility(let kind):
            switch kind {
            case .ability(let ability):
                return XPShopShuffleTile(
                    title: ability.name,
                    subtitle: ability.effectDescription,
                    icon: abilityIcon(for: ability),
                    accent: .green
                )
            case .emptyPool:
                return XPShopShuffleTile(
                    title: "Pusta pula",
                    subtitle: "Brak wolnych zdolności",
                    icon: "sparkles",
                    accent: .orange
                )
            }
        }
    }
}

private struct XPShopOutcomeTileView: View {
    let tile: XPShopShuffleTile
    var highlighted: Bool

    var body: some View {
        VStack(spacing: highlighted ? 10 : 6) {
            Image(systemName: tile.icon)
                .font(highlighted ? .system(size: 44, weight: .semibold) : .title2)
                .foregroundStyle(tile.accent.color)
            Text(tile.title)
                .font(highlighted ? .title3.bold() : .caption2.bold())
                .lineLimit(highlighted ? 3 : 2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
            if highlighted {
                Text(tile.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(highlighted ? 22 : 10)
        .frame(maxWidth: .infinity, minHeight: highlighted ? nil : 88)
        .background(
            LiquidGlassBackground(
                accentStroke: tile.accent.color,
                cornerRadius: highlighted ? 18 : 12
            )
        )
    }
}
