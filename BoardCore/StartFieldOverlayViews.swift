//
//  StartFieldOverlayViews.swift
//  BoardCore
//

import SwiftUI

enum StartFieldOverlayPhase: Equatable {
    case hidden
    case choosing
    case stayingReward(previousHealth: Int, newHealth: Int)
    case stayingFullHealthReward(previousFinances: Int, newFinances: Int, xpGained: Int)
    case passingCoinReward(previousFinances: Int, newFinances: Int)
    case passingDecisions
    case choiceEffectsReveal(ChoiceEffectsPresentation)
}

// MARK: - Liquid glass

struct LiquidGlassButton: View {
    @Environment(AppSettings.self) private var settings

    let title: String
    var prominent: Bool = false
    var isTrikiSelected: Bool = false
    var trikiChargeProgress: Double = 0
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(prominent ? .white : settings.accentColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background {
                    if prominent {
                        LiquidGlassProminentBackground(
                            accent: settings.accentColor,
                            cornerRadius: 20
                        )
                    } else {
                        LiquidGlassBackground(
                            accentStroke: settings.accentColor,
                            cornerRadius: 20
                        )
                    }
                }
        }
        .buttonStyle(.plain)
        .overlay {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(settings.accentColor.opacity(isTrikiSelected ? trikiChargeProgress * 0.44 : 0))
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        isTrikiSelected ? settings.accentColor.opacity(0.5 + trikiChargeProgress * 0.45) : .clear,
                        lineWidth: isTrikiSelected ? (2.0 + trikiChargeProgress * 1.5) : 0
                    )
            }
            .shadow(
                color: isTrikiSelected ? settings.accentColor.opacity(0.35 + trikiChargeProgress * 0.5) : .clear,
                radius: 6 + trikiChargeProgress * 12
            )
            .animation(.easeOut(duration: 0.12), value: trikiChargeProgress)
            .animation(.easeInOut(duration: 0.16), value: isTrikiSelected)
        }
    }
}

// MARK: - Full-screen overlay

struct StartFieldFullScreenOverlay: View {
    @Environment(AppSettings.self) private var settings

    let playerGlow: PlayerGlowColor
    let phase: StartFieldOverlayPhase
    let scene: CampaignScene?
    let decisionQuestion: String
    let priorInfluenceLines: [String]
    let choiceLabels: [String]
    var trikiHighlightIndex: Int? = nil
    var trikiHoldChargeProgress: Double = 0
    let onStay: () -> Void
    let onPass: () -> Void
    let onDismissStayReward: () -> Void
    let onDismissChoiceEffects: () -> Void
    let onSelectChoice: (Int, String) -> Void

    var body: some View {
        ZStack {
            AppGradientBackground(glow: playerGlow)
            Color.black.opacity(0.2)
                .ignoresSafeArea()

            switch phase {
            case .hidden:
                EmptyView()
            case .choosing:
                choosingContent
            case .stayingReward(let before, let after):
                stayingRewardContent(previous: before, new: after)
            case .stayingFullHealthReward(let before, let after, let xp):
                stayingFullHealthRewardContent(previousFinances: before, newFinances: after, xpGained: xp)
            case .passingCoinReward(let before, let after):
                passingCoinRewardContent(previous: before, new: after)
            case .passingDecisions:
                passingDecisionsContent
            case .choiceEffectsReveal(let presentation):
                ChoiceEffectsRevealView(
                    presentation: presentation,
                    isTrikiContinueSelected: trikiHighlightIndex == 0,
                    onContinue: onDismissChoiceEffects
                )
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }

    private var startFieldHeader: some View {
        HStack(spacing: 12) {
            Text("Pole start")
                .font(.largeTitle.bold())
            Image(systemName: "flag.checkered")
                .font(.title)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var choosingContent: some View {
        VStack(alignment: .leading, spacing: 28) {
            startFieldHeader
            Spacer(minLength: 0)
            VStack(spacing: 16) {
                LiquidGlassButton(
                    title: "Jestem na start",
                    prominent: true,
                    isTrikiSelected: trikiHighlightIndex == 0,
                    trikiChargeProgress: trikiHighlightIndex == 0 ? trikiHoldChargeProgress : 0,
                    action: onStay
                )
                LiquidGlassButton(
                    title: "Przechodzę przez start",
                    isTrikiSelected: trikiHighlightIndex == 1,
                    trikiChargeProgress: trikiHighlightIndex == 1 ? trikiHoldChargeProgress : 0,
                    action: onPass
                )
            }
            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func stayingRewardContent(previous: Int, new: Int) -> some View {
        StartFieldHealthRewardView(
            previousHealth: previous,
            newHealth: new,
            isTrikiContinueSelected: trikiHighlightIndex == 0,
            onContinue: onDismissStayReward
        )
    }

    private func stayingFullHealthRewardContent(
        previousFinances: Int,
        newFinances: Int,
        xpGained: Int
    ) -> some View {
        StartFieldStayFullHealthRewardView(
            previousFinances: previousFinances,
            newFinances: newFinances,
            xpGained: xpGained,
            isTrikiContinueSelected: trikiHighlightIndex == 0,
            onContinue: onDismissStayReward
        )
    }

    private func passingCoinRewardContent(previous: Int, new: Int) -> some View {
        StartFieldFinancesRewardView(
            previousFinances: previous,
            newFinances: new,
            isTrikiContinueSelected: trikiHighlightIndex == 0,
            onContinue: onDismissStayReward
        )
    }

    private var passingDecisionsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                startFieldHeader

                if let scene {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(scene.title)
                            .font(.title2.bold())
                        Text(scene.narrative)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        LiquidGlassBackground(
                            accentStroke: settings.accentColor,
                            cornerRadius: 16
                        )
                    )
                }

                if !priorInfluenceLines.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Wpływ wcześniejszych wyborów", systemImage: "person.2.fill")
                            .font(.headline)
                            .foregroundStyle(settings.accentColor)

                        ForEach(Array(priorInfluenceLines.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        LiquidGlassBackground(
                            accentStroke: settings.accentColor.opacity(0.7),
                            cornerRadius: 16
                        )
                    )
                }

                if !decisionQuestion.isEmpty {
                    Text(decisionQuestion)
                        .font(.headline)
                        .padding(.horizontal, 4)

                    if choiceLabels.isEmpty {
                        Text("Brak wyborów dla tego gracza w tej scenie.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(Array(choiceLabels.enumerated()), id: \.offset) { index, label in
                                LiquidGlassButton(
                                    title: label,
                                    isTrikiSelected: trikiHighlightIndex == index,
                                    trikiChargeProgress: trikiHighlightIndex == index ? trikiHoldChargeProgress : 0
                                ) {
                                    onSelectChoice(index, label)
                                }
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - Health reward

struct StartFieldHealthRewardView: View {
    @Environment(AppSettings.self) private var settings

    let previousHealth: Int
    let newHealth: Int
    var isTrikiContinueSelected: Bool = false
    let onContinue: () -> Void

    @State private var displayedHealth: Int
    @State private var ringScale: CGFloat = 0.88
    @State private var glowOpacity: Double = 0

    init(
        previousHealth: Int,
        newHealth: Int,
        isTrikiContinueSelected: Bool = false,
        onContinue: @escaping () -> Void
    ) {
        self.previousHealth = previousHealth
        self.newHealth = newHealth
        self.isTrikiContinueSelected = isTrikiContinueSelected
        self.onContinue = onContinue
        _displayedHealth = State(initialValue: previousHealth)
    }

    private var bonus: Int { max(newHealth - previousHealth, 0) }

    var body: some View {
        VStack(spacing: 28) {
            HStack(spacing: 12) {
                Text("Pole start")
                    .font(.largeTitle.bold())
                Image(systemName: "flag.checkered")
                    .font(.title)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            VStack(spacing: 16) {
                Text("Odnawiasz siły")
                    .font(.title2.bold())
                Text("+\(bonus) zdrowia (+20%)")
                    .font(.title3)
                    .foregroundStyle(.green)
                    .contentTransition(.numericText())

                ZStack {
                    Circle()
                        .fill(Color.green.opacity(glowOpacity * 0.35))
                        .frame(width: 140, height: 140)
                        .blur(radius: 10)

                    VStack(spacing: 10) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 56, weight: .bold))
                            .foregroundStyle(.green)
                            .shadow(color: .green.opacity(0.55), radius: 12)

                        Text("\(displayedHealth)")
                            .font(.system(size: 44, weight: .heavy, design: .rounded))
                            .foregroundStyle(.green)
                            .monospacedDigit()
                            .contentTransition(.numericText())

                        Text("zdrowia")
                            .font(.headline.bold())
                            .foregroundStyle(.secondary)
                    }
                    .scaleEffect(ringScale)
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity)
            .background(
                LiquidGlassBackground(
                    accentStroke: settings.accentColor,
                    cornerRadius: 20
                )
            )

            Spacer(minLength: 0)

            LiquidGlassButton(
                title: "Kontynuuj grę",
                prominent: true,
                isTrikiSelected: isTrikiContinueSelected,
                action: onContinue
            )
        }
        .padding(24)
        .onAppear {
            withAnimation(.spring(response: 0.85, dampingFraction: 0.72)) {
                ringScale = 1.06
                glowOpacity = 1
            }
            withAnimation(.easeOut(duration: 1.1).delay(0.15)) {
                displayedHealth = newHealth
                ringScale = 1
            }
            withAnimation(.easeInOut(duration: 0.9).delay(0.5)) {
                glowOpacity = 0.35
            }
        }
    }
}

// MARK: - Pełne zdrowie na starcie

struct StartFieldStayFullHealthRewardView: View {
    @Environment(AppSettings.self) private var settings

    let previousFinances: Int
    let newFinances: Int
    let xpGained: Int
    var isTrikiContinueSelected: Bool = false
    let onContinue: () -> Void

    @State private var displayedFinances: Int
    @State private var heartScale: CGFloat = 0.88
    @State private var glowOpacity: Double = 0

    init(
        previousFinances: Int,
        newFinances: Int,
        xpGained: Int,
        isTrikiContinueSelected: Bool = false,
        onContinue: @escaping () -> Void
    ) {
        self.previousFinances = previousFinances
        self.newFinances = newFinances
        self.xpGained = xpGained
        self.isTrikiContinueSelected = isTrikiContinueSelected
        self.onContinue = onContinue
        _displayedFinances = State(initialValue: previousFinances)
    }

    private var coinBonus: Int { max(newFinances - previousFinances, 0) }

    var body: some View {
        VStack(spacing: 28) {
            HStack(spacing: 12) {
                Text("Pole start")
                    .font(.largeTitle.bold())
                Image(systemName: "flag.checkered")
                    .font(.title)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            VStack(spacing: 16) {
                Text("Pełne zdrowie!")
                    .font(.title2.bold())

                Image(systemName: "heart.fill")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(.green)
                    .shadow(color: .green.opacity(0.5), radius: 14)
                    .scaleEffect(heartScale)

                VStack(spacing: 8) {
                    Text("+\(coinBonus) monet")
                        .font(.title3.bold())
                        .foregroundStyle(.yellow)
                    Text("+\(xpGained) XP")
                        .font(.title3.bold())
                        .foregroundStyle(settings.accentColor)
                    Text("\(displayedFinances) monet łącznie")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity)
            .background(
                LiquidGlassBackground(
                    accentStroke: .green.opacity(0.85),
                    cornerRadius: 20
                )
            )

            Spacer(minLength: 0)

            LiquidGlassButton(
                title: "Kontynuuj grę",
                prominent: true,
                isTrikiSelected: isTrikiContinueSelected,
                action: onContinue
            )
        }
        .padding(24)
        .onAppear {
            withAnimation(.spring(response: 0.85, dampingFraction: 0.72)) {
                heartScale = 1.08
                glowOpacity = 1
            }
            withAnimation(.easeOut(duration: 1.0).delay(0.12)) {
                displayedFinances = newFinances
                heartScale = 1
            }
        }
    }
}

// MARK: - Finances reward (przejście przez start bez kampanii)

struct StartFieldFinancesRewardView: View {
    @Environment(AppSettings.self) private var settings

    let previousFinances: Int
    let newFinances: Int
    var isTrikiContinueSelected: Bool = false
    let onContinue: () -> Void

    @State private var displayedFinances: Int
    @State private var ringScale: CGFloat = 0.88
    @State private var glowOpacity: Double = 0
    @State private var bonusOpacity: Double = 0

    init(
        previousFinances: Int,
        newFinances: Int,
        isTrikiContinueSelected: Bool = false,
        onContinue: @escaping () -> Void
    ) {
        self.previousFinances = previousFinances
        self.newFinances = newFinances
        self.isTrikiContinueSelected = isTrikiContinueSelected
        self.onContinue = onContinue
        _displayedFinances = State(initialValue: previousFinances)
    }

    private var bonus: Int { max(newFinances - previousFinances, 0) }

    var body: some View {
        VStack(spacing: 28) {
            HStack(spacing: 12) {
                Text("Pole start")
                    .font(.largeTitle.bold())
                Image(systemName: "flag.checkered")
                    .font(.title)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            VStack(spacing: 16) {
                Text("Przechodzisz przez start")
                    .font(.title2.bold())

                Text("+\(bonus) monet")
                    .font(.title3.bold())
                    .foregroundStyle(.yellow)
                    .opacity(bonusOpacity)

                ZStack {
                    Circle()
                        .fill(Color.yellow.opacity(glowOpacity * 0.28))
                        .frame(width: 120, height: 120)
                        .blur(radius: 8)

                    VStack(spacing: 6) {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.system(size: 44, weight: .bold))
                            .foregroundStyle(.yellow)
                        Text("\(displayedFinances)")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text("monet")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                    .scaleEffect(ringScale)
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity)
            .background(
                LiquidGlassBackground(
                    accentStroke: settings.accentColor,
                    cornerRadius: 20
                )
            )

            Spacer(minLength: 0)

            LiquidGlassButton(
                title: "Kontynuuj grę",
                prominent: true,
                isTrikiSelected: isTrikiContinueSelected,
                action: onContinue
            )
        }
        .padding(24)
        .onAppear {
            withAnimation(.spring(response: 0.85, dampingFraction: 0.72)) {
                ringScale = 1.06
                glowOpacity = 1
                bonusOpacity = 1
            }
            withAnimation(.easeOut(duration: 1.1).delay(0.15)) {
                displayedFinances = newFinances
                ringScale = 1
            }
            withAnimation(.easeInOut(duration: 0.9).delay(0.5)) {
                glowOpacity = 0.35
            }
        }
    }
}

// MARK: - Skutki wyboru (najpierw negatywne, potem pozytywne)

struct ChoiceEffectsRevealView: View {
    @Environment(AppSettings.self) private var settings

    let presentation: ChoiceEffectsPresentation
    var isTrikiContinueSelected: Bool = false
    let onContinue: () -> Void

    @State private var showPositive = false
    @State private var negativeOpacity: Double = 0
    @State private var positiveOpacity: Double = 0

    var body: some View {
        VStack(spacing: 24) {
            Text("Skutki decyzji")
                .font(.largeTitle.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(presentation.choiceTitle)
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 16) {
                effectsBlock(
                    title: "Straty i ryzyko",
                    icon: "exclamationmark.triangle.fill",
                    tint: .red,
                    entries: presentation.negativeEntries,
                    opacity: negativeOpacity
                )

                if showPositive {
                    effectsBlock(
                        title: "Korzyści",
                        icon: "sparkles",
                        tint: .green,
                        entries: presentation.positiveEntries,
                        opacity: positiveOpacity
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            Spacer(minLength: 0)

            if showPositive {
                LiquidGlassButton(
                    title: "Kontynuuj — następna tura",
                    prominent: true,
                    isTrikiSelected: isTrikiContinueSelected,
                    action: onContinue
                )
                .transition(.opacity)
            }
        }
        .padding(24)
        .onAppear {
            withAnimation(.easeOut(duration: 0.55)) {
                negativeOpacity = 1
            }
            Task {
                try? await Task.sleep(for: .seconds(1.35))
                await MainActor.run {
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                        showPositive = true
                    }
                    withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                        positiveOpacity = 1
                    }
                }
            }
        }
    }

    private func effectsBlock(
        title: String,
        icon: String,
        tint: Color,
        entries: [ChoiceEffectEntry],
        opacity: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(tint)

            ForEach(entries) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text(entry.detail)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LiquidGlassBackground(
                accentStroke: settings.accentColor,
                cornerRadius: 16
            )
        )
        .opacity(opacity)
    }
}
